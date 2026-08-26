#!/usr/bin/env bash
# run.sh — the contractor test harness entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for t in ground-check-test.sh skill-doc-test.sh setup-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "contractor tests: ALL GREEN"
else
  echo "contractor tests: FAILURES" >&2
fi
exit "$rc"
