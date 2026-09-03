#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";SOURCE="$SKILL/scripts/trackers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-setup-resume.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >"$T/out" 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
newroot(){ mkdir -p "$1";git -C "$1" init -q;}
complete(){ "$SETUP" "$1" --apply;}
initialized(){ local count="${2:-5}";[ -x "$1/.trackers/trackers.sh" ]&&[ -f "$1/.trackers/history.tsv" ]&&[ -f "$1/.trackers/tables/.gitkeep" ]&&[ "$(find "$1/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')" -eq "$count" ]&&[ ! -e "$1/.trackers/.setup-selection" ];}
HEADER=$'id\tcreated\ttext\tevidence'

# Every provider/queue/prompt-prefix relationship produced by setup is resumable.
# Per queue: 0=absent, 1=header only, 2=header plus its exact prompt section.
for provider in 0 1;do for code in $(seq 0 80);do
  R="$T/prefix-$provider-$code";newroot "$R";mkdir -p "$R/.trackers/tables";touch "$R/.trackers/tables/.gitkeep"
  if [ "$provider" -eq 1 ];then cp "$SOURCE" "$R/.trackers/trackers.sh";chmod +x "$R/.trackers/trackers.sh";fi
  n="$code";prompt=false
  for stem in tasks issues feedback routines;do
    state=$((n%3));n=$((n/3))
    if [ "$state" -gt 0 ];then printf '%s\n' "$HEADER">"$R/.trackers/tables/$stem.tsv";fi
    [ "$state" -eq 2 ]&&prompt=true
  done
  if [ "$prompt" = true ];then
    mkdir -p "$R/.trackers"
    printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.'>"$R/.trackers/DEBRIEF.md"
    n="$code";for stem in tasks issues feedback routines;do
      state=$((n%3));n=$((n/3))
      if [ "$state" -eq 2 ];then printf '\n'>>"$R/.trackers/DEBRIEF.md";awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$SKILL/suggestions/$stem.md">>"$R/.trackers/DEBRIEF.md";fi
    done
  fi
  ok complete "$R";initialized "$R" 4&&pass=$((pass+1))||{ echo "FAIL prefix $provider/$code did not converge" >&2;fail=$((fail+1));}
done
done

CANON="$T/canonical-prompt";printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.'>"$CANON"
for stem in tasks issues feedback routines;do printf '\n'>>"$CANON";awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$SKILL/suggestions/$stem.md">>"$CANON";done
cmp "$CANON" "$T/prefix-0-18/.trackers/DEBRIEF.md" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL relationship prefix did not normalize canonically' >&2;fail=$((fail+1));}

# Failure after each setup-owned durable mutation leaves a state that the next run converges.
HOOK="$T/stop-at.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -ne "$STOP_AT" ] || exit 86'>"$HOOK";chmod +x "$HOOK"

# A retry also recognizes prompt bytes inserted while reconciling a non-leading section subset.
REL="$T/relationship-interrupt";newroot "$REL";mkdir -p "$REL/.trackers/tables";touch "$REL/.trackers/tables/.gitkeep";printf '%s\n' "$HEADER">"$REL/.trackers/tables/feedback.tsv"
printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' ''>"$REL/.trackers/DEBRIEF.md";awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$SKILL/suggestions/feedback.md">>"$REL/.trackers/DEBRIEF.md"
if STOP_AT=3 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$REL" >/dev/null 2>&1;then echo 'FAIL relationship interruption missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
ok complete "$REL"
for stop in $(seq 1 17);do
  R="$T/interrupted-$stop";newroot "$R"
  if STOP_AT="$stop" BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$R" >"$T/interrupted.out" 2>&1;then echo "FAIL injection $stop missed" >&2;fail=$((fail+1));else pass=$((pass+1));fi
  ok complete "$R";initialized "$R"&&pass=$((pass+1))||fail=$((fail+1))
done

# Empty-directory interruption is restartable and asks for no reconstructed selection.
STOP_DIR="$T/stop-after-dir.sh";printf '%s\n' '#!/bin/sh' 'exit 86'>"$STOP_DIR";chmod +x "$STOP_DIR"
ED="$T/empty-dir";newroot "$ED";if BACKLOG_SETUP_TEST_AFTER_LAYER_CREATE="$STOP_DIR" complete "$ED" >/dev/null 2>&1;then echo 'FAIL layer-create interruption missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ -d "$ED/.trackers" ]&&[ -z "$(find "$ED/.trackers" -mindepth 1 -print -quit)" ]&&pass=$((pass+1))||{ echo 'FAIL empty-dir interruption wrote an artifact' >&2;fail=$((fail+1));}
ok "$SETUP" "$ED" --apply --trackers failures;initialized "$ED" 1&&pass=$((pass+1))||fail=$((fail+1))

# A selected setup resumes only its recorded normalized set and rejects a conflict.
for stop in $(seq 1 11);do
  R="$T/selected-interrupted-$stop";newroot "$R"
  if STOP_AT="$stop" BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" "$SETUP" "$R" --apply --trackers feedback,tasks >"$T/selected.out" 2>&1;then echo "FAIL selected injection $stop missed" >&2;fail=$((fail+1));else pass=$((pass+1));fi
  if [ -f "$R/.trackers/.setup-selection" ];then no "$SETUP" "$R" --apply --trackers issues;has "$T/out" 'reason=conflicting-trackers';fi
  ok complete "$R"
  [ "$(find "$R/.trackers/tables" -name '*.tsv' -exec basename {} .tsv \; | sort)" = $'feedback\ntasks' ]&&pass=$((pass+1))||{ echo "FAIL selected resume population $stop" >&2;fail=$((fail+1));}
done

# Intent staging cleans only its own temporary on every supported signal.
SIGNAL_HOOK="$T/signal-selection.sh";printf '%s\n' '#!/bin/sh' 'kill -"$SIGNAL_NAME" "$PPID"' >"$SIGNAL_HOOK";chmod +x "$SIGNAL_HOOK"
for signal in HUP INT TERM;do
  R="$T/signal-$signal";newroot "$R"
  if SIGNAL_NAME="$signal" BACKLOG_SETUP_TEST_BEFORE_SELECTION_RENAME="$SIGNAL_HOOK" complete "$R" >/dev/null 2>&1;then echo "FAIL $signal staging interruption missed" >&2;fail=$((fail+1));else pass=$((pass+1));fi
  if find "$R/.trackers" -maxdepth 1 -name '.setup-selection.tmp.*' -print -quit | grep -q .;then echo "FAIL $signal left selection temporary" >&2;fail=$((fail+1));else pass=$((pass+1));fi
done

# Any unexplained reserved temporary survives and makes the layer ambiguous.
for kind in file symlink directory;do
  R="$T/reserved-temp-$kind";newroot "$R";mkdir -p "$R/.trackers";path="$R/.trackers/.setup-selection.tmp.foreign"
  case "$kind" in file)printf 'foreign\n'>"$path";;symlink)ln -s "$T" "$path";;directory)mkdir "$path";;esac
  no complete "$R";has "$T/out" 'reason=ambiguous-state';[ -e "$path" ]||[ -L "$path" ]&&pass=$((pass+1))||{ echo "FAIL setup removed foreign $kind temporary" >&2;fail=$((fail+1));}
