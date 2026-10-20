# Bench client: decode on 8 fresh prompts (512 tok, thinking off), then a ~32K-token prompt
# (random nonce, no cache reuse) -> prefill rate + decode rate at that depth.
# BENCH_SAMPLING (JSON, e.g. {"temperature": 0.7, "top_p": 0.8, "top_k": 20}) is sent with every request; unset, the
# server's own defaults apply.  BENCH_LONG_SRC: the glob of source files the ~32K-token prompt is cut from.
import glob, json, os, sys, time, uuid, urllib.request
URL = sys.argv[1]
SAMPLING = json.loads(os.environ.get("BENCH_SAMPLING") or "{}")
LONG_SRC = os.environ.get("BENCH_LONG_SRC") or "/data/maya/project-maya/src/**/*.c*"
def call(content, max_tokens):
    body = {"model": "glm", "max_tokens": max_tokens, "stream": True, "thinking": {"type": "disabled"},
            "messages": [{"role": "user", "content": content}]}
    body.update(SAMPLING)
    req = urllib.request.Request(URL + "/v1/messages", json.dumps(body).encode(), {"content-type": "application/json"})
    t0 = time.time(); first = None; usage = {}
    with urllib.request.urlopen(req, timeout=7200) as r:
        for line in r:
            line = line.decode().strip()
            if not line.startswith("data:"): continue
            ev = json.loads(line[5:])
            if ev.get("type") == "content_block_delta" and first is None: first = time.time()
            if ev.get("type") == "message_start": usage.update(ev["message"].get("usage", {}))
            if ev.get("type") == "message_delta": usage.update(ev.get("usage", {}))
    return t0, first, time.time(), usage.get("input_tokens", 0), usage.get("output_tokens", 0)
call("Say hi.", 8)
prompts = ["Write a Python function that merges overlapping intervals, with tests.",
           "Explain how TCP congestion control works, step by step.",
           "Write a complete HTML page with a canvas that draws a rotating 3D cube in plain JavaScript.",
           "Write a Rust CLI that counts word frequencies in a file, using clap and a HashMap.",
           "Describe the causes and consequences of the 1929 stock market crash.",
           "Write a bash script that rotates log files older than 7 days and compresses them.",
           "Explain the difference between Raft and Paxos to a backend engineer.",
           "Write a short science-fiction story about a lighthouse keeper on Europa."]
dec = []
for p in prompts:
    t0, f, t1, pin, pout = call(p, 512); dec.append(round(pout / (t1 - f), 1))
out = {"decode": round(sum(dec) / len(dec), 1), "decode_last4": round(sum(dec[4:]) / 4, 1), "each": dec}
src = "".join(open(f, errors="replace").read() for f in sorted(glob.glob(LONG_SRC, recursive=True)))
text = f"[run {uuid.uuid4()}]\n" + src[: int(32000 * 3.2)]
t0, f, t1, pin, pout = call(text + "\n\nExplain in detail what this code does, file by file.", 400)
out.update(prefill_32k=round(pin / (f - t0)), tokens_32k=pin, decode_at_32k=round(pout / (t1 - f), 1))
print(json.dumps(out))
