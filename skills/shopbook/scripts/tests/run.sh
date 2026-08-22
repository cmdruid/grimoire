#!/usr/bin/env bash
# run.sh — the shopbook test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for t in flows-door-test.sh flows-index-test.sh flows-upkeep-test.sh flows-create-test.sh skill-doc-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "shopbook tests: ALL GREEN"
else
  echo "shopbook tests: FAILURES" >&2
fi
exit "$rc"
