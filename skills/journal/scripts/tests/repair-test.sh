#!/usr/bin/env bash
# repair-test.sh — initialized-layer provider/README-only reconciliation.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; STANDUP="$SKILL/scripts/standup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-repair.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

root="$TMP/root"; mkdir -p "$root"; "$STANDUP" setup "$root" >/dev/null
mkdir -p "$root/.records/notes"
record="$root/.records/notes/2026-09-02-canary.md"
printf '%s\n' '---' 'doctype: notes' 'status: published' 'schema: notepad/note@1' 'tags: []' \
  '---' '# Canary' >"$record"
printf 'ledger-canary\n' >"$root/.records/history.tsv"
cp "$record" "$TMP/record.before"; cp "$root/.records/history.tsv" "$TMP/ledger.before"
printf '\n# stale\n' >>"$root/.records/records.sh"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$root/.records/README.md"
rm "$root/.records/README.md.bak"
"$STANDUP" repair "$root" >"$OUT" 2>"$ERR"
expect "repair reports provider" 'wrote: .records/records.sh' "$OUT"
expect "repair reports README" 'wrote: .records/README.md' "$OUT"
expect_absent "repair does not report ledger" 'wrote: .records/history.tsv' "$OUT"
cmp -s "$TMP/record.before" "$record" && pass=$((pass + 1)) || fail=$((fail + 1))
cmp -s "$TMP/ledger.before" "$root/.records/history.tsv" && pass=$((pass + 1)) || fail=$((fail + 1))

rm "$root/.records/history.tsv"; rc=0
"$STANDUP" repair "$root" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing ledger repair rc" 2 "$rc"
expect_eq "missing ledger repair route" 'reason=setup-required action=/journal setup' "$(cat "$ERR")"

spaces="$TMP/spaces"; mkdir -p "$spaces"; "$STANDUP" setup "$spaces" >/dev/null
mkdir -p "$spaces/.spaces/journal"; printf 'residue\n' >"$spaces/.spaces/journal/setup.intent"
cp "$spaces/.spaces/journal/setup.intent" "$TMP/residue.before"
"$STANDUP" repair "$spaces" >"$OUT" 2>"$ERR"
cmp -s "$TMP/residue.before" "$spaces/.spaces/journal/setup.intent" && pass=$((pass + 1)) || {
  echo 'FAIL: repair inspected or changed workspace residue' >&2; fail=$((fail + 1)); }

report repair-test
