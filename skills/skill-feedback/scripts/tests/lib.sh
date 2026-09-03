#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
PROVIDER="$SKILL/scripts/feedback.sh"
# shellcheck disable=SC2034 # Used by tests that source this library.
IDENTITY="$SKILL/scripts/skill-content-ref.py"
# shellcheck disable=SC2034 # Used by tests that source this library.
HEADER=$'id\tcreated_at\tupdated_at\tskill\tskill_ref\tinvocation\tkind\tsummary\tincident\tconsequence\tsuggestion\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref'
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
ok() { if "$@" >/dev/null 2>&1; then pass; else fail "$*"; fi; }
no() { if "$@" >/dev/null 2>&1; then fail "accepted: $*"; else pass; fi; }
has() { if grep -qF -- "$2" "$1"; then pass; else fail "missing [$2] in $1"; fi; }
same() { if cmp -s "$1" "$2"; then pass; else fail "$1 differs from $2"; fi; }

mode_of() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }
new_home() { mkdir -p "$1"; chmod 700 "$1"; }
store_for() { printf '%s/.agents/skilldata/skill-feedback/feedback.tsv\n' "$1"; }

capture_one() {
  local home="$1" skill="${2:-architect}" kind="${3:-friction}" project_ref="${4:-}"
  local args=(capture --skill "$skill" --skill-ref unknown --invocation architect/spec --kind "$kind"
    --summary "A concrete observation should change the skill."
    --incident "The invocation required a repeated manual workaround."
    --consequence "The workaround added ambiguity and avoidable work."
    --suggestion "Add a deterministic instruction and a regression fixture.")
  [ -z "$project_ref" ] || args+=(--project-ref "$project_ref")
  HOME="$home" "$PROVIDER" "${args[@]}"
}

finish() {
  printf '%s: %s passed, %s failed\n' "$1" "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
