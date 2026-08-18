#!/usr/bin/env bash
# run.sh — the backlog test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== record-mint-test.sh"
bash "$DIR/record-mint-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "backlog tests: ALL GREEN"
else
  echo "backlog tests: FAILURES" >&2
fi
exit "$rc"
