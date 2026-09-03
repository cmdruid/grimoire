#!/usr/bin/env bash
# Note-first/tracker-second finalization converges after interruption.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-final.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
mkdir -p "$ROOT/.records/plans"; printf 'base\n' >"$ROOT/file"; printf '# Next\n' >"$ROOT/.records/plans/next.md"
git -C "$ROOT" add file .records/plans/next.md; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init final main final >"$OUT"; "$HELPER" "$ROOT" unit-begin final unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/final/file"; git -C "$ROOT/.streams/final" add file; git -C "$ROOT/.streams/final" commit -qm unit
"$HELPER" "$ROOT" unit-complete final >"$OUT"; "$HELPER" "$ROOT" ship-prepare final >"$OUT"; "$HELPER" "$ROOT" gate-run final --class docs --label gate -- true >"$OUT"; "$HELPER" "$ROOT" land-advance final --authority confirmed >"$OUT"
"$HELPER" "$ROOT" close-check final >"$OUT"; expect 'unfinalized shipment blocks close' 'lifecycle_blocked=yes' "$OUT"
TRACKER="$ROOT/.streams/final/workstream.tsv"; RUNBOOK="$ROOT/.streams/final/WORKSTREAM.md"; cp "$TRACKER" "$TMP/tracker-before"
tip_before="$(git -C "$ROOT/.streams/final" rev-parse HEAD)"
cat >"$TMP/race.sh" <<'EOF'
#!/usr/bin/env bash
printf '\n' >>"$1"
EOF
chmod +x "$TMP/race.sh"
if WORKSTREAM_TEST_BEFORE_REPLACE="$TMP/race.sh" "$HELPER" "$ROOT" ship-finalize final --note 'Shipment landed.' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'note survives interrupted tracker finalize' $'operator-note\tShipment landed.' "$RUNBOOK"
cp "$TMP/tracker-before" "$TRACKER"
"$HELPER" "$ROOT" ship-finalize final --note 'Shipment landed.' >"$OUT"
expect 'retry finalizes' 'status=finalized' "$OUT"
expect_eq 'transaction rows clear' 0 "$(awk -F '\t' '$1=="shipment"{n++}END{print n+0}' "$TRACKER")"
expect 'counters survive' $'next-shipment\t2' "$TRACKER"
expect_eq 'finalization creates no commit' "$tip_before" "$(git -C "$ROOT/.streams/final" rev-parse HEAD)"
expect_eq 'history remains one row' 2 "$(wc -l <"$ROOT/.streams/history.tsv" | tr -d ' ')"
"$HELPER" "$ROOT" close-check final >"$OUT"; expect 'finalized shipment releases close' 'lifecycle_blocked=no' "$OUT"
"$HELPER" "$ROOT" ship-finalize final --note 'Shipment landed.' >"$OUT"
expect 'second retry is idempotent' 'status=already-finalized' "$OUT"
"$HELPER" "$ROOT" recycle final --source-kind plan --cursor .records/plans/next.md >"$OUT"
expect 'recycle adopts a plan queue' 'status=recycled' "$OUT"
expect 'recycle records queue source' $'queue\t-\tsource-kind\tplan' "$TRACKER"
expect 'recycle records queue cursor' $'queue\t-\tcursor\t.records/plans/next.md' "$TRACKER"
report 'workstream finalization'
