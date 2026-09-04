#!/usr/bin/env bash
# Note-first/tracker-second finalization converges after interruption.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-final.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
mkdir -p "$ROOT/.records/plans"; printf 'base\n' >"$ROOT/file"; printf '# Next\n' >"$ROOT/.records/plans/next.md"
git -C "$ROOT" add file .records/plans/next.md; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init final main final >"$OUT"; "$HELPER" "$ROOT" unit-begin final unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/final/file"; git -C "$ROOT/.streams/final" add file; git -C "$ROOT/.streams/final" commit -qm unit
"$HELPER" "$ROOT" unit-complete final >"$OUT"; "$HELPER" "$ROOT" ship-prepare final >"$OUT"; "$HELPER" "$ROOT" gate-run final --class full --label gate -- true >"$OUT"; "$HELPER" "$ROOT" land-advance final --authority confirmed >"$OUT"
"$HELPER" "$ROOT" close-check final >"$OUT"; expect 'unfinalized shipment blocks close' 'lifecycle_blocked=yes' "$OUT"
TRACKER="$ROOT/.streams/final/workstream.tsv"; RUNBOOK="$ROOT/.streams/final/WORKSTREAM.md"; cp "$TRACKER" "$TMP/tracker-before"
awk -F '\t' '$2!="1/local-target"' "$TRACKER" >"$TMP/no-local-receipt.tsv"; cp "$TMP/no-local-receipt.tsv" "$TRACKER"
if "$HELPER" "$ROOT" ship-finalize final >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'finalization requires local synchronization evidence' 'no advanced local-target receipt' "$ERR"
cp "$TMP/tracker-before" "$TRACKER"
git -C "$ROOT" switch -qc invalid-finalize
printf 'side\n' >"$ROOT/side"; git -C "$ROOT" add side; git -C "$ROOT" commit -qm side
side_tip="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" switch -q main
awk -F '\t' -v tip="$side_tip" 'BEGIN{OFS="\t"} $1=="shipment"&&$3=="branch-tip"{$4=tip} {print}' "$TRACKER" >"$TMP/rejected-finalize.tsv"
cp "$TMP/rejected-finalize.tsv" "$TRACKER"
runbook_before="$(shasum -a 256 "$RUNBOOK" | awk '{print $1}')"
if "$HELPER" "$ROOT" ship-finalize final --note 'must not survive' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_eq 'rejected finalization leaves runbook unchanged' "$runbook_before" "$(shasum -a 256 "$RUNBOOK" | awk '{print $1}')"
cp "$TMP/tracker-before" "$TRACKER"
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
"$HELPER" "$ROOT" close-check final >"$OUT"; expect 'finalized shipment releases close' 'lifecycle_blocked=no' "$OUT"
"$HELPER" "$ROOT" ship-finalize final --note 'Shipment landed.' >"$OUT"
expect 'second retry is idempotent' 'status=already-finalized' "$OUT"
"$HELPER" "$ROOT" recycle final --source-kind plan --cursor .records/plans/next.md >"$OUT"
expect 'recycle adopts a plan queue' 'status=recycled' "$OUT"
expect 'recycle records queue source' $'queue\t-\tsource-kind\tplan' "$TRACKER"
expect 'recycle records queue cursor' $'queue\t-\tcursor\t.records/plans/next.md' "$TRACKER"
report 'workstream finalization'
