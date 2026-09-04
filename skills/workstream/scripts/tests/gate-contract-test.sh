#!/usr/bin/env bash
# Direct and semantic gates use closed invocation/evidence contracts.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-gate.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial

prepare_stream() {
  local stream="$1"
  "$HELPER" "$ROOT" runtime-init "$stream" main "$stream" >"$OUT"; "$HELPER" "$ROOT" unit-begin "$stream" unit unit >"$OUT"
  printf '%s\n' "$stream" >"$ROOT/.streams/$stream/$stream"; git -C "$ROOT/.streams/$stream" add "$stream"; git -C "$ROOT/.streams/$stream" commit -qm "$stream"
  "$HELPER" "$ROOT" unit-complete "$stream" >"$OUT"; "$HELPER" "$ROOT" ship-prepare "$stream" >"$OUT"
}

prepare_stream direct
if "$HELPER" "$ROOT" gate-run direct --class docs --label wrong-class -- true >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'docs gate rejects extensionless change' 'documentation gate is illegal' "$ERR"
expect_absent 'rejected gate class writes no receipt' $'gate\t1\t' "$ROOT/.streams/direct/workstream.tsv"
if "$HELPER" "$ROOT" gate-run direct --class full --label first -- false >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'failed direct gate is recorded' $'outcome\tfailed' "$ROOT/.streams/direct/workstream.tsv"
printf 'remediation\n' >>"$ROOT/.streams/direct/direct"; git -C "$ROOT/.streams/direct" add direct; git -C "$ROOT/.streams/direct" commit -qm remediation
"$HELPER" "$ROOT" ship-prepare direct >"$OUT"
expect 'remediation resumes same shipment at gate' 'status=gate-required' "$OUT"
expect 'remediation preserves shipment identity' 'shipment=1' "$OUT"
"$HELPER" "$ROOT" gate-run direct --class full --label retry -- true >"$OUT"
expect 'remediated direct gate passes' 'status=passed' "$OUT"
expect 'gate recovery is friction' $'friction\t1/gate-recovery\tpresent\tyes' "$ROOT/.streams/direct/workstream.tsv"
expect 'disabled friction hook permits readiness' $'phase\tready-to-land' "$ROOT/.streams/direct/workstream.tsv"
printf 'contention\n' >"$ROOT/contention"; git -C "$ROOT" add contention; git -C "$ROOT" commit -qm contention
cp "$ROOT/.streams/direct/workstream.tsv" "$TMP/stale-ready.tsv"
if "$HELPER" "$ROOT" land-advance direct --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'stale readiness refuses before delivery mutation' 'primary target moved after preparation' "$ERR"
if cmp -s "$TMP/stale-ready.tsv" "$ROOT/.streams/direct/workstream.tsv"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: stale readiness changed receipts' >&2; fi
"$HELPER" "$ROOT" ship-prepare direct >"$OUT"
expect 'target movement resumes original shipment' 'shipment=1' "$OUT"
expect 'target movement invalidates gate evidence' 'status=gate-required' "$OUT"

cat >"$TMP/direct-env.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
[ "${WORKSTREAM_GATE_SECRET+x}" != x ]
EOF
chmod +x "$TMP/direct-env.sh"
prepare_stream direct-env
WORKSTREAM_GATE_SECRET=ambient "$HELPER" "$ROOT" gate-run direct-env --class full --label clean-env -- "$TMP/direct-env.sh" >"$OUT"
expect 'direct gate clears ambient selector namespace' 'status=passed' "$OUT"

prepare_stream interrupted
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_GATE_RUNNING="$TMP/interrupt.sh" "$HELPER" "$ROOT" gate-run interrupted --class full --label interrupted -- true >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'running gate receipt precedes command launch' $'outcome\trunning' "$ROOT/.streams/interrupted/workstream.tsv"
if "$HELPER" "$ROOT" gate-run interrupted --class full --label interrupted -- true >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'running gate is never replayed' 'gate result is uncertain' "$ERR"

"$HELPER" "$ROOT" runtime-init none main none >"$OUT"; "$HELPER" "$ROOT" unit-begin none empty empty >"$OUT"
git -C "$ROOT/.streams/none" commit --allow-empty -qm 'empty unit'; "$HELPER" "$ROOT" unit-complete none >"$OUT"; "$HELPER" "$ROOT" ship-prepare none >"$OUT"
"$HELPER" "$ROOT" gate-none none >"$OUT"
expect 'none gate records no-command receipt' 'class=none' "$OUT"
expect 'none gate reaches readiness' $'phase\tready-to-land' "$ROOT/.streams/none/workstream.tsv"
expect_absent 'none receipt has no command hash' $'command-sha256' "$ROOT/.streams/none/workstream.tsv"

cat >"$TMP/selector.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
[ "$WORKSTREAM_GATE_SCHEMA" = workstream-gate@1 ]
[ -f "$WORKSTREAM_GATE_OWN_MANIFEST" ] && [ ! -L "$WORKSTREAM_GATE_OWN_MANIFEST" ]
[ ! -e "$WORKSTREAM_GATE_RECEIPT" ]
printf 'key\tvalue\nschema\tworkstream-gate@1\noutcome\tpassed\ntest-state\tclean\n' >"$WORKSTREAM_GATE_RECEIPT"
echo selector-ok
EOF
chmod +x "$TMP/selector.sh"
prepare_stream semantic
"$HELPER" "$ROOT" gate-run semantic --class semantic --selector --label host-selector -- "$TMP/selector.sh" >"$OUT"
expect 'semantic selector passes' 'status=passed' "$OUT"
expect 'selector output tail retained' 'selector-ok' "$OUT"
expect 'semantic class recorded' $'class\tsemantic' "$ROOT/.streams/semantic/workstream.tsv"

cat >"$TMP/no-receipt.sh" <<'EOF'
#!/usr/bin/env bash
echo no-receipt
EOF
chmod +x "$TMP/no-receipt.sh"
prepare_stream uncertain
if "$HELPER" "$ROOT" gate-run uncertain --class semantic --selector --label broken -- "$TMP/no-receipt.sh" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'missing receipt is uncertain' $'outcome\tuncertain' "$ROOT/.streams/uncertain/workstream.tsv"
if "$HELPER" "$ROOT" gate-run uncertain --class semantic --label illegal -- true >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if "$HELPER" "$ROOT" gate-run uncertain --class docs --selector --label illegal -- true >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
report 'workstream gate contract'
