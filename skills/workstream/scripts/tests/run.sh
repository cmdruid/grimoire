#!/usr/bin/env bash
# run.sh — the workstream test harness entrypoint. Runs every suite against
# throwaway fixtures (patient-zero holds: nothing touches the library's own tree).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== runtime-tracer-test.sh"
bash "$DIR/runtime-tracer-test.sh" || rc=1
echo "== state-contract-test.sh"
bash "$DIR/state-contract-test.sh" || rc=1
echo "== read-envelope-test.sh"
bash "$DIR/read-envelope-test.sh" || rc=1
echo "== runbook-contract-test.sh"
bash "$DIR/runbook-contract-test.sh" || rc=1
echo "== unit-lifecycle-test.sh"
bash "$DIR/unit-lifecycle-test.sh" || rc=1
echo "== hook-runtime-test.sh"
bash "$DIR/hook-runtime-test.sh" || rc=1
echo "== isolation-contract-test.sh"
bash "$DIR/isolation-contract-test.sh" || rc=1
echo "== operator-note-test.sh"
bash "$DIR/operator-note-test.sh" || rc=1
echo "== shipment-prepare-test.sh"
bash "$DIR/shipment-prepare-test.sh" || rc=1
echo "== gate-contract-test.sh"
bash "$DIR/gate-contract-test.sh" || rc=1
echo "== gitlink-readiness-test.sh"
bash "$DIR/gitlink-readiness-test.sh" || rc=1
echo "== ship-friction-test.sh"
bash "$DIR/ship-friction-test.sh" || rc=1
echo "== delivery-contract-test.sh"
bash "$DIR/delivery-contract-test.sh" || rc=1
echo "== landing-lease-test.sh"
bash "$DIR/landing-lease-test.sh" || rc=1
echo "== primary-checkout-contract-test.sh"
bash "$DIR/primary-checkout-contract-test.sh" || rc=1
echo "== partial-delivery-test.sh"
bash "$DIR/partial-delivery-test.sh" || rc=1
echo "== pr-delivery-test.sh"
bash "$DIR/pr-delivery-test.sh" || rc=1
echo "== finalization-test.sh"
bash "$DIR/finalization-test.sh" || rc=1
echo "== control-surface-test.sh"
bash "$DIR/control-surface-test.sh" || rc=1
echo "== anchor-test.sh"
bash "$DIR/anchor-test.sh" || rc=1
echo "== recovery-contract-test.sh"
bash "$DIR/recovery-contract-test.sh" || rc=1
echo "== reconfig-test.sh"
bash "$DIR/reconfig-test.sh" || rc=1
echo "== migration-test.sh"
bash "$DIR/migration-test.sh" || rc=1
shellcheck "$DIR/../workstream-migrate.sh" "$DIR/migration-test.sh" || rc=1
echo "== topology-contract-test.sh"
bash "$DIR/topology-contract-test.sh" || rc=1
echo "== git-helpers-test.sh"
bash "$DIR/git-helpers-test.sh" || rc=1
echo "== artifact-contract-test.sh"
bash "$DIR/artifact-contract-test.sh" || rc=1
echo "== seam-contract-test.sh"
bash "$DIR/seam-contract-test.sh" || rc=1
echo "== workstream-prime-test.sh"
bash "$DIR/workstream-prime-test.sh" || rc=1

if [ "$rc" -eq 0 ]; then
  echo "workstream tests: ALL GREEN"
else
  echo "workstream tests: FAILURES" >&2
fi
exit "$rc"
