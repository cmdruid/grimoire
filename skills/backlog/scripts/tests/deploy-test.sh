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

R="$T/default";newroot "$R";out="$("$SETUP" "$R" --apply)"
has <(printf '%s\n' "$out") 'wrote=.trackers/trackers.sh'
for f in README.md trackers.sh receipts.tsv tasks.tsv issues.tsv feedback.tsv routines.tsv;do
  [ -f "$R/.trackers/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing $f" >&2;fail=$((fail+1));}
done
[ -x "$R/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for s in tasks issues feedback routines;do has "$R/.trackers/DEBRIEF.md" "## $s";done
extract_route "$R/AGENTS.md">"$T/route";cmp "$TEMPLATE" "$T/route" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))

# Initialized setup preserves data and an intentionally removed default queue.
"$R/.trackers/trackers.sh" create --tracker tasks --text 'keep me' >/dev/null
"$SETUP" "$R" tracker-remove issues >/dev/null
cp "$R/.trackers/tasks.tsv" "$T/tasks.before";cp "$R/.trackers/receipts.tsv" "$T/receipts.before"
printf 'legacy residue\n'>"$R/.trackers/tracker-api.sh";printf '\nproject prompt tail\n'>>"$R/.trackers/DEBRIEF.md"
"$SETUP" "$R" --apply >/dev/null
cmp "$T/tasks.before" "$R/.trackers/tasks.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
cmp "$T/receipts.before" "$R/.trackers/receipts.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/issues.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))
has "$R/.trackers/tracker-api.sh" 'legacy residue';has "$R/.trackers/DEBRIEF.md" 'project prompt tail'

# First setup has no selection surface; administration owns later population changes.
S="$T/selection";newroot "$S";no "$SETUP" "$S" --apply tasks
[ ! -e "$S/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))
ok "$SETUP" "$S" --apply;ok "$SETUP" "$S" tracker-add decisions
has "$S/.trackers/DEBRIEF.md" '## decisions';ok "$SETUP" "$S" tracker-remove decisions
chmod -x "$S/.trackers/trackers.sh";if "$SETUP" "$S" tracker-add blocked >"$T/admin-recovery.out" 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
grep -qF 'reason=repair-required action=/backlog repair' "$T/admin-recovery.out"&&pass=$((pass+1))||fail=$((fail+1));chmod +x "$S/.trackers/trackers.sh"

# Noncanonical canaries are ignored, and every retired selector refuses before writing.
O="$T/noncanonical";newroot "$O";mkdir -p "$O/project-trackers";printf 'CUSTOM_CANARY\n'>"$O/project-trackers/README.md"
ok "$SETUP" "$O" --apply;has "$O/project-trackers/README.md" 'CUSTOM_CANARY';[ -x "$O/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for selector in --trackers-root --records-root --workspace --workspace-root;do
  U="$T/reject-${selector#--}";newroot "$U";no "$SETUP" "$U" "$selector" custom --apply
  [ ! -e "$U/.trackers" ]&&[ ! -e "$U/.spaces" ]&&pass=$((pass+1))||fail=$((fail+1))
done

# A nested directory inside a Git checkout is not a second project root.
N="$T/nested-root";newroot "$N";mkdir -p "$N/child"
no "$SETUP" "$N/child" --apply
[ ! -e "$N/child/.trackers" ]&&[ ! -e "$N/child/AGENTS.md" ]&&pass=$((pass+1))||fail=$((fail+1))

# The explicit brownfield prompt move preserves project customizations; setup has no old-path probe.
U="$T/upgrade";newroot "$U";ok "$SETUP" "$U" --apply
printf '\nPROJECT_CUSTOMIZATION\n'>>"$U/.trackers/DEBRIEF.md";git -C "$U" add .;git -C "$U" -c user.name=test -c user.email=test@example.invalid commit -qm pre-cut
mkdir -p "$U/.spaces/backlog/hooks";git -C "$U" mv .trackers/DEBRIEF.md .spaces/backlog/hooks/debrief.md;git -C "$U" -c user.name=test -c user.email=test@example.invalid commit -qam pre-cut-location
git -C "$U" mv .spaces/backlog/hooks/debrief.md .trackers/DEBRIEF.md;cp "$U/.trackers/DEBRIEF.md" "$T/upgrade.before";ok "$SETUP" "$U" --apply
cmp "$T/upgrade.before" "$U/.trackers/DEBRIEF.md" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$U/.spaces/backlog/hooks/debrief.md" ]&&pass=$((pass+1))||fail=$((fail+1))

# Malformed route ownership still refuses before creating the tracker layer.
M="$T/malformed";newroot "$M";printf '%s\n' '<!-- skill:backlog BEGIN broken -->'>"$M/AGENTS.md";no "$SETUP" "$M" --apply;[ ! -e "$M/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))

echo "deploy-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
