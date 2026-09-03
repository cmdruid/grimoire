#!/usr/bin/env bash
# A verified partial delivery admits only the two-parent reconciliation exception.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-partial.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; base="$(git -C "$ROOT" rev-parse HEAD)"
"$HELPER" "$ROOT" runtime-init partial main partial >"$OUT"; "$HELPER" "$ROOT" unit-begin partial unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/partial/file"; git -C "$ROOT/.streams/partial" add file; git -C "$ROOT/.streams/partial" commit -qm unit
"$HELPER" "$ROOT" unit-complete partial >"$OUT"; "$HELPER" "$ROOT" ship-prepare partial >"$OUT"; "$HELPER" "$ROOT" gate-run partial --class docs --label gate -- true >"$OUT"
candidate="$(git -C "$ROOT/.streams/partial" rev-parse HEAD)"; "$HELPER" "$ROOT" land-advance partial --authority confirmed >"$OUT"
expect_eq 'clean landing is not a merge' 1 "$(git -C "$ROOT/.streams/partial" rev-list --parents -n1 "$candidate" | awk '{print NF-1}')"
tree="$(git -C "$ROOT" rev-parse "$base^{tree}")"; divergent="$(printf 'divergent destination\n' | git -C "$ROOT" commit-tree "$tree" -p "$base")"
TRACKER="$ROOT/.streams/partial/workstream.tsv"
{
  cat "$TRACKER"
  printf 'delivery\t1/remote-target\tcandidate-tip\t%s\n' "$candidate"
  printf 'delivery\t1/remote-target\texpected-tip\t%s\n' "$base"
  printf 'delivery\t1/remote-target\tobserved-tip\t%s\n' "$divergent"
  printf 'delivery\t1/remote-target\tstate\trejected\n'
} >"$TMP/partial.tsv"; cp "$TMP/partial.tsv" "$TRACKER"
"$HELPER" "$ROOT" validate-tracker "$TRACKER" >"$OUT"
"$HELPER" "$ROOT" delivery-classify partial >"$OUT"; expect 'divergent receipts classify partial' 'classifier=partial-delivery' "$OUT"
if "$HELPER" "$ROOT" reconcile-partial partial >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" reconcile-partial partial --authority confirmed >"$OUT"
expect 'partial tips reconcile' 'status=reconciled' "$OUT"
expect 'reconciliation invalidates authority' 'authority=invalidated' "$OUT"
merged="$(git -C "$ROOT/.streams/partial" rev-parse HEAD)"
expect_eq 'candidate is first parent' "$candidate" "$(git -C "$ROOT/.streams/partial" rev-parse "$merged^1")"
expect_eq 'divergent tip is second parent' "$divergent" "$(git -C "$ROOT/.streams/partial" rev-parse "$merged^2")"
expect_absent 'destination receipts become stale and clear' $'delivery\t' "$TRACKER"
expect 'reconciliation returns to gate' $'phase\tgate' "$TRACKER"
report 'workstream partial delivery'
