#!/usr/bin/env bash
# Documentation spine for gcloud-operator.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

expect "entrypoint documented" 'scripts/gcloud-session.sh' "$SKILL/SKILL.md"
expect "doctor verb" 'gcloud-session.sh doctor' "$SKILL/SKILL.md"
expect "open verb" 'gcloud-session.sh open' "$SKILL/SKILL.md"
expect "run verb" 'gcloud-session.sh run' "$SKILL/SKILL.md"
expect "copy-to verb" 'copy-to' "$SKILL/SKILL.md"
expect "copy-from verb" 'copy-from' "$SKILL/SKILL.md"
expect "status verb" 'status' "$SKILL/SKILL.md"
expect "close verb" 'close' "$SKILL/SKILL.md"
expect "transport ref" 'references/transport.md' "$SKILL/SKILL.md"
expect "failures ref" 'references/failures.md' "$SKILL/SKILL.md"
expect "threat model ref" 'references/threat-model.md' "$SKILL/SKILL.md"
expect "live smoke ref" 'references/live-smoke.md' "$SKILL/SKILL.md"
expect "scratch-only disposition" 'scratch-only' "$SKILL/SKILL.md"
expect "no durable home" 'no durable project home' "$SKILL/SKILL.md"
expect "IAP only" 'Never create an external IP' "$SKILL/SKILL.md"
expect "troubleshoot default" 'Prohibit `gcloud compute ssh --troubleshoot` by default' "$SKILL/SKILL.md"
expect "impersonation control-plane" 'control-plane' "$SKILL/SKILL.md"
expect "no SA keys" 'persistent service-account keys' "$SKILL/SKILL.md"
expect "hypothesis not promise" 'hypothesis' "$SKILL/references/transport.md"
expect "live test disposable dir" 'mktemp' "$SKILL/references/live-smoke.md"
expect "live smoke planned path" 'planned_network_path=iap-tcp' "$SKILL/references/live-smoke.md"
expect "live smoke IAM baseline" 'get-iam-policy' "$SKILL/references/live-smoke.md"
expect "inspection IAM documented" 'compute.instances.get' "$SKILL/references/failures.md"
expect "threat model residual risk" 'does not' "$SKILL/references/threat-model.md"

if grep -q 'eval' "$SKILL/SKILL.md"; then
  echo "FAIL: SKILL.md should not instruct eval" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "skill-doc-test"
