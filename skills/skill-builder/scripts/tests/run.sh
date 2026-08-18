#!/usr/bin/env bash
# run.sh — the skill-builder test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== lint-records-writer-test.sh"
bash "$DIR/lint-records-writer-test.sh" || rc=1

echo "== lint-doctrine-consumer-test.sh"
bash "$DIR/lint-doctrine-consumer-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "skill-builder tests: ALL GREEN"
else
  echo "skill-builder tests: FAILURES" >&2
fi
exit "$rc"
