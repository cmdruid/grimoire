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
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# --- slice 1: no records.sh ---
ROOT="$TMP/bare"
RR="$ROOT/.records"
AT="$ROOT/.spaces/notepad/templates"
mkdir -p "$RR"

OUT="$(/bin/bash "$MINT" mint "$ROOT" "Alpha fact")"
rr_abs="$(cd "$RR" && pwd)"
expect_eq "mint fixed records" "$rr_abs" "$(kv records "$OUT")"
expect_eq "mint mode=file" "file" "$(kv mode "$OUT")"
expect_eq "mint rel" "notes/$today-alpha-fact.md" "$(kv rel "$OUT")"
path="$(kv path "$OUT")"
expect_eq "mint path exists" "1" "$([ -f "$path" ] && echo 1 || echo 0)"
expect_match "doctype" '^doctype: notes$' "$(cat "$path")"
expect_match "status draft" '^status: draft$' "$(cat "$path")"
expect_match "owned schema" '^schema: notepad/note@1$' "$(cat "$path")"
expect_eq "retired keys absent" "0" "$(grep -cE '^(created|updated|created_at|updated_at|revision):' "$path" || true)"
expect_match "filled title" '^# Alpha fact$' "$(cat "$path")"
expect_absent "no history.tsv after mint" "$RR/history.tsv"
expect_absent "no scripts/ after mint" "$RR/scripts"
expect_absent "bundled fallback creates no project template" "$AT/notes.md"
expect_absent "no flat templates/notes.md" "$RR/templates/notes.md"

OUT2="$(/bin/bash "$MINT" mint "$ROOT" "Alpha fact")"
expect_eq "collision rel" "notes/$today-alpha-fact-2.md" "$(kv rel "$OUT2")"
expect_eq "collision mode" "file" "$(kv mode "$OUT2")"

if /bin/bash "$MINT" mint "$ROOT" "" >/dev/null 2>&1; then
  echo "FAIL: empty title — expected non-zero" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if /bin/bash "$MINT" mint "$ROOT" "???" >/dev/null 2>&1; then
  echo "FAIL: punctuation-only title — expected non-zero" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
nfiles="$(find "$RR/notes" -type f | wc -l | tr -d ' ')"
expect_eq "empty/punct wrote nothing extra" "2" "$nfiles"

/bin/bash "$MINT" stamp "$ROOT" "$path" --status superseded >/dev/null
expect_match "stamp status" '^status: archived$' "$(cat "$path")"
expect_match "stamp preserves schema" '^schema: notepad/note@1$' "$(cat "$path")"
expect_eq "stamp adds no retired key" "0" "$(grep -cE '^(created|updated|created_at|updated_at|revision):' "$path" || true)"
expect_absent "stamp created no history.tsv" "$RR/history.tsv"

# --- slice 2: opportunistic records.sh ---
if [ -f "$JOURNAL_RS" ]; then
  ROOT2="$TMP/with-rs"
  RR2="$ROOT2/.records"
  AT2="$ROOT2/.spaces/notepad/templates"
  mkdir -p "$RR2"
  cp "$JOURNAL_RS" "$RR2/records.sh"
  chmod +x "$RR2/records.sh"
  : > "$RR2/history.tsv"

  OUT3="$(/bin/bash "$MINT" mint "$ROOT2" "Via records")"
  expect_eq "records mode" "records" "$(kv mode "$OUT3")"
  rpath="$(kv path "$OUT3")"
  expect_eq "records path exists" "1" "$([ -f "$rpath" ] && echo 1 || echo 0)"
  expect_absent "records mint keeps bundled fallback read-only" "$AT2/notes.md"
  expect_absent "records no flat notes.md" "$RR2/templates/notes.md"
  if /bin/sh "$RR2/records.sh" check >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: records.sh check after new" >&2
    fail=$((fail + 1))
  fi

  ROOT3="$TMP/rs-no-tpl"
  RR3="$ROOT3/.records"
  AT3="$ROOT3/.spaces/notepad/templates"
  mkdir -p "$RR3"
  cp "$JOURNAL_RS" "$RR3/records.sh"
  chmod +x "$RR3/records.sh"
  : > "$RR3/history.tsv"
  OUT4="$(/bin/bash "$MINT" mint "$ROOT3" "Nested dest")"
  expect_eq "nested-dest mode" "records" "$(kv mode "$OUT4")"
  expect_absent "nested mint does not implicitly deploy" "$AT3/notes.md"
  expect_absent "no flat implicit deployment" "$RR3/templates/notes.md"

  STAMP_RS="$(/bin/bash "$MINT" stamp "$ROOT2" "$rpath" --status superseded)"
  expect_eq "stamp records mode" "records" "$(kv mode "$STAMP_RS")"
  expect_match "stamp records status" '^status: archived$' "$(cat "$rpath")"
  expect_eq "ledger exists" "1" "$([ -f "$RR2/history.tsv" ] && echo 1 || echo 0)"
  expect_eq "ledger one line" "1" "$(grep -c . "$RR2/history.tsv" || true)"
  expect_match "ledger --as superseded" '	superseded	' "$(cat "$RR2/history.tsv")"
  if /bin/sh "$RR2/records.sh" check >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: records.sh check after done" >&2
    fail=$((fail + 1))
  fi
fi

# file-mode supersede still no ledger (already asserted on $RR)
expect_absent "file-mode supersede no history" "$RR/history.tsv"

# Ordinary minting hard-cuts legacy template locations; it does not adopt.
ROOTLEG="$TMP/legacy-template"; RRLEG="$ROOTLEG/.records"
mkdir -p "$RRLEG/templates/notepad"
printf '# Customized legacy note\n' > "$RRLEG/templates/notepad/notes.md"
rc=0
/bin/bash "$MINT" mint "$ROOTLEG" "Must migrate" >/dev/null 2>&1 || rc=$?
expect_eq "legacy template blocks ordinary mint" "2" "$rc"
expect_absent "legacy template was not adopted" "$ROOTLEG/.spaces/notepad/templates/notes.md"

# Project templates cannot take over the package-owned schema.
ROOTSC="$TMP/schema-template"; RRSC="$ROOTSC/.records"; ATSC="$ROOTSC/.spaces/notepad/templates"
mkdir -p "$RRSC" "$ATSC"
printf '%s\n' '---' 'schema: hostile/note@1' '---' '# Body' > "$ATSC/notes.md"
rc=0
/bin/bash "$MINT" mint "$ROOTSC" "Schema override" >/dev/null 2>&1 || rc=$?
expect_eq "project template schema blocks mint" "2" "$rc"

echo "note-mint-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
