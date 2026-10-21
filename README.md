# LLM Benchmarks

Personal log of local LLM inference benchmarks across my hardware. Mostly here
to keep myself organized, but if you found this while trying to figure out how
a model runs on similar hardware, hopefully it helps.

> Work in progress. Results will be added as I run them.

## Hardware

| Device | GPU / APU | Memory | Notes |
|---|---|---|---|
| [ryzen-ai-max-395-128gb](results/ryzen-ai-max-395-128gb/README.md) | AMD Strix Halo: Ryzen AI Max+ 395 / Radeon 8060S | 128 GB LPDDR5X-8000, shared | ASUS ProArt PX13 laptop, on AC at 60 / 70 / 85 W |
| [7950x-2xa100-3090](results/7950x-2xa100-3090/README.md) | 2x NVIDIA A100 SXM4 40GB + RTX 3090 24GB (104 GB VRAM) | 96 GB DDR5-3600 | Ryzen 9 7950X, PCIe only (no NVLink), NVMe RAID0 |

## Layout

```
results/
  <hardware>/
    README.md                              the hardware, software versions, build steps
    <yyyy-mm-dd>-<model>-<engine>.md
    <yyyy-mm-dd>-<model>-<engine>/         exact configs of every row, raw results
tools/
  bench/                                   the client and runner the results were measured with
```

Each result should note:

- Model + quantization (e.g. `Qwen3.8-27B Q4_K_M`)
- Engine + version/commit (llama.cpp, vLLM, SGLang, ...)
- Driver / runtime (ROCm, CUDA, Vulkan) versions
- Context length and batch settings
- Prompt processing (prefill) tok/s and generation (decode) tok/s
- Exact command used, so it can be reproduced

## Results

| Date | Hardware | Model | Engine | Decode | Prefill @ 32K |
|---|---|---|---|---:|---:|
| 2026-10-20 | 7950x-2xa100-3090 | [GLM-5.3-Flash Maya-L](results/7950x-2xa100-3090/2026-10-20-glm-5.3-flash-maya-l-maya.md) | Project Maya v1.1.17 | 47.7 tok/s | 1,168 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [GLM-5.3-Flash unsloth UD-IQ4_XS](results/7950x-2xa100-3090/2026-10-20-glm-5.3-flash-unsloth-ud-iq4_xs-maya-vs-llamacpp.md) | Project Maya v1.1.17 | 47.2 tok/s | 1,169 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [GLM-5.3-Flash Maya-M](results/7950x-2xa100-3090/2026-10-20-glm-5.3-flash-maya-m-maya.md) | Project Maya v1.1.17 | 62.5 tok/s | 1,326 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [DeepSeek-V4.1-Flash-1017 Maya-S](results/7950x-2xa100-3090/2026-10-20-deepseek-v4.1-flash-maya-s-maya.md) | Project Maya v1.1.17 | 39.8 tok/s | 421 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [Qwen3.8-Flash-Next UD-Q4_K_XL](results/7950x-2xa100-3090/2026-10-20-qwen3.8-flash-next-strata-vs-llamacpp.md) | Strata v0.2.0-beta | 103.0 tok/s | 3,169 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [Qwen3.8-Flash-Next UD-Q4_K_XL](results/7950x-2xa100-3090/2026-10-20-qwen3.8-flash-next-strata-vs-llamacpp.md) | llama.cpp 5aeac37 | 67.8 tok/s | 1,068 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [Qwen3.8-Flash-Next UD-Q6_K_XL](results/7950x-2xa100-3090/2026-10-20-qwen3.8-flash-next-quants-strata.md) | Strata v0.2.0-beta | 78.3 tok/s | 3,046 tok/s |
| 2026-10-20 | 7950x-2xa100-3090 | [Qwen3.8-Flash-Next Q8_0](results/7950x-2xa100-3090/2026-10-20-qwen3.8-flash-next-quants-strata.md) | Strata v0.2.0-beta | 60.5 tok/s | 1,669 tok/s |
| 2026-10-20 | ryzen-ai-max-395-128gb | [Qwen3.8-Flash-Next (Halogen v2), 70 W](results/ryzen-ai-max-395-128gb/2026-10-20-power-limits-maya-s-halogen.md) | halogen-flash-server 0.17.5 | 63.6 tok/s | 1,458 tok/s |
| 2026-10-20 | ryzen-ai-max-395-128gb | [GLM-5.3-Flash Maya-S-v2, 70 W](results/ryzen-ai-max-395-128gb/2026-10-20-power-limits-maya-s-halogen.md) | Project Maya v1.1.15 | 22.9 tok/s | 278 tok/s |
