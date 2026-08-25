# shellcheck shell=bash
pass=0
fail=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected '$2', got '$3'" >&2
    fail=$((fail + 1))
  fi
}

expect_file_contains() {
  if grep -qF -- "$2" "$3"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — missing '$2' in $3" >&2
    fail=$((fail + 1))
  fi
}

report() {
  echo "$1: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
