#!/usr/bin/env bash
# run.sh — the workstream test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== hooks-test.sh"
rc=0
bash "$DIR/hooks-test.sh" || rc=1
echo "== git-helpers-test.sh"
bash "$DIR/git-helpers-test.sh" || rc=1
echo "== artifact-contract-test.sh"
bash "$DIR/artifact-contract-test.sh" || rc=1
echo "== seam-contract-test.sh"
bash "$DIR/seam-contract-test.sh" || rc=1
echo "== workstream-prime-test.sh"
bash "$DIR/workstream-prime-test.sh" || rc=1
echo "== setup-test.sh"
bash "$DIR/setup-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "workstream tests: ALL GREEN"
else
  echo "workstream tests: FAILURES" >&2
fi
exit "$rc"
