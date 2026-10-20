# GLM-5.3 Maya-L quality check for ROUTE_AFFINITY: teacher-forced logits (STRATA_GLM_KL_DUMP) on the same 8.4K tokens.
#   kl.py tokens                 -> kl/tokens.txt (8448 tokens of real docs + code, GLM tokenizer)
#   kl.py run NAME "ENV=V ..."   -> kl/NAME.f32 (the last 256 positions' logits)
#   kl.py compare REF A B ...    -> KL(REF || X), top-1 agreement
import json, os, subprocess, sys
sys.path.insert(0, os.environ.get("MAYA_DIR") or "/data/maya/project-maya")
K = os.environ.get("KL_DIR") or "/data/bench/kl"; os.makedirs(K, exist_ok=True)
MAYA = os.environ.get("MAYA_DIR") or "/data/maya/project-maya"
N, TOTAL = 256, 8448
cmd = sys.argv[1]
if cmd == "tokens":
    sys.path.insert(0, f"{MAYA}/tools")
    import strata_tokenizer as ST                     # Maya's own tokenizer (the pack's pre-tokenizer: glm4)
    tok = ST.Tokenizer.from_dir(os.environ.get("GLM_TOKENIZER") or "/data/models/glm-5.3-flash-maya/Maya-L/pack/tokenizer")
    text = "".join(open(f"{MAYA}/{p}", errors="replace").read()
                   for p in ("docs/GLM5-FLASH.md", "docs/SETTINGS.md", "src/core/expert_cache.cpp"))
    ids = tok.encode(text)[:TOTAL]
    assert len(ids) == TOTAL, len(ids)
    open(f"{K}/tokens.txt", "w").write(",".join(map(str, ids)))
elif cmd == "run":
    import serve.server as SV
    name, envs = sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""
    cfg = json.load(open(os.environ.get("MAYA_BASE") or f"{MAYA}/maya-l.json"))
    for k in ("STRATA_GLM_SLOT_KEEP", "STRATA_GLM_USAGE"): cfg["env"].pop(k, None)
    for kv in filter(None, envs.split()):
        k, v = kv.split("=", 1); cfg["env"][k] = v
    env = SV.child_env(cfg); env["STRATA_GLM_KL_DUMP"] = f"{K}/{name}.f32,{N}"
    args = [cfg["exe"]] + SV.engine_args(cfg) + ["--tokens-file", f"{K}/tokens.txt"]
    with open(f"{K}/{name}.log", "w") as log:
        sys.exit(subprocess.run(args, cwd=cfg["cwd"], env=env, stdout=log, stderr=subprocess.STDOUT).returncode)
elif cmd == "compare":
    import numpy as np
    def load(n):
        a = np.fromfile(f"{K}/{n}.f32", dtype=np.float32); return a.reshape(N, -1).astype(np.float64)
    def logp(x): x = x - x.max(1, keepdims=True); return x - np.log(np.exp(x).sum(1, keepdims=True))
    ref = logp(load(sys.argv[2])); pr = np.exp(ref)
    for n in sys.argv[3:]:
        x = logp(load(n))
        kl = (pr * (ref - x)).sum(1)
        top1 = (ref.argmax(1) == x.argmax(1)).mean()
        print(f"{n:10s} KL mean {kl.mean():.4f}  median {np.median(kl):.4f}  p95 {np.percentile(kl, 95):.4f}  top-1 {top1 * 100:.1f}%")
