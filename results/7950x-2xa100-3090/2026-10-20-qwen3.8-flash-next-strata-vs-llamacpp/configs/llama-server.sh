#!/usr/bin/env bash
# llama.cpp 5aeac37 + PR #30592 (../../files/llama-cpp-pr30592-qwen4exp-mtp-sidecar.patch), CUDA 13.4,
# GGML_CUDA_FA_ALL_QUANTS=ON, sm_80 + sm_86. The exact server the fn_llamacpp_* rows ran.
# The chat template is froggeric's Qwen3.8 template v22.4 (sha256 c47c82b0544752d454f4e427228d9d9d8c3df64c9e446cbd0229362f67948009):
# Qwen's official template raises an exception on the mid-conversation system messages Claude Code sends.
export CUDA_VISIBLE_DEVICES=0,1,2
M=/data/models/qwen3.8-flash-next
exec llama-server \
  -m $M/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf \
  -md $M/MTP/mtp-Qwen3.8-Flash-Next-Q8_0.gguf -devd CUDA0 \
  --spec-type draft-mtp --spec-draft-n-max 3 \
  -ngl 999 -ngld 999 -ot per_layer_token_embd=CPU \
  -sm layer --tensor-split 36,40,24 \
  -fa on -ctk q8_0 -ctv q8_0 -c 262144 --parallel 1 \
  --mmproj $M/mmproj-F16.gguf --mmproj-device CUDA1 \
  -b 2048 -ub 1536 -t 16 --cache-ram 24576 \
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 \
  --jinja --chat-template-file qwen3.8-froggeric-v22.4.jinja \
  --chat-template-kwargs '{"reasoning_effort":"xhigh"}' \
  --alias qwen3.8-flash-next --no-webui \
  --sse-ping-interval 5 \
  --host 0.0.0.0 --port 8005
