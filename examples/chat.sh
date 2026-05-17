#!/usr/bin/env bash
set -euo pipefail

: "${TENSTORRENT_KEY:?Set TENSTORRENT_KEY first}"

curl -sS -X POST "https://console.tenstorrent.com/v1/chat/completions" \
  -H "Authorization: Bearer ${TENSTORRENT_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-32B-Instruct",
    "messages": [{"role":"user","content":"Reply with one concise sentence about Tenstorrent."}],
    "max_tokens": 256
  }' | jq -r '.choices[0].message.content // .choices[0].message.reasoning // .choices[0].message.reasoning_content'
