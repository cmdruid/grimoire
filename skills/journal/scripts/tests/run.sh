#!/usr/bin/env bash
# run.sh — the journal test harness entrypoint. Runs every suite against throwaway
# fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for t in standup-test.sh records-test.sh; do
  echo "== $t"
  bash "$DIR/$t" || rc=1
done

if [ "$rc" -eq 0 ]; then
  echo "journal tests: ALL GREEN"
else
  echo "journal tests: FAILURES" >&2
fi
exit "$rc"
