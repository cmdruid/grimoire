#!/usr/bin/env bash
# Shared assertions for Foreman's disposable-fixture tests.
pass=0; fail=0
ok() { if "$@"; then pass=$((pass + 1)); else echo "FAIL: $*" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL: $1 — want <$2>, got <$3>" >&2; fail=$((fail + 1)); fi; }
has() { if grep -qF -- "$2" "$3"; then pass=$((pass + 1)); else echo "FAIL: $1 — missing <$2>" >&2; fail=$((fail + 1)); fi; }
lacks() { if ! grep -qF -- "$2" "$3"; then pass=$((pass + 1)); else echo "FAIL: $1 — found <$2>" >&2; fail=$((fail + 1)); fi; }
fact() { sed -n "s/^$1=//p" "$2" | tail -n 1; }
report() { echo "$1: $pass passed, $fail failed"; [ "$fail" -eq 0 ]; }
