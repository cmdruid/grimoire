#!/usr/bin/env bash

pass=0
fail=0

ok() { pass=$((pass + 1)); }
not_ok() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }

require_line() {
  local file="$1" expected="$2"
  if grep -Fqx -- "$expected" "$file"; then ok; else not_ok "missing: $expected"; fi
}

reject_text() {
  local file="$1" text="$2"
  if grep -Fq -- "$text" "$file"; then not_ok "unexpected: $text"; else ok; fi
}

finish() {
  echo "${TEST_NAME:-test}: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
