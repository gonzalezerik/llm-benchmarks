# LLM Benchmarks

Personal log of local LLM inference benchmarks across my hardware. Mostly here
to keep myself organized, but if you found this while trying to figure out how
a model runs on similar hardware, hopefully it helps.

> Work in progress. Results will be added as I run them.

## Hardware

| Device | GPU / APU | Memory | Notes |
|---|---|---|---|
| _TBD_ | AMD Strix Halo | _TBD_ | |
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
