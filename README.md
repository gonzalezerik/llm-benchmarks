# LLM Benchmarks

Personal log of local LLM inference benchmarks across my hardware. Mostly here
to keep myself organized, but if you found this while trying to figure out how
a model runs on similar hardware, hopefully it helps.

> Work in progress. Results will be added as I run them.

## Hardware

| Device | GPU / APU | Memory | Notes |
|---|---|---|---|
| _TBD_ | AMD Strix Halo | _TBD_ | |
| _TBD_ | | | |

## Layout

```
results/
  <hardware>/
    <yyyy-mm-dd>-<model>-<engine>.md
```

Each result should note:

- Model + quantization (e.g. `Qwen3.8-27B Q4_K_M`)
- Engine + version/commit (llama.cpp, vLLM, SGLang, ...)
- Driver / runtime (ROCm, CUDA, Vulkan) versions
- Context length and batch settings
- Prompt processing (prefill) tok/s and generation (decode) tok/s
- Exact command used, so it can be reproduced

## Results

_Nothing yet._
