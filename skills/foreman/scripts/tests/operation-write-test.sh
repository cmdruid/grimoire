#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures/migration"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-write-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R"; OUT="$T/out"; C="$T/candidate.md"; awk '{print}' "$FIX/clean-operation.md" >"$C"

"$WRITE" put --root "$R" --workspace .spaces --identity foreman/prepare-release --candidate "$C" >"$OUT"
has "put creates" 'status=created' "$OUT"; ok test -f "$R/.spaces/foreman/operations/prepare-release.md"
sum="$(cksum "$R/.spaces/foreman/operations/prepare-release.md")"
"$WRITE" put --root "$R" --workspace .spaces --identity foreman/prepare-release --candidate "$C" >"$OUT"
has "put preserves" 'status=preserved' "$OUT"; eq "incumbent bytes" "$sum" "$(cksum "$R/.spaces/foreman/operations/prepare-release.md")"

sed 's/Build the release artifact/Build a changed artifact/' "$C" >"$T/conflict.md"
if "$WRITE" put --root "$R" --workspace .spaces --identity foreman/prepare-release --candidate "$T/conflict.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "conflict reason" 'reason=incumbent-conflict' "$OUT"; eq "conflict preserved" "$sum" "$(cksum "$R/.spaces/foreman/operations/prepare-release.md")"

if "$WRITE" put --root "$R" --workspace .spaces --identity debugger/foreign --candidate "$C" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign owner" 'reason=foreign-owner' "$OUT"; ok test ! -e "$R/.spaces/debugger"
if FOREMAN_WRITE_TEST_DEST_REL='.spaces/debugger/operations/escape.md' "$WRITE" put --root "$R" --workspace .spaces --identity foreman/escape --candidate "$C" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "owner sentinel" 'reason=foreign-destination' "$OUT"; ok test ! -e "$R/.spaces/debugger"

S="$T/symlink"; mkdir -p "$S/real"; ln -s "$S/real" "$S/.spaces"
if "$WRITE" put --root "$S" --workspace .spaces --identity foreman/unsafe --candidate "$C" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "symlink refusal" 'reason=symlink-destination-parent' "$OUT"; ok test ! -e "$S/real/foreman"

report operation-write-test
