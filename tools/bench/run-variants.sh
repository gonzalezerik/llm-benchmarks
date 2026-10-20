#!/usr/bin/env bash
# Runs a list of engine configurations one after another and measures each with client.py.
#
#   run-variants.sh VARIANTS_FILE
#
# VARIANTS_FILE: one variant per line, "engine|name|ENV=V ENV2=V|--extra args"
#   engine  maya   GLM-5.3-Flash on Project Maya       (base config: $MAYA_BASE)
#           ds4    DeepSeek-V4.1-Flash on Project Maya (base config: $DS4_BASE)
#           strata Qwen3.8-Flash-Next on Strata        (base config: $STRATA_BASE, or $STRATA_BASE_Q8 when the name has "q8")
#           llama  llama.cpp's llama-server            (the command line in $LLAMA_CMD)
#   env     environment variables added to the config's "env" block ("NAME=-" removes one)
#   args    engine arguments: "--flag value" replaces that flag's value or appends it, "--flag -" removes it
# A name ending in _t07 / _t10 sends that sampling with every request (see client.py); otherwise the server's defaults.
#
# Per variant: wait until the GPUs are free, drop the page cache, start the engine in the CUDA container, wait for a
# real 1-token answer, run client.py, stop the engine. A watchdog stops the engine if MemAvailable falls under
# 1.5 GB (pinned RAM tiers can take a box down otherwise) and records the lowest MemAvailable seen.
# Output: one line per variant in $OUT/results.tsv; the generated configs and logs next to it.
set -u

# ---- paths (mine; change them for your box) -------------------------------------------------------------------------
OUT=${OUT:-/data/bench}                                   # results, generated configs, logs
MAYA_DIR=${MAYA_DIR:-/data/maya/project-maya}             # Project Maya checkout (engine built in build/)
STRATA_DIR=${STRATA_DIR:-/data/strata/Strata}             # Strata checkout (engine in build/, packs/, mtp/rt)
MAYA_BASE=${MAYA_BASE:-$MAYA_DIR/maya-l.json}             # configs written by Maya's setup / by hand
DS4_BASE=${DS4_BASE:-$MAYA_DIR/maya-ds4.json}
STRATA_BASE=${STRATA_BASE:-$OUT/strata-q4.json}
STRATA_BASE_Q8=${STRATA_BASE_Q8:-$OUT/strata-q8.json}
MODELS=${MODELS:-/data/models}                            # mounted into the container as-is
IMG=${IMG:-localhost/maya-cuda:13.4.3}                    # see the hardware page: nvidia/cuda:13.4.3-devel-ubuntu24.04 + python/cmake
LLAMA_CMD=${LLAMA_CMD:-}                                  # e.g. "llama-server -m ... --port 8005"
LLAMA_PORT=${LLAMA_PORT:-8005}
CLIENT=$(dirname "$(readlink -f "$0")")/client.py
# ----------------------------------------------------------------------------------------------------------------------

mkdir -p "$OUT"
POD="podman run -d --replace --rm --name bench --dns-search=. --device nvidia.com/gpu=all --ipc host --network host
     --ulimit memlock=-1:-1 -v $MODELS:$MODELS -v $OUT:$OUT"
gpus_free() { [ "$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{s+=$1} END {print s}')" -lt 2000 ]; }
running() { if [ "$1" = llama ]; then [ -n "${LLAMA_PID:-}" ] && kill -0 "$LLAMA_PID" 2>/dev/null; else podman container exists bench; fi; }
stop_it() {
  if [ "$1" = llama ]; then kill "$LLAMA_PID" 2>/dev/null; while kill -0 "$LLAMA_PID" 2>/dev/null; do sleep 1; done
  else podman stop -t 60 bench >/dev/null 2>&1; fi
}
watchdog() {   # $1 engine, $2 name
  local min=999999 a
  while running "$1"; do
    a=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    [ "$a" -lt "$min" ] && min=$a && echo "$min" > "$OUT/minavail-$2"
    if [ "$a" -lt 1500 ]; then echo "WATCHDOG stop at ${a} MiB" >> "$OUT/log-$2.txt"; stop_it "$1"; podman kill bench 2>/dev/null; fi
    sleep 1
  done
}
ready() { curl -sf -m 600 "localhost:$1/v1/messages" -H 'content-type: application/json' \
  -d '{"model":"x","max_tokens":1,"thinking":{"type":"disabled"},"messages":[{"role":"user","content":"hi"}]}' >/dev/null; }
