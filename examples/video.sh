#!/usr/bin/env bash
set -euo pipefail

: "${TENSTORRENT_KEY:?Set TENSTORRENT_KEY first}"

prompt="${1:-A calm cinematic shot of a tiny robot waving beside a workbench, soft studio light.}"
mkdir -p output

job_id="$(
  curl -sS -X POST "https://console.tenstorrent.com/v1/video/jobs" \
    -H "Authorization: Bearer ${TENSTORRENT_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt" '{
      model: "Wan2.2-T2V-A14B-Diffusers",
      prompt: $prompt,
      negative_prompt: "low quality, distorted hands, blurry"
    }')" | jq -r '.job_id // .id'
)"

if [[ -z "$job_id" || "$job_id" == "null" ]]; then
  echo "No job id returned" >&2
  exit 1
fi

echo "job_id=${job_id}"

for _ in {1..40}; do
  status_json="$(
    curl -sS "https://console.tenstorrent.com/v1/video/jobs/${job_id}" \
      -H "Authorization: Bearer ${TENSTORRENT_KEY}"
  )"
  status="$(jq -r '.status // empty' <<<"$status_json")"
  echo "status=${status}"

  if [[ "$status" == "completed" ]]; then
    video_url="$(jq -r '.video_url // empty' <<<"$status_json")"
    if [[ -z "$video_url" ]]; then
      sleep 5
      continue
    fi
    output_path="output/video-$(date +%Y%m%d-%H%M%S).mp4"
    curl -L -sS "$video_url" -o "$output_path"
    echo "$output_path"
    exit 0
  fi

  if [[ "$status" == "failed" || "$status" == "cancelled" ]]; then
    jq . <<<"$status_json" >&2
    exit 1
  fi

  sleep 5
done

echo "Timed out waiting for video job ${job_id}" >&2
exit 1
