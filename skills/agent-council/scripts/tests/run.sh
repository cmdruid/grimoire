#!/usr/bin/env bash
# run.sh — agent-council test entrypoint. Throwaway PATH fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
echo "== probe-seats-test.sh"
bash "$DIR/probe-seats-test.sh" || rc=1
if [ "$rc" -eq 0 ]; then
  echo "agent-council tests: ALL GREEN"
else
  echo "agent-council tests: FAILURES" >&2
fi
exit "$rc"
