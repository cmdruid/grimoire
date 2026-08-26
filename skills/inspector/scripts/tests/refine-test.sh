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
has "$REFINE" 'carries re-review intent by' "failed-review default queue missing"
has "$REFINE" 'Re-review: queued after apply' "proposal queue disclosure missing"
has "$REFINE" 'Explicit no agent re-review.' "queued re-review opt-out missing"
has "$REFINE" 'Queued or named re-review:' "queued after-confirm path missing"

classify_package() {
  local row keep=0
  for row in "$@"; do case "$row" in keep|keep-optional-take) keep=1 ;; esac; done
  [ "$keep" -eq 1 ] && echo propose || echo nothing-material
}
[ "$(classify_package resolved push-back deferred)" = nothing-material ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(classify_package resolved keep)" = propose ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(classify_package keep-optional-take)" = propose ] && pass=$((pass + 1)) || fail=$((fail + 1))

after_confirm() {
  local origin="$1" accepted="$2" named="$3" canceled="$4" queued=false
  [ "$origin" = failed-review ] && queued=true
  [ "$named" = true ] && queued=true
  [ "$canceled" = true ] && queued=false
  [ "$accepted" = true ] || { echo wait; return; }
  [ "$queued" = true ] && echo apply-then-review || echo apply-then-offer
}
[ "$(after_confirm failed-review true false false)" = apply-then-review ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(after_confirm standalone true false false)" = apply-then-offer ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(after_confirm standalone true true false)" = apply-then-review ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(after_confirm failed-review true false true)" = apply-then-offer ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ "$(after_confirm failed-review false false false)" = wait ] && pass=$((pass + 1)) || fail=$((fail + 1))

echo "refine-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
