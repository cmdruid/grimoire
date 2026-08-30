#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";SETUP="$SKILL/scripts/backlog-setup.sh"
TEMPLATE="$SKILL/templates/debrief-anchor.md";STATUS="$SKILL/scripts/route-status.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-deploy-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
newroot(){ mkdir -p "$1";git -C "$1" init -q;}
extract_route(){ local facts begin end;facts="$("$STATUS" "$TEMPLATE" "$1")";begin="$(printf '%s\n' "$facts"|sed -n 's/^route_begin_line=//p')";end="$(printf '%s\n' "$facts"|sed -n 's/^route_end_line=//p')";sed -n "${begin},${end}p" "$1";}
BASE=(--workspace .spaces --records-root .records)

R="$T/default";newroot "$R";out="$("$SETUP" "$R" "${BASE[@]}" --apply)"
has <(printf '%s\n' "$out") 'wrote=.trackers/trackers.sh'
for f in README.md trackers.sh receipts.tsv tasks.tsv issues.tsv feedback.tsv routines.tsv;do
  [ -f "$R/.trackers/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing $f" >&2;fail=$((fail+1));}
done
[ -x "$R/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for s in tasks issues feedback routines;do has "$R/.spaces/backlog/hooks/debrief.md" "## $s";done
extract_route "$R/AGENTS.md">"$T/route";cmp "$TEMPLATE" "$T/route" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))

# Initialized setup preserves data and an intentionally removed default queue.
"$R/.trackers/trackers.sh" create --tracker tasks --text 'keep me' >/dev/null
"$SETUP" "$R" "${BASE[@]}" tracker-remove issues >/dev/null
cp "$R/.trackers/tasks.tsv" "$T/tasks.before";cp "$R/.trackers/receipts.tsv" "$T/receipts.before"
printf 'legacy residue\n'>"$R/.trackers/tracker-api.sh";printf '\nproject prompt tail\n'>>"$R/.spaces/backlog/hooks/debrief.md"
"$SETUP" "$R" "${BASE[@]}" --apply >/dev/null
cmp "$T/tasks.before" "$R/.trackers/tasks.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
cmp "$T/receipts.before" "$R/.trackers/receipts.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/issues.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))
has "$R/.trackers/tracker-api.sh" 'legacy residue';has "$R/.spaces/backlog/hooks/debrief.md" 'project prompt tail'

# First setup has no selection surface; administration owns later population changes.
S="$T/selection";newroot "$S";no "$SETUP" "$S" "${BASE[@]}" --apply tasks
[ ! -e "$S/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))
ok "$SETUP" "$S" "${BASE[@]}" --apply;ok "$SETUP" "$S" "${BASE[@]}" tracker-add decisions
has "$S/.spaces/backlog/hooks/debrief.md" '## decisions';ok "$SETUP" "$S" "${BASE[@]}" tracker-remove decisions
chmod -x "$S/.trackers/trackers.sh";if "$SETUP" "$S" "${BASE[@]}" tracker-add blocked >"$T/admin-recovery.out" 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
grep -qF 'reason=repair-required action=/backlog repair' "$T/admin-recovery.out"&&pass=$((pass+1))||fail=$((fail+1));chmod +x "$S/.trackers/trackers.sh"

# A custom first root declares before it writes the layer; later resolution honors it.
O="$T/override";newroot "$O";ok "$SETUP" "$O" "${BASE[@]}" --trackers-root project-trackers --apply
has "$O/AGENTS.md" 'agent-trackers: project-trackers';[ -x "$O/project-trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
ok "$SETUP" "$O" "${BASE[@]}" --apply;no "$SETUP" "$O" "${BASE[@]}" --trackers-root elsewhere --apply
U="$T/undeclared-custom";newroot "$U";mkdir -p "$U/project-trackers";printf 'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult\n'>"$U/project-trackers/receipts.tsv"
no "$SETUP" "$U" "${BASE[@]}" --trackers-root project-trackers --apply;[ ! -e "$U/AGENTS.md" ]&&pass=$((pass+1))||fail=$((fail+1))

# Unsafe and malformed destinations refuse before creating the tracker layer.
for bad in . ../escape /absolute custom/ custom//nested;do B="$T/bad-${bad//\//x}";newroot "$B";no "$SETUP" "$B" "${BASE[@]}" --trackers-root "$bad" --apply;done
M="$T/malformed";newroot "$M";printf '%s\n' '<!-- skill:backlog BEGIN broken -->'>"$M/AGENTS.md";no "$SETUP" "$M" "${BASE[@]}" --apply;[ ! -e "$M/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))

echo "deploy-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
