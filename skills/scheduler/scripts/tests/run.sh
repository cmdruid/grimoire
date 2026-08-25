#!/usr/bin/env bash
# run.sh — scheduler test harness entrypoint.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== schedule-test.sh"
if bash "$DIR/schedule-test.sh"; then
  echo "scheduler tests: ALL GREEN"
else
  echo "scheduler tests: FAILURES" >&2
  exit 1
fi
