#!/usr/bin/env bash
# run.sh — the clankshop test harness entrypoint. Runs every suite against throwaway
# fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for t in seed-test.sh face-test.sh migrate-scan-test.sh lint-exemption-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "clankshop tests: ALL GREEN"
else
  echo "clankshop tests: FAILURES" >&2
fi
exit "$rc"