done

# A durable history plus valid intent is cleanup-only; a retry rewrites no incumbent byte.
CLEANUP_STOP="$T/stop-cleanup.sh";printf '%s\n' '#!/bin/sh' 'exit 86'>"$CLEANUP_STOP";chmod +x "$CLEANUP_STOP"
CL="$T/cleanup";newroot "$CL";if BACKLOG_SETUP_TEST_BEFORE_SELECTION_REMOVE="$CLEANUP_STOP" "$SETUP" "$CL" --apply --trackers failures >/dev/null 2>&1;then echo 'FAIL cleanup interruption missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
has <("$SKILL/scripts/tracker-layer-status.sh" setup --root "$CL") 'layer_status=selection-cleanup'
cp -R "$CL/.trackers" "$T/cleanup.before";complete "$CL">"$T/cleanup.out"
if grep -q '^wrote=' "$T/cleanup.out";then echo 'FAIL cleanup retry rewrote incumbent bytes' >&2;fail=$((fail+1));else pass=$((pass+1));fi
diff -ru --exclude='.setup-selection' "$T/cleanup.before" "$CL/.trackers" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL cleanup retry changed incumbent bytes' >&2;fail=$((fail+1));}
[ ! -e "$CL/.trackers/.setup-selection" ]&&pass=$((pass+1))||fail=$((fail+1))

# Cleanup revalidation detects a population race and leaves the intent for review.
MUTATE_CLEANUP="$T/mutate-cleanup.sh";printf '%s\n' '#!/bin/sh' 'printf "id\tcreated\ttext\tevidence\n" >"$1/$2/tables/tasks.tsv"'>"$MUTATE_CLEANUP";chmod +x "$MUTATE_CLEANUP"
CR="$T/cleanup-race";newroot "$CR";if BACKLOG_SETUP_TEST_BEFORE_SELECTION_REMOVE="$MUTATE_CLEANUP" "$SETUP" "$CR" --apply --trackers failures >"$T/cleanup-race.out" 2>&1;then echo 'FAIL cleanup population race survived' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ -f "$CR/.trackers/.setup-selection" ]&&pass=$((pass+1))||fail=$((fail+1));rm "$CR/.trackers/tables/tasks.tsv";ok complete "$CR"

