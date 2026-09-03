#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; DOOR="$HERE/../foreman-door.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-projection-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R"; printf '%s\n' '# Host' '<!-- skill:foreign BEGIN -->' KEEP '<!-- skill:foreign END -->' >"$R/AGENTS.md"; OUT="$T/out"
if "$DOOR" check --root "$R" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "missing block" missing "$(fact block "$OUT")"; "$DOOR" apply --root "$R" >"$OUT"
"$DOOR" check --root "$R" >"$OUT"; eq "projection healthy" false "$(fact drift "$OUT")"; has "foreign projection kept" KEEP "$R/AGENTS.md"
sed -i.bak 's#\.agents/skilldata/<owner>#dev/<owner>#' "$R/AGENTS.md"; rm "$R/AGENTS.md.bak"
if "$DOOR" check --root "$R" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "drift detected" true "$(fact drift "$OUT")"; "$DOOR" apply --root "$R" >"$OUT"; has "drift repaired" '.agents/skilldata/<owner>/operations' "$R/AGENTS.md"; has "foreign still kept" KEEP "$R/AGENTS.md"
report projection-test
