#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"; B="$ROOT/skills/backlog"; pass=0 fail=0
for f in setup tracker file debrief curate; do [ -f "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
for f in task issue feedback promote; do [ ! -e "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
for f in "$B/scripts/record-"mint.sh "$B/templates/"trackers.md; do [ ! -e "$f" ] && pass=$((pass+1)) || fail=$((fail+1)); done
if rg -n '/backlog (task|issue|feedback|promote)([^a-z-]|$)' "$ROOT/skills" >/dev/null; then fail=$((fail+1)); else pass=$((pass+1)); fi
echo "skill-doc-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
