# Strix Halo at 60 / 70 / 85 W: GLM-5.3-Flash Maya-S and Qwen3.8-Flash-Next (Halogen)

**Hardware:** [ASUS ProArt PX13, Ryzen AI Max+ 395, 128 GB](README.md), on AC ·
**Engines:** [Project Maya](https://github.com/mw00/project-maya) v1.1.15 (HIP) and
[halogen-flash-server](https://github.com/peonist-ai/halogen-flash-server) 0.17.5 ·
**Measured with:** [`tools/bench`](../../tools/bench/README.md) · 2026-10-20

## Result

| Power limit | Maya-S decode | Maya-S prefill @ 32K | Halogen decode | Halogen prefill @ 32K |
|---|---:|---:|---:|---:|
| 60 W | 22.3 tok/s | 246 tok/s | 63.3 tok/s | 1,366 tok/s |
| **70 W** | 22.9 tok/s | **278 tok/s** | 63.6 tok/s | 1,458 tok/s |
| 85 W | 23.7 tok/s | 265 tok/s | 66.0 tok/s | 1,549 tok/s |

**Decode barely cares about the power limit** (+4-6% from 60 to 85 W): it is limited by memory bandwidth, which the
limit doesn't change. **Prefill is compute-bound** and gains 7-13% up to 70 W. At 85 W Halogen's prefill still gains,
but Maya-S's drops below 70 W: Tctl reached 99 °C and the package fell under 40 W for 4 seconds during that run.
70 W is the sweet spot for Maya-S; Halogen takes another +6% prefill at 85 W, at 96 °C.

## The models

| | Maya-S | Halogen |
|---|---|---|
| Model | [zai-org/GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash), 320B / 18B active | [Qwen/Qwen3.8-Flash-Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next), 180B (51B n-gram table) / ~4.5B active |
| Weights | [peasantsmith/GLM-5.3-Flash-Maya-GGUF](https://huggingface.co/peasantsmith/GLM-5.3-Flash-Maya-GGUF) `Maya-S-v2-IQ2_XXS/`, revision `f16ee4ba50d8fd2bb726ea1862ca6ca14ba188da`: 3 shards, 96.5 GB | [peonist-ai/halogen-qwen3.8-flash-next](https://huggingface.co/peonist-ai/halogen-qwen3.8-flash-next), revision `506567c641cfb737e0b01c1deff10813154c5529`: `qwen38-flash-next-v2.hgn` (62.1 GiB, Halogen's own 4-bit format) + the n-gram table (47.7 GiB) |
| Context | 262,144 | 262,144 (KV pool 262,144 positions, 2 slots) |
| Sampling | none sent: the config's temperature 1.0, top_p 0.95 | sent with every request: temperature 1.0, top_p 0.95, top_k 20 (the same as the matched-sampling Flash-Next runs on the [server](../7950x-2xa100-3090/2026-10-20-qwen3.8-flash-next-strata-vs-llamacpp.md)) |
| Thinking | disabled | disabled |

## Configs

**Maya-S:** [`configs/maya-s.json`](2026-10-20-power-limits-maya-s-halogen/configs/maya-s.json), written by Maya's setup
(Maya-S-v2, HIP), with hand changes from tuning this laptop: `STRATA_GLM_RESERVE_MB=1024`,
`STRATA_GLM_RAM_HEADROOM_GB=16`, `STRATA_GLM_SPLIT=0`, `STRATA_GLM_PREFILL_SUB=1024`, `STRATA_GLM_PREFILL_MB=6144`, the
gfx1151 hipBLASLt tuning tables, and a CPU vision block (the HIP installer is text-only). As on the other pages,
`STRATA_GLM_SLOT_KEEP` and `STRATA_GLM_USAGE` were removed for the bench.

```json
"args": ["--glm-pack", ".../Maya-S-v2-IQ2_XXS/pack", "--max-context", "262144", "--expert-cache", "auto",
         "--prefill", "auto", "--kv-streaming", "on", "--expert-profile", ".../data/expert-profile-glm.bin"]
```

```sh
podman run --rm --name maya --network host --device /dev/kfd --device /dev/dri --group-add keep-groups \
  --ipc=host --ulimit memlock=-1:-1 -e HOME=$HOME/.local/share/maya/home \
  -v $HOME/.local/share/maya:$HOME/.local/share/maya -v $HOME/models/glm-5.3-flash/maya:$HOME/models/glm-5.3-flash/maya \
  -w $HOME/.local/share/maya/project-maya maya-rocm:7.14.1 ./maya.sh --config maya-s.json --plain
```

With the 512 MiB carve-out the GPU sees ~124 GiB, and Maya's pool held 98.6% of Maya-S's experts in GPU memory
(the rest in a small pinned RAM tier).

**Halogen:** [`configs/halogen.sh`](2026-10-20-power-limits-maya-s-halogen/configs/halogen.sh): the container image as
published, the weights mounted read-only, KV pool 262,144 positions / 2 slots, vision tower on.

## Every run

| Run | PPT limits | Decode | Last 4 | Decode @ 32K | Prefill @ 32K | Load | PPT mean / max | Tctl max | GPU clock mean | < 40 W |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `maya-s_60w` | 60/70/85 | 22.3 | 20.5 | 16.6 | 246 | 31 s | 64.1 / 84.9 W | 84 °C | 2,333 MHz | 0 s |
| `halogen_60w` | 60/70/85 | 63.3 | 59.8 | 57.4 | 1,366 | 21 s | 62.7 / 66.1 W | 78 °C | 2,299 MHz | 0 s |
| `maya-s_70w` | 70/80/95 | 22.9 | 21.0 | 18.2 | 278 | 31 s | 70.0 / 70.6 W | 88 °C | 2,420 MHz | 0 s |
| `halogen_70w` | 70/80/95 | 63.6 | 58.5 | 58.7 | 1,458 | 20 s | 71.1 / 73.4 W | 85 °C | 2,443 MHz | 0 s |
| `maya-s_85w` | 85/95/115 | 23.7 | 21.6 | 18.0 | 265 | 31 s | 83.8 / 85.9 W | 99 °C | 2,516 MHz | 4 s |
| `halogen_85w` | 85/95/115 | 66.0 | 60.4 | 56.7 | 1,549 | 20 s | 86.1 / 89.6 W | 96 °C | 2,633 MHz | 0 s |

Decode values in tok/s; prefill over ~27,820 (Maya-S) and ~30,490 (Halogen) prompt tokens. Power columns: over the
seconds the GPU was ≥ 50% busy during the measurement (Maya-S ~300 s per run, Halogen ~86 s). Each run started with
Tctl under 55 °C. The per-second logs (PPT, Tctl, GPU clock, GPU busy) are in [`raw/`](2026-10-20-power-limits-maya-s-halogen/raw/).

Notes:

- The page cache was not dropped between runs here (the runner has no root on this laptop); both engines load their
  weights into GPU memory at start, so this mostly affects load time.
- Maya is v1.1.15 here (the server pages use v1.1.16 / v1.1.17); its GLM changes since are mostly for Volta GPUs and
  DeepSeek.
- For comparison with the server: Flash-Next on the 2x A100 + RTX 3090 box decodes at 103 tok/s on Strata and 68 on
  llama.cpp at the same sampling, so this laptop's Halogen sits at llama.cpp-on-three-GPUs speed, at 60-85 W.

## To reproduce

1. Halogen: put the weights in a folder, run [`configs/halogen.sh`](2026-10-20-power-limits-maya-s-halogen/configs/halogen.sh).
2. Maya-S: build Maya in the ROCm container ([hardware page](README.md#mayas-rocm-container)), `./maya.sh --setup`,
   choose Maya-S-v2, keep the GPU carve-out at its minimum in the BIOS (Maya sizes its pool from free memory).
3. Set the power limits ([hardware page](README.md#power-limits)), then [`tools/bench/run-power-limits.sh`](../../tools/bench/run-power-limits.sh)
   runs the whole table.
