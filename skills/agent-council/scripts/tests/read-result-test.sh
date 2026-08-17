#!/usr/bin/env bash
# read-result-test.sh — golden RESULT.md fixtures for read-result.sh.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
READ="$SKILL/scripts/read-result.sh"
FIXTURES="$DIR/fixtures"

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

kv() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -n 1
}

claims() {
  printf '%s\n' "$1" | sed -n 's/^claim=//p'
}

OUT="$(/bin/bash "$READ" "$FIXTURES/result-ranked.md")"
expect_eq "ranked n" "2" "$(kv "$OUT" n)"
expect_eq "first claim" "Description does not fire on genesis." "$(claims "$OUT" | sed -n '1p')"
expect_eq "second claim" "Deploy dest walk skips existing ancestors." "$(claims "$OUT" | sed -n '2p')"
expect_absent "rescued claim stays out of ranked" 'was rescinded' "$OUT"

OUT="$(/bin/bash "$READ" "$FIXTURES/result-rescinded-only.md")"
expect_eq "rescinded-only n" "0" "$(kv "$OUT" n)"
expect_absent "rescinded-only has no claim" '^claim=' "$OUT"

OUT="$(/bin/bash "$READ" "$FIXTURES/result-empty-ranked.md")"
expect_eq "empty ranked n" "0" "$(kv "$OUT" n)"

echo "read-result-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
