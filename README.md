# Tenstorrent Skill

Tenstorrent `console.tenstorrent.com` skill for Claude Code, Codex, and Agent SDK: Wan 2.2 text-to-video plus OpenAI-compatible chat with DeepSeek-R1, Qwen3-32B, and Qwen3-VL.

## Install

Place `SKILL.md` at one of these paths:

```text
~/.claude/skills/tenstorrent/SKILL.md
~/.codex/skills/tenstorrent/SKILL.md
```

## Authentication

Create a Tenstorrent Console account at `https://console.tenstorrent.com`, generate an API key, and export it as an environment variable:

```bash
export TENSTORRENT_KEY="your-api-key"
```

Do not commit `.env` files or real API keys.

## Chat

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/chat/completions" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-32B-Instruct",
    "messages": [{"role":"user","content":"Say hello in one short sentence."}],
    "max_tokens": 256
  }' | jq -r '.choices[0].message.content // .choices[0].message.reasoning // .choices[0].message.reasoning_content'
```

## Video

```bash
curl -sS -X POST "https://console.tenstorrent.com/v1/video/jobs" \
  -H "Authorization: Bearer $TENSTORRENT_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Wan2.2-T2V-A14B-Diffusers",
    "prompt": "A quiet cinematic shot of a small robot waving beside a workbench.",
    "negative_prompt": "low quality, distorted hands, blurry"
  }'
```

Minimal runnable examples live in `examples/`.

## License

MIT. See `LICENSE`.
