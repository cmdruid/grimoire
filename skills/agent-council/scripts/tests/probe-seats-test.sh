#!/usr/bin/env bash
# probe-seats-test.sh — PATH-isolated smoke for probe-seats.sh.
# Fixtures live in mktemp; nothing touches the real PATH or the library tree
# except reading the script under test.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
PROBE="$SKILL/scripts/probe-seats.sh"

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

expect_absent() {
  if printf '%s' "$3" | grep -qE "$2"; then
    echo "FAIL: $1 — expected NOT to match: $2" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/probe-seats-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
# Two present, one missing — the degrade case the council actually hits.
: >"$BIN/claude"
: >"$BIN/grok"
chmod +x "$BIN/claude" "$BIN/grok"

OUT="$(PATH="$BIN" /bin/bash "$PROBE")"
expect_eq "three lines" "3" "$(printf '%s\n' "$OUT" | grep -c .)"
expect_eq "claude key" "claude=$BIN/claude" "$(printf '%s\n' "$OUT" | sed -n '1p')"
expect_eq "grok key" "grok=$BIN/grok" "$(printf '%s\n' "$OUT" | sed -n '2p')"
expect_eq "codex empty" "codex=" "$(printf '%s\n' "$OUT" | sed -n '3p')"
expect_absent "no verdict words" '(convene|recommend|should|missing|error|fail)' "$OUT"

EMPTY="$(PATH="/nonexistent-agent-council-$$" /bin/bash "$PROBE")"
expect_eq "empty claude" "claude=" "$(printf '%s\n' "$EMPTY" | sed -n '1p')"
expect_eq "empty grok" "grok=" "$(printf '%s\n' "$EMPTY" | sed -n '2p')"
expect_eq "empty codex" "codex=" "$(printf '%s\n' "$EMPTY" | sed -n '3p')"

echo "probe-seats-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
