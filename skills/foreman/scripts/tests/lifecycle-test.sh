#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; WRITE="$HERE/../operation-write.sh"; CHECK="$HERE/../operation-check.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-lifecycle-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R/.spaces/foreman/operations"; F="$R/.spaces/foreman/operations/release.md"; cp "$FIX" "$F"; OUT="$T/out"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; digest="$(fact digest "$OUT")"
sed -i.bak "/^tags:/a\\
verified-against: $digest" "$F"; rm "$F.bak"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; eq "evidence current" current "$(fact verification "$OUT")"
"$WRITE" lifecycle --root "$R" --identity foreman/release --status active --expected-digest "$digest" >"$OUT"
has "activated" 'transition=active' "$OUT"; has "status line active" 'status: active' "$F"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; eq "active eligible" true "$(fact goal_eligible "$OUT")"
"$WRITE" lifecycle --root "$R" --identity foreman/release --status deprecated --expected-digest "$digest" >"$OUT"
has "deprecated" 'status: deprecated' "$F"

sed -i.bak 's/Build the release artifact/Build a changed artifact/' "$F"; rm "$F.bak"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; changed="$(fact digest "$OUT")"; eq "edit stales" stale "$(fact verification "$OUT")"
if "$WRITE" lifecycle --root "$R" --identity foreman/release --status active --expected-digest "$changed" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "stale activation refused" 'reason=stale-verification' "$OUT"; has "stays deprecated" 'status: deprecated' "$F"

if "$WRITE" lifecycle --root "$R" --identity debugger/diagnostics --status active --expected-digest "$digest" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign proposal" 'status=proposed' "$OUT"; has "foreign identity" 'identity=debugger/diagnostics' "$OUT"; has "foreign no write" 'write=false' "$OUT"

report lifecycle-test
