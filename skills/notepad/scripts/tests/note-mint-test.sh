#!/usr/bin/env bash
# note-mint-test.sh — mktemp fixture smoke for note-mint.sh.
# Nothing touches the library tree except reading the script and template.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
MINT="$SKILL/scripts/note-mint.sh"
JOURNAL_RS="$(cd "$SKILL/../journal/scripts" && pwd)/records.sh"

pass=0
fail=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_match() {
  if printf '%s' "$3" | grep -qE "$2"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected to match: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent() {
  if [ -e "$2" ]; then
    echo "FAIL: $1 — path exists: $2" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

kv() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1; }

today="$(date +%Y-%m-%d)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/note-mint-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- slice 1: no records.sh ---
RR="$TMP/bare"
mkdir -p "$RR"

OUT="$(/bin/bash "$MINT" mint "$RR" "Alpha fact")"
expect_eq "mint mode=file" "file" "$(kv mode "$OUT")"
expect_eq "mint rel" "notes/$today-alpha-fact.md" "$(kv rel "$OUT")"
path="$(kv path "$OUT")"
expect_eq "mint path exists" "1" "$([ -f "$path" ] && echo 1 || echo 0)"
expect_match "doctype" '^doctype: notes$' "$(cat "$path")"
expect_match "status open" '^status: open$' "$(cat "$path")"
expect_match "created today" "^created: $today$" "$(cat "$path")"
expect_match "updated today" "^updated: $today$" "$(cat "$path")"
expect_match "filled title" '^# Alpha fact$' "$(cat "$path")"
expect_absent "no history.tsv after mint" "$RR/history.tsv"
expect_absent "no scripts/ after mint" "$RR/scripts"
expect_absent "no templates/ after mint" "$RR/templates"

OUT2="$(/bin/bash "$MINT" mint "$RR" "Alpha fact")"
expect_eq "collision rel" "notes/$today-alpha-fact-2.md" "$(kv rel "$OUT2")"
expect_eq "collision mode" "file" "$(kv mode "$OUT2")"

if /bin/bash "$MINT" mint "$RR" "" >/dev/null 2>&1; then
  echo "FAIL: empty title — expected non-zero" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if /bin/bash "$MINT" mint "$RR" "???" >/dev/null 2>&1; then
  echo "FAIL: punctuation-only title — expected non-zero" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
nfiles="$(find "$RR/notes" -type f | wc -l | tr -d ' ')"
expect_eq "empty/punct wrote nothing extra" "2" "$nfiles"

created_before="$(sed -n 's/^created: //p' "$path")"
# force a distinguishable updated: if we could; stamp still writes today
/bin/bash "$MINT" stamp "$RR" "$path" --status superseded >/dev/null
expect_match "stamp status" '^status: superseded$' "$(cat "$path")"
expect_eq "stamp left created" "$created_before" "$(sed -n 's/^created: //p' "$path")"
expect_match "stamp updated" "^updated: $today$" "$(cat "$path")"
expect_absent "stamp created no history.tsv" "$RR/history.tsv"

# --- slice 2: opportunistic records.sh ---
if [ -f "$JOURNAL_RS" ]; then
  RR2="$TMP/with-rs"
  mkdir -p "$RR2/scripts" "$RR2/templates"
  cp "$JOURNAL_RS" "$RR2/scripts/records.sh"
  chmod +x "$RR2/scripts/records.sh"
  cp "$SKILL/templates/notes.md" "$RR2/templates/notes.md"

  OUT3="$(/bin/bash "$MINT" mint "$RR2" "Via records")"
  expect_eq "records mode" "records" "$(kv mode "$OUT3")"
  rpath="$(kv path "$OUT3")"
  expect_eq "records path exists" "1" "$([ -f "$rpath" ] && echo 1 || echo 0)"
  if /bin/sh "$RR2/scripts/records.sh" check >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: records.sh check after new" >&2
    fail=$((fail + 1))
  fi

  RR3="$TMP/rs-no-tpl"
  mkdir -p "$RR3/scripts"
  cp "$JOURNAL_RS" "$RR3/scripts/records.sh"
  chmod +x "$RR3/scripts/records.sh"
  OUT4="$(/bin/bash "$MINT" mint "$RR3" "Lazy deploy")"
  expect_eq "lazy-deploy mode" "records" "$(kv mode "$OUT4")"
  expect_eq "lazy-deploy copied template" "1" "$([ -f "$RR3/templates/notes.md" ] && echo 1 || echo 0)"

  STAMP_RS="$(/bin/bash "$MINT" stamp "$RR2" "$rpath" --status superseded)"
  expect_eq "stamp records mode" "records" "$(kv mode "$STAMP_RS")"
  expect_match "stamp records status" '^status: superseded$' "$(cat "$rpath")"
  expect_eq "ledger exists" "1" "$([ -f "$RR2/history.tsv" ] && echo 1 || echo 0)"
  expect_eq "ledger one line" "1" "$(grep -c . "$RR2/history.tsv" || true)"
  if /bin/sh "$RR2/scripts/records.sh" check >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: records.sh check after done" >&2
    fail=$((fail + 1))
  fi
fi

# file-mode supersede still no ledger (already asserted on $RR)
expect_absent "file-mode supersede no history" "$RR/history.tsv"

echo "note-mint-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
