#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";SETUP="$SKILL/scripts/backlog-setup.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-deploy-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
newroot(){ local r="$1";mkdir -p "$r";git -C "$r" init -q;}
BASE=(--workspace .spaces --records-root .records)

R="$T/default";newroot "$R"
out="$("$SETUP" "$R" "${BASE[@]}" --apply)"
has <(printf '%s\n' "$out") 'wrote=.trackers/tracker-api.sh'
for f in README.md tracker-api.sh receipts.tsv tasks.tsv issues.tsv feedback.tsv routines.tsv;do [ -f "$R/.trackers/$f" ]&&pass=$((pass+1))||{ echo "FAIL missing $f" >&2;fail=$((fail+1));};done
for s in tasks issues feedback routines;do has "$R/.spaces/backlog/hooks/debrief.md" "## $s";done
has "$R/AGENTS.md" 'After a human-visible work unit completes'
if grep -q '^agent-trackers:' "$R/AGENTS.md";then echo 'FAIL default declared' >&2;fail=$((fail+1));else pass=$((pass+1));fi

# Incumbents win; only the managed executable refreshes.
printf 'custom readme\n' > "$R/.trackers/README.md";printf '\nproject edit\n' >> "$R/.spaces/backlog/hooks/debrief.md"
printf 'stale\n' > "$R/.trackers/tracker-api.sh";chmod -x "$R/.trackers/tracker-api.sh"
before="$(shasum "$R/.trackers/tasks.tsv"|awk '{print $1}')";out="$("$SETUP" "$R" "${BASE[@]}" --apply)"
eq 'queue preserved' "$before" "$(shasum "$R/.trackers/tasks.tsv"|awk '{print $1}')";has "$R/.trackers/README.md" 'custom readme';has "$R/.spaces/backlog/hooks/debrief.md" 'project edit'
cmp "$SKILL/scripts/tracker-api.sh" "$R/.trackers/tracker-api.sh" >/dev/null&&pass=$((pass+1))||fail=$((fail+1));[ -x "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))

# Explicit selection replaces the default set on first setup.
S="$T/selected";newroot "$S";"$SETUP" "$S" "${BASE[@]}" --apply tasks --custom decisions >/dev/null
[ -f "$S/.trackers/tasks.tsv" ]&&[ -f "$S/.trackers/decisions.tsv" ]&&[ ! -e "$S/.trackers/issues.tsv" ]&&[ ! -e "$S/.trackers/routines.tsv" ]&&pass=$((pass+1))||fail=$((fail+1));has "$S/.spaces/backlog/hooks/debrief.md" '## decisions'

# Safe first override writes one declaration; later resolution honors it and conflicts refuse.
O="$T/override";newroot "$O";"$SETUP" "$O" "${BASE[@]}" --trackers-root project-trackers --apply tasks >/dev/null
has "$O/AGENTS.md" 'agent-trackers: project-trackers';[ -x "$O/project-trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1));ok "$SETUP" "$O" "${BASE[@]}" --apply tasks
no "$SETUP" "$O" "${BASE[@]}" --trackers-root elsewhere --apply tasks

# Root grammar and all overlap directions refuse before writes.
for bad in . ../escape /absolute custom/ custom//nested;do B="$T/bad-${bad//\//x}";newroot "$B";no "$SETUP" "$B" "${BASE[@]}" --trackers-root "$bad" --apply tasks;[ ! -e "$B/.spaces" ]&&pass=$((pass+1))||fail=$((fail+1));done
for args in '--workspace .spaces/' '--records-root .records/';do
  B="$(mktemp -d "$T/trailing.XXXXXX")";git -C "$B" init -q
  # shellcheck disable=SC2086
  no "$SETUP" "$B" $args --apply tasks
done
for args in '--trackers-root .records' '--trackers-root .records/nested' '--records-root .trackers/nested' '--trackers-root .spaces' '--workspace .trackers/nested';do
  B="$(mktemp -d "$T/overlap.XXXXXX")";git -C "$B" init -q
  # shellcheck disable=SC2086
  no "$SETUP" "$B" --workspace .spaces --records-root .records $args --apply tasks
done

# Unsafe parents and malformed routes refuse without escaping.
Y="$T/symlink";newroot "$Y";mkdir "$Y/outside";ln -s "$Y/outside" "$Y/.trackers";no "$SETUP" "$Y" "${BASE[@]}" --apply tasks
[ -z "$(find "$Y/outside" -mindepth 1 -print -quit)" ]&&pass=$((pass+1))||fail=$((fail+1))
M="$T/malformed";newroot "$M";printf '%s\n' '<!-- skill:backlog BEGIN broken -->' > "$M/AGENTS.md";no "$SETUP" "$M" "${BASE[@]}" --apply tasks;[ ! -e "$M/.trackers" ]&&pass=$((pass+1))||fail=$((fail+1))

# A later injected failure reports safe writes; rerun preserves and completes.
P="$T/partial";newroot "$P";HOOK="$T/stop.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' > "$HOOK";chmod +x "$HOOK"
if BACKLOG_SETUP_TEST_AFTER_WRITE="$HOOK" "$SETUP" "$P" "${BASE[@]}" --apply tasks > "$T/partial.out" 2>&1;then echo 'FAIL injection missed' >&2;fail=$((fail+1));else pass=$((pass+1));fi
has "$T/partial.out" 'wrote=.trackers/README.md';ok "$SETUP" "$P" "${BASE[@]}" --apply tasks;[ -f "$P/.trackers/tasks.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))

# Red-proof immediate destination checks: swap a later target after one safe write.
Q="$T/raced";newroot "$Q";RACE="$T/race.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] || exit 0' 'mkdir -p "$1/outside"' 'ln -s "$1/outside/receipts.tsv" "$1/$2/receipts.tsv"' > "$RACE";chmod +x "$RACE"
if BACKLOG_SETUP_TEST_AFTER_WRITE="$RACE" "$SETUP" "$Q" "${BASE[@]}" --apply tasks > "$T/race.out" 2>&1;then echo 'FAIL raced symlink accepted' >&2;fail=$((fail+1));else pass=$((pass+1));fi
has "$T/race.out" 'wrote=.trackers/README.md';[ ! -e "$Q/outside/receipts.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL wrote through raced symlink' >&2;fail=$((fail+1));}

# Red-proof final validation: corrupt the last-written result after its write.
F="$T/final-race";newroot "$F";FINAL_RACE="$T/final-race.sh";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 6 ] || exit 0' 'mkdir -p "$1/outside"' 'mv "$1/$2/tasks.tsv" "$1/outside/tasks.tsv"' 'ln -s "$1/outside/tasks.tsv" "$1/$2/tasks.tsv"' > "$FINAL_RACE";chmod +x "$FINAL_RACE"
if BACKLOG_SETUP_TEST_AFTER_WRITE="$FINAL_RACE" "$SETUP" "$F" "${BASE[@]}" --apply tasks > "$T/final-race.out" 2>&1;then echo 'FAIL unsafe final layer accepted' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ -L "$F/.trackers/tasks.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL final race fixture missed' >&2;fail=$((fail+1));}

# Literal add/remove manages only that queue and prompt section; final removal drops route.
A="$T/admin";newroot "$A";"$SETUP" "$A" "${BASE[@]}" --apply --custom alpha >/dev/null
ok "$SETUP" "$A" "${BASE[@]}" tracker-add beta;has "$A/.spaces/backlog/hooks/debrief.md" '## beta';no "$SETUP" "$A" "${BASE[@]}" tracker-add receipts
printf 'alpha-1\t2026-08-27T00:00:00Z\topen item\t\n' >> "$A/.trackers/alpha.tsv"
ok "$SETUP" "$A" "${BASE[@]}" tracker-remove alpha;[ ! -e "$A/.trackers/alpha.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))
ok "$SETUP" "$A" "${BASE[@]}" tracker-remove beta
if grep -q 'skill:backlog' "$A/AGENTS.md";then echo 'FAIL route remained' >&2;fail=$((fail+1));else pass=$((pass+1));fi
[ -f "$A/.trackers/receipts.tsv" ]&&pass=$((pass+1))||fail=$((fail+1))

echo "deploy-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
