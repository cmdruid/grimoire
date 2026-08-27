#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";B="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";D="$B/verbs/debrief.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-debrief-contract.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
for needle in 'since the previous' 'Pure Q&A' 'child/delegate' 'Zero sections or zero filed' \
  'trigger, repeated response/decision, cost/risk/confusion' 'labels inferred recurrence' \
  'do not create a durable cursor' 'API `create` or `update`';do has "$D" "$needle";done

# Red-proof the routine-criteria assertion: require one real replacement and a failed copied check.
cp "$D" "$T/debrief.md";before="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/debrief.md")";[ "$before" -eq 1 ]||{ echo 'FAIL mutation target count' >&2;exit 1;}
sed 's/trigger, repeated response\/decision, cost\/risk\/confusion/trigger and response/' "$T/debrief.md" > "$T/broken.md"
after="$(grep -cF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md"||true)";[ "$after" -eq 0 ]||{ echo 'FAIL mutation not applied' >&2;exit 1;}
if grep -qF 'trigger, repeated response/decision, cost/risk/confusion' "$T/broken.md";then echo 'FAIL broken contract passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
cmp "$D" "$T/debrief.md" >/dev/null||{ echo 'FAIL source changed' >&2;fail=$((fail+1));}
echo "debrief-contract-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