# A failures prefix without the new intent can never masquerade as the legacy four-default path.
FI="$T/failures-without-intent";newroot "$FI";mkdir -p "$FI/.trackers/tables";printf '%s\n' "$HEADER">"$FI/.trackers/tables/failures.tsv";no complete "$FI";has "$T/out" 'reason=ambiguous-state'

# The history publication boundary revalidates every prehistory extent.
RACE="$T/prehistory-race.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -ne 10 ] || printf "bad\\n" >"$1/$2/tables/tasks.tsv"'>"$RACE";chmod +x "$RACE"
B="$T/preledger-race";newroot "$B";if BACKLOG_SETUP_TEST_AFTER_WRITE="$RACE" complete "$B" >"$T/preledger.out" 2>&1;then echo 'FAIL preledger mutation survived' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ ! -e "$B/.trackers/history.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL history published over invalid prefix' >&2;fail=$((fail+1));}

# A tracker-parent swap after a reported write cannot redirect later writes.
SWAP="$T/swap-parent.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -ne 1 ] || { mv "$1/$2" "$OUTSIDE"; ln -s "$OUTSIDE" "$1/$2"; }'>"$SWAP";chmod +x "$SWAP"
S="$T/parent-swap";newroot "$S";OUTSIDE="$T/swapped-layer"
if OUTSIDE="$OUTSIDE" BACKLOG_SETUP_TEST_AFTER_WRITE="$SWAP" complete "$S" >"$T/parent-swap.out" 2>&1;then echo 'FAIL tracker-parent swap survived' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ ! -e "$OUTSIDE/tables/tasks.tsv" ]&&[ ! -e "$OUTSIDE/history.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL write escaped through swapped tracker parent' >&2;fail=$((fail+1));}

# A swap after the final tracker-root write refuses without touching a front door.
LATE_SWAP="$T/swap-after-readme.sh";printf '%s\n' '#!/bin/sh' '[ "$3" != "$2/README.md" ] || { mv "$1/$2" "$OUTSIDE"; ln -s "$OUTSIDE" "$1/$2"; }'>"$LATE_SWAP";chmod +x "$LATE_SWAP"
LS="$T/late-parent-swap";newroot "$LS";LATE_OUTSIDE="$T/late-swapped-layer"
if OUTSIDE="$LATE_OUTSIDE" BACKLOG_SETUP_TEST_AFTER_WRITE="$LATE_SWAP" complete "$LS" >"$T/late-parent-swap.out" 2>&1;then echo 'FAIL late tracker-parent swap survived' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ ! -e "$LS/AGENTS.md" ]&&pass=$((pass+1))||{ echo 'FAIL setup created a front door after tracker custody was lost' >&2;fail=$((fail+1));}

