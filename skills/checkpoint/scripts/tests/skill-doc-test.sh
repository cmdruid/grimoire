#!/usr/bin/env bash
# skill-doc-test.sh — guard the CHECKPOINT-only lifecycle after the rename cleanup.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

if grep -ERq 'HANDOFF\.md|Formerly the `handoff` skill|pre-rename' \
  "$SKILL/SKILL.md" "$SKILL/verbs"; then
  echo "FAIL: checkpoint still carries pre-rename HANDOFF compatibility" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

finish "checkpoint skill docs"
