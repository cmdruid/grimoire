#!/usr/bin/env bash
# run.sh — debugger test harness entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== bug-mint-test.sh"
bash "$DIR/bug-mint-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "debugger tests: ALL GREEN"
else
  echo "debugger tests: FAILURES" >&2
fi
exit "$rc"
