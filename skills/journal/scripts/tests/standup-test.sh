#!/usr/bin/env bash
# standup-test.sh — split/coincident roots, refresh, and safe-parent proofs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

STANDUP="$SKILL/scripts/standup.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

run_default() {
  "$STANDUP" "$1" --workspace .spaces --records-root .records
}

# Split roots: engine under Workspace, data substrate under Records.
proj="$TMP/project"
mkdir -p "$proj"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "split standup rc" "0" "$rc"
expect "split self-check" "records check: OK (0 records)" "$OUT"
[ -x "$proj/.spaces/journal/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: staged engine missing" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/history.tsv" ] && pass=$((pass + 1)) || {
  echo "FAIL: ledger missing" >&2; fail=$((fail + 1)); }
[ ! -e "$proj/.records/scripts" ] && pass=$((pass + 1)) || {
  echo "FAIL: records-home script dump created" >&2; fail=$((fail + 1)); }
expect "README names staged engine" ".spaces/journal/scripts/records.sh" "$proj/.records/README.md"

rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "zero-write rerun rc" "0" "$rc"
expect_absent "zero-write rerun reports no write" "wrote:" "$OUT"

# Re-run preserves project substrate and refreshes package bytes.
printf '%s\n' 'keep-ledger' > "$proj/.records/history.tsv"
printf '%s\n' 'project readme' > "$proj/.records/README.md"
printf '%s\n' '# drift' >> "$proj/.spaces/journal/scripts/records.sh"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "refresh rc" "0" "$rc"
expect_absent "refresh removes drift" "# drift" "$proj/.spaces/journal/scripts/records.sh"
expect "refresh preserves ledger" "keep-ledger" "$proj/.records/history.tsv"
expect "refresh preserves README" "project readme" "$proj/.records/README.md"

# Custom split roots and coincident roots both work.
custom="$TMP/custom"
mkdir -p "$custom"
rc=0
"$STANDUP" "$custom" --workspace dev --records-root data/records >"$OUT" 2>"$ERR" || rc=$?
expect_eq "custom split rc" "0" "$rc"
[ -x "$custom/dev/journal/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: custom staged engine missing" >&2; fail=$((fail + 1)); }
[ -f "$custom/data/records/history.tsv" ] && pass=$((pass + 1)) || {
  echo "FAIL: custom ledger missing" >&2; fail=$((fail + 1)); }

same="$TMP/same"
mkdir -p "$same"
rc=0
"$STANDUP" "$same" --workspace .records --records-root .records >"$OUT" 2>"$ERR" || rc=$?
expect_eq "coincident rc" "0" "$rc"
[ -x "$same/.records/journal/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: coincident staged engine missing" >&2; fail=$((fail + 1)); }
[ -f "$same/.records/history.tsv" ] && pass=$((pass + 1)) || {
  echo "FAIL: coincident ledger missing" >&2; fail=$((fail + 1)); }

# Setup is a hard cut: it reports legacy records but never migrates them while
# reading or refreshing the tool layer.
mig="$TMP/migrate"
mkdir -p "$mig/.records/notes"
today=$(date +%Y-%m-%d)
printf '%s\n' '---' 'doctype: notes' 'status: open' "created: $today" "updated: $today" \
  'tags: []' '---' '' '# Old status' > "$mig/.records/notes/$today-old.md"
run_default "$mig" >"$OUT" 2>"$ERR"
expect_absent "setup performs no implicit migration" "migrated=" "$OUT"
expect "setup reports legacy check failure" "records check failed" "$ERR"
expect "legacy status is untouched" "status: open" "$mig/.records/notes/$today-old.md"

# Unsafe parents fail before any writes.
unsafe="$TMP/unsafe"
mkdir -p "$unsafe/real"
ln -s "$unsafe/real" "$unsafe/dev"
rc=0
"$STANDUP" "$unsafe" --workspace dev --records-root .records >"$OUT" 2>"$ERR" || rc=$?
expect_eq "workspace symlink rejected" "2" "$rc"
[ ! -e "$unsafe/real/journal" ] && pass=$((pass + 1)) || {
  echo "FAIL: symlink target mutated" >&2; fail=$((fail + 1)); }
[ ! -e "$unsafe/.records" ] && pass=$((pass + 1)) || {
  echo "FAIL: records root partially created" >&2; fail=$((fail + 1)); }

for bad in /abs foo/../bar .; do
  rc=0
  "$STANDUP" "$proj" --workspace "$bad" --records-root .records >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "bad workspace $bad" "1" "$rc"
  rc=0
  "$STANDUP" "$proj" --workspace .spaces --records-root "$bad" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "bad records root $bad" "1" "$rc"
done

# Exchange the workspace owner after preflight; the immediate creation/write
# recheck must refuse without following it.
race="$TMP/race"
mkdir -p "$race/.spaces/journal" "$race/elsewhere"
hook="$TMP/journal-exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/journal" "$1/held-journal"' \
  'ln -s "$1/elsewhere" "$1/$2/journal"' > "$hook"
chmod +x "$hook"
rc=0
JOURNAL_SETUP_TEST_AFTER_PREFLIGHT="$hook" run_default "$race" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "post-preflight exchange rejected" "2" "$rc"
[ ! -e "$race/elsewhere/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: journal wrote through exchanged parent" >&2; fail=$((fail + 1)); }

# Stop after staging the engine, then prove the completed path is reported and
# a clean rerun finishes the ledger and README.
partial="$TMP/partial"
mkdir -p "$partial"
write_hook="$TMP/journal-stop-after-first.sh"
printf '%s\n' '#!/bin/sh' '[ "$5" -eq 1 ] && exit 86' 'exit 0' > "$write_hook"
chmod +x "$write_hook"
rc=0
JOURNAL_SETUP_TEST_AFTER_WRITE="$write_hook" run_default "$partial" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "post-first-write interruption exercised" "86" "$rc"
expect "partial reports staged engine" "wrote: .spaces/journal/scripts/records.sh" "$OUT"
[ ! -e "$partial/.records/history.tsv" ] && pass=$((pass + 1)) || fail=$((fail + 1))
rc=0; run_default "$partial" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "partial rerun rc" "0" "$rc"
[ -f "$partial/.records/history.tsv" ] && [ -f "$partial/.records/README.md" ] \
  && pass=$((pass + 1)) || fail=$((fail + 1))

report "standup-test"
