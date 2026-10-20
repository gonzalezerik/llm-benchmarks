#!/usr/bin/env bash
# llama.cpp 5aeac37 + PR #30592 (../../files/llama-cpp-pr30592-qwen4exp-mtp-sidecar.patch), CUDA 13.4, sm_80 + sm_86.
# The exact server the glmu_llamacpp rows ran: no -ngl / -ot, so llama.cpp's own fit decides what goes on the GPUs.
# glmu_llamacpp_nommap is the same command plus --load-mode none.
export CUDA_VISIBLE_DEVICES=0,1,2
exec llama-server \
  -m /data/models/glm-5.3-flash-unsloth/UD-IQ4_XS/GLM-5.3-Flash-UD-IQ4_XS-00001-of-00005.gguf \
  -sm layer -fa on -c 131072 --parallel 1 -t 16 -b 2048 -ub 1536 \
  --temp 1.0 --top-p 0.95 --jinja --no-webui \
  --host 127.0.0.1 --port 8099
