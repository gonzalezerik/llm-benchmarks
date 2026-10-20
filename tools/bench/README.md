# Bench tools

The scripts every result in `results/` that links here was measured with.

| File | What it does |
|---|---|
| `client.py` | The measurement: 8 short prompts, then one ~32K-token prompt, against any server that speaks the Anthropic Messages API (`/v1/messages`, streaming). Prints one JSON line. |
| `run-variants.sh` | Runs a list of engine configurations one after another, each in a fresh engine process, and measures each with `client.py`. |
| `kl.py` | Quality check for settings that change a GLM-5.3-Flash model's routing on Project Maya: teacher-forced logits of the same tokens, compared as KL divergence and top-1 agreement. |

## What client.py measures

1. **Warm-up:** one request ("Say hi.", 8 tokens). Not counted.
2. **Decode:** 8 different prompts (code, explanation, a script, a story, ...), `max_tokens` 512 each, thinking
   disabled (`"thinking": {"type": "disabled"}`). For each: output tokens / (time of the last event - time of the
   first content delta). `decode` is the mean of the 8, `decode_last4` the mean of the last 4 (after the engine's
   caches have seen a few answers), `each` the 8 values in order.
3. **Prefill + decode at depth:** one prompt of ~28-30K tokens (the C/C++/CUDA sources of
   [Project Maya](https://github.com/mw00/project-maya) v1.1.17 `src/`, concatenated in sorted path order, cut to
   102,400 characters, with a random UUID in the first line so no server can reuse a cached prefix), then
   "Explain in detail what this code does, file by file.", `max_tokens` 400.
   - `prefill_32k` = input tokens / time to the first content delta
   - `tokens_32k` = the input tokens the server reported (the same text tokenizes differently per model)
   - `decode_at_32k` = output tokens / (end - first delta) of that answer

Every request streams. Token counts are the server's own (`usage` in `message_start` / `message_delta`).

**Sampling:** `client.py` sends none unless `BENCH_SAMPLING` is set (JSON merged into each request, e.g.
`{"temperature": 0.7, "top_p": 0.8, "top_k": 20}`), so each server applies its own defaults. Each result page says which.
Sampling matters for speculative decoding (MTP / DFlash / DSpark): lower temperature means more accepted drafts and a
higher decode rate. Engine-vs-engine comparisons on the same model are made with the same explicit sampling.

## What run-variants.sh does per variant

1. waits until the GPUs are free (under 2 GB used in total)
2. `sync; echo 3 > /proc/sys/vm/drop_caches`, so every variant starts with a cold page cache
3. starts the engine in the CUDA container, with the base config plus that variant's changes written to
   `cfg-<name>.json` (the exact config each result row came from)
4. waits for a real 1-token answer, not just a health endpoint
5. runs `client.py`, then stops the engine
6. a watchdog samples `MemAvailable` every second, records the lowest value (`minavail` in the results) and stops the
   engine below 1.5 GB

`load` in the results = engine start to the first successful 1-token answer (includes Maya's speed calibration where
it runs, which is noted on the result pages).

## Caveats

- **One run per variant.** Prompt-to-prompt spread inside a run is about ±10% (see `each`); between two runs of the
  same config the means moved about ±2-3%. Treat differences under ~3% as noise.
- Decode excludes the time to the first token; prefill includes the server's tokenizing and request handling.
- The 32K prompt is code. Prose, or a real agent conversation with tool results, will give different numbers,
  especially with speculative decoding.
