#!/usr/bin/env bash
# Preparation allocates one immutable batch and one metadata commit.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-prepare.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init batch main batch >"$OUT"; "$HELPER" "$ROOT" unit-begin batch one one >"$OUT"
printf 'one\n' >>"$ROOT/.streams/batch/file"; git -C "$ROOT/.streams/batch" add file; git -C "$ROOT/.streams/batch" commit -qm one
"$HELPER" "$ROOT" unit-complete batch >"$OUT"
printf 'incoming\n' >"$ROOT/incoming"; git -C "$ROOT" add incoming; git -C "$ROOT" commit -qm incoming
target_before="$(git -C "$ROOT" rev-parse main)"; commits_before="$(git -C "$ROOT/.streams/batch" rev-list --count main..HEAD)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare reaches gate' 'status=prepared' "$OUT"
if git -C "$ROOT/.streams/batch" merge-base --is-ancestor main HEAD; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
expect_eq 'prepare does not advance target' "$target_before" "$(git -C "$ROOT" rev-parse main)"
expect_eq 'metadata makes one commit' "$((commits_before + 1))" "$(git -C "$ROOT/.streams/batch" rev-list --count main..HEAD)"
TRACKER="$ROOT/.streams/batch/workstream.tsv"
expect 'shipment batch is fixed' $'shipment-unit\t1/1\tunit\t1' "$TRACKER"
expect 'shipment phase is gate' $'phase\tgate' "$TRACKER"
history_hash="$(shasum -a 256 "$ROOT/.streams/batch/.streams/history.tsv" | awk '{print $1}')"
tip="$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
"$HELPER" "$ROOT" ship-prepare batch >"$OUT"
expect 'prepare resumes same shipment' 'shipment=1' "$OUT"
expect_eq 'retry preserves candidate' "$tip" "$(git -C "$ROOT/.streams/batch" rev-parse HEAD)"
expect_eq 'retry preserves history' "$history_hash" "$(shasum -a 256 "$ROOT/.streams/batch/.streams/history.tsv" | awk '{print $1}')"
expect_eq 'one history row' 2 "$(wc -l <"$ROOT/.streams/batch/.streams/history.tsv" | tr -d ' ')"
report 'workstream shipment prepare'
