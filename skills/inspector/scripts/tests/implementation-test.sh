#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
KIND="$SKILL/kinds/implementation.md"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

for needle in 'named diff, range, worktree, or commit' 'behavior matches the governing design' \
  'passing test could still encode the wrong implementation' 'claimed deletions and absence assertions' \
  'call sites and configuration' 'compatibility substrate forbidden by the design' \
  'None. Implementation review never amends code'; do
  has "$KIND" "$needle" "implementation doctrine missing: $needle"
done
has "$REVIEW" 'Implementation target: inspect the full diff' "implementation review walk missing"
for needle in 'control-flow complexity' 'changed authored functions' \
  'same analyzer identity and version' \
  'report the analyzer identity, version, configuration, population, and exclusions' \
  'function or method identity, repo-relative source location, and value at each endpoint' \
  'endpoint-unavailable' 'never apply the diff' 'raw value or threshold crossing'; do
  has "$KIND" "$needle" "implementation complexity doctrine missing: $needle"
done

review_fixture() {
  local file="$1" findings=0
  for marker in DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT \
    AVOIDABLE_BRANCHING_MISSING_PATHS; do
    if grep -qF "$marker" "$file"; then echo must-fix; findings=$((findings + 1)); fi
  done
  [ "$findings" -gt 0 ] || { grep -qF COMPLEXITY_RECOMMENDED "$file" && echo recommended \
    || grep -qF RECOMMENDED "$file" && echo recommended || echo clean; }
}
verdict() { case "$1" in *must-fix*) echo needs-rework ;; *recommended*) echo approve-with-changes ;; *) echo approve ;; esac; }

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
printf '%s\n' DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT > "$ROOT/bad.diff"
before="$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
result="$(review_fixture "$ROOT/bad.diff")"
eq "four implementation findings" 4 "$(printf '%s\n' "$result" | wc -l | tr -d ' ')"
eq "must-fix implementation verdict" needs-rework "$(verdict "$result")"
eq "implementation fixture unmodified" "$before" "$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
printf '%s\n' RECOMMENDED > "$ROOT/recommended.diff"
eq "recommended implementation verdict" approve-with-changes "$(verdict "$(review_fixture "$ROOT/recommended.diff")")"
: > "$ROOT/clean.diff"
eq "clean implementation verdict" approve "$(verdict "$(review_fixture "$ROOT/clean.diff")")"

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
    && ! grep -qF 'Implementation review may remediate complex code.' "$1" \
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
red_proof 'Implementation review may remediate complex code.'
red_proof 'A numeric delta may omit analyzer identity and population.'
red_proof 'A numeric complexity row may omit function identity and source location.'
cmp -s "$KIND" "$ROOT/implementation.original" && pass=$((pass + 1)) || fail=$((fail + 1))

echo "implementation-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
