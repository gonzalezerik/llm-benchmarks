#!/usr/bin/env bash
# halogen-flash-server 0.17.5 as the halogen_* rows ran it (rootless podman, the GPU through /dev/kfd + /dev/dri).
# Weights: peonist-ai/halogen-qwen3.8-flash-next, revision 506567c641cfb737e0b01c1deff10813154c5529:
# qwen38-flash-next-v2.hgn (62.1 GiB), qwen38-flash-next-ngram.hgn (47.7 GiB), qwen38-flash-next-vision.hgn, tokenizer/.
# No HALOGEN_DOWNLOAD: the weights are already in ~/models/qwen3/halogen, mounted read-only, so the container makes
# no outbound connections. KV pool 262,144 positions in 2 slots (~20 GiB) instead of the default 524,288 / 4 (~27 GiB).
exec podman run --rm --replace --name halogen \
  -p 127.0.0.1:8731:8731 \
  --device /dev/kfd --device /dev/dri --group-add keep-groups \
  --ipc=host --ulimit memlock=-1:-1 \
  -e HALOGEN_VISION_TOWER=1 \
  -e HALOGEN_KV_POOL_POSITIONS=262144 \
  -e HALOGEN_KV_SLOTS=2 \
  -v ~/models/qwen3/halogen:/models:ro \
  ghcr.io/peonist-ai/halogen-flash-server:0.17.5
