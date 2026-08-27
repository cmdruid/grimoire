#!/usr/bin/env bash
# procedure-contract-test.sh — ordered write-boundary checks for instruction-driven verbs.
set -u
DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd "$DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/architect-procedure.XXXXXX")"
trap 'rm -rf "$T"' EXIT

first_line() { grep -n -m 1 -E "$1" "$2" | cut -d: -f1; }

spike_order_ok() {
  local file="$1" confirmation experiment draft conclude publish
  confirmation="$(first_line 'explicit confirmation' "$file")"
  experiment="$(first_line '^3\. \*\*Experiment after confirmation' "$file")"
  draft="$(first_line 'architect-artifacts\.sh draft-save' "$file")"
  conclude="$(first_line '^4\. \*\*Conclude' "$file")"
  publish="$(first_line 'architect-artifacts\.sh spike-publish' "$file")"
  [ -n "$confirmation" ] && [ -n "$experiment" ] && [ -n "$draft" ] \
    && [ -n "$conclude" ] && [ -n "$publish" ] \
    && [ "$confirmation" -lt "$experiment" ] && [ "$experiment" -le "$draft" ] \
    && [ "$draft" -lt "$conclude" ] && [ "$conclude" -le "$publish" ]
}

brainstorm_order_ok() {
  local file="$1" ordinary no_write save writer
  ordinary="$(first_line 'For an ordinary brainstorm' "$file")"
  no_write="$(first_line 'do not write' "$file")"
  # shellcheck disable=SC2016 # Backticks are literal Markdown in the searched text.
  save="$(first_line 'For `save` or a valid resumed path' "$file")"
  writer="$(first_line 'architect-artifacts\.sh draft-save' "$file")"
  [ -n "$ordinary" ] && [ -n "$no_write" ] && [ -n "$save" ] && [ -n "$writer" ] \
    && [ "$ordinary" -le "$no_write" ] && [ "$no_write" -le "$save" ] \
    && [ "$save" -le "$writer" ]
}

if spike_order_ok "$SKILL/verbs/spike.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: spike writer calls are not ordered after confirmation" >&2
  fail=$((fail + 1))
fi

awk 'NR == 7 { print "`scripts/architect-artifacts.sh draft-save`" } { print }' \
  "$SKILL/verbs/spike.md" >"$T/bad-spike.md"
before="$(grep -Ec 'architect-artifacts\.sh draft-save' "$SKILL/verbs/spike.md")"
after="$(grep -Ec 'architect-artifacts\.sh draft-save' "$T/bad-spike.md")"
expect_eq "spike mutation applied once" "$((before + 1))" "$after"
if spike_order_ok "$T/bad-spike.md"; then
  echo "FAIL: spike ordering guard missed a pre-confirmation writer" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

if brainstorm_order_ok "$SKILL/verbs/brainstorm.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: ordinary brainstorm is not separated from the save writer" >&2
  fail=$((fail + 1))
fi

sed 's/do not write/write immediately/' "$SKILL/verbs/brainstorm.md" >"$T/bad-brainstorm.md"
before="$(grep -Fc 'do not write' "$SKILL/verbs/brainstorm.md")"
after="$(grep -Fc 'do not write' "$T/bad-brainstorm.md")"
expect_eq "brainstorm mutation removed the guard" "$((before - 1))" "$after"
if brainstorm_order_ok "$T/bad-brainstorm.md"; then
  echo "FAIL: brainstorm ordering guard missed the removed no-write boundary" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

finish
