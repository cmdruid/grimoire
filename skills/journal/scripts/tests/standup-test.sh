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
  "$STANDUP" "$1" --workspace .dev --records-root .records
}

# Split roots: engine under Workspace, data substrate under Records.
proj="$TMP/project"
mkdir -p "$proj"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "split standup rc" "0" "$rc"
expect "split self-check" "records check: OK (0 records)" "$OUT"
[ -x "$proj/.dev/journal/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: staged engine missing" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/history.tsv" ] && pass=$((pass + 1)) || {
  echo "FAIL: ledger missing" >&2; fail=$((fail + 1)); }
[ ! -e "$proj/.records/scripts" ] && pass=$((pass + 1)) || {
  echo "FAIL: records-home script dump created" >&2; fail=$((fail + 1)); }
expect "README names staged engine" ".dev/journal/scripts/records.sh" "$proj/.records/README.md"

# Re-run preserves project substrate and refreshes package bytes.
printf '%s\n' 'keep-ledger' > "$proj/.records/history.tsv"
printf '%s\n' 'project readme' > "$proj/.records/README.md"
printf '%s\n' '# drift' >> "$proj/.dev/journal/scripts/records.sh"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "refresh rc" "0" "$rc"
expect_absent "refresh removes drift" "# drift" "$proj/.dev/journal/scripts/records.sh"
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

# Status migration runs through the explicitly rooted deployed engine.
mig="$TMP/migrate"
mkdir -p "$mig/.records/notes"
today=$(date +%Y-%m-%d)
printf '%s\n' '---' 'doctype: notes' 'status: open' "created: $today" "updated: $today" \
  'tags: []' '---' '' '# Old status' > "$mig/.records/notes/$today-old.md"
run_default "$mig" >"$OUT" 2>"$ERR"
expect "migration reports one" "migrated=1" "$OUT"
expect "migration rewrites status" "status: draft" "$mig/.records/notes/$today-old.md"

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
  "$STANDUP" "$proj" --workspace .dev --records-root "$bad" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "bad records root $bad" "1" "$rc"
done

report "standup-test"
