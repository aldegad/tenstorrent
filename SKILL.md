---
name: tenstorrent
description: "Use Tenstorrent console.tenstorrent.com models — Wan 2.2 text-to-video (Diffusers full / Lightning distilled) for cinematic shots, and OpenAI-compatible chat/completions for DeepSeek-R1 reasoning, Qwen3-32B thinking-mode, Qwen3-VL-32B vision-language. Triggers (Korean/English): tenstorrent, 텐스토렌트, Wan2.2, T2V, text-to-video, console.tenstorrent.com, Lightning distilled video, prompt 2000자 한도, UMT5 token limit, video_url 1h presigned, DeepSeek-R1, Qwen3, Qwen3-VL, reasoning model, thinking mode."
license: MIT
compatibility: Requires internet access and a Tenstorrent console account / API key.
---

# Tenstorrent console API — Wan 2.2 video + OpenAI-compatible chat

본 스킬의 SSoT. `console.tenstorrent.com` 는 두 종류 엔드포인트를 노출한다:

- `/v1/video/jobs` — Wan 2.2 (Diffusers full / Lightning distilled) text-to-video.
- `/v1/chat/completions` — OpenAI 호환 chat. DeepSeek-R1, Qwen3-32B, Qwen3-VL-32B.

prompt 한도와 모델별 응답 함정을 사전 검증해 retry round-trip / quota 낭비를 막는다.

## Trigger / Routing SSoT

라우팅 trigger 의 canonical source 는 frontmatter `description` 이다.
YAML 파싱 안전성 때문에 trigger 를 본문으로만 내리거나 축약하지 않는다.
본문은 실행 절차용이며, skill loader 가 본문 trigger 를 항상 라우팅에 반영한다고 가정하지 않는다.

## 인증

`Authorization: Bearer <TENSTORRENT_KEY>`. 환경변수 `TENSTORRENT_KEY` 우선.
bash subshell 사이에 env 전파가 안 되는 환경(`env` 분리, `xargs`, 별도 worker)에서는
**매 curl 호출에서 literal 키를 박는 게 안전함**.

## 호출 — video

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/video/jobs" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Wan2.2-T2V-A14B-Diffusers",
    "prompt": "<prompt 2000자 이하>",
    "negative_prompt": "<negatives>"
  }'
```

응답: `job_id`. 이후 `GET /v1/video/jobs/{id}` 폴링 → `status: completed` 면 `video_url`.

## 호출 — chat (OpenAI 호환)

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/chat/completions" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-32B-Instruct",
    "messages": [{"role":"user","content":"..."}],
    "max_tokens": 1024
  }'
```

응답 파싱은 모델별로 다름 (아래 카탈로그의 nuance 컬럼 참고).

## 모델 카탈로그 (2026-05-17 실측 기준)

### Video (POST `/v1/video/jobs`)

| Model ID (literal) | 종류 | step | 실측 영상 | 실측 latency | 강점 / 한계 |
|---|---|---|---|---|---|
| `Wan2.2-T2V-A14B-Diffusers` | full | 40 (디폴트 40, 응답엔 20 으로도 잡힘) | 1280×720, 16fps, 5.06s, h264, ~4.2MB | 26s (queue+infer) | 발표용 품질, multi-phase action OK |
| `Prodia Wan 2.2 Lighting Text to Video` | distilled (Lightning) | 20 | 1280×720, 16fps, 5.06s, h264, ~3.7MB | 29s (queue+infer) | 빠르지만 multi-phase action (빠른 격투 액션 같은) **못 잡음** — 정지 캐릭터 + 카메라 오비트로 우회하는 게 ROI |

- 두 모델 모두 응답에 `duration_seconds: 5` 로 박혀 나오고 실제 영상도 5.06s. SKILL 이전판의 "15~40s / ~7s" 는 ask 가능한 상한이지 기본 응답이 아니다. 길이를 명시적으로 늘리려면 별도 파라미터 검증 필요.
- 응답에 `estimated_cents: 5` ($0.05/영상) — 두 모델 동일.

### Chat (POST `/v1/chat/completions`)

