#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-concurrency.XXXXXX")"
trap 'rm -rf "$T"' EXIT
H="$T/home"; new_home "$H"; HOME="$H" "$PROVIDER" init >/dev/null
F="$(store_for "$H")"

pids=()
for n in $(seq 1 20); do
  (capture_one "$H" architect friction > "$T/writer-$n.out") & pids+=("$!")
done
for pid in "${pids[@]}"; do if wait "$pid"; then :; else fail "writer $pid failed"; fi; done
[ "$(awk 'END{print NR-1}' "$F")" = 20 ] && pass || fail 'concurrent row count'
[ "$(awk -F '\t' 'NR>1{seen[$1]++}END{for(id in seen)if(seen[id]>1)dup++;print dup+0}' "$F")" = 0 ] && pass || fail 'duplicate concurrent id'
[ ! -e "$F.lock" ] && pass || fail 'lock survived writers'
[ "$(find "$(dirname "$F")" -name '.feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ] && pass || fail 'temporary survived writers'
HOME="$H" "$PROVIDER" query --limit 100 --format tsv > "$T/page"
has "$T/page" 'count=20'

mkdir "$F.lock"; printf '%s\n' "$$" > "$F.lock/pid"
before="$(shasum -a 256 "$F" | awk '{print $1}')"
start="$(date +%s)"
if capture_one "$H" architect friction >"$T/out" 2>"$T/busy.err"; then fail 'live lock accepted'; else pass; fi
elapsed=$(( $(date +%s) - start ))
[ "$elapsed" -ge 4 ] && pass || fail 'lock retry was not bounded near five seconds'
has "$T/busy.err" 'reason=feedback-busy action=retry'
[ "$(shasum -a 256 "$F" | awk '{print $1}')" = "$before" ] && pass || fail 'busy capture mutated store'
rm "$F.lock/pid"; rmdir "$F.lock"

mkdir "$F.lock"; printf '999999\n' > "$F.lock/pid"
HOME="$H" "$PROVIDER" init > "$T/stale"
has "$T/stale" 'status=ready'
[ ! -e "$F.lock" ] && pass || fail 'stale lock survived init'

# Setup never guesses that a malformed lock is stale.
mkdir "$F.lock"; printf 'not-a-pid\n' > "$F.lock/pid"
cp "$F.lock/pid" "$T/ambiguous-lock.before"
if HOME="$H" "$PROVIDER" init >"$T/out" 2>"$T/ambiguous.err"; then fail 'ambiguous lock accepted'; else pass; fi
has "$T/ambiguous.err" 'reason=feedback-busy action=retry'
same "$F.lock/pid" "$T/ambiguous-lock.before"
rm "$F.lock/pid"; rmdir "$F.lock"

mkdir "$F.lock"; (sleep 1; rm "$F.lock/pid"; rmdir "$F.lock") & releaser=$!; printf '%s\n' "$releaser" > "$F.lock/pid"
capture_one "$H" architect gap > "$T/delayed"
wait "$releaser" 2>/dev/null || true
has "$T/delayed" 'captured=SF-'
[ "$(awk 'END{print NR-1}' "$F")" = 21 ] && pass || fail 'delayed writer lost rows'

HOOK="$T/fail-before-rename.sh"
printf '%s\n' '#!/bin/sh' 'exit 87' > "$HOOK"; chmod +x "$HOOK"
cp "$F" "$T/pre-interrupt"
if HOME="$H" SKILL_FEEDBACK_TEST_BEFORE_RENAME="$HOOK" "$PROVIDER" capture --skill architect --skill-ref unknown --invocation architect/spec --kind gap --summary x --incident x --consequence x --suggestion x >"$T/out" 2>"$T/interrupt.err"; then fail 'interruption hook accepted'; else pass; fi
same "$F" "$T/pre-interrupt"
[ "$(find "$(dirname "$F")" -name '.feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ] && pass || fail 'interrupt left temporary'

# ID generation rerolls a planted collision while the lock is held.
collision_time='2026-09-02T12:00:00Z'
collision_id='SF-20260902T120000Z-deadbeef'
printf '%s\t%s\t%s\tarchitect\tunknown\tx\tgap\tx\tx\tx\tx\t\topen\t\t\t\n' \
  "$collision_id" "$collision_time" "$collision_time" >>"$F"
random_state="$T/random-state"
printf '0\n' >"$random_state"
random_source="$T/random-source.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
  'n="$(cat "$SKILL_FEEDBACK_TEST_RANDOM_STATE")"' \
  'if [ "$n" = 0 ]; then printf deadbeef; else printf cafebabe; fi' \
  'printf "%s\n" "$((n + 1))" >"$SKILL_FEEDBACK_TEST_RANDOM_STATE"' >"$random_source"
chmod +x "$random_source"
HOME="$H" SKILL_FEEDBACK_TEST_UTC_NOW="$collision_time" \
  SKILL_FEEDBACK_TEST_RANDOM_STATE="$random_state" \
  SKILL_FEEDBACK_TEST_RANDOM_SOURCE="$random_source" \
  "$PROVIDER" capture --skill architect --skill-ref unknown --invocation x --kind gap \
    --summary x --incident x --consequence x --suggestion x >"$T/collision"
has "$T/collision" 'captured=SF-20260902T120000Z-cafebabe'
[ "$(cat "$random_state")" = 2 ] && pass || fail 'collision did not consume a reroll'
[ "$(awk -F '\t' -v id="$collision_id" 'NR>1&&$1==id{n++}END{print n+0}' "$F")" = 1 ] && pass || fail 'planted collision duplicated'

finish concurrency-test
