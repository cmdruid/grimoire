#!/usr/bin/env bash
# PR-style delivery waits for observed integration before finalization.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-pr.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
REMOTE="$TMP/remote.git"; git init -q --bare "$REMOTE"
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; git -C "$ROOT" remote add origin "$REMOTE"; git -C "$ROOT" push -qu origin main
mkdir -p "$ROOT/.streams"; sed -e 's/isolation: worktree/isolation: in-place/' -e 's/landing: local/landing: pr/' "$DIR/../../templates/streams-config.md" >"$ROOT/.streams/CONFIG.md"
"$HELPER" "$ROOT" runtime-init pr main pr >"$OUT"; "$HELPER" "$ROOT" unit-begin pr unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm unit
"$HELPER" "$ROOT" unit-complete pr >"$OUT"; "$HELPER" "$ROOT" ship-prepare pr >"$OUT"; "$HELPER" "$ROOT" gate-run pr --class docs --label gate -- true >"$OUT"
target_before="$(git -C "$ROOT" rev-parse main)"
git -C "$ROOT" push -qu origin stream/pr
"$HELPER" "$ROOT" pr-await pr --authority confirmed --reference 'fixture-pr-1' >"$OUT"
expect 'PR records awaiting merge' 'status=awaiting-merge' "$OUT"
expect_eq 'PR preparation leaves target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
if "$HELPER" "$ROOT" pr-verify pr >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'unmerged PR remains waiting' 'next_action=await-merge' "$OUT"
candidate="$(git -C "$ROOT" rev-parse stream/pr)"; git -C "$ROOT" push -q origin "$candidate:refs/heads/main"
"$HELPER" "$ROOT" pr-verify pr >"$OUT"
expect 'observed merge reaches postflight' 'status=merged' "$OUT"
expect 'PR outcome becomes landed' $'outcome\tlanded' "$ROOT/.streams/pr/workstream.tsv"
expect_eq 'PR leaves local target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" ship-finalize pr >"$OUT"; expect 'verified PR finalizes' 'status=finalized' "$OUT"
"$HELPER" "$ROOT" close-check pr >"$OUT"; expect 'remote PR containment permits close' 'ahead=0' "$OUT"
report 'workstream PR delivery'
