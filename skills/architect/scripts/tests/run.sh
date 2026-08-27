#!/usr/bin/env bash
# run.sh — the architect test harness entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for t in ground-check-test.sh artifacts-test.sh procedure-contract-test.sh skill-doc-test.sh migrate-contract-test.sh setup-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "architect tests: ALL GREEN"
else
  echo "architect tests: FAILURES" >&2
fi
exit "$rc"
