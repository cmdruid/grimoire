#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"
expect 'parent pauses for isolation' 'pause the parent' "$SKILL/SKILL.md"
expect 'native isolation only' 'native full-context fork' "$SKILL/SKILL.md"
expect 'delegate is forbidden for hook isolation' 'Do not substitute' "$SKILL/SKILL.md"
expect 'child returns closure only' 'status: complete | blocked | uncertain' "$SKILL/SKILL.md"
expect 'failed child has no fallback' 'failure never falls back inline' "$SKILL/SKILL.md"
expect 'single lifecycle writer' 'sole lifecycle writer' "$SKILL/SKILL.md"
if rg -n 'Also read|read .*verbs/|flow\.md' "$SKILL/SKILL.md" "$SKILL/verbs" >/dev/null; then fail=$((fail + 1)); echo 'FAIL: runtime procedure has a chained read edge' >&2; else pass=$((pass + 1)); fi
if rg -n 'Task tool|codex exec --model|use (a |the )?generic worker|use (a |the )?parallel dispatcher' "$SKILL/SKILL.md" "$SKILL/verbs" >/dev/null; then fail=$((fail + 1)); echo 'FAIL: unsupported hook transport is live' >&2; else pass=$((pass + 1)); fi
report 'seam-contract-test'
