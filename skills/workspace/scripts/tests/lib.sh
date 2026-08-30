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

expect() {
  if grep -qF -- "$2" "$3"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — missing '$2' in $3" >&2
    fail=$((fail + 1))
  fi
}

run_check() {
  local root="$1"
  rc=0
  export rc
  "$CHECK" --root "$root" >"$OUT" 2>"$ERR" || rc=$?
}

finish() {
  echo "workspace-check-test: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
