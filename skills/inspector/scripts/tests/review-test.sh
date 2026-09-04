#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
ROUTER="$SKILL/SKILL.md"
SPEC="$SKILL/kinds/spec.md"
PLAN="$SKILL/kinds/plan.md"
pass=0 fail=0

has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
missing() { if grep -qF -- "$2" "$1"; then echo "FAIL $3" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }

has "$REVIEW" 'every required soundness axis and groundedness extra' "adequacy inventory missing"
missing "$REVIEW" 'no new supported must-fix finding' "adequacy mining loop still present"
has "$REVIEW" 'written step cannot succeed as specified' "must-fix definition missing"
has "$REVIEW" 'Two legal in-boundary remedies → ask' "two-remedies ask missing"
has "$REVIEW" 'not a second switch' "light/deep dial missing"
missing "$REVIEW" 'Depth dial' "second depth dial still present"
has "$REVIEW" 'Never an editing subagent' "deep subagent rule missing"
has "$REVIEW" 'no numeric finding cap.' "uncapped review missing"
missing "$PLAN" 'open decision branches do not belong here' "plan still blocks on open decisions"
for word in specific grounded consequential actionable non-duplicate; do
  if grep -qi "\*\*$word\*\*" "$REVIEW"; then
    pass=$((pass + 1))
  else
    echo "FAIL materiality criterion missing: $word" >&2; fail=$((fail + 1))
  fi
done
has "$REVIEW" 'any must-fix finding' "must-fix mapping missing"
has "$REVIEW" 'at least one recommended change' "recommended mapping missing"
has "$REVIEW" 'no material findings' "clean mapping missing"
has "$ROUTER" '## Scope firewall' "shared scope firewall missing"
has "$REVIEW" '## Review boundary' "review boundary procedure missing"
has "$REVIEW" 'requested outcome' "requested outcome is not review authority"
has "$REVIEW" 'explicit non-goals' "non-goals are not binding"
has "$REVIEW" 'direct causal evidence' "unnamed-subsystem circuit breaker missing"
has "$REVIEW" 'outside the verdict' "follow-ups can still affect the verdict"
has "$REVIEW" 'inherit the same boundary' "re-review can widen scope"
has "$REVIEW" 'acceptance-critical' "red-proof is not proportional"
has "$REVIEW" 'ask the substrate inverse only when' "spec greenfield inverse still bypasses the depth gate"
has "$REVIEW" 'non-blocking follow-ups' "follow-ups are not separated in the report"
has "$REVIEW" 'carry the original review boundary into' "offered revision loses scope custody"
has "$SPEC" 'stay off on a light review' "spec substrate skepticism remains default-on"
has "$SPEC" 'An explicit deep review' "spec deep-mode gate missing"
has "$PLAN" 'An atomic plan is valid' "bounded plans are still forced to slice"
has "$PLAN" 'Every slice must map' "plan slices do not inherit scope"
has "$PLAN" 'uncovered in-boundary requirement' "plan revision may add out-of-scope slices"

scope_disposition() {
  case "$1:$2" in
    required:*) echo must-fix ;;
    material:inside) echo recommended ;;
    independent:*) echo follow-up ;;
    speculative:*) echo omit ;;
  esac
}
eq "Docker startup defect blocks bounded outcome" must-fix "$(scope_disposition required inside)"
eq "browser storage is an independent follow-up" follow-up "$(scope_disposition independent outside)"
eq "unsupported bookkeeping idea is omitted" omit "$(scope_disposition speculative outside)"

# A deliberately tiny fixture oracle proves the coverage assertion can detect a
# reviewer that stops after its first true finding. It models only the two planted
# defects; the skill's judgment remains prose-driven.
review_fixture() {
  local file="$1" stop_after_first="${2:-false}" count=0
  grep -qF 'Requirement: mode is always on.' "$file" \
    && grep -qF 'Requirement: mode is always off.' "$file" \
    && { echo contradiction; count=$((count + 1)); }
  [ "$stop_after_first" = true ] && [ "$count" -gt 0 ] && return 0
  grep -qF 'Acceptance-critical guard: absence check without red-proof.' "$file" \
    && echo false-green
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/two-defects.md" <<'EOF'
Requirement: mode is always on.
Requirement: mode is always off.
Acceptance-critical guard: absence check without red-proof.
EOF
eq "complete fixture review" "2" "$(review_fixture "$TMP/two-defects.md" | wc -l | tr -d ' ')"
if [ "$(review_fixture "$TMP/two-defects.md" true | wc -l | tr -d ' ')" -eq 2 ]; then
  echo "FAIL stop-after-first mutation did not make the coverage fixture fail" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

verdict() {
  case "$1" in must-fix*) echo needs-rework ;; recommended*) echo approve-with-changes ;; *) echo approve ;; esac
}
eq "must-fix verdict" needs-rework "$(verdict must-fix)"
eq "recommended-only verdict" approve-with-changes "$(verdict recommended)"
eq "nit-only verdict" approve "$(verdict nit-only)"

if rg -n 'at most [0-9]+|maximum of [0-9]+|first [0-9]+ findings' "$REVIEW" >/dev/null; then
  echo "FAIL numeric finding cap present" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

echo "review-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
