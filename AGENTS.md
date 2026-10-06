# tenstorrent 작업지침

이 레포가 `tenstorrent` 스킬의 SSoT 다. 루트 `SKILL.md` 하나가 정본이고 사본은 없다.

## 스킬 등록

전역 스킬이 아니라 **프로젝트 스코프**다 (2026-08-20 — 전역 스킬 목록에서
빼고 이 레포에서 일할 때만 로드되게 옮겼다). 등록은 레포가 소유하는 상대 심링크다:

```text
.claude/skills/tenstorrent/{SKILL.md,examples}  -> ../../../{SKILL.md,examples}   # Claude Code
.agents/skills/tenstorrent/{SKILL.md,examples}  -> ../../../{SKILL.md,examples}   # Codex / Cursor / Grok
```

루트를 통째로 심링크하지 않는 이유: `.claude`/`.agents` 가 루트 안에 있어 재귀 루프가 되고
Codex 의 skills 스캔 traversal budget 을 태운다. 필요한 항목만 지목해 건다.

전역 설치가 필요해지면 사본을 만들지 말고 여기 경로를 링크한다 — 예전 사본은 2026-08-20 에
삭제했다 (그 사본이 live API 에 없는 모델을 문서화한 채로 6월 수정본과 갈라져 있었다).

## 규칙

- 모델 카탈로그는 실측이 근거다. `/v1/models` 에 없는 모델을 문서에 넣지 않는다.
- `examples/*.sh` 는 API 에러를 삼키지 않는다 (no silent fallback). 회귀는 `bash test/run.sh`.
- 게이트는 `bash test/lane.sh` 하나다 — 문법(`bash -n`), `shellcheck --severity=error`, 회귀 테스트를
  커밋한 깨끗한 체크아웃에서 차례로 돈다. 자체 러너(jq·shellcheck 가 PATH 에 있는 리눅스)에서 돌린다.

## CI

GitHub(git 호스팅) CI 는 쓰지 않는다 — 워크플로를 만들지도 돌리지도 않는다. CI 는 알렉스가 구성해 둔 자체 인프라(원격 러너·테스트 장비)에서 따로 돌린다. 이유: git CI 는 너무 느리다. 새 프로젝트를 시작할 때 이 절을 그 프로젝트 `AGENTS.md` 에 그대로 복사해 넣는다.
