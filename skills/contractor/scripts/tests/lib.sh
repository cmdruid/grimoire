# shellcheck shell=bash
# lib.sh — shared assertions for the contractor test harness. Source, don't execute.
# Patient-zero: every test builds fixtures in a mktemp dir.

pass=0
fail=0

expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_match() { # expect_match <label> <regex> <haystack>
  if printf '%s' "$3" | grep -qE "$2"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected to match: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent_match() { # expect_absent_match <label> <regex> <haystack>
  if printf '%s' "$3" | grep -qE "$2"; then
    echo "FAIL: $1 — expected NOT to match: $2  got: $3" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

kv() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1; }

finish() {
  echo "passed=$pass failed=$fail"
  if [ "$fail" -ne 0 ]; then
    echo "contractor tests: FAILURES" >&2
    exit 1
  fi
}
