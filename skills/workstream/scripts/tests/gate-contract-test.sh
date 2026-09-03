#!/usr/bin/env bash
# Direct and semantic gates use closed invocation/evidence contracts.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-gate.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial

prepare_stream() {
  local stream="$1"
  "$HELPER" "$ROOT" runtime-init "$stream" main "$stream" >"$OUT"; "$HELPER" "$ROOT" unit-begin "$stream" unit unit >"$OUT"
  printf '%s\n' "$stream" >"$ROOT/.streams/$stream/$stream"; git -C "$ROOT/.streams/$stream" add "$stream"; git -C "$ROOT/.streams/$stream" commit -qm "$stream"
  "$HELPER" "$ROOT" unit-complete "$stream" >"$OUT"; "$HELPER" "$ROOT" ship-prepare "$stream" >"$OUT"
}

prepare_stream direct
if "$HELPER" "$ROOT" gate-run direct --class docs --label first -- false >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'failed direct gate is recorded' $'outcome\tfailed' "$ROOT/.streams/direct/workstream.tsv"
"$HELPER" "$ROOT" gate-run direct --class docs --label retry -- true >"$OUT"
expect 'remediated direct gate passes' 'status=passed' "$OUT"
expect 'gate recovery is friction' $'friction\t1/gate-recovery\tpresent\tyes' "$ROOT/.streams/direct/workstream.tsv"
expect 'disabled friction hook permits readiness' $'phase\tready-to-land' "$ROOT/.streams/direct/workstream.tsv"

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
