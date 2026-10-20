# Ryzen 9 7950X + 2x A100 SXM4 40GB + RTX 3090 (104 GB VRAM, 96 GB DDR5)

A headless home server. Everything on this page applies to every result in this folder unless a result says otherwise.

## Results

| Date | Model | Engine(s) | Best decode | Page |
|---|---|---|---|---|
| 2026-10-20 | GLM-5.3-Flash Maya-L (IQ3_S mix, 156 GB) | Project Maya v1.1.16 / v1.1.17 | 47.7 tok/s | [glm-5.3-flash-maya-l](2026-10-20-glm-5.3-flash-maya-l-maya.md) |
| 2026-10-20 | GLM-5.3-Flash Maya-M (IQ2_S mix, 116 GB) | Project Maya v1.1.17 | 62.5 tok/s | [glm-5.3-flash-maya-m](2026-10-20-glm-5.3-flash-maya-m-maya.md) |
| 2026-10-20 | DeepSeek-V4.1-Flash-1017 Maya-S (178 GB + 203 GB Engram) | Project Maya v1.1.16 / v1.1.17 | 39.8 tok/s | [deepseek-v4.1-flash-maya-s](2026-10-20-deepseek-v4.1-flash-maya-s-maya.md) |
| 2026-10-20 | Qwen3.8-Flash-Next UD-Q4_K_XL / Q8_0 | Strata v0.2.0-beta vs llama.cpp | 103.0 tok/s | [qwen3.8-flash-next](2026-10-20-qwen3.8-flash-next-strata-vs-llamacpp.md) |

## Hardware

