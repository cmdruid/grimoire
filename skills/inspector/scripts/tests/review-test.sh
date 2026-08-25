#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0

has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }

has "$REVIEW" 'every required soundness axis and groundedness extra' "adequacy inventory missing"
has "$REVIEW" 'no new supported must-fix finding' "adequacy stop missing"
has "$REVIEW" 'no numeric finding cap.' "uncapped review missing"
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

# A deliberately tiny fixture oracle proves the coverage assertion can detect a
# reviewer that stops after its first true finding. It models only the two planted
# defects; the skill's judgment remains prose-driven.
review_fixture() {
  local file="$1" stop_after_first="${2:-false}" count=0
  grep -qF 'Requirement: mode is always on.' "$file" \
    && grep -qF 'Requirement: mode is always off.' "$file" \
    && { echo contradiction; count=$((count + 1)); }
  [ "$stop_after_first" = true ] && [ "$count" -gt 0 ] && return 0
  grep -qF 'Guard: absence check without red-proof.' "$file" \
    && echo false-green
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/two-defects.md" <<'EOF'
Requirement: mode is always on.
Requirement: mode is always off.
Guard: absence check without red-proof.
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