# Retired selectors refuse before the first durable change; a normal retry uses `.trackers`.
C="$T/selector-refusal";newroot "$C";no "$SETUP" "$C" --trackers-root project-trackers --apply
[ ! -e "$C/project-trackers" ]&&[ ! -e "$C/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))
ok complete "$C";[ -f "$C/.trackers/history.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))

# Non-prefix content refuses before mutation.
for kind in custom nonempty malformed-provider malformed-queue;do
  R="$T/ambiguous-$kind";newroot "$R";mkdir -p "$R/.trackers"
  case "$kind" in
    custom) printf '%s\n' "$HEADER">"$R/.trackers/decisions.tsv";;
    nonempty) printf '%s\n' "$HEADER" $'tasks-1\t2026-08-29T00:00:00Z\twork\t'>"$R/.trackers/tasks.tsv";;
    malformed-provider) printf 'bad\n'>"$R/.trackers/trackers.sh";chmod +x "$R/.trackers/trackers.sh";;
    malformed-queue) printf 'bad\n'>"$R/.trackers/tasks.tsv";;
  esac
  no complete "$R";[ ! -e "$R/.trackers/history.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))
done

# A prompt file is a resumable prefix only when it has the exact package base.
Z="$T/arbitrary-prompt";newroot "$Z";mkdir -p "$Z/.trackers";printf 'unrelated project prompt\n'>"$Z/.trackers/DEBRIEF.md"
no complete "$Z";has "$T/out" 'reason=ambiguous-state';[ ! -e "$Z/.trackers/history.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL arbitrary prompt published history' >&2;fail=$((fail+1));}

# Git and README witnesses keep missing-ledger recovery branches distinct.
G="$T/git-loss";newroot "$G";complete "$G" >/dev/null;git -C "$G" add .;git -C "$G" -c user.name=test -c user.email=test@example.invalid commit -qm initialized
rm "$G/.trackers/history.tsv";no complete "$G";has "$T/out" 'reason=ledger-recovery-required action=git-restore'
H="$T/readme-loss";newroot "$H";complete "$H" >/dev/null;rm "$H/.trackers/history.tsv";no complete "$H";has "$T/out" 'reason=ledger-recovery-required action=human-review'
W="$T/unwitnessed";newroot "$W";if STOP_AT=16 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$W" >/dev/null 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
rm "$W/.trackers/history.tsv";ok complete "$W";[ "$(wc -l <"$W/.trackers/history.tsv"|tr -d ' ')" -eq 1 ]&&pass=$((pass+1))||fail=$((fail+1))

# Initialized setup preserves custom and deliberately empty populations.
P="$T/population";newroot "$P";complete "$P" >/dev/null;"$SETUP" "$P" tracker-add decisions >/dev/null
for stem in tasks issues failures feedback routines;do "$SETUP" "$P" tracker-remove "$stem" >/dev/null;done
cp "$P/.trackers/tables/decisions.tsv" "$T/decisions";complete "$P" >/dev/null;cmp "$T/decisions" "$P/.trackers/tables/decisions.tsv" >/dev/null&&[ "$(find "$P/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')" -eq 1 ]&&pass=$((pass+1))||fail=$((fail+1))
"$SETUP" "$P" tracker-remove decisions >/dev/null;complete "$P" >/dev/null
[ "$(find "$P/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')" -eq 0 ]&&[ -f "$P/.trackers/tables/.gitkeep" ]&&pass=$((pass+1))||fail=$((fail+1))

# A retry claims custody of the marker written before the first interruption.
M="$T/marker-custody";newroot "$M";if STOP_AT=2 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$M" >/dev/null 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
complete "$M">"$T/marker-custody.out";has "$T/marker-custody.out" 'reconciled=.trackers/tables/.gitkeep'

# A resumed run reports prior exact package results; a committed rerun is silent.
K="$T/custody";newroot "$K";if STOP_AT=5 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$K" >/dev/null 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
complete "$K">"$T/custody.out";has "$T/custody.out" 'reconciled=.trackers/trackers.sh';has "$T/custody.out" 'wrote=.trackers/tables/feedback.tsv'
git -C "$K" add .;git -C "$K" -c user.name=test -c user.email=test@example.invalid commit -qm setup;complete "$K">"$T/clean.out"
if grep -Eq '^(wrote|reconciled)=' "$T/clean.out";then echo 'FAIL clean rerun claimed custody' >&2;fail=$((fail+1));else pass=$((pass+1));fi

# A resumed managed README with an indistinguishable project edit refuses custody.
J="$T/mixed-custody";newroot "$J";if STOP_AT=15 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$J" >/dev/null 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
printf '\nproject edit after interrupted setup\n'>>"$J/.trackers/README.md";no complete "$J";has "$T/out" 'reason=commit-custody-required detail=.trackers/README.md'
[ ! -e "$J/AGENTS.md" ]&&pass=$((pass+1))||{ echo 'FAIL mixed custody created a front door before refusal' >&2;fail=$((fail+1));}

# A tracked project README changed only by the interrupted package write resumes safely.
L="$T/readme-custody";newroot "$L";mkdir -p "$L/.trackers";printf 'project guide\n'>"$L/.trackers/README.md"
git -C "$L" add .;git -C "$L" -c user.name=test -c user.email=test@example.invalid commit -qm guide
if STOP_AT=15 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$L" >/dev/null 2>&1;then echo 'FAIL README interruption missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
if complete "$L">"$T/readme-custody.out" 2>&1;then pass=$((pass+1));else echo 'FAIL package-only README resume refused custody' >&2;fail=$((fail+1));fi
has "$T/readme-custody.out" 'reconciled=.trackers/README.md';grep -qFx 'project guide' "$L/.trackers/README.md"&&pass=$((pass+1))||fail=$((fail+1))

# A project edit after an interrupted package prompt write refuses before another write.
E="$T/prompt-custody";newroot "$E";if STOP_AT=6 BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" complete "$E" >/dev/null 2>&1;then echo 'FAIL prompt interruption missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
printf '\nproject prompt edit\n'>>"$E/.trackers/DEBRIEF.md";no complete "$E";has "$T/out" 'reason=commit-custody-required detail=.trackers/DEBRIEF.md'
[ ! -e "$E/.trackers/tables/issues.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL setup wrote after losing prompt custody' >&2;fail=$((fail+1));}

echo "setup-resume-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
