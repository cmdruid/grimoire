#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";B="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";D="$B/verbs/debrief.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-debrief-contract.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
for needle in 'since the previous' 'Pure Q&A' 'child/delegate' 'Zero sections or zero filed' \
  'trigger, repeated response/decision, cost/risk/confusion' 'labels inferred recurrence' \
  'do not create a durable cursor' 'API `create` or `update`' \
  'Before consulting the editable project prompt' 'non-overridable remedy-owner cut' \
  'reusable installed skill' 'do not write it to `.trackers`' 'skill-tagged byproduct' \
  'remedy belongs in this repository';do has "$D" "$needle";done

subject_cut_ok(){
  local file="$1" cut prompt
  cut="$(grep -nF 'Before consulting the editable project prompt' "$file"|head -n1|cut -d: -f1)"
  prompt="$(grep -nF 'Use each configured `## <stem>` body' "$file"|head -n1|cut -d: -f1)"
  [ -n "$cut" ] && [ -n "$prompt" ] && [ "$cut" -lt "$prompt" ] &&
    grep -qF 'reusable installed skill' "$file" &&
    grep -qF 'skill-tagged byproduct' "$file" &&
    grep -qF 'remedy belongs in this repository' "$file"
}
if subject_cut_ok "$D";then pass=$((pass+1));else echo 'FAIL remedy-owner cut is not before editable routing' >&2;fail=$((fail+1));fi

printf '%s\n' \
  $'case\towner\texpected' \
  $'project-workflow-friction\tproject\tfeedback' \
  $'installed-skill-friction\tskill\tbyproduct' \
  $'project-defect\tproject\tissue' \
  $'project-work\tproject\ttask' \
  $'repeated-project-response\tproject\troutine' >"$T/debrief-cases.tsv"
[ "$(awk -F '\t' 'NR > 1 && $2 == "project" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 4 ]&&pass=$((pass+1))||fail=$((fail+1))
[ "$(awk -F '\t' 'NR > 1 && $2 == "skill" && $3 == "byproduct" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 1 ]&&pass=$((pass+1))||fail=$((fail+1))

# Red-proof the routine-criteria assertion: require one real replacement and a failed copied check.
cp "$D" "$T/debrief.md";before="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/debrief.md")";[ "$before" -eq 1 ]||{ echo 'FAIL mutation target count' >&2;exit 1;}
sed 's/trigger, repeated response\/decision, cost\/risk\/confusion/trigger and response/' "$T/debrief.md" > "$T/broken.md"
after="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md"||true)";[ "$after" -eq 0 ]||{ echo 'FAIL mutation not applied' >&2;exit 1;}
if grep -qF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md";then echo 'FAIL broken contract passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
cmp "$D" "$T/debrief.md" >/dev/null||{ echo 'FAIL source changed' >&2;fail=$((fail+1));}

# Red-proof the hard subject cut independently of the routine criteria.
sed '/Before consulting the editable project prompt/,/remedy belongs in this repository/d' "$D" >"$T/no-subject-cut.md"
if subject_cut_ok "$T/no-subject-cut.md";then echo 'FAIL missing remedy-owner cut passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
echo "debrief-contract-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
