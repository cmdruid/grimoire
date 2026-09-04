#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown code spans are literal throughout this fixture.
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
KIND="$SKILL/kinds/implementation.md"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
missing() { if grep -qF -- "$2" "$1"; then echo "FAIL $3" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

for needle in 'named diff, range, worktree, or commit' 'behavior matches the governing design' \
  'passing test could still encode the wrong implementation' 'claimed deletions and absence assertions' \
  'call sites and configuration' 'compatibility substrate forbidden by the design' \
  'None. Implementation never enters document `revise` or `refine`' \
  'The review phase never amends code'; do
  has "$KIND" "$needle" "implementation doctrine missing: $needle"
done
has "$REVIEW" 'Implementation target: inspect the full diff' "implementation review walk missing"
has "$REVIEW" '## Implementation close' "implementation close heading missing"
has "$REVIEW" 'The verdict itself is never confirmation' "implementation confirmation guard missing"
has "$REVIEW" 'not this tree, refuse to apply' "foreign-tree refuse missing"
has "$REVIEW" 'fix must-fix findings in this tree' "needs-rework English close missing"
has "$REVIEW" 'stand as-is, or apply the recommended changes here' "recommended English close missing"
has "$REVIEW" '`yes` / `fix them` / `stop`' "English reply tokens missing"
has "$KIND" 'English close, inline, in this checkout' "implementation kind English close missing"
missing "$REVIEW" '1-A-R' "1-A-R still in review close"
missing "$REVIEW" 'isolated implementation agent' "isolated-fixer preflight still present"
missing "$REVIEW" 'one unambiguous writable destination' "destination-identity protocol still present"
missing "$KIND" '1-A-R' "1-A-R still in implementation kind"
missing "$KIND" 'numbered scope' "numbered close still in implementation kind"
for needle in 'control-flow complexity' 'changed authored functions' \
  'same analyzer identity and version' \
  'report the analyzer identity, version, configuration, population, and exclusions' \
  'function or method identity, repo-relative source location, and value at each endpoint' \
  'endpoint-unavailable' 'never apply the diff' 'raw value or threshold crossing'; do
  has "$KIND" "$needle" "implementation complexity doctrine missing: $needle"
done
has "$REVIEW" 'full accumulated change' "look-again is not a complete review"

review_fixture() {
  local file="$1" findings=0
  for marker in DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT \
    AVOIDABLE_BRANCHING_MISSING_PATHS; do
    if grep -qF "$marker" "$file"; then echo must-fix; findings=$((findings + 1)); fi
  done
  if grep -qF COMPLEXITY_RECOMMENDED "$file" || grep -qF RECOMMENDED "$file"; then
    echo recommended
    findings=$((findings + 1))
  fi
  [ "$findings" -gt 0 ] || echo clean
}
verdict() { case "$1" in *must-fix*) echo needs-rework ;; *recommended*) echo approve-with-changes ;; *) echo approve ;; esac; }

english_close() {
  local verdict="$1" answer="$2" tree="${3:-this}"
  [ "$tree" = this ] || { echo refuse-apply; return; }
  case "$verdict" in
    approve) echo ready; return ;;
  esac
  case "$verdict:$answer" in
    needs-rework:yes|needs-rework:'fix them') echo fix-here-then-look-again ;;
    approve-with-changes:yes|approve-with-changes:'stand as-is') echo stand-as-is ;;
    approve-with-changes:'fix them') echo apply-recommended-here ;;
    *:stop) echo stop ;;
    *) echo ask ;;
  esac
}

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
printf '%s\n' DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT RECOMMENDED > "$ROOT/bad.diff"
before="$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
result="$(review_fixture "$ROOT/bad.diff")"
eq "five implementation findings" 5 "$(printf '%s\n' "$result" | wc -l | tr -d ' ')"
eq "four must-fix findings" 4 "$(printf '%s\n' "$result" | grep -c '^must-fix$')"
eq "one recommended finding" 1 "$(printf '%s\n' "$result" | grep -c '^recommended$')"
eq "must-fix implementation verdict" needs-rework "$(verdict "$result")"
eq "implementation fixture unmodified" "$before" "$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
printf '%s\n' RECOMMENDED > "$ROOT/recommended.diff"
eq "recommended implementation verdict" approve-with-changes "$(verdict "$(review_fixture "$ROOT/recommended.diff")")"
: > "$ROOT/clean.diff"
eq "clean implementation verdict" approve "$(verdict "$(review_fixture "$ROOT/clean.diff")")"

