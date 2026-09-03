#!/usr/bin/env bash
# Changed gitlinks must name locally obtainable objects before the gate.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-gitlink.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; SUB="$TMP/sub"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
git init -q -b main "$SUB"; git -C "$SUB" config user.name test; git -C "$SUB" config user.email test@example.invalid
printf 'sub\n' >"$SUB/sub"; git -C "$SUB" add sub; git -C "$SUB" commit -qm sub
object="$(git -C "$SUB" rev-parse HEAD)"

"$HELPER" "$ROOT" runtime-init ready-link main ready >"$OUT"; "$HELPER" "$ROOT" unit-begin ready-link link link >"$OUT"
git -C "$ROOT/.streams/ready-link" config advice.addEmbeddedRepo false
git clone -q "$SUB" "$ROOT/.streams/ready-link/vendor"
git -C "$ROOT/.streams/ready-link" add vendor; git -C "$ROOT/.streams/ready-link" commit -qm 'add ready gitlink'
"$HELPER" "$ROOT" unit-complete ready-link >"$OUT"; "$HELPER" "$ROOT" ship-prepare ready-link >"$OUT"
expect 'available gitlink reaches gate' 'status=prepared' "$OUT"
expect 'ready availability recorded' $'availability\tready' "$ROOT/.streams/ready-link/workstream.tsv"
expect 'local publication is not required' $'published\tnot-required' "$ROOT/.streams/ready-link/workstream.tsv"

"$HELPER" "$ROOT" runtime-init missing-link main missing >"$OUT"; "$HELPER" "$ROOT" unit-begin missing-link link link >"$OUT"
git -C "$ROOT/.streams/missing-link" update-index --add --cacheinfo "160000,$object,missing"
git -C "$ROOT/.streams/missing-link" commit -qm 'add missing gitlink'
"$HELPER" "$ROOT" unit-complete missing-link >"$OUT"
if "$HELPER" "$ROOT" ship-prepare missing-link >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'missing gitlink blocks' 'phase=gitlinks' "$OUT"
expect 'missing availability recorded' $'availability\tmissing' "$ROOT/.streams/missing-link/workstream.tsv"
expect_absent 'blocked gitlink has no gate receipt' $'gate\t' "$ROOT/.streams/missing-link/workstream.tsv"
report 'workstream gitlink readiness'
