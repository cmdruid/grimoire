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
  'remedy belongs in this repository' 'Route by the state of the knowledge' \
  'unresolved operational sighting' 'established negative condition' 'chosen project outcome' \
  'subjective slowness' 'timeout, hang, or unexplained benchmark' 'confirmed regression' \
  'accepted optimization' 'Expected red-green failures' 'resolved during the current objective' \
  'configured layer has no `failures` queue' 'page the bounded open `failures` population' \
  'component or command, stable signature, and observed behavior' 'strongest current evidence';do has "$D" "$needle";done

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
  $'subjective-slowness\tproject\tfeedback' \
  $'unexplained-timeout\tproject\tfailures' \
  $'confirmed-regression\tproject\tissues' \
  $'accepted-optimization\tproject\ttasks' \
  $'unresolved-flake\tproject\tfailures' \
  $'expected-red-green\tproject\tnone' \
  $'same-session-resolved\tproject\tnone' \
  $'qualitative-nitpick\tproject\tfeedback' \
  $'vague-preference\tproject\tnone' \
  $'installed-skill-friction\tskill\tbyproduct' \
  $'project-defect\tproject\tissue' \
  $'project-work\tproject\ttask' \
  $'repeated-project-response\tproject\troutine' >"$T/debrief-cases.tsv"
[ "$(awk -F '\t' 'NR > 1 && $2 == "project" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 13 ]&&pass=$((pass+1))||fail=$((fail+1))
[ "$(awk -F '\t' 'NR > 1 && $2 == "skill" && $3 == "byproduct" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 1 ]&&pass=$((pass+1))||fail=$((fail+1))
[ "$(awk -F '\t' 'NR > 1 && $3 == "failures" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 2 ]&&pass=$((pass+1))||fail=$((fail+1))
[ "$(awk -F '\t' 'NR > 1 && $3 == "none" { n++ } END { print n+0 }' "$T/debrief-cases.tsv")" -eq 3 ]&&pass=$((pass+1))||fail=$((fail+1))

# Red-proof the routine-criteria assertion: require one real replacement and a failed copied check.
cp "$D" "$T/debrief.md";before="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/debrief.md")";[ "$before" -eq 1 ]||{ echo 'FAIL mutation target count' >&2;exit 1;}
sed 's/trigger, repeated response\/decision, cost\/risk\/confusion/trigger and response/' "$T/debrief.md" > "$T/broken.md"
after="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md"||true)";[ "$after" -eq 0 ]||{ echo 'FAIL mutation not applied' >&2;exit 1;}
if grep -qF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md";then echo 'FAIL broken contract passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
cmp "$D" "$T/debrief.md" >/dev/null||{ echo 'FAIL source changed' >&2;fail=$((fail+1));}

# Red-proof the hard subject cut independently of the routine criteria.
sed '/Before consulting the editable project prompt/,/remedy belongs in this repository/d' "$D" >"$T/no-subject-cut.md"
if subject_cut_ok "$T/no-subject-cut.md";then echo 'FAIL missing remedy-owner cut passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi

failure_intake_ok(){
  grep -qF 'page the bounded open `failures` population' "$1"&&
    grep -qF 'component or command, stable signature, and observed behavior' "$1"&&
    grep -qF 'Use `update` for one matching family' "$1"&&
    grep -qF 'otherwise use `create`' "$1"
}
if failure_intake_ok "$D";then pass=$((pass+1));else echo 'FAIL failure-family intake contract' >&2;fail=$((fail+1));fi
before="$(grep -cF 'component or command, stable signature, and observed behavior' "$D")";[ "$before" -eq 1 ]||{ echo 'FAIL failure mutation target count' >&2;exit 1;}
sed 's/component or command, stable signature, and observed behavior/component alone/' "$D">"$T/broken-failure.md"
if failure_intake_ok "$T/broken-failure.md";then echo 'FAIL broken failure-family contract passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
echo "debrief-contract-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
