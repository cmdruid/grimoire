#!/usr/bin/env bash
# run.sh — the skill-builder test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== source-custody-test.sh"
bash "$DIR/source-custody-test.sh" || rc=1
echo "== tune-contract-test.sh"
bash "$DIR/tune-contract-test.sh" || rc=1

echo "== lint-records-writer-test.sh"
bash "$DIR/lint-records-writer-test.sh" || rc=1
echo "== lint-edges-test.sh"
bash "$DIR/lint-edges-test.sh" || rc=1

echo "== lint-bundle-ref-test.sh"
bash "$DIR/lint-bundle-ref-test.sh" || rc=1

echo "== lint-doctrine-consumer-test.sh"
bash "$DIR/lint-doctrine-consumer-test.sh" || rc=1

echo "== lint-skilldata-path-test.sh"
bash "$DIR/lint-skilldata-path-test.sh" || rc=1

echo "== lint-global-skilldata-test.sh"
bash "$DIR/lint-global-skilldata-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "skill-builder tests: ALL GREEN"
else
  echo "skill-builder tests: FAILURES" >&2
fi
exit "$rc"
