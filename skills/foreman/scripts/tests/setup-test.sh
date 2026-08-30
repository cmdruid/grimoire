#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; DOOR="$HERE/../foreman-door.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-setup-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
OUT="$T/out"

R="$T/absent"; mkdir -p "$R"
if "$DOOR" apply --root "$R" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test ! -e "$R/AGENTS.md"
"$DOOR" apply --root "$R" --allow-create >"$OUT"
has "minimal route" '<!-- skill:foreman BEGIN -->' "$R/AGENTS.md"
has "identity rule" '<owner>/<stem>' "$R/AGENTS.md"
ok test ! -e "$R/.spaces"
sum="$(cksum "$R/AGENTS.md")"; "$DOOR" apply --root "$R" >"$OUT"
eq "idempotent route" "$sum" "$(cksum "$R/AGENTS.md")"

R2="$T/existing"; mkdir -p "$R2"; printf '%s\n' '# Host' '<!-- skill:other BEGIN -->' 'KEEP' '<!-- skill:other END -->' >"$R2/AGENTS.md"
before="$(cksum "$R2/AGENTS.md")"; "$DOOR" apply --root "$R2" >"$OUT"
has "foreign bytes kept" KEEP "$R2/AGENTS.md"; has "fixed workspace" '.spaces/<owner>/operations' "$R2/AGENTS.md"
ok test "$before" != "$(cksum "$R2/AGENTS.md")"

R4="$T/retired-selector"; mkdir -p "$R4"; printf '# Host\n'>"$R4/AGENTS.md"; sum="$(cksum "$R4/AGENTS.md")"; if "$DOOR" apply --root "$R4" --workspace dev >"$OUT" 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "retired selector leaves door untouched" "$sum" "$(cksum "$R4/AGENTS.md")"

R3="$T/malformed"; mkdir -p "$R3"; printf '%s\n' '<!-- skill:foreman BEGIN -->' broken >"$R3/AGENTS.md"
sum="$(cksum "$R3/AGENTS.md")"; if "$DOOR" apply --root "$R3" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "malformed untouched" "$sum" "$(cksum "$R3/AGENTS.md")"

report setup-test
