# ASUS ProArt PX13: Ryzen AI Max+ 395 (Strix Halo), 128 GB

A laptop. Everything on this page applies to every result in this folder unless a result says otherwise.

## Results

| Date | Model | Engine | Best decode | Page |
|---|---|---|---|---|
| 2026-10-20 | GLM-5.3-Flash Maya-S-v2 (96.5 GB) | Project Maya v1.1.15 (HIP) | 23.7 tok/s | [power limits](2026-10-20-power-limits-maya-s-halogen.md) |
| 2026-10-20 | Qwen3.8-Flash-Next (Halogen v2 weights) | halogen-flash-server 0.17.5 | 66.0 tok/s | [power limits](2026-10-20-power-limits-maya-s-halogen.md) |

## Hardware

| Part | What | Notes |
|---|---|---|
| Laptop | ASUS ProArt PX13 HN7306EAC, BIOS 310 | always on its AC adapter for these runs |
| APU | AMD Ryzen AI Max+ 395: 16 cores / 32 threads + Radeon 8060S (gfx1151, 40 CUs) | one package, one power limit for CPU and GPU together |
| Memory | 128 GB LPDDR5X-8000, 256-bit, shared by CPU and GPU | BIOS GPU carve-out set to the minimum (512 MiB); the GPU uses the rest through GTT (124 GiB visible to it) |
| Storage | the internal NVMe | models load from here |

### Power limits

The APU's package power (PPT) limits are what the "60 / 70 / 85 W" in the results mean. They are set through the
`asus-armoury` firmware attributes with asusctl, in the AC Performance profile:

| Profile | `ppt_pl1_spl` (sustained) | `ppt_pl2_sppt` (slow boost) | `ppt_pl3_fppt` (fast boost) |
|---|---:|---:|---:|
| 60 W | 60 | 70 | 85 |
| 70 W | 70 | 80 | 95 |
| 85 W | 85 | 95 | 115 |

```sh
asusctl armoury set ppt_pl1_spl 70; asusctl armoury set ppt_pl2_sppt 80; asusctl armoury set ppt_pl3_fppt 95
```

Two things I found on this laptop: right after boot nothing writes these values and the SMU sits at ~35-44 W until
they are written once; and at 85 W during a long (100K+ token) prompt the SMU once latched to ~35 W at ~100 °C and
stayed there until the limits were written again. 70 W is the setting I run day to day.

## Software

| | Version |
|---|---|
| OS | NixOS 26.11, kernel 7.2.6 (CachyOS-based) |
| CPU governor | `amd-pstate-epp`, EPP `performance` |
| Container runtime | podman 5.8.8, rootless; the GPU through `--device /dev/kfd --device /dev/dri --group-add keep-groups` |
| [Project Maya](https://github.com/mw00/project-maya) | v1.1.15 (`a4e1ff0`), HIP engine, in a ROCm 7.14.1 container (below) |
| [halogen-flash-server](https://github.com/peonist-ai/halogen-flash-server) | 0.17.5 (`ghcr.io/peonist-ai/halogen-flash-server:0.17.5`) |

### Maya's ROCm container

```dockerfile
FROM docker.io/rocm/dev-ubuntu-24.04:7.14.1-full
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev python3-pip cmake ninja-build git build-essential ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
```

ROCm 7.14.1 is the version Maya pins and validated on Strix Halo; its hipBLASLt tuning tables for gfx1151 are in
Maya's `tools/hip/`. The engine was compiled in this image (Maya's own `./maya.sh --setup` steps for HIP, gfx1151), the
source tree bind-mounted at the path it runs from.

## How everything here is measured

With [`tools/bench/client.py`](../../tools/bench/README.md) (the same client and prompts as the other hardware) and
[`tools/bench/run-power-limits.sh`](../../tools/bench/run-power-limits.sh), which also logs package power, Tctl and GPU
clock every second.
