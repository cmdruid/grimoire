#!/usr/bin/env bash
# run.sh — mailbox test harness entrypoint.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for test in mailbox-test.sh contract-test.sh; do
  echo "== $test"
  bash "$DIR/$test" || rc=1
done
[ "$rc" -eq 0 ] && echo "mailbox tests: ALL GREEN" || echo "mailbox tests: FAILURES" >&2
exit "$rc"
