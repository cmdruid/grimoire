#!/usr/bin/env bash
# Local delivery persists running before mutation and recovers from observation.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-delivery.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init delivery main delivery >"$OUT"; "$HELPER" "$ROOT" unit-begin delivery unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/delivery/file"; git -C "$ROOT/.streams/delivery" add file; git -C "$ROOT/.streams/delivery" commit -qm unit
"$HELPER" "$ROOT" unit-complete delivery >"$OUT"; "$HELPER" "$ROOT" ship-prepare delivery >"$OUT"; "$HELPER" "$ROOT" gate-run delivery --class docs --label gate -- true >"$OUT"
target_before="$(git -C "$ROOT" rev-parse main)"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_DELIVERY_RUNNING="$TMP/interrupt.sh" "$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'running receipt precedes mutation' $'state\trunning' "$ROOT/.streams/delivery/workstream.tsv"
expect_eq 'interruption leaves target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT"
expect 'recovered delivery lands' 'status=landed' "$OUT"
expect 'observed advance persists' $'state\tadvanced' "$ROOT/.streams/delivery/workstream.tsv"
landed="$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT"
expect 'land retry observes completion' 'status=already-landed' "$OUT"
expect_eq 'target advances only once' "$landed" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" delivery-classify delivery >"$OUT"; expect 'advanced destination classifies complete' 'classifier=complete' "$OUT"
report 'workstream delivery contract'
