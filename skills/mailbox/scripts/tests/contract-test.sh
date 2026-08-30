#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/../.." && pwd)"
pass=0
fail=0

eq(){
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected '$2', got '$3'" >&2
    fail=$((fail + 1))
  fi
}

contract_ok(){
  local doc="$1/SKILL.md"
  grep -q 'dispatch capability the caller already selected' "$doc" &&
    grep -q 'absolute slot path' "$doc" &&
    grep -q 'exact single-writer contract' "$doc" &&
    grep -q 'Mailbox neither selects nor reinterprets provider or model values' "$doc" &&
    grep -q 'git status --short.*unchanged from dispatch' "$doc" &&
    grep -q 'scripts/mailbox-apply.sh' "$doc" &&
    ! rg -q '(Claude|Codex).*(always has|has no|no native|must use).*(dispatch|sub-agent|Task tool|codex exec)' "$doc"
}

if contract_ok "$SKILL"; then pass=$((pass + 1)); else echo 'FAIL: live mailbox contract' >&2; fail=$((fail + 1)); fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/mailbox-contract.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/mailbox"
cp -R "$SKILL" "$fixture"
cp "$fixture/SKILL.md" "$tmp/SKILL.before"
plant='Claude always has a native sub-agent dispatch primitive.'
printf '\n%s\n' "$plant" >> "$fixture/SKILL.md"
eq "one named-harness plant" "1" "$(grep -cFx "$plant" "$fixture/SKILL.md")"
if contract_ok "$fixture"; then
  echo 'FAIL: named-harness assertion guard stayed green' >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
cp "$tmp/SKILL.before" "$fixture/SKILL.md"
if cmp -s "$tmp/SKILL.before" "$fixture/SKILL.md"; then pass=$((pass + 1)); else echo 'FAIL: fixture restore drifted' >&2; fail=$((fail + 1)); fi
if contract_ok "$fixture"; then pass=$((pass + 1)); else echo 'FAIL: restored mailbox contract' >&2; fail=$((fail + 1)); fi

echo "contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
