#!/usr/bin/env bash
# standup-test.sh — standup.sh end to end: tool layer on a bare repo, honor a
# declared records-root, stay additive on a legacy root, and every advertised
# failure mode actually fails (proven by breaking).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-standup-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# --- bare-repo standup, default root -------------------------------------------
proj="$TMP/proj"
mkdir -p "$proj"
git init -q "$proj"

"$SKILL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR"
expect "standup reports" "records: $proj/.records (journal)" "$OUT"
expect "standup self-check green" "records check: OK (0 records)" "$OUT"

[ -x "$proj/.records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: records.sh not executable" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/history.tsv" ] && pass=$((pass + 1)) || { echo "FAIL: missing history.tsv" >&2; fail=$((fail + 1)); }
expect "README stamped with the real date" "Stood up by journal on $(date +%Y-%m-%d)." "$proj/.records/README.md"

# The seeded README must not re-assert the pre-`agent-workspace` layout. Doctrine
# stopped defaulting under the records home when that variable shipped; the README
# kept saying it did, so every project seeded since was told the wrong home.
expect "README sends doctrine to the agent-workspace home" \
  ".dev/doctrine/" "$proj/.records/README.md"
expect_absent "README does not park doctrine under the records home" \
  "project doctrine) default" "$proj/.records/README.md"

# Slim layer: the tool layer and nothing else. Asserted EXHAUSTIVELY rather than
# against a list of store names -- there is no fixed taxonomy left to enumerate,
# and a whitelist also catches anything new that creeps in.
actual="$(cd "$proj/.records" && ls -A | sort | tr '\n' ' ')"
expect_eq "standup creates only the tool layer" "README.md history.tsv scripts " "$actual"

# --- declared records-root, additive on a legacy tree ---------------------------
legacy="$TMP/legacy"
mkdir -p "$legacy/dev/records"
echo "pre-existing" > "$legacy/dev/records/keep.txt"
"$SKILL/scripts/standup.sh" "$legacy" --records-root dev/records >"$OUT" 2>"$ERR"
expect "declared root honored" "records: $legacy/dev/records (journal)" "$OUT"
expect "legacy content survives" "pre-existing" "$legacy/dev/records/keep.txt"
[ -x "$legacy/dev/records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: records.sh missing under declared root" >&2; fail=$((fail + 1)); }
actual="$(cd "$legacy/dev/records" && ls -A | sort | tr '\n' ' ')"
expect_eq "declared-root standup creates only the tool layer" \
  "README.md history.tsv keep.txt scripts " "$actual"

# --- a home that merely exists (notes/ already there, no tool) is additive ------
partial="$TMP/partial"
mkdir -p "$partial/.records/notes"
echo "kept" > "$partial/.records/notes/keep.txt"
"$SKILL/scripts/standup.sh" "$partial" >"$OUT" 2>"$ERR"
expect "partial home still stands up" "records: $partial/.records (journal)" "$OUT"
expect "existing store survives" "kept" "$partial/.records/notes/keep.txt"
[ -x "$partial/.records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: records.sh missing on partial home" >&2; fail=$((fail + 1)); }

# --- proven by breaking ----------------------------------------------------------
rc=0; "$SKILL/scripts/standup.sh" "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "re-standup refused rc" "2" "$rc"
expect "re-standup refusal message" "refusing" "$ERR"

# templates/ alone is NOT already-stood-up
tplonly="$TMP/tplonly"
mkdir -p "$tplonly/.records/templates"
echo "legacy" > "$tplonly/.records/templates/notes.md"
"$SKILL/scripts/standup.sh" "$tplonly" >"$OUT" 2>"$ERR"
expect "templates-only home is not refused" "records: $tplonly/.records (journal)" "$OUT"
[ -x "$tplonly/.records/scripts/records.sh" ] && pass=$((pass + 1)) || { echo "FAIL: templates-only home did not get records.sh" >&2; fail=$((fail + 1)); }

rc=0; "$SKILL/scripts/standup.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad target rc" "2" "$rc"

rc=0; "$SKILL/scripts/standup.sh" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "no-args usage rc" "1" "$rc"

report "standup-test"
