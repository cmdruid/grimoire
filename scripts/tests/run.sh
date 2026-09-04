#!/usr/bin/env bash
# run.sh — repository integration-test entrypoint. Throwaway fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
for test_file in agent-feedback-hard-cut-test.sh configure-clankshop-test.sh clankshop-contract-test.sh workstream-hard-cut-contract-test.sh backlog-provider-contract-test.sh project-layer-anchor-contract-test.sh canonical-provider-parity-test.sh; do
  echo "== $test_file"
  bash "$DIR/$test_file" || rc=1
done

echo "== skills/chiropractor/scripts/tests/run.sh"
bash "$DIR/../../skills/chiropractor/scripts/tests/run.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "repository integration tests: ALL GREEN"
else
  echo "repository integration tests: FAILURES" >&2
fi
exit "$rc"
