#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
PROVIDER="$SKILL/scripts/feedback.sh"
# shellcheck disable=SC2034 # Used by tests that source this library.
IDENTITY="$SKILL/scripts/skill-content-ref.py"
# shellcheck disable=SC2034 # Used by tests that source this library.
HEADER=$'id\tcreated_at\tupdated_at\torigin\tsubject_type\tsubject\tsubject_ref\tinvocation\tkind\tsummary\tstatement\tincident\tconsequence\tsuggestion\tredacted\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref'
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
store_for() { printf '%s/.agents/skilldata/agent-feedback/feedback.tsv\n' "$1"; }

capture_human() {
  local home="$1" subject="${2:-architect}" kind="${3:-request}" project_ref="${4:-}"
  local args=(capture --origin human --subject-type skill --subject "$subject" --subject-ref unknown
    --invocation '/agent-feedback capture' --kind "$kind"
    --summary 'Please clarify the ambiguous setup step.'
    --statement 'Please clarify the ambiguous setup step.'
    --incident '' --consequence '' --suggestion '' --redacted no)
  [ -z "$project_ref" ] || args+=(--project-ref "$project_ref")
  HOME="$home" "$PROVIDER" "${args[@]}"
}

capture_agent() {
  local home="$1" subject="${2:-architect}" kind="${3:-friction}" project_ref="${4:-}"
  local args=(capture --origin agent --subject-type skill --subject "$subject" --subject-ref unknown
    --invocation architect/spec --kind "$kind"
    --summary 'A concrete observation should change the skill.'
    --statement 'The invocation required a repeated manual workaround.'
    --incident 'The invocation required a repeated manual workaround.'
    --consequence 'The workaround added ambiguity and avoidable work.'
    --suggestion 'Add a deterministic instruction and a regression fixture.' --redacted no)
  [ -z "$project_ref" ] || args+=(--project-ref "$project_ref")
  HOME="$home" "$PROVIDER" "${args[@]}"
}

capture_one() { capture_agent "$@"; }

finish() {
  printf '%s: %s passed, %s failed\n' "$1" "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