| Model ID (literal) | 종류 | 실측 latency | tokens (prompt/completion/total) | 응답 nuance |
|---|---|---|---|---|
| `deepseek-ai/DeepSeek-R1-0528` | reasoning | 2.2s | 20 / 333 / 353 (reasoning 275) | **응답이 `choices[0].message.reasoning` 에도 들어옴** — final answer 는 `content`. `max_tokens` 너무 작으면 reasoning 도중 잘림. 1024+ 권장. `tps`, `ttft_ms` 메타 포함. |
| `Qwen/Qwen3-32B` | thinking | 7.3s | 별도 표기 없음 (vLLM 스타일 응답) | thinking 텍스트가 `reasoning` 및 `reasoning_content` 필드 양쪽에 들어옴 (`<think>...</think>` 태그 아님 — 별도 필드). `content` 는 최종 답만. completion 가끔 깨진 문자 (`이야기��스트`) — sanity check 필요. |
| `Qwen/Qwen3-VL-32B-Instruct` | vision-language (text-only OK) | 7.7s | 23 / 56 / 79 | 가장 깔끔. `reasoning`/`reasoning_content` 모두 null, `content` 만 채워옴. `finish_reason: stop`. self-identification 이 "네이버 클로바" 로 오답 — 모델이 페르소나 제어가 약함. |

## 운영 한도 — 사전 검증 필수 (video)

### prompt 길이

- 한도: **`len(prompt) <= 2000` (UTF-8 문자수, ~512 UMT5 토큰)**.
- 넘으면 400 `prompt_too_long`:
  ```json
  {"error":{"code":"prompt_too_long","message":"Prompt must be 2000 characters or fewer (~512 UMT5 tokens)"}}
  ```
- **quota 안 깎이지만 retry round-trip 낭비** — submit 전 클라이언트에서 길이 체크.
- 실측: 2200/2004 chars → reject (정확히 2000 이하 필요), 1968/1886 → 통과.
- 응답 메시지 정규식으로 한도 추출 가능: `/Prompt must be (\d+) characters or fewer/`.

### prompt 압축 포인트 (한도 초과 시 줄이는 부위)

1. **중복 형용사** — "sharp angular hawkish + sharp jawline" 같이 같은 의미 두 번이면 하나로.
2. **ACTION / Setting 섹션 부연 설명** — 보조 묘사가 길면 짧게.
3. **negative 의 동의어 그룹** — "shiny / glossy / polished" 같은 그룹은 1~2개로 충분.

### negative_prompt

- 별도 길이 제한이 있는지 확실치 않으나 `prompt + negative_prompt` 합산 한도는 아님.
- 보수적으로 따로 짧게 유지.

## 응답 / 동작 메모 (video)

- `visibility` 입력 무시됨 — 항상 public 으로 모더레이션 결정.
- `PATCH` (수정) → 405 Method Not Allowed.
- `DELETE` (취소) → 204. **큐 단계에서 삭제하면 quota 환불.**
- `video_url` = S3 presigned URL (us-east-2 버킷 `tenstorrent-cloud-console-prod`), **1 시간 만료** → 즉시 다운로드.
- 버킷 anonymous 접근은 403 — presigned URL 으로만.

## 응답 메모 (chat)

- DeepSeek-R1 은 OpenAI 응답 스키마에 `reasoning` 필드를 추가했음. 파싱 시 `content` 가 비어 있으면 `reasoning` 도 같이 확인.
- Qwen3-32B 는 `reasoning` 과 `reasoning_content` 가 같은 내용으로 중복돼서 들어옴. UI 노출은 하나만.
- 세 모델 모두 한국어 즉답 OK. self-identification 답변은 모델별로 부정확할 수 있으니 검증 용도로 쓰지 말 것.

## 모델 선택 가이드 — video

- multi-phase action / 격투 / 빠른 격투 / 변신 → Diffusers full.
- 정지 + 카메라 오비트 / 분위기 / 풍경 → Lightning distilled (저비용, 빠름).
- 멀티 액션을 Lightning 으로 무리하면 동작 누락. 그럴 거면 Diffusers full 로 가거나
  카메라 오비트 / 정지 캐릭터 컨셉으로 우회.

## 모델 선택 가이드 — chat

- **추론 (수학·코드·계획)** → DeepSeek-R1. `reasoning` trace 가 별도 필드로 와서 디버깅·로그에 그대로 떨굴 수 있음.
- **장문 한국어 / 다국어 / thinking trace 필요** → Qwen3-32B.
- **빠른 일반 답 / vision 입력 가능성** → Qwen3-VL-32B-Instruct. 응답 스키마가 가장 표준에 가까워 OpenAI SDK 직결 시 가장 무난.

## Cross-references

- 결이 다른 비디오 API: BytePlus Seedance (`byteplus-seedance` skill) — image-to-video,
  flf2v seamless loop. 입력이 이미지면 거기로 라우팅.

## Source

운영 룰 SSoT 는 본 파일이다. 근거 데이터:
- 운영 실측 (3회 reject 2221/2220/2004 chars, 1968/1886 통과).
- 2026-05-17 5-model spike 실측 (DeepSeek-R1, Qwen3-32B, Qwen3-VL, Wan2.2 full/Lightning).
