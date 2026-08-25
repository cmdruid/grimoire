#!/usr/bin/env bash
# run.sh — mailbox test harness entrypoint.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== mailbox-test.sh"
if bash "$DIR/mailbox-test.sh"; then
  echo "mailbox tests: ALL GREEN"
else
  echo "mailbox tests: FAILURES" >&2
  exit 1
fi
