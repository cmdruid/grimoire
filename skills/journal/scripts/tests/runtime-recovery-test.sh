#!/usr/bin/env bash
# runtime-recovery-test.sh — exact runtime diagnostics and staged-provider route.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; RUNTIME="$SKILL/scripts/records-runtime-check.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-runtime.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

run_runtime() { "$RUNTIME" --root "$1" >"$OUT" 2>"$ERR"; }
expect_refusal() {
  label="$1"; root="$2"; diagnostic="$3"; rc=0
  run_runtime "$root" || rc=$?
  expect_eq "$label rc" 2 "$rc"
  expect_eq "$label diagnostic" "$diagnostic" "$(cat "$ERR")"
  expect_eq "$label stdout" '' "$(cat "$OUT")"
}
install_provider() {
  mkdir -p "$1/.records"
  cp "$SKILL/scripts/records.sh" "$1/.records/records.sh"; chmod 755 "$1/.records/records.sh"
}

missing="$TMP/missing"; mkdir -p "$missing"
expect_refusal "missing ledger" "$missing" 'reason=setup-required action=/journal setup'

provider_missing="$TMP/provider-missing"; mkdir -p "$provider_missing/.records"
: >"$provider_missing/.records/history.tsv"
expect_refusal "missing provider" "$provider_missing" 'reason=repair-required action=/journal repair'

healthy="$TMP/healthy"; mkdir -p "$healthy"; healthy="$(cd -P "$healthy" && pwd)"; install_provider "$healthy"
: >"$healthy/.records/history.tsv"
ln -s "$TMP/nowhere" "$healthy/.spaces"
run_runtime "$healthy"
expect_eq "healthy runtime succeeds" 0 "$?"
expect_eq "runtime returns staged provider" "$healthy/.records/records.sh" "$(cat "$OUT")"
"$(cat "$OUT")" list >/dev/null
pass=$((pass + 1))

printf '%s\n' '<!-- journal:records-tool BEGIN -->' >"$healthy/.records/README.md"
run_runtime "$healthy"
expect_eq "runtime ignores malformed README" "$healthy/.records/records.sh" "$(cat "$OUT")"

chmod 644 "$healthy/.records/records.sh"
expect_refusal "non-executable provider" "$healthy" 'reason=repair-required action=/journal repair'
chmod 755 "$healthy/.records/records.sh"
printf '\n# drift\n' >>"$healthy/.records/records.sh"
expect_refusal "drifted provider" "$healthy" 'reason=repair-required action=/journal repair'

unsafe_ledger="$TMP/unsafe-ledger"; install_provider "$unsafe_ledger"
printf 'ledger\n' >"$unsafe_ledger/target"; ln -s "$unsafe_ledger/target" \
  "$unsafe_ledger/.records/history.tsv"
expect_refusal "unsafe ledger" "$unsafe_ledger" 'reason=setup-required action=/journal setup'

unsafe_provider="$TMP/unsafe-provider"; mkdir -p "$unsafe_provider/.records"
: >"$unsafe_provider/.records/history.tsv"; ln -s "$SKILL/scripts/records.sh" \
  "$unsafe_provider/.records/records.sh"
expect_refusal "unsafe provider" "$unsafe_provider" 'reason=repair-required action=/journal repair'

unreadable="$TMP/unreadable"; install_provider "$unreadable"
mkdir -p "$unreadable/.records/locked"
printf '%s\n' '---' 'doctype: notes' 'status: archived' 'schema: notepad/note@1' \
  'tags: []' '---' '# Closed' >"$unreadable/.records/locked/2026-09-02-closed.md"
chmod 000 "$unreadable/.records/locked"
expect_refusal "runtime skips setup-only witness crawl" "$unreadable" \
  'reason=setup-required action=/journal setup'
chmod 700 "$unreadable/.records/locked"

report runtime-recovery-test
