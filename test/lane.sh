#!/usr/bin/env bash
# The repository's gates, run on the owner's own runner (GitHub-hosted CI is not used).
#
# Run it from a clean checkout of the commit being measured, on a host with bash, jq and
# shellcheck on PATH. It installs nothing: a missing tool ends the run by name. Each gate stops
# the run on its first failure:
#   1. syntax   bash -n over the wrapper scripts and the test harness
#   2. lint     shellcheck --severity=error over the same files
#   3. test     test/run.sh (curl is mocked; no API key, network or quota)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

FILES=(examples/chat.sh examples/video.sh test/run.sh test/mock-bin/curl)

fail() {
  echo "lane: $*" >&2
  exit 1
}
step() {
  echo "== $*"
}

step "preflight"
for tool in bash jq shellcheck; do
  command -v "$tool" >/dev/null || fail "$tool is not on PATH"
done
git diff --quiet && git diff --cached --quiet || fail "the checkout has uncommitted changes"
echo "commit $(git rev-parse HEAD)"
echo "shellcheck $(shellcheck --version | sed -n 's/^version: //p')"

step "syntax"
# One file per call: `bash -n a b c` reads only a and passes the rest as its arguments.
for f in "${FILES[@]}"; do
  bash -n "$f"
done

step "lint"
shellcheck --severity=error "${FILES[@]}"

step "test"
bash test/run.sh

echo "lane: every gate passed at $(git rev-parse HEAD)"
