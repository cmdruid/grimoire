#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";STATUS="$SKILL/scripts/tracker-readme-status.sh";TEMPLATE="$SKILL/templates/trackers-readme-block.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-readme-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
has_flat(){ tr '\n' ' ' <"$1" | tr -s '[:space:]' ' ' | grep -qF -- "$2" \
  && pass=$((pass+1)) || { echo "FAIL missing $2" >&2;fail=$((fail+1));};}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
state(){ "$STATUS" "$TEMPLATE" "$1"|sed -n 's/^readme_status=//p';}

M="$T/missing";eq absent absent "$(state "$M")"
printf 'project prose\n'>"$T/plain";eq absent absent "$(state "$T/plain")"
cp "$TEMPLATE" "$T/current";eq current current "$(state "$T/current")"
sed 's/sole writer/only writer/' "$TEMPLATE">"$T/drifted";eq drifted drifted "$(state "$T/drifted")"
for shape in duplicate nested reversed begin-only end-only;do
  case "$shape" in
    duplicate) { cat "$TEMPLATE";cat "$TEMPLATE";} >"$T/$shape";;
    nested) { head -n 1 "$TEMPLATE";cat "$TEMPLATE";tail -n +2 "$TEMPLATE";} >"$T/$shape";;
    reversed) { tail -n 1 "$TEMPLATE";head -n 1 "$TEMPLATE";} >"$T/$shape";;
    begin-only) head -n 1 "$TEMPLATE">"$T/$shape";;
    end-only) tail -n 1 "$TEMPLATE">"$T/$shape";;
  esac
  eq "$shape" malformed "$(state "$T/$shape")"
done
cp "$TEMPLATE" "$T/broken-template";sed '1s/BEGIN/BROKEN/' "$T/broken-template">"$T/broken-template.tmp";mv "$T/broken-template.tmp" "$T/broken-template"
if "$STATUS" "$T/broken-template" "$T/current" >/dev/null 2>&1;then echo 'FAIL accepted broken package template' >&2;fail=$((fail+1));else pass=$((pass+1));fi

R="$T/root";mkdir -p "$R/.trackers";git -C "$R" init -q;printf 'before canary\n'>"$R/.trackers/README.md"
"$SETUP" "$R" --apply >/dev/null
git -C "$R" add .;git -C "$R" -c user.name=test -c user.email=test@example.invalid commit -qm setup
printf '\nafter canary\n'>>"$R/.trackers/README.md";git -C "$R" add .trackers/README.md;git -C "$R" -c user.name=test -c user.email=test@example.invalid commit -qm prose
sed 's/## Use the tracker tool/## Drifted tracker tool/' "$R/.trackers/README.md">"$T/readme.drift";mv "$T/readme.drift" "$R/.trackers/README.md"
"$SETUP" "$R" --apply >/dev/null
eq managed current "$(state "$R/.trackers/README.md")";has "$R/.trackers/README.md" 'before canary';has "$R/.trackers/README.md" 'after canary'
eq marker-count 1 "$(grep -cFx '<!-- backlog:trackers-tool BEGIN -->' "$R/.trackers/README.md")"
for needle in 'complete ordinary-use interface' '`history.tsv`' 'Git owns file history' '`trackers.sh` is their sole writer' 'never hand-edit' 'State is derived' 'Consumption is terminal' 'Observation is consumer-scoped and idempotent' '--consumer KEY --unobserved' '`next=`' '`--after`' 'tracker-root-relative `wrote=` paths' '.trackers/DEBRIEF.md' '/backlog repair' "Backlog skill isn't available" "Don't improvise";do has_flat "$R/.trackers/README.md" "$needle";done
if grep -qF 'immutable source rows' "$R/.trackers/README.md";then
  echo 'FAIL tracker guide calls updateable rows immutable' >&2;fail=$((fail+1))
else pass=$((pass+1));fi
has_flat "$R/.trackers/README.md" 'source rows for one queue can change only through `create` and `update`'
for cmd in describe catalog history page create update observe consume;do has "$R/.trackers/README.md" ".trackers/trackers.sh $cmd";done

# Execute each representative command family against the installed adjacent provider.
P="$R/.trackers/trackers.sh";(cd "$R"&&.trackers/trackers.sh describe >/dev/null);"$P" catalog >/dev/null;"$P" history --limit 20 >/dev/null;"$P" page --tracker tasks --status open --limit 20 >/dev/null
"$P" create --tracker tasks --text 'README exercise' --evidence doc >/dev/null
"$P" create --tracker tasks --text 'README second item' --evidence doc >/dev/null
"$P" update --tracker tasks --id tasks-1 --text 'README exercise updated' --evidence doc >/dev/null
"$P" observe --consumer example/review --tracker tasks --ids tasks-1 >/dev/null
"$P" observe --consumer example/review --tracker tasks --ids tasks-1 >"$T/observe-again"
has "$T/observe-again" 'unchanged=tasks-1'
"$P" page --tracker tasks --status open --limit 20 --consumer example/review --unobserved >"$T/unobserved"
has "$T/unobserved" 'tasks-2';if grep -qF 'tasks-1' "$T/unobserved";then fail=$((fail+1));else pass=$((pass+1));fi
"$P" consume --consumer example/review --tracker tasks --ids tasks-1 --resolution Resolved --result doc >/dev/null
"$P" page --tracker tasks --status all --limit 20 --consumer example/other --unobserved >"$T/other-unobserved"
has "$T/other-unobserved" $'tasks-1\t';has "$T/other-unobserved" $'consumed'
"$P" history --limit 1 >"$T/history-page-1";has "$T/history-page-1" 'next=event-1'
"$P" history --limit 20 --after event-1 >"$T/history-page-2";has "$T/history-page-2" $'event-2\t'
grep -qF 'README exercise updated' "$R/.trackers/tables/tasks.tsv"&&pass=$((pass+1))||fail=$((fail+1))
[ "$(wc -l <"$R/.trackers/history.tsv"|tr -d ' ')" -eq 3 ]&&pass=$((pass+1))||fail=$((fail+1))

echo "readme-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
