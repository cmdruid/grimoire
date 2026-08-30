#!/usr/bin/env bash
# bug-mint-test.sh — mktemp fixture smoke for bug-mint.sh.
# Nothing touches the library tree except reading the script and template.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
MINT="$SKILL/scripts/bug-mint.sh"
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
TMP="$(mktemp -d "${TMPDIR:-/tmp}/bug-mint-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# --- no records.sh: file-mode mint -------------------------------------------
ROOT="$TMP/bare"
RR="$ROOT/.records"
AT="$ROOT/.spaces/debugger/templates"
mkdir -p "$RR"

OUT="$(/bin/bash "$MINT" mint "$ROOT" "Alpha crash")"
rr_abs="$(cd "$RR" && pwd)"
expect_eq "mint fixed records" "$rr_abs" "$(kv records "$OUT")"
expect_eq "mint mode=file" "file" "$(kv mode "$OUT")"
expect_eq "mint rel" "bugs/$today-alpha-crash.md" "$(kv rel "$OUT")"
path="$(kv path "$OUT")"
expect_eq "mint path exists" "1" "$([ -f "$path" ] && echo 1 || echo 0)"
expect_match "doctype" '^doctype: bugs$' "$(cat "$path")"
expect_match "status draft" '^status: draft$' "$(cat "$path")"
expect_match "owned schema" '^schema: debugger/bug@1$' "$(cat "$path")"
expect_eq "retired keys absent" "0" "$(grep -cE '^(created|updated|created_at|updated_at|revision):' "$path" || true)"
expect_match "filled title" '^# Alpha crash$' "$(cat "$path")"
expect_absent "bundled fallback creates no project template" "$AT/bugs.md"
expect_absent "no flat templates/bugs.md" "$RR/templates/bugs.md"
expect_absent "no history.tsv after mint" "$RR/history.tsv"
expect_absent "no scripts/ after mint" "$RR/scripts"
expect_absent "mint opened no trackers/" "$RR/trackers"

OUT2="$(/bin/bash "$MINT" mint "$ROOT" "Alpha crash")"
expect_eq "collision rel" "bugs/$today-alpha-crash-2.md" "$(kv rel "$OUT2")"

# missing bundled template → refuse
FAKE="$TMP/no-tpl-skill"
mkdir -p "$FAKE/scripts"
cp "$MINT" "$FAKE/scripts/bug-mint.sh"
if /bin/bash "$FAKE/scripts/bug-mint.sh" mint "$ROOT" "Nope" >/dev/null 2>&1; then
  echo "FAIL: missing doctype template — expected non-zero" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# file-mode close must not create history.tsv
/bin/bash "$MINT" stamp "$ROOT" "$path" --status "done" --note "fixed" >/dev/null
expect_match "file-mode close status" '^status: archived$' "$(cat "$path")"
expect_absent "file-mode close no history.tsv" "$RR/history.tsv"
expect_absent "stamp opened no trackers/" "$RR/trackers"

# --- with records.sh ---------------------------------------------------------
if [ -f "$JOURNAL_RS" ]; then
  ROOT2="$TMP/with-rs"
  RR2="$ROOT2/.records"
  AT2="$ROOT2/.spaces/debugger/templates"
  mkdir -p "$RR2"
  cp "$JOURNAL_RS" "$RR2/records.sh"
  chmod +x "$RR2/records.sh"
  : > "$RR2/history.tsv"

  OUT3="$(/bin/bash "$MINT" mint "$ROOT2" "Need the key")"
  expect_eq "records mode" "records" "$(kv mode "$OUT3")"
  rpath="$(kv path "$OUT3")"
  expect_eq "records path exists" "1" "$([ -f "$rpath" ] && echo 1 || echo 0)"
  expect_absent "records mint keeps bundled fallback read-only" "$AT2/bugs.md"
  expect_absent "records no flat bugs.md" "$RR2/templates/bugs.md"
  expect_absent "records mint opened no trackers/" "$RR2/trackers"
  if /bin/sh "$RR2/records.sh" check >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL: records.sh check after new" >&2
    fail=$((fail + 1))
  fi

  STAMP_RS="$(/bin/bash "$MINT" stamp "$ROOT2" "$rpath" --status "done" --note "fixed")"
  expect_eq "stamp records mode" "records" "$(kv mode "$STAMP_RS")"
  expect_match "stamp records status" '^status: archived$' "$(cat "$rpath")"
  expect_eq "ledger one line" "1" "$(grep -c . "$RR2/history.tsv" || true)"
  expect_match "ledger --as done" '	done	' "$(cat "$RR2/history.tsv")"
  expect_absent "records stamp opened no trackers/" "$RR2/trackers"
fi

echo "bug-mint-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
