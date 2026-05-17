---
name: tenstorrent
description: "Use Tenstorrent console.tenstorrent.com models across chat, image, video, TTS, and STT. Triggers: tenstorrent, 텐스토렌트, Torendissi, 토렌디시, Wan2.2, T2V, text-to-video, image jobs, SDXL, tt-sd3.5, tt-z-image-turbo, DeepSeek-R1, Qwen3, Qwen3-VL, Gemma 4 31B, tts-1, whisper-large-v3."
license: MIT
compatibility: Requires internet access and a Tenstorrent console account / API key.
---

# Tenstorrent console API — full model catalog v3

본 스킬의 SSoT. `console.tenstorrent.com` 는 OpenAI-compatible chat, async image/video jobs, and audio endpoints를 노출하거나 노출 예정인 inference surface로 다룬다.

## Authentication

Use `Authorization: Bearer <TENSTORRENT_KEY>`.

```bash
export TENSTORRENT_KEY="your-api-key"
```

Do not commit real keys or `.env` files.

## Model Catalog (18 models)

### Chat (POST `/v1/chat/completions`)

| Model ID | Notes |
|---|---|
| `deepseek-ai/DeepSeek-R1-0528` | reasoning model; final answer in `content`, reasoning trace may appear in `reasoning`. |
| `Qwen/Qwen3-32B` | thinking model; trace may appear in `reasoning` and `reasoning_content`. |
| `Qwen/Qwen3-VL-32B-Instruct` | default chat; standard OpenAI-style response and text-only OK. |
| `google/gemma-4-31B-it` | Gemma 4 31B Instruct. |

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/chat/completions" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-32B-Instruct",
    "messages": [{"role":"user","content":"한국어로 한 문장 인사해줘."}],
    "max_tokens": 256
  }'
```

Parsing priority: `content > reasoning > reasoning_content`.

### Image (POST `/v1/image/jobs`)

| Model ID | Notes |
|---|---|
| `sdxl` | default image model; 1024x1024; observed target cost around $0.02. |
| `tt-sd3.5` | Stable Diffusion 3.5. |
| `tt-z-image-turbo` | Z-Image Turbo. |

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/image/jobs" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sdxl",
    "prompt": "a small robot smiling in a clean studio, soft light",
    "width": 1024,
    "height": 1024,
    "steps": 20
  }'
```

Poll `GET /v1/image/jobs/{id}` until `status: completed`, then download the returned presigned image URL immediately. Presigned artifact URLs expire.

### Video (POST `/v1/video/jobs`)

| Model ID | Notes |
|---|---|
| `Wan2.2-T2V-A14B-Diffusers` | default video; full model; ~5s 1280x720 output; observed target cost around $0.05. |
| `Prodia Wan 2.2 Lighting Text to Video` | distilled/Lightning display name from usage page. |
| `prodia/Wan2.2-T2V-A14B-Lightning` | Prodia Lightning literal. |
| `Wan2.2-T2V-A14B-Lighting-Diffusers` | usage-page spelling keeps `Lighting`. |
| `Wan2.2-T2V-A14B-Lightning` | Lightning literal. |
| `Wan2.2-T2V-A14B-Lightning-Diffusers` | Lightning Diffusers literal. |
| `Wan2.2-T2V-A14B-Lightning-Diffusers-FP8` | FP8 Lightning Diffusers literal. |
| `Wan2.2-T2V-Lightning` | short Lightning literal. |

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/video/jobs" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Wan2.2-T2V-A14B-Diffusers",
    "prompt": "A serene Korean rice field at sunrise",
    "negative_prompt": "low quality, blurry, watermark"
  }'
```

Poll `GET /v1/video/jobs/{id}` until `status: completed`, then download `video_url` or the first returned presigned URL immediately. In live use, `status: completed` can appear briefly before `video_url`; keep polling until the URL appears.

### TTS

| Model ID | Notes |
|---|---|
| `tts-1` | Endpoint discovery order: try OpenAI-compatible `POST /v1/audio/speech`, then `POST /v1/tts/jobs`. If both are unavailable, report a visible TBD instead of silently falling back. |

Expected OpenAI-compatible body:

```json
{"model":"tts-1","input":"안녕하세요","voice":"alloy"}
```

### STT

| Model ID | Notes |
|---|---|
| `whisper-large-v3` | Endpoint discovery: `POST /v1/audio/transcriptions` multipart upload with `file` and `model`. If unavailable, report visible TBD. |

## Prompt and Artifact Rules

- Video prompt limit: keep prompts at or below 2000 characters.
- Image default: `sdxl`, 1024x1024, 20 steps.
- Video default: `Wan2.2-T2V-A14B-Diffusers`.
- Audio defaults: `tts-1`, `whisper-large-v3`.
- Presigned artifact URLs expire; download immediately into local output paths.
- No silent fallback: if an endpoint is missing, report the missing endpoint explicitly.

## CLI Companion

The companion CLI is `aldegad/tenstorrent-cli`.

```bash
tenstorrent
/model
/image a cat
/video A serene Korean rice field at sunrise
/tts 안녕하세요
/stt ./audio.wav
```

## Source

Catalog source: console.tenstorrent.com inference usage page as captured for the 2026-05-18 v0.2 Torendissi patch, plus live CLI endpoint probes for image/video/audio behavior.
