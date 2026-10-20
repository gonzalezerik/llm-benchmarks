#!/usr/bin/env bash
# Laptop (ASUS ProArt PX13, Ryzen AI Max+ 395 / Radeon 8060S, 128 GB) bench: Maya-S and Halogen at the 60 / 70 / 85 W AC Performance
# limits. Each run: set PPT, wait for Tctl < 55 C, start the engine fresh, wait for a real answer, client.py, stop.
# A 1 s logger records PPT / Tctl / GPU sclk / GPU busy for the whole run (power-<name>.csv).
S=$(dirname "$(readlink -f "$0")"); OUT=$S/out; mkdir -p "$OUT"
MAYA=$HOME/.local/share/maya/project-maya
export BENCH_LONG_SRC="$S/longsrc/src/**/*.c*"     # the same prompt text as the 7950x-2xa100-3090 runs (Maya v1.1.17 src/)
gufo_was=$(systemctl --user is-active gufo.service)   # another LLM server on the same iGPU: stopped for the runs, restarted after
systemctl --user stop gufo.service halogen.service maya.service 2>/dev/null

# Maya-S bench config: the live one without kept conversations / usage learning, own log
python3 - "$MAYA" "$OUT" <<'PY'
import json, sys
maya, out = sys.argv[1:3]
c = json.load(open(f"{maya}/maya-config.json"))
for k in ("STRATA_GLM_SLOT_KEEP", "STRATA_GLM_USAGE"): c["env"].pop(k, None)
c["log"] = f"{maya}/bench-power.log"
json.dump(c, open(f"{maya}/bench-power.json", "w"), indent=1)
json.dump(c, open(f"{out}/cfg-maya-s.json", "w"), indent=1)
PY

set_ppt() {   # sustained / slow boost / fast boost
  asusctl armoury set ppt_pl1_spl "$1" >/dev/null; asusctl armoury set ppt_pl2_sppt "$2" >/dev/null
  asusctl armoury set ppt_pl3_fppt "$3" >/dev/null
  echo "$(cat /sys/class/firmware-attributes/*/attributes/ppt_pl1_spl/current_value)/$(cat /sys/class/firmware-attributes/*/attributes/ppt_pl2_sppt/current_value)/$(cat /sys/class/firmware-attributes/*/attributes/ppt_pl3_fppt/current_value)"
}
tctl() { sensors -j 2>/dev/null | python3 -c "import json,sys; print(int(json.load(sys.stdin)['k10temp-pci-00c3']['Tctl']['temp1_input']))"; }
logger() {    # $1 csv
  echo "t,ppt_w,tctl_c,sclk_mhz,gpu_busy" > "$1"
  while :; do
    sensors -j 2>/dev/null | python3 -c "
import json,sys,time
d=json.load(sys.stdin); g=d['amdgpu-pci-c400']
busy=open('/sys/class/drm/card1/device/gpu_busy_percent').read().strip()
print(f\"{time.time():.0f},{g['PPT']['power1_average']:.1f},{d['k10temp-pci-00c3']['Tctl']['temp1_input']:.1f},{g['sclk']['freq1_input']/1e6:.0f},{busy}\")" >> "$1"
    sleep 1
  done
}
ready() { curl -sf -m 900 "localhost:$1/v1/messages" -H 'content-type: application/json' \
  -d '{"model":"x","max_tokens":1,"thinking":{"type":"disabled"},"messages":[{"role":"user","content":"hi"}]}' >/dev/null; }
start_engine() {
  case $1 in
    maya-s) podman run -d --rm --replace --name maya-bench --network host --device /dev/kfd --device /dev/dri \
              --group-add keep-groups --ipc=host --ulimit memlock=-1:-1 -e HOME="$HOME/.local/share/maya/home" \
              -v "$HOME/.local/share/maya:$HOME/.local/share/maya" -v "$HOME/models/glm-5.3-flash/maya:$HOME/models/glm-5.3-flash/maya" \
              -w "$MAYA" docker.io/library/maya-rocm:7.14.1 ./maya.sh --config bench-power.json --plain >/dev/null; echo 8742 ;;
    halogen) systemctl --user start halogen.service; echo 8731 ;;
  esac
}
stop_engine() { case $1 in maya-s) podman stop -t 60 maya-bench >/dev/null 2>&1 ;; halogen) systemctl --user stop halogen.service ;; esac; }

for watts in "60 70 85" "70 80 95" "85 95 115"; do
  set -- $watts; pl1=$1
  for eng in maya-s halogen; do
    name=${eng}_${pl1}w
    until [ "$(tctl)" -lt 55 ]; do sleep 10; done
    ppt=$(set_ppt $watts)
    logger "$OUT/power-$name.csv" & lg=$!
    t0=$(date +%s); port=$(start_engine $eng)
    ok=0; for _ in $(seq 120); do ready "$port" && { ok=1; break; }; sleep 10; done
    load=$(( $(date +%s) - t0 ))
    case $eng in halogen) export BENCH_SAMPLING='{"temperature": 1.0, "top_p": 0.95, "top_k": 20}' ;; *) export BENCH_SAMPLING='{}' ;; esac
    tb=$(date +%s)
    if [ $ok = 1 ]; then res=$(python3 "$S/client.py" "http://127.0.0.1:$port" 2>&1 | tail -1); else res='{"error": "did not start"}'; fi
    te=$(date +%s)
    kill $lg; stop_engine $eng
    pw=$(python3 - "$OUT/power-$name.csv" "$tb" "$te" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if sys.argv[2] <= r["t"] <= sys.argv[3]]
busy = [r for r in rows if int(r["gpu_busy"]) >= 50]
p = [float(r["ppt_w"]) for r in busy] or [0]
low = sum(1 for r in busy if float(r["ppt_w"]) < 40)
print(f"ppt_mean {sum(p)/len(p):.1f} ppt_max {max(p):.1f} tctl_max {max(float(r['tctl_c']) for r in rows):.0f} "
      f"sclk_mean {sum(int(r['sclk_mhz']) for r in busy)/max(1,len(busy)):.0f} busy_s {len(busy)} below40w_s {low}")
PY
)
    echo -e "$name\tppt $ppt\tload ${load}s\t$pw\t$res" | tee -a "$OUT/results.tsv"
  done
done
set_ppt 70 80 95 >/dev/null          # back to the AC Performance setting it had
[ "$gufo_was" = active ] && systemctl --user start gufo.service
echo "=== $(date +%T) done (PPT back to 70/80/95, gufo $gufo_was -> $(systemctl --user is-active gufo.service))" >> "$OUT/results.tsv"
