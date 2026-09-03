#!/usr/bin/env bash
# A verified partial delivery admits only the two-parent reconciliation exception.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-partial.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
REMOTE="$TMP/remote.git"; UPSTREAM="$TMP/upstream"; git init -q --bare "$REMOTE"
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; git -C "$ROOT" remote add origin "$REMOTE"; git -C "$ROOT" push -qu origin main
mkdir -p "$ROOT/.streams"; sed -e 's/isolation: worktree/isolation: in-place/' -e 's/landing: local/landing: push/' "$DIR/../../templates/streams-config.md" >"$ROOT/.streams/CONFIG.md"
"$HELPER" "$ROOT" runtime-init partial main partial >"$OUT"; "$HELPER" "$ROOT" unit-begin partial unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm unit
"$HELPER" "$ROOT" unit-complete partial >"$OUT"; "$HELPER" "$ROOT" ship-prepare partial >"$OUT"; "$HELPER" "$ROOT" gate-run partial --class full --label gate -- true >"$OUT"
candidate="$(git -C "$ROOT" rev-parse HEAD)"
expect_eq 'clean landing is not a merge' 1 "$(git -C "$ROOT" rev-list --parents -n1 "$candidate" | awk '{print NF-1}')"
TRACKER="$ROOT/.streams/partial/workstream.tsv"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_REMOTE_RUNNING="$TMP/interrupt.sh" "$HELPER" "$ROOT" land-advance partial --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
git clone -q -b main "$REMOTE" "$UPSTREAM"; configure_repo "$UPSTREAM"
printf 'divergent\n' >"$UPSTREAM/divergent"; git -C "$UPSTREAM" add divergent; git -C "$UPSTREAM" commit -qm divergent; divergent="$(git -C "$UPSTREAM" rev-parse HEAD)"; git -C "$UPSTREAM" push -q origin main
if "$HELPER" "$ROOT" land-advance partial --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" delivery-classify partial >"$OUT"; expect 'divergent receipts classify partial' 'classifier=partial-delivery' "$OUT"
if "$HELPER" "$ROOT" reconcile-partial partial >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" reconcile-partial partial --authority confirmed >"$OUT"
expect 'partial tips reconcile' 'status=reconciled' "$OUT"
expect 'reconciliation invalidates authority' 'authority=invalidated' "$OUT"
merged="$(git -C "$ROOT" rev-parse HEAD)"
expect_eq 'candidate is first parent' "$candidate" "$(git -C "$ROOT" rev-parse "$merged^1")"
expect_eq 'divergent tip is second parent' "$divergent" "$(git -C "$ROOT" rev-parse "$merged^2")"
expect_absent 'destination receipts become stale and clear' $'delivery\t' "$TRACKER"
expect 'reconciliation returns to gate' $'phase\tgate' "$TRACKER"
report 'workstream partial delivery'
