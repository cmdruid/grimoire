#!/usr/bin/env bash
# run.sh — the backlog test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== tracker-api-test.sh"
bash "$DIR/tracker-api-test.sh" || rc=1
echo "== deploy-test.sh"
bash "$DIR/deploy-test.sh" || rc=1
echo "== debrief-contract-test.sh"
bash "$DIR/debrief-contract-test.sh" || rc=1
echo "== hard-cut-test.sh"
bash "$DIR/hard-cut-test.sh" || rc=1
echo "== skill-doc-test.sh"
bash "$DIR/skill-doc-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "backlog tests: ALL GREEN"
else
  echo "backlog tests: FAILURES" >&2
fi
exit "$rc"
