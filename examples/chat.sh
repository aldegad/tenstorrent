#!/usr/bin/env bash
set -euo pipefail

: "${TENSTORRENT_KEY:?Set TENSTORRENT_KEY first}"

response="$(
  curl -sS -X POST "https://console.tenstorrent.com/v1/chat/completions" \
    -H "Authorization: Bearer ${TENSTORRENT_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "Qwen/Qwen3-32B",
      "messages": [{"role":"user","content":"Reply with one concise sentence about Tenstorrent."}],
      "max_tokens": 256
    }'
)"

# No silent fallback: surface API errors instead of printing null on exit 0.
if [[ "$(jq -r 'has("error")' <<<"$response")" == "true" || "$(jq -r 'has("choices")' <<<"$response")" != "true" ]]; then
  echo "Chat request failed:" >&2
  jq . <<<"$response" >&2
  exit 1
fi

jq -r '.choices[0].message.content // .choices[0].message.reasoning // .choices[0].message.reasoning_content' <<<"$response"