| Part | What | Notes |
|---|---|---|
| CPU | AMD Ryzen 9 7950X, 16 cores / 32 threads | one NUMA node; `amd-pstate-epp`, governor `powersave`, EPP `balance_performance` |
| Board | MSI MEG X670E ACE, BIOS 1P3 (AGESA 1.3.0.1d) | |
| RAM | **96 GB DDR5 at 3600 MT/s**, 4 DIMMs, 2 channels | 2x 32 GB G.Skill F5-6000J3040G32G (dual rank) + 2x 16 GB G.Skill F5-6000J3636F16G (single rank). Two different kits in four slots only booted at 3600 ([why](#why-the-ram-runs-at-3600-mts-yes-on-purpose)); EXPO off. 93 GiB visible to Linux. Maya's start-up probe reads RAM at **40-44 GB/s**. |
| GPU 0 | NVIDIA A100-SXM4-40GB (sm_80, 1555 GB/s) | on an SXM4-to-PCIe adapter, **PCIe 4.0 x8**, power limit **250 W** |
| GPU 1 | NVIDIA A100-SXM4-40GB (sm_80, 1555 GB/s) | same, PCIe 4.0 x8, 250 W |
| GPU 2 | NVIDIA GeForce RTX 3090 24 GB (sm_86, 936 GB/s) | **PCIe 4.0 x4** (slot), power limit **210 W** |
| GPU links | no NVLink, no peer-to-peer | everything between cards goes through host memory. Strata's probe: 13.4 GB/s to each A100, 6.7 GB/s to the 3090 |
| Model storage | 3x 1 TB NVMe (MSI M470, Samsung 970 EVO Plus, Fanxiang S660), Linux md **RAID0**, XFS | ~6.2 GB/s parallel read, 4.8 GB/s single stream. Models load from here, and engines that stream weights (Maya's disk tier, Strata's n-gram table) read from here while answering |

### Why the RAM runs at 3600 MT/s (yes, on purpose)

This box started with one 2x 32 GB kit. To run bigger models I added the 2x 16 GB kit from another machine, so it's
now four sticks from two different kits: dual-rank SK Hynix next to single-rank Samsung, two DIMMs per channel on
AM5. That's about the worst case for memory training. At BIOS defaults it hung on the memory-training POST code, and
3600 MT/s was the only speed where all four sticks booted.

So it's a trade: 96 GB at 3600 beats 64 GB at full speed for these models. The extra 32 GB is what lets the MoE models
here keep every expert that doesn't fit in VRAM in RAM instead of reading them from the SSD. The cost shows up wherever
the CPU computes experts: on GLM-5.3 Maya-L a CPU-side expert takes 0.26-0.44 ms instead of 0.18-0.20 ms
([details](2026-10-20-glm-5.3-flash-maya-l-maya.md#where-it-sits-on-this-box)). Models that sit entirely in VRAM
don't care. A matched 4x 32 GB kit is the real fix.

Power limits are set at boot (`nvidia-smi -pl`), fans pinned to maximum. The A100s run at 250 W instead of 400 W for
thermal reasons on the adapters: for llama.cpp, 400 W measured +9% prefill and no decode change.

## Software

| | Version |
|---|---|
| OS | NixOS 26.11, kernel 6.18.52 |
| NVIDIA driver | 615.71.09 (CUDA 13.4 user-mode driver) |
| Container runtime | podman 5.8.6 with the NVIDIA CDI (`--device nvidia.com/gpu=all`) |
| Build/run container | `nvidia/cuda:13.4.3-devel-ubuntu24.04` + Python 3.12 / CMake / Ninja (below), nvcc 13.4.92, gcc 13.3 |
| [Project Maya](https://github.com/mw00/project-maya) | v1.1.16 (`abc09c7`) and v1.1.17 (`8d9a9b5`); pinned llama.cpp `3cf03257` for ggml |
| [Strata](https://github.com/Niko1221/Strata) | v0.2.0-beta (`3d1fb48`); pinned llama.cpp `3cf03257` |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | `5aeac37` + the patch from PR #30592 (qwen4exp MTP with a separate draft GGUF), CUDA 13.4, `GGML_CUDA_FA_ALL_QUANTS=ON`, sm_80 + sm_86 |

### The container

Maya and Strata are built and run inside this image (the source trees are bind-mounted at the same path they run from):

```dockerfile
FROM docker.io/nvidia/cuda:13.4.3-devel-ubuntu24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev python3-pip cmake ninja-build git build-essential ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
```

```sh
podman build -t maya-cuda:13.4.3 -f Containerfile.cuda .
```

Engines run with `--device nvidia.com/gpu=all --ipc host --network host --ulimit memlock=-1:-1` (the pinned RAM tiers
need unlimited `memlock`).

### Building Project Maya (CUDA, sm_80 + sm_86)

Maya's own setup (`./maya.sh --setup`) does this, downloads the model and writes the config. To build by hand in the
container, from the checkout (after `setup.py` has fetched llama.cpp into `third_party/llama.cpp` and made `.venv`):

```sh
git clone https://github.com/mw00/project-maya && cd project-maya && git checkout v1.1.17
.venv/bin/cmake -G Ninja -DCMAKE_MAKE_PROGRAM=$PWD/.venv/bin/ninja -S . -B build -DCMAKE_BUILD_TYPE=Release \
  -DSTRATA_ENABLE_CUDA=ON "-DCMAKE_CUDA_ARCHITECTURES=80;86" -DSTRATA_NATIVE_EXPERTS=ON -DSTRATA_BUILD_TESTS=OFF \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCUDAToolkit_ROOT=/usr/local/cuda-13.4 \
  -DSTRATA_GGML_DIR=$PWD/third_party/llama.cpp
.venv/bin/cmake --build build -j 32        # -> build/maya (GLM) and build/maya-ds4 (DeepSeek)
```

### Building Strata (CUDA, sm_80 + sm_86)

Mirrors Strata's own Dockerfile, for these two architectures only:

```sh
git clone --branch v0.2.0-beta https://github.com/Niko1221/Strata && cd Strata
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-build.txt
.venv/bin/python -c "import setup; print(setup.get_llama_cpp())"      # llama.cpp at the pinned commit
.venv/bin/cmake -G Ninja -S . -B build -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON -DSTRATA_BUILD_TESTS=OFF \
  -DSTRATA_NATIVE_EXPERTS=ON -DSTRATA_Q6K_EXPERTS=ON -DSTRATA_MMQ_KQUANTS=ON \
  "-DCMAKE_CUDA_ARCHITECTURES=80-real;86-real" -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
  -DSTRATA_GGML_DIR=$PWD/third_party/llama.cpp
.venv/bin/cmake --build build --target strata strata_kq -j 32
```

### Building llama.cpp

```sh
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp && git checkout 5aeac37
git apply llama-cpp-pr30592-qwen4exp-mtp-sidecar.patch          # PR #30592's diff
cmake -B build -DGGML_CUDA=ON -DGGML_CUDA_FA_ALL_QUANTS=ON "-DCMAKE_CUDA_ARCHITECTURES=80;86" -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 32 --target llama-server
```

## How everything here is measured

With the scripts in [`tools/bench`](../../tools/bench/README.md): one engine at a time, cold page cache, the same
client and prompts for every engine. Each result page lists the exact config of every row.
