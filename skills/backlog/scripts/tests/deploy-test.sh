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
for f in .gitkeep tasks.tsv issues.tsv failures.tsv feedback.tsv routines.tsv;do [ -f "$R/.trackers/tables/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing tables/$f" >&2;fail=$((fail+1));};done
[ -x "$R/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for s in tasks issues failures feedback routines;do has "$R/.trackers/DEBRIEF.md" "## $s";done
[ ! -e "$R/.trackers/.setup-selection" ]&&pass=$((pass+1))||{ echo 'FAIL successful setup retained selection intent' >&2;fail=$((fail+1));}
if find "$R/.trackers" -maxdepth 1 -name '.setup-selection.tmp.*' -print -quit | grep -q .;then echo 'FAIL successful setup retained selection temporary' >&2;fail=$((fail+1));else pass=$((pass+1));fi
has "$R/.trackers/DEBRIEF.md" '## feedback'
has "$R/.trackers/DEBRIEF.md" 'remedy belongs in this repository'
has "$R/.trackers/DEBRIEF.md" "skill's home feedback channel"
catalog="$T/catalog";"$SETUP" "$R" --list >"$catalog"
eq_catalog=$'stem=tasks\ttitle=Tasks\tuse-when="Accepted concrete project outcomes."\nstem=issues\ttitle=Issues\tuse-when="Established project problems, risks, and limitations."\nstem=failures\ttitle=Failures\tuse-when="Unresolved test, build, and project-tool behavior."\nstem=feedback\ttitle=Project Feedback\tuse-when="Qualitative development experience whose remedy belongs in this project."\nstem=routines\ttitle=Routines\tuse-when="Repeatable responses to recognizable development triggers."'
[ "$(cat "$catalog")" = "$eq_catalog" ]&&pass=$((pass+1))||{ echo 'FAIL catalog/order mismatch' >&2;fail=$((fail+1));}
[ ! -e "$R/AGENTS.md" ]&&pass=$((pass+1))||{ echo 'FAIL setup created AGENTS.md' >&2;fail=$((fail+1));}

# Initialized setup preserves data and an intentionally removed default queue.
"$R/.trackers/trackers.sh" create --tracker tasks --text 'keep me' >/dev/null
feedback_out="$("$R/.trackers/trackers.sh" create --tracker feedback --text 'project-owned friction')"
feedback_id="$(printf '%s\n' "$feedback_out"|sed -n 's/^created=//p')"
"$SETUP" "$R" tracker-remove issues >/dev/null
"$SETUP" "$R" tracker-remove failures >/dev/null
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
[ ! -e "$R/.trackers/tables/failures.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL initialized setup silently added failures' >&2;fail=$((fail+1));}
[ -f "$R/.trackers/tables/.gitkeep" ]&&[ ! -s "$R/.trackers/tables/.gitkeep" ]&&pass=$((pass+1))||fail=$((fail+1))
has "$R/.trackers/tracker-api.sh" 'legacy residue';has "$R/.trackers/DEBRIEF.md" 'project prompt tail'

# First setup accepts one normalized packaged selection; administration owns later population changes.
S="$T/selection";newroot "$S";no "$SETUP" "$S" --apply tasks
[ ! -e "$S/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))
ok "$SETUP" "$S" --apply --trackers failures
[ "$(find "$S/.trackers/tables" -name '*.tsv' -exec basename {} .tsv \; | sort)" = failures ]&&pass=$((pass+1))||{ echo 'FAIL failures-only selection population' >&2;fail=$((fail+1));}
[ "$(sed -n 's/^## //p' "$S/.trackers/DEBRIEF.md")" = failures ]&&pass=$((pass+1))||{ echo 'FAIL failures-only prompt population' >&2;fail=$((fail+1));}
if "$SETUP" "$S" --apply --trackers tasks >"$T/initialized-selection.out" 2>&1;then echo 'FAIL initialized selection accepted' >&2;fail=$((fail+1));else pass=$((pass+1));fi
has "$T/initialized-selection.out" 'reason=trackers-only-during-initialization'
ok "$SETUP" "$S" tracker-add decisions
has "$S/.trackers/DEBRIEF.md" '## decisions';ok "$SETUP" "$S" tracker-remove decisions
chmod -x "$S/.trackers/trackers.sh";if "$SETUP" "$S" tracker-add blocked >"$T/admin-recovery.out" 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
grep -qF 'reason=repair-required action=/backlog repair' "$T/admin-recovery.out"&&pass=$((pass+1))||fail=$((fail+1));chmod +x "$S/.trackers/trackers.sh"

MSEL="$T/multi-selection";newroot "$MSEL";ok "$SETUP" "$MSEL" --apply --trackers routines,tasks,feedback
[ "$(sed -n 's/^## //p' "$MSEL/.trackers/DEBRIEF.md")" = $'tasks\nfeedback\nroutines' ]&&pass=$((pass+1))||{ echo 'FAIL selection was not normalized to package order' >&2;fail=$((fail+1));}
[ "$(find "$MSEL/.trackers/tables" -name '*.tsv' -exec basename {} .tsv \; | sort)" = $'feedback\nroutines\ntasks' ]&&pass=$((pass+1))||{ echo 'FAIL selected table set mismatch' >&2;fail=$((fail+1));}

# Invalid fresh selections refuse before creating the tracker layer.
for value in '' 'tasks,tasks' 'tasks,unknown' ',tasks' 'tasks,' 'tasks,,issues';do
  BAD="$T/bad-selection-${fail}-${pass}";newroot "$BAD";no "$SETUP" "$BAD" --apply --trackers "$value"
  [ ! -e "$BAD/.trackers" ]&&pass=$((pass+1))||{ echo "FAIL invalid selection wrote layer: [$value]" >&2;fail=$((fail+1));}
done

# Red-prove the exact-population assertion against an unselected packaged table.
exact_population(){ [ "$(find "$1/.trackers/tables" -name '*.tsv' -exec basename {} .tsv \; | sort)" = failures ];}
exact_population "$S"&&pass=$((pass+1))||fail=$((fail+1))
printf 'id\tcreated\ttext\tevidence\n'>"$S/.trackers/tables/tasks.tsv"
if exact_population "$S";then echo 'FAIL exact population guard missed unselected table' >&2;fail=$((fail+1));else pass=$((pass+1));fi
rm "$S/.trackers/tables/tasks.tsv";exact_population "$S"&&pass=$((pass+1))||fail=$((fail+1))

# Noncanonical canaries are ignored, and every retired selector refuses before writing.
O="$T/noncanonical";newroot "$O";mkdir -p "$O/project-trackers";printf 'CUSTOM_CANARY\n'>"$O/project-trackers/README.md"
ok "$SETUP" "$O" --apply;has "$O/project-trackers/README.md" 'CUSTOM_CANARY';[ -x "$O/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for selector in --trackers-root --records-root --workspace --workspace-root;do
  U="$T/reject-${selector#--}";newroot "$U";no "$SETUP" "$U" "$selector" custom --apply
  [ ! -e "$U/.trackers" ]&&[ ! -e "$U/.agents/skilldata" ]&&pass=$((pass+1))||fail=$((fail+1))
done

# A nested directory inside a Git checkout is not a second project root.
N="$T/nested-root";newroot "$N";mkdir -p "$N/child"
no "$SETUP" "$N/child" --apply
[ ! -e "$N/child/.trackers" ]&&[ ! -e "$N/child/AGENTS.md" ]&&pass=$((pass+1))||fail=$((fail+1))

# The explicit brownfield prompt move preserves project customizations; setup has no old-path probe.
U="$T/upgrade";newroot "$U";ok "$SETUP" "$U" --apply
printf '\nPROJECT_CUSTOMIZATION\n'>>"$U/.trackers/DEBRIEF.md";git -C "$U" add .;git -C "$U" -c user.name=test -c user.email=test@example.invalid commit -qm pre-cut
mkdir -p "$U/.agents/skilldata/backlog/hooks";git -C "$U" mv .trackers/DEBRIEF.md .agents/skilldata/backlog/hooks/debrief.md;git -C "$U" -c user.name=test -c user.email=test@example.invalid commit -qam pre-cut-location
git -C "$U" mv .agents/skilldata/backlog/hooks/debrief.md .trackers/DEBRIEF.md;cp "$U/.trackers/DEBRIEF.md" "$T/upgrade.before";ok "$SETUP" "$U" --apply
cmp "$T/upgrade.before" "$U/.trackers/DEBRIEF.md" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$U/.agents/skilldata/backlog/hooks/debrief.md" ]&&pass=$((pass+1))||fail=$((fail+1))

# Front-door state is outside Backlog ownership, including malformed old markers.
M="$T/malformed";newroot "$M";printf '%s\n' '<!-- skill:backlog BEGIN broken -->'>"$M/AGENTS.md";cp "$M/AGENTS.md" "$T/malformed-agents.before"
ok "$SETUP" "$M" --apply;ok "$SETUP" "$M" tracker-add decisions;ok "$SETUP" "$M" tracker-remove decisions
cmp "$T/malformed-agents.before" "$M/AGENTS.md" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL Backlog administration changed AGENTS.md' >&2;fail=$((fail+1));}

# The deterministic setup helper cannot orchestrate or infer front-door consent.
setup_front_door_neutral(){
  [ "$(grep -Ec 'trackers-anchor[.]sh|AGENTS[.]md|--debrief' "$1")" -eq 0 ]
}
if setup_front_door_neutral "$SETUP";then pass=$((pass+1));else echo 'FAIL setup helper owns front-door behavior' >&2;fail=$((fail+1));fi
cp "$SETUP" "$T/setup-helper"
printf '\n%s\n' '"$SKILL/scripts/trackers-anchor.sh" preview --root "$root"' >>"$T/setup-helper"
[ "$(grep -Ec 'trackers-anchor[.]sh|AGENTS[.]md|--debrief' "$T/setup-helper")" -eq 1 ]||{ echo 'FAIL automatic-anchor mutation target count' >&2;exit 1;}
if setup_front_door_neutral "$T/setup-helper";then echo 'FAIL injected automatic anchor call passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
cp "$SETUP" "$T/setup-helper"
cmp "$SETUP" "$T/setup-helper" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL setup helper fixture did not restore' >&2;fail=$((fail+1));}

echo "deploy-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
