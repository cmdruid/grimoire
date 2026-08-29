# shellcheck shell=bash
# lib.sh — shared assertions. Source, don't execute.
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

expect_match() {
  if printf '%s' "$3" | grep -qE "$2"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected to match: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent_match() {
  if printf '%s' "$3" | grep -qE "$2"; then
    echo "FAIL: $1 — expected NOT to match: $2  got: $3" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

kv() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1; }

files_of() {
  printf '%s\n' "$1" | sed -n 's/^file=//p'
}

finish() {
  echo "passed=$pass failed=$fail"
  if [ "$fail" -ne 0 ]; then
    echo "code-humanizer tests: FAILURES" >&2
    exit 1
  fi
}

init_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config commit.gpgsign false
}
