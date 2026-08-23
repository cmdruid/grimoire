#!/usr/bin/env bash
# ground-check-test.sh — characterization of scripts/ground-check.sh.
# Throwaway fixtures only; nothing touches the library tree except reading the script.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
GC="$SKILL/scripts/ground-check.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/contractor-gc-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/proj"
mkdir -p "$ROOT/src" "$ROOT/docs"
printf 'line1\nline2\nline3\n' > "$ROOT/src/foo.rs"

# --- usage ---
set +e
out="$("$GC" 2>&1)"
rc=$?
set -e
expect_eq "usage no-args exit" "2" "$rc"
expect_match "usage no-args text" 'usage: ground-check.sh' "$out"

set +e
out="$("$GC" "$ROOT" 2>&1)"
rc=$?
set -e
expect_eq "usage one-arg exit" "2" "$rc"

# --- resolving path ---
printf 'see `src/foo.rs`\n' > "$ROOT/docs/ok.md"
out="$("$GC" "$ROOT" "$ROOT/docs/ok.md")"
expect_eq "ok unresolved_count" "0" "$(kv unresolved_count "$out")"
expect_eq "ok checked" "1" "$(kv checked "$out")"
expect_absent_match "ok no missing line" 'missing' "$out"

# --- missing path whose first segment is a top-level dir ---
printf 'see `src/missing.rs`\n' > "$ROOT/docs/miss.md"
out="$("$GC" "$ROOT" "$ROOT/docs/miss.md")"
expect_eq "miss unresolved_count" "1" "$(kv unresolved_count "$out")"
expect_eq "miss checked" "1" "$(kv checked "$out")"
expect_match "miss reports missing" 'src/missing.rs  \(missing\)' "$out"

# --- first segment is not a top-level dir: skipped, not a false unresolved ---
printf 'see `notadir/x.rs`\n' > "$ROOT/docs/skip.md"
out="$("$GC" "$ROOT" "$ROOT/docs/skip.md")"
expect_eq "skip checked" "0" "$(kv checked "$out")"
expect_eq "skip unresolved_count" "0" "$(kv unresolved_count "$out")"
expect_absent_match "skip no missing" 'notadir' "$out"

# --- file:line in range ---
printf 'see `src/foo.rs:2`\n' > "$ROOT/docs/line-ok.md"
out="$("$GC" "$ROOT" "$ROOT/docs/line-ok.md")"
expect_eq "line-ok unresolved_count" "0" "$(kv unresolved_count "$out")"
expect_eq "line-ok checked" "1" "$(kv checked "$out")"

# --- file:line past EOF ---
printf 'see `src/foo.rs:999`\n' > "$ROOT/docs/line-bad.md"
out="$("$GC" "$ROOT" "$ROOT/docs/line-bad.md")"
expect_eq "line-bad unresolved_count" "1" "$(kv unresolved_count "$out")"
expect_match "line-bad reports line count" 'src/foo.rs:999  \(file has 3 lines\)' "$out"

# --- hidden top-level dirs are not tlds ---
mkdir -p "$ROOT/.hidden"
printf 'see `.hidden/x.rs`\n' > "$ROOT/docs/dot.md"
out="$("$GC" "$ROOT" "$ROOT/docs/dot.md")"
expect_eq "dotdir checked" "0" "$(kv checked "$out")"

# --- bash -n ---
if bash -n "$GC"; then
  pass=$((pass + 1))
else
  echo "FAIL: bash -n ground-check.sh" >&2
  fail=$((fail + 1))
fi

finish
