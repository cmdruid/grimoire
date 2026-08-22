# shellcheck shell=bash
# lib.sh — shared assertions for the shopbook test harness. Source, don't execute.
# Patient-zero holds: every test builds its fixtures in a mktemp dir — nothing runs
# against the library's own tree.

pass=0
fail=0

expect() { # expect <label> <needle> <haystack-file>
  if grep -qF -- "$2" "$3"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected to find: $2" >&2
    echo "      in: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent() { # expect_absent <label> <needle> <haystack-file>
  if grep -qF -- "$2" "$3"; then
    echo "FAIL: $1 — expected NOT to find: $2" >&2
    echo "      in: $3" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

fact() { sed -n -E "s/^$1=//p" "$2" | head -n 1; }

hash_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

functional_body() {
  awk '
    /^#!/ { print; next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { print }
  ' "$1"
}

report() { # report <suite-name>; returns 1 on any failure
  echo "$1: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
