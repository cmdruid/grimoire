#!/usr/bin/env bash
set -u
DIR="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; SKILL="$(CDPATH='' cd -P "$DIR/../.." && pwd)"; PRIME="$DIR/../workstream-prime.sh"; TEMPLATE="$SKILL/templates/workstream-handoff.md"
. "$DIR/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/workstream-prime-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
H="$T/WORKSTREAM.md"; SOURCE='.records/goals/2026-08-26-release.md'; OUT="$T/out"
awk -v h="$H" -v source="$SOURCE" '
  /^- source:[[:space:]]*/ {print "- source:        " source; next}
  /^- this hand-off:[[:space:]]*/ {print "- this hand-off: " h; next}
  {print}
' "$TEMPLATE" >"$H"
sed -i.bak '/^## Queue state$/a\
Parked: false\
Phase: build' "$H"; rm "$H.bak"
strip_owned() { awk '
  /^## TL;DR$|^## Queue state$|^## What.s next$/ {skip=1; next}
  skip&&/^## / {skip=0}
  !skip {print}
' "$1"; }
strip_owned "$H" >"$T/before"
"$PRIME" --handoff "$H" --source "$SOURCE" --unit 'Complete the accepted goal runbook.' --next '/foreman goal resume .records/goals/2026-08-26-release.md' >"$OUT"
expect "primed status" 'status=primed' "$OUT"; expect "queue unit" 'Current unit: Complete the accepted goal runbook.' "$H"
expect_eq "same next sentence twice" 2 "$(grep -cFx '/foreman goal resume .records/goals/2026-08-26-release.md' "$H")"
expect "parked kept" 'Parked: false' "$H"; expect "phase kept" 'Phase: build' "$H"
strip_owned "$H" >"$T/after"; if cmp -s "$T/before" "$T/after"; then pass=$((pass+1)); else echo 'FAIL: unrelated bytes changed' >&2; fail=$((fail+1)); fi
sum="$(cksum "$H")"; "$PRIME" --handoff "$H" --source "$SOURCE" --unit 'Complete the accepted goal runbook.' --next '/foreman goal resume .records/goals/2026-08-26-release.md' >"$OUT"
expect "idempotent status" 'status=unchanged' "$OUT"; expect_eq "idempotent bytes" "$sum" "$(cksum "$H")"

if "$PRIME" --handoff "$H" --source wrong.md --unit Unit --next Next >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
expect "wrong source refused" 'reason=wrong-source' "$OUT"
M="$T/missing.md"; sed "/^## What's next$/d" "$H" >"$M"
if "$PRIME" --handoff "$M" --source "$SOURCE" --unit Unit --next Next >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
expect "missing section refused" 'reason=malformed-sections' "$OUT"
L="$T/link.md"; ln -s "$H" "$L"
if "$PRIME" --handoff "$L" --source "$SOURCE" --unit Unit --next Next >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
expect "symlink refused" 'reason=unsafe-handoff' "$OUT"
expect_absent "generic helper has no foreman knowledge" 'foreman' "$PRIME"
report "workstream-prime-test.sh"
