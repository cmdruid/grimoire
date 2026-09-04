#!/usr/bin/env bash
# Red-prove skill contracts: forbidden mutations, MFA distinction, live-smoke isolation.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
pass=0
fail=0

contract_ok() {
  local root="$1"
  grep -q 'scripts/gcloud-session.sh' "$root/SKILL.md" &&
    grep -q -- '--mfa-method' "$root/SKILL.md" &&
    grep -q 'security-code' "$root/SKILL.md" &&
    grep -q 'authenticator' "$root/SKILL.md" &&
    grep -q 'never inferred from digit count' "$root/SKILL.md" &&
    grep -q 'does not authorize' "$root/SKILL.md" &&
    grep -q 'gcloud compute ssh --troubleshoot' "$root/SKILL.md" &&
    grep -q 'do not copy' "$root/SKILL.md" &&
    grep -q 'references/live-smoke.md' "$root/SKILL.md" &&
    grep -q 'hypothesis' "$root/references/transport.md" &&
    ! grep -q 'eval ' "$root/scripts/gcloud-session.sh" &&
    ! grep -q 'eval ' "$root/scripts/gcloud-session-lib.sh"
}

if contract_ok "$SKILL"; then pass=$((pass + 1)); else echo 'FAIL: live contract' >&2; fail=$((fail + 1)); fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-operator-contract.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
cp -R "$SKILL" "$tmp/skill"
cp "$tmp/skill/SKILL.md" "$tmp/SKILL.before"
plant='Infer the MFA method from the number of digits in the code.'
printf '\n%s\n' "$plant" >>"$tmp/skill/SKILL.md"
if grep -q 'never inferred from digit count' "$tmp/skill/SKILL.md" && grep -qFx "$plant" "$tmp/skill/SKILL.md"; then
  # contract_ok still requires the never-inferred line, so plant a deletion too
  :
fi
# Break the load-bearing prohibition and prove the guard would catch it.
sed -i.bak '/never inferred from digit count/d' "$tmp/skill/SKILL.md"
eq_count="$(grep -c 'never inferred from digit count' "$tmp/skill/SKILL.md" || true)"
if [ "$eq_count" = 0 ]; then pass=$((pass + 1)); else echo 'FAIL: plant did not remove prohibition' >&2; fail=$((fail + 1)); fi
if contract_ok "$tmp/skill"; then
  echo 'FAIL: contract stayed green after deleting MFA distinction' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
cp "$tmp/SKILL.before" "$tmp/skill/SKILL.md"
if cmp -s "$tmp/SKILL.before" "$tmp/skill/SKILL.md"; then pass=$((pass + 1)); else echo 'FAIL: restore drifted' >&2; fail=$((fail + 1)); fi
if contract_ok "$tmp/skill"; then pass=$((pass + 1)); else echo 'FAIL: restored contract' >&2; fail=$((fail + 1)); fi

# Helper must not mutate GCP during doctor/open/status/close.
if grep -E 'services enable|firewall-rules create|add-access-config|iam service-accounts keys create' \
    "$SKILL/scripts/gcloud-session.sh" "$SKILL/scripts/gcloud-session-lib.sh"; then
  echo 'FAIL: forbidden mutation strings in helper' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

echo "contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