mkcfg() {   # engine name env args -> path of the generated config
  OUT=$OUT MAYA_BASE=$MAYA_BASE DS4_BASE=$DS4_BASE STRATA_BASE=$STRATA_BASE STRATA_BASE_Q8=$STRATA_BASE_Q8 python3 - "$@" <<'PY'
import json, os, sys
eng, name, envs, args = sys.argv[1:5]
base = {"maya": os.environ["MAYA_BASE"], "ds4": os.environ["DS4_BASE"],
        "strata": os.environ["STRATA_BASE_Q8"] if "q8" in name else os.environ["STRATA_BASE"]}[eng]
c = json.load(open(base)); c.setdefault("env", {})
c["log"] = f"{os.environ['OUT']}/engine-{name}.log"
for k in ("STRATA_GLM_SLOT_KEEP", "STRATA_GLM_USAGE"):   # no kept conversations / usage learning between variants
    c["env"].pop(k, None)
for kv in filter(None, envs.split()):
    k, v = kv.split("=", 1)
    if v == "-": c["env"].pop(k, None)
    else: c["env"][k] = v
extra = args.split()
while extra:
    f = extra.pop(0); v = extra.pop(0) if extra and not extra[0].startswith("--") else None
    if f in c["args"]:
        i = c["args"].index(f)
        if v == "-": del c["args"][i:i + 2]
        elif v is not None: c["args"][i + 1] = v
    else: c["args"] += [f] + ([v] if v is not None else [])
p = f"{os.environ['OUT']}/cfg-{name}.json"; json.dump(c, open(p, "w"), indent=1); print(p)
PY
}

while IFS='|' read -r eng name envs args; do
  [ -z "$eng" ] || [[ $eng == \#* ]] && continue
  while running maya || ! gpus_free; do sleep 5; done
  sync; echo 3 | sudo -n tee /proc/sys/vm/drop_caches >/dev/null
  t0=$(date +%s); port=8090
  case $eng in
    maya|ds4)
      cfg=$(mkcfg "$eng" "$name" "$envs" "$args")
      $POD -v "$MAYA_DIR:$MAYA_DIR" -e HOME="$OUT/home" -w "$MAYA_DIR" "$IMG" ./maya.sh --config "$cfg" --port 8090 --plain >/dev/null ;;
    strata)
      cfg=$(mkcfg strata "$name" "$envs" "$args")
      $POD -v "$STRATA_DIR:$STRATA_DIR" -w "$STRATA_DIR" "$IMG" \
        .venv/bin/python -m serve.server --engine strata --config "$cfg" --host 127.0.0.1 --port 8090 >/dev/null ;;
    llama)
      port=$LLAMA_PORT; nohup $LLAMA_CMD > "$OUT/log-$name.txt" 2>&1 & LLAMA_PID=$! ;;
  esac
  ( watchdog "$eng" "$name" ) & wd=$!
  ok=0; for _ in $(seq 90); do ready $port && { ok=1; break; }; running "$eng" || break; sleep 10; done
  load=$(( $(date +%s) - t0 ))
  case $name in
    *_t07) export BENCH_SAMPLING='{"temperature": 0.7, "top_p": 0.8, "top_k": 20}' ;;
    *_t10) export BENCH_SAMPLING='{"temperature": 1.0, "top_p": 0.95, "top_k": 20}' ;;
    *)     export BENCH_SAMPLING='{}' ;;
  esac
  if [ $ok = 1 ]; then res=$(python3 "$CLIENT" "http://127.0.0.1:$port" 2>&1 | tail -1); else res='{"error": "did not start"}'; fi
  [ "$eng" = llama ] || podman logs bench > "$OUT/log-$name.txt" 2>&1
  stop_it "$eng"; wait $wd
  echo -e "$name\t$eng\t$envs $args\tload ${load}s\tminavail $(cat "$OUT/minavail-$name" 2>/dev/null)MiB\t$res" | tee -a "$OUT/results.tsv"
done < "${1:?usage: run-variants.sh VARIANTS_FILE}"