eq "approve has no menu" ready "$(english_close approve yes)"
eq "verdict is never confirmation on another tree" refuse-apply \
  "$(english_close needs-rework yes other)"
eq "needs-rework asks to fix here" fix-here-then-look-again "$(english_close needs-rework 'fix them')"
eq "recommended may stand as-is" stand-as-is "$(english_close approve-with-changes yes)"
eq "implementation never enters document revise" unavailable \
  "$(sed -n 's/^revision-after-review:[[:space:]]*//p' "$KIND")"

printf '%s\n' AVOIDABLE_BRANCHING_MISSING_PATHS > "$ROOT/complex.diff"
eq "avoidable branching is material" needs-rework "$(verdict "$(review_fixture "$ROOT/complex.diff")")"
printf '%s\n' RAW_SCORE_ONLY > "$ROOT/raw-score.diff"
eq "raw score is not a finding" approve "$(verdict "$(review_fixture "$ROOT/raw-score.diff")")"
printf '%s\n' JUSTIFIED_EXHAUSTIVE_DISPATCH > "$ROOT/exhaustive.diff"
eq "justified exhaustive dispatch is not a finding" approve "$(verdict "$(review_fixture "$ROOT/exhaustive.diff")")"
printf '%s\n' ANALYZER_UNAVAILABLE > "$ROOT/unavailable.diff"
eq "unavailable analyzer is not a finding" approve "$(verdict "$(review_fixture "$ROOT/unavailable.diff")")"

delta_route() {
  case "$1:$2" in
    materialized:materialized|absent:materialized|materialized:absent) echo compare-read-only ;;
    *) echo qualitative:endpoint-unavailable ;;
  esac
}
eq "materialized endpoints compare" compare-read-only "$(delta_route materialized materialized)"
eq "added function uses absent before" compare-read-only "$(delta_route absent materialized)"
eq "deleted function uses absent after" compare-read-only "$(delta_route materialized absent)"
eq "missing endpoint falls back" qualitative:endpoint-unavailable "$(delta_route unavailable materialized)"

analyzer_delta_valid() {
  [ "$1" = "$6" ] && [ "$2" = "$7" ] && [ "$3" = "$8" ] \
    && [ "$4" = "$9" ] && [ "$5" = "${10}" ]
}
analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a src generated \
  && pass=$((pass + 1)) || fail=$((fail + 1))
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-b v2 cfg-a src generated
rejects analyzer_delta_valid tool-a v1 cfg-a src generated tool-a v2 cfg-a src generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-b src generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a lib generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a src vendor

contract_clean() {
  ! grep -qF 'A raw complexity score is automatically a finding.' "$1" \
    && ! grep -qF 'Apply the diff to construct an analyzer endpoint.' "$1" \
    && ! grep -qF 'Implementation review may remediate code before confirmation.' "$1" \
    && ! grep -qF 'A numeric delta may omit analyzer identity and population.' "$1" \
    && ! grep -qF 'A numeric complexity row may omit function identity and source location.' "$1"
}
cp "$KIND" "$ROOT/implementation.original"
red_proof() {
  local sentence="$1"
  cp "$ROOT/implementation.original" "$ROOT/implementation.broken"
  printf '%s\n' "$sentence" >> "$ROOT/implementation.broken"
  eq "complexity red-proof plants one defect" 1 \
    "$(grep -cF "$sentence" "$ROOT/implementation.broken")"
  rejects contract_clean "$ROOT/implementation.broken"
}
red_proof 'A raw complexity score is automatically a finding.'
red_proof 'Apply the diff to construct an analyzer endpoint.'
red_proof 'Implementation review may remediate code before confirmation.'
red_proof 'A numeric delta may omit analyzer identity and population.'
red_proof 'A numeric complexity row may omit function identity and source location.'
cmp -s "$KIND" "$ROOT/implementation.original" && pass=$((pass + 1)) || fail=$((fail + 1))

echo "implementation-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
