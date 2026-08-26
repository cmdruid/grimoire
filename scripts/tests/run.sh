#!/usr/bin/env bash
# run.sh — repository integration-test entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for test_file in install-pack-test.sh configure-clankshop-test.sh; do
  echo "== $test_file"
  bash "$DIR/$test_file" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "repository integration tests: ALL GREEN"
else
  echo "repository integration tests: FAILURES" >&2
fi
exit "$rc"
