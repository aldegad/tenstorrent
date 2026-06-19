#!/usr/bin/env bash
# Regression tests for the Tenstorrent wrapper scripts (examples/chat.sh, examples/video.sh).
# Shadows `curl` with test/mock-bin so no real API key, network, or quota is used.
# Verifies the no-silent-fallback contract: API errors are surfaced and exit non-zero,
# success paths print/download as documented in SKILL.md.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK_BIN="$ROOT/test/mock-bin"
CHAT="$ROOT/examples/chat.sh"
VIDEO="$ROOT/examples/video.sh"
PASS=0
FAIL=0

RC=0; OUT=""; ERR=""; DLED=""
run() { # run <scenario> <key|''> <script> [args...]
  local scenario="$1" key="$2" script="$3"
  shift 3
  local workdir
  workdir="$(mktemp -d)"
  if [[ -n "$key" ]]; then
    OUT="$(cd "$workdir" && MOCK_SCENARIO="$scenario" PATH="$MOCK_BIN:$PATH" \
      TENSTORRENT_KEY="$key" bash "$script" "$@" 2>"$workdir/err")"
  else
    OUT="$(cd "$workdir" && MOCK_SCENARIO="$scenario" PATH="$MOCK_BIN:$PATH" \
      env -u TENSTORRENT_KEY bash "$script" "$@" 2>"$workdir/err")"
  fi
  RC=$?
  ERR="$(cat "$workdir/err" 2>/dev/null)"
  DLED="$(find "$workdir/output" -name '*.mp4' 2>/dev/null | head -1)"
  rm -rf "$workdir"
}
ok()  { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n     RC=%s OUT=[%s] ERR=[%s] DL=[%s]\n' "$1" "$RC" "$OUT" "$ERR" "$DLED"; }

echo "[env guard] 키 없으면 즉시 실패"
run "" "" "$CHAT";  { [[ "$RC" -ne 0 ]] && [[ "$ERR" == *TENSTORRENT_KEY* ]]; } && ok "chat: missing key -> fail" || bad "chat: missing key"
run "" "" "$VIDEO"; { [[ "$RC" -ne 0 ]] && [[ "$ERR" == *TENSTORRENT_KEY* ]]; } && ok "video: missing key -> fail" || bad "video: missing key"

echo "[chat]"
run "chat-ok" "dummy" "$CHAT";    { [[ "$RC" -eq 0 ]] && [[ "$OUT" == *Tenstorrent* ]]; } && ok "chat: success prints content" || bad "chat: success"
run "chat-error" "dummy" "$CHAT"; { [[ "$RC" -ne 0 ]] && [[ "$ERR" == *invalid_api_key* || "$ERR" == *error* ]]; } && ok "chat: API error surfaced + nonzero" || bad "chat: error surfaced"

echo "[video]"
run "video-ok" "dummy" "$VIDEO" "test prompt";   { [[ "$RC" -eq 0 ]] && [[ -n "$DLED" ]]; } && ok "video: success downloads + exit 0" || bad "video: success"
run "video-presigned" "dummy" "$VIDEO" "test";   { [[ "$RC" -eq 0 ]] && [[ -n "$DLED" ]]; } && ok "video: presigned-only completed downloads" || bad "video: presigned fallback"
run "video-error" "dummy" "$VIDEO" "test";       { [[ "$RC" -ne 0 ]] && [[ "$ERR" == *"no job id"* || "$ERR" == *error* ]]; } && ok "video: missing job_id surfaced + exit 1" || bad "video: missing job_id"
run "video-failed" "dummy" "$VIDEO" "test";      { [[ "$RC" -ne 0 ]]; } && ok "video: failed status -> exit 1" || bad "video: failed status"

echo ""
echo "RESULT: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
