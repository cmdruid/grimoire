#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";SETUP="$SKILL/scripts/backlog-setup.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-deploy-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
newroot(){ mkdir -p "$1";git -C "$1" init -q;}

R="$T/default";newroot "$R";out="$("$SETUP" "$R" --apply)"
has <(printf '%s\n' "$out") 'wrote=.trackers/trackers.sh'
for f in README.md trackers.sh history.tsv;do [ -f "$R/.trackers/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing $f" >&2;fail=$((fail+1));};done
for f in .gitkeep tasks.tsv issues.tsv feedback.tsv routines.tsv;do [ -f "$R/.trackers/tables/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing tables/$f" >&2;fail=$((fail+1));};done
[ -x "$R/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for s in tasks issues feedback routines;do has "$R/.trackers/DEBRIEF.md" "## $s";done
has "$R/.trackers/DEBRIEF.md" '## feedback'
has "$R/.trackers/DEBRIEF.md" 'remedy belongs in this repository'
has "$R/.trackers/DEBRIEF.md" "skill's home feedback channel"
catalog="$T/catalog";"$SETUP" "$R" --list >"$catalog"
has "$catalog" $'stem=feedback\ttitle=Project Feedback\tuse-when="Development-experience observations whose remedy belongs in this project."'
[ ! -e "$R/AGENTS.md" ]&&pass=$((pass+1))||{ echo 'FAIL setup created AGENTS.md' >&2;fail=$((fail+1));}

# Initialized setup preserves data and an intentionally removed default queue.
"$R/.trackers/trackers.sh" create --tracker tasks --text 'keep me' >/dev/null
feedback_out="$("$R/.trackers/trackers.sh" create --tracker feedback --text 'project-owned friction')"
feedback_id="$(printf '%s\n' "$feedback_out"|sed -n 's/^created=//p')"
"$SETUP" "$R" tracker-remove issues >/dev/null
cp "$R/.trackers/tables/tasks.tsv" "$T/tasks.before";cp "$R/.trackers/tables/feedback.tsv" "$T/feedback.before";cp "$R/.trackers/history.tsv" "$T/history.before"
printf 'legacy residue\n'>"$R/.trackers/tracker-api.sh";printf '\nproject prompt tail\n'>>"$R/.trackers/DEBRIEF.md"
cp "$R/.trackers/DEBRIEF.md" "$T/prompt.before"
rm "$R/.trackers/tables/.gitkeep"
"$SETUP" "$R" --apply >/dev/null
cmp "$T/tasks.before" "$R/.trackers/tables/tasks.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
cmp "$T/feedback.before" "$R/.trackers/tables/feedback.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
cmp "$T/history.before" "$R/.trackers/history.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
cmp "$T/prompt.before" "$R/.trackers/DEBRIEF.md" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL initialized prompt wording was migrated' >&2;fail=$((fail+1));}
grep -qF "$feedback_id" "$R/.trackers/tables/feedback.tsv"&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tables/issues.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))
[ -f "$R/.trackers/tables/.gitkeep" ]&&[ ! -s "$R/.trackers/tables/.gitkeep" ]&&pass=$((pass+1))||fail=$((fail+1))
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

# Front-door state is outside Backlog ownership, including malformed old markers.
M="$T/malformed";newroot "$M";printf '%s\n' '<!-- skill:backlog BEGIN broken -->'>"$M/AGENTS.md";cp "$M/AGENTS.md" "$T/malformed-agents.before"
ok "$SETUP" "$M" --apply;ok "$SETUP" "$M" tracker-add decisions;ok "$SETUP" "$M" tracker-remove decisions
cmp "$T/malformed-agents.before" "$M/AGENTS.md" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL Backlog administration changed AGENTS.md' >&2;fail=$((fail+1));}

echo "deploy-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
