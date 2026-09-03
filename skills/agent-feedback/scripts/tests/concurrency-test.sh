#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-concurrency.XXXXXX")"
trap 'rm -rf "$T"' EXIT
H="$T/home"; new_home "$H"; HOME="$H" "$PROVIDER" init >/dev/null
F="$(store_for "$H")"

# Twenty simultaneous writers serialize through the bounded lock without torn
# rows, duplicate IDs, or operation-owned debris.
pids=()
for n in $(seq 1 20); do
  (capture_agent "$H" architect friction >"$T/writer-$n.out") & pids+=("$!")
done
for pid in "${pids[@]}"; do if wait "$pid"; then :; else fail "writer $pid failed"; fi; done
[ "$(awk 'END{print NR-1}' "$F")" = 20 ] && pass || fail 'concurrent row count'
[ "$(awk -F '\t' 'NR>1{seen[$1]++}END{for(id in seen)if(seen[id]>1)dup++;print dup+0}' "$F")" = 0 ] && pass || fail 'duplicate concurrent ID'
[ ! -e "$F.lock" ] && pass || fail 'lock survived writers'
[ "$(find "$(dirname "$F")" -name '.agent-feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ] && pass || fail 'temporary survived writers'
HOME="$H" "$PROVIDER" query --limit 100 --format tsv >"$T/page"
[ "$(awk 'END{print NR-1}' "$T/page")" = 20 ] && pass || fail 'query page count'
if grep -q '^count=' "$T/page"; then fail 'TSV query emitted count trailer'; else pass; fi

# A live lock produces a bounded retry and preserves the store.
mkdir "$F.lock"; printf '%s\n' "$$" >"$F.lock/pid"
cp "$F" "$T/busy.before"; start="$(date +%s)"
no capture_agent "$H" architect friction
elapsed=$(( $(date +%s) - start ))
[ "$elapsed" -ge 4 ] && [ "$elapsed" -le 8 ] && pass || fail "lock wait was not bounded: ${elapsed}s"
same "$F" "$T/busy.before"
rm "$F.lock/pid"; rmdir "$F.lock"

# Setup alone may clear one conclusively stale, well-formed PID lock.
mkdir "$F.lock"; printf '999999\n' >"$F.lock/pid"
HOME="$H" "$PROVIDER" init >"$T/stale"
has "$T/stale" 'status=ready'; [ ! -e "$F.lock" ] && pass || fail 'stale lock survived init'

# Ambiguous locks—including extra PID bytes—are never guessed stale.
for lock_body in 'not-a-pid' '999999
extra'; do
  mkdir "$F.lock"; printf '%s\n' "$lock_body" >"$F.lock/pid"; cp "$F.lock/pid" "$T/lock.before"
  no env HOME="$H" "$PROVIDER" init
  same "$F.lock/pid" "$T/lock.before"
  rm "$F.lock/pid"; rmdir "$F.lock"
done

# A lock released during retries is acquired normally.
mkdir "$F.lock"; (sleep 1; rm "$F.lock/pid"; rmdir "$F.lock") & releaser=$!
printf '%s\n' "$releaser" >"$F.lock/pid"
capture_agent "$H" architect gap >"$T/delayed"; wait "$releaser" 2>/dev/null || true
has "$T/delayed" 'captured=AF-'
[ "$(awk 'END{print NR-1}' "$F")" = 21 ] && pass || fail 'delayed writer lost rows'

# Failure immediately before rename leaves the incumbent and filesystem clean.
HOOK="$T/fail-before-rename.sh"
printf '%s\n' '#!/bin/sh' 'exit 87' >"$HOOK"; chmod +x "$HOOK"
cp "$F" "$T/interrupt.before"
no env HOME="$H" AGENT_FEEDBACK_TEST_BEFORE_RENAME="$HOOK" "$PROVIDER" capture \
  --origin agent --subject-type skill --subject architect --subject-ref unknown --invocation x \
  --kind gap --summary x --statement x --incident x --consequence x --suggestion x --redacted no
same "$F" "$T/interrupt.before"
[ "$(find "$(dirname "$F")" -name '.agent-feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ] && pass || fail 'interrupt left temporary'
[ ! -e "$F.lock" ] && pass || fail 'interrupt left lock'

# ID generation rerolls a planted collision while holding the lock.
collision_time=2026-09-03T12:00:00Z
constant="$T/constant.sh"; printf '%s\n' '#!/bin/sh' 'printf deadbeef' >"$constant"; chmod +x "$constant"
HOME="$H" AGENT_FEEDBACK_TEST_UTC_NOW="$collision_time" AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$constant" \
  capture_human "$H" architect request >"$T/planted"
collision_id="$(sed -n 's/^captured=//p' "$T/planted")"
state="$T/random-state"; printf '0\n' >"$state"
reroll="$T/reroll.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
  'n="$(sed -n "1p" "$AGENT_FEEDBACK_TEST_RANDOM_STATE")"' \
  'if [ "$n" = 0 ]; then printf deadbeef; else printf cafebabe; fi' \
  'printf "%s\n" "$((n + 1))" >"$AGENT_FEEDBACK_TEST_RANDOM_STATE"' >"$reroll"
chmod +x "$reroll"
HOME="$H" AGENT_FEEDBACK_TEST_UTC_NOW="$collision_time" AGENT_FEEDBACK_TEST_RANDOM_STATE="$state" \
  AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$reroll" capture_human "$H" architect request >"$T/rerolled"
has "$T/rerolled" 'captured=AF-20260903T120000Z-cafebabe'
[ "$(sed -n '1p' "$state")" = 2 ] && pass || fail 'collision did not consume one reroll'
[ "$(awk -F '\t' -v id="$collision_id" 'NR>1&&$1==id{n++}END{print n+0}' "$F")" = 1 ] && pass || fail 'planted collision duplicated'

# A pathological random source is bounded and cannot mutate the incumbent.
cp "$F" "$T/collision-bound.before"
if HOME="$H" AGENT_FEEDBACK_TEST_UTC_NOW="$collision_time" \
  AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$constant" capture_human "$H" architect request \
  >"$T/out" 2>"$T/collision-bound.err"; then
  fail 'unbounded collision source was accepted'
else
  pass
fi
has "$T/collision-bound.err" 'reason=id-collision action=retry'
same "$F" "$T/collision-bound.before"

finish concurrency-test
