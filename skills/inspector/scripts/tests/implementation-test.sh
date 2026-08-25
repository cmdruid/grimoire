#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
KIND="$SKILL/kinds/implementation.md"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }

for needle in 'named diff, range, worktree, or commit' 'behavior matches the governing design' \
  'passing test could still encode the wrong implementation' 'claimed deletions and absence assertions' \
  'call sites and configuration' 'compatibility substrate forbidden by the design' \
  'None. Implementation review never amends code'; do
  has "$KIND" "$needle" "implementation doctrine missing: $needle"
done
has "$REVIEW" 'Implementation target: inspect the full diff' "implementation review walk missing"

review_fixture() {
  local file="$1" findings=0
  for marker in DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT; do
    if grep -qF "$marker" "$file"; then echo must-fix; findings=$((findings + 1)); fi
  done
  [ "$findings" -gt 0 ] || { grep -qF RECOMMENDED "$file" && echo recommended || echo clean; }
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

echo "implementation-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
