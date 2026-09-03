#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";SOURCE="$SKILL/scripts/trackers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-repair-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >"$T/out" 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
newroot(){ mkdir -p "$1";git -C "$1" init -q;}

U="$T/uninitialized";newroot "$U";no "$SETUP" "$U" repair
grep -qF 'reason=setup-required action=/backlog setup' "$T/out"&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$U/.trackers" ]&&[ ! -e "$U/.agents/skilldata" ]&&pass=$((pass+1))||fail=$((fail+1))

R="$T/root";newroot "$R";"$SETUP" "$R" --apply >/dev/null
printf 'DOOR_CANARY\n'>>"$R/AGENTS.md";printf 'PROMPT_CANARY\n'>>"$R/.trackers/DEBRIEF.md"
cp "$R/AGENTS.md" "$T/door";cp "$R/.trackers/DEBRIEF.md" "$T/prompt";cp "$R/.trackers/tables/tasks.tsv" "$T/queue";cp "$R/.trackers/history.tsv" "$T/history"
for damage in missing nonexec wrong drifted;do
  case "$damage" in
    missing) rm "$R/.trackers/trackers.sh";;
    nonexec) chmod -x "$R/.trackers/trackers.sh";;
    wrong) sed 's/schema=tracker@2/schema=tracker@1/' "$SOURCE">"$R/.trackers/trackers.sh";chmod +x "$R/.trackers/trackers.sh";;
    drifted) printf '\n# drift\n'>>"$R/.trackers/trackers.sh";;
  esac
  printf '\n<!-- project prose %s -->\n' "$damage">>"$R/.trackers/README.md"
  ok "$SETUP" "$R" repair
  cmp "$SOURCE" "$R/.trackers/trackers.sh" >/dev/null&&[ -x "$R/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
  [ "$(grep -cFx '<!-- backlog:trackers-tool BEGIN -->' "$R/.trackers/README.md")" -eq 1 ]&&pass=$((pass+1))||fail=$((fail+1))
done
cmp "$T/door" "$R/AGENTS.md" >/dev/null&&cmp "$T/prompt" "$R/.trackers/DEBRIEF.md" >/dev/null&&cmp "$T/queue" "$R/.trackers/tables/tasks.tsv" >/dev/null&&cmp "$T/history" "$R/.trackers/history.tsv" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
grep -qF '<!-- project prose drifted -->' "$R/.trackers/README.md"&&pass=$((pass+1))||fail=$((fail+1))

# Repair accepts initialized default-with-removal, custom, and zero-queue populations.
for population in removed custom zero;do
  V="$T/population-$population";newroot "$V";"$SETUP" "$V" --apply >/dev/null
  case "$population" in
    removed)"$SETUP" "$V" tracker-remove issues >/dev/null;;
    custom)"$SETUP" "$V" tracker-add decisions >/dev/null;for s in tasks issues feedback routines;do "$SETUP" "$V" tracker-remove "$s" >/dev/null;done;;
    zero)for s in tasks issues feedback routines;do "$SETUP" "$V" tracker-remove "$s" >/dev/null;done;;
  esac
  before_count="$(find "$V/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')";printf 'bad\n'>"$V/.trackers/trackers.sh";chmod +x "$V/.trackers/trackers.sh"
  ok "$SETUP" "$V" repair;[ "$before_count" -eq "$(find "$V/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')" ]&&pass=$((pass+1))||fail=$((fail+1))
done

# An injected repair failure can leave only an allowed provider write; retry completes the README.
I="$T/interrupted";newroot "$I";"$SETUP" "$I" --apply >/dev/null;printf 'bad\n'>"$I/.trackers/trackers.sh";chmod +x "$I/.trackers/trackers.sh";sed 's/## Use the tracker tool/## Drifted tracker tool/' "$I/.trackers/README.md">"$T/readme.drift";mv "$T/readme.drift" "$I/.trackers/README.md"
STOP="$T/stop.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -ne 1 ] || exit 86'>"$STOP";chmod +x "$STOP"
if BACKLOG_SETUP_TEST_AFTER_WRITE="$STOP" "$SETUP" "$I" repair >/dev/null 2>&1;then fail=$((fail+1));else pass=$((pass+1));fi
cmp "$SOURCE" "$I/.trackers/trackers.sh" >/dev/null&&pass=$((pass+1))||fail=$((fail+1));ok "$SETUP" "$I" repair

# Malformed data and ownership markers refuse before any repair write.
Q="$T/malformed-queue";newroot "$Q";"$SETUP" "$Q" --apply >/dev/null;printf 'bad\n'>"$Q/.trackers/tables/tasks.tsv";cp "$Q/.trackers/trackers.sh" "$T/provider.before";no "$SETUP" "$Q" repair;cmp "$T/provider.before" "$Q/.trackers/trackers.sh" >/dev/null&&pass=$((pass+1))||fail=$((fail+1))
M="$T/malformed-readme";newroot "$M";"$SETUP" "$M" --apply >/dev/null;printf '\n<!-- backlog:trackers-tool BEGIN -->\n'>>"$M/.trackers/README.md";rm "$M/.trackers/trackers.sh";no "$SETUP" "$M" repair;[ ! -e "$M/.trackers/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))

# Repair never recreates a tracker root that vanishes after classification.
VANISH="$T/vanish-root.sh";printf '%s\n' '#!/bin/sh' 'mv "$1/$2" "$MOVED"'>"$VANISH";chmod +x "$VANISH"
N="$T/vanished-root";newroot "$N";"$SETUP" "$N" --apply >/dev/null;printf 'bad\n'>"$N/.trackers/trackers.sh";chmod +x "$N/.trackers/trackers.sh";MOVED="$T/vanished-layer"
if MOVED="$MOVED" BACKLOG_SETUP_TEST_AFTER_PREFLIGHT="$VANISH" "$SETUP" "$N" repair >"$T/vanished.out" 2>&1;then echo 'FAIL repair recreated vanished root' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ ! -e "$N/.trackers" ]&&[ "$(find "$MOVED" -name '*.tmp.*'|wc -l|tr -d ' ')" -eq 0 ]&&pass=$((pass+1))||{ echo 'FAIL repair mutated after tracker root vanished' >&2;fail=$((fail+1));}

# A project README edit between rendering and replacement wins; repair refuses instead of overwriting it.
EDIT="$T/edit-readme.sh";printf '%s\n' '#!/bin/sh' 'printf "CONCURRENT_PROJECT_EDIT\\n" >>"$1/$2/README.md"'>"$EDIT";chmod +x "$EDIT"
C="$T/readme-race";newroot "$C";"$SETUP" "$C" --apply >/dev/null;sed 's/## Use the tracker tool/## Drifted tracker tool/' "$C/.trackers/README.md">"$T/readme.race";mv "$T/readme.race" "$C/.trackers/README.md"
if BACKLOG_SETUP_TEST_BEFORE_README_RENAME="$EDIT" "$SETUP" "$C" repair >"$T/readme-race.out" 2>&1;then echo 'FAIL concurrent README edit was overwritten' >&2;fail=$((fail+1));else pass=$((pass+1));fi
grep -qF 'reason=concurrent-project-edit detail=.trackers/README.md' "$T/readme-race.out"&&grep -qFx 'CONCURRENT_PROJECT_EDIT' "$C/.trackers/README.md"&&grep -qF '## Drifted tracker tool' "$C/.trackers/README.md"&&pass=$((pass+1))||{ echo 'FAIL concurrent README bytes were not preserved' >&2;fail=$((fail+1));}

echo "repair-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
