#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
for test_file in tracer-test.sh scanner-test.sh procedure-contract-test.sh walkthrough-branch-test.sh dogfood-test.sh; do
  echo "== $test_file"
  bash "$HERE/$test_file"
done
echo "chiropractor tests: ALL GREEN"
