#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REFINE="$SKILL/verbs/refine.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }

has "$REFINE" 'Classify the whole batch before editing any.' "batch-first classification missing"
has "$REFINE" 'One unresolved' "ask hold missing"
has "$REFINE" 'that the owner recommends' "empty package gate missing"
has "$REFINE" 'Do not show' "empty package ceremony guard missing"
has "$REFINE" 'status: draft' "draft-on-apply missing"
has "$REFINE" 'Do not create or append `## Review' "review-history guard missing"
has "$REFINE" 'Full procedure (two-axis, conversation verdict, stop).' "full named re-review missing"
has "$REFINE" 'implementation review never enters refine' "implementation refine refusal missing"

classify_package() {
  local row keep=0
  for row in "$@"; do case "$row" in keep|keep-optional-take) keep=1 ;; esac; done
  [ "$keep" -eq 1 ] && echo propose || echo nothing-material
}
[ "$(classify_package resolved push-back deferred)" = nothing-material ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(classify_package resolved keep)" = propose ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(classify_package keep-optional-take)" = propose ] && pass=$((pass + 1)) || fail=$((fail + 1))

echo "refine-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
