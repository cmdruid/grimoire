#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVISE="$SKILL/verbs/revise.md"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

has "$REVISE" 'Review-origin entry.' "automatic entry contract missing"
has "$REVISE" 'skip only the standalone resolver' "automatic resolver skip is too broad"
has "$REVISE" 'automatically or' "all review-origin paths do not queue re-review"
has "$REVISE" 'Classify the whole batch before editing any.' "batch-first classification missing"
has "$REVISE" 'One unresolved' "ask hold missing"
has "$REVISE" 'There is no skip-proposal token' "pre-confirm no-write guard missing"
has "$REVISE" 'offer to' "empty recommended package publish offer missing"
has "$REVISE" 'run one full review' "empty must-fix package review loop missing"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$REVISE" 'or `push-back`' "thrash brake push-back disposition missing"
has "$REVISE" 'Accept/publish as-is.' "proposal publish-as-is parser missing"
has "$REVISE" 'status: draft' "draft-on-apply missing"
has "$REVISE" 'Do not create or append `## Review' "review-history guard missing"
has "$REVISE" 'implementation review never enters revise' "implementation revise refusal missing"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$REVISE" 'effective continuation is `unavailable`' "unavailable document revise refusal missing"
has "$REVISE" 'Re-review: queued after apply' "proposal queue disclosure missing"
has "$REVISE" 'inherited review boundary' "review-origin scope custody missing"
has "$REVISE" 'cannot enlarge the artifact' "revision may expand accepted scope"
has "$REVISE" 'introduce another subsystem' "subsystem expansion guard missing"
has "$REVISE" 'direct causal evidence' "necessary expansion evidence missing"
has "$REVISE" 'inherits the same boundary' "queued re-review may reopen scope"

classify_package() {
  local row keep=0
  for row in "$@"; do case "$row" in keep|keep-optional-take) keep=1 ;; esac; done
  [ "$keep" -eq 1 ] && echo propose || echo nothing-material
}
eq "disposed-only batch is empty" nothing-material "$(classify_package resolved push-back deferred)"
eq "must-fix batch proposes" propose "$(classify_package resolved keep)"
eq "recommended optional batch proposes" propose "$(classify_package keep-optional-take)"

before_confirm() { case "$1" in question|proposal) echo no-write ;; confirmed) echo apply ;; esac; }
eq "questions never write" no-write "$(before_confirm question)"
eq "proposal never writes" no-write "$(before_confirm proposal)"
eq "confirmation authorizes apply" apply "$(before_confirm confirmed)"
write_guard() { [ "$(before_confirm "$1")" = apply ]; }
rejects write_guard proposal
preconfirm_clean() { ! grep -qF 'A proposal may amend before confirmation.' "$1"; }
cp "$REVISE" "$ROOT/revise.original"
cp "$ROOT/revise.original" "$ROOT/revise.broken"
printf '%s\n' 'A proposal may amend before confirmation.' >> "$ROOT/revise.broken"
eq "write red-proof plants one bad authorization" 1 \
  "$(grep -cF 'A proposal may amend before confirmation.' "$ROOT/revise.broken")"
rejects preconfirm_clean "$ROOT/revise.broken"
cmp -s "$REVISE" "$ROOT/revise.original" && pass=$((pass + 1)) || fail=$((fail + 1))

revise_allowed() { [ "$1" != implementation ] && [ "$2" != unavailable ]; }
revise_allowed spec automatic-proposal && pass=$((pass + 1)) || fail=$((fail + 1))
rejects revise_allowed brief unavailable
rejects revise_allowed implementation automatic-proposal

after_confirm() {
  local origin="$1" accepted="$2" named="$3" canceled="$4" queued=false
  case "$origin" in review-*) queued=true ;; esac
  [ "$named" = true ] && queued=true
  [ "$canceled" = true ] && queued=false
  [ "$accepted" = true ] || { echo wait; return; }
  [ "$queued" = true ] && echo apply-then-review || echo apply-then-offer
}
eq "automatic must-fix queues review" apply-then-review "$(after_confirm review-needs-rework true false false)"
eq "automatic recommended queues review" apply-then-review "$(after_confirm review-approve-with-changes true false false)"
eq "offered review-origin queues review" apply-then-review "$(after_confirm review-offered true false false)"
eq "standalone applies then offers" apply-then-offer "$(after_confirm standalone true false false)"
eq "standalone named review queues" apply-then-review "$(after_confirm standalone true true false)"
eq "review-origin opt-out clears queue" apply-then-offer "$(after_confirm review-needs-rework true false true)"
eq "unaccepted package waits" wait "$(after_confirm review-needs-rework false false false)"

empty_close() {
  local origin="$1" row has_row=false all_disposed=true
  shift
  for row in "$@"; do
    [ "$row" = parked ] && { echo blocked-upstream; return; }
    has_row=true
    case "$row" in resolved|push-back) ;; *) all_disposed=false ;; esac
  done
  case "$origin" in
    review-approve-with-changes) echo publish-as-is-offer ;;
    review-needs-rework)
      if [ "$has_row" = true ] && [ "$all_disposed" = true ]; then
        echo full-review-once
      else
        echo nothing-material
      fi
      ;;
    *) echo nothing-material ;;
  esac
}
eq "empty recommendation offers unchanged publish" publish-as-is-offer \
  "$(empty_close review-approve-with-changes resolved deferred)"
eq "resolved and pushed-back must-fix reruns review once" full-review-once \
  "$(empty_close review-needs-rework resolved push-back)"
eq "deferred must-fix does not rerun review" nothing-material \
  "$(empty_close review-needs-rework resolved deferred)"
eq "unsupported must-fix does not rerun review" nothing-material \
  "$(empty_close review-needs-rework unsupported)"
eq "empty standalone stops" nothing-material "$(empty_close standalone resolved)"
eq "park-only package stays blocked" blocked-upstream \
  "$(empty_close review-approve-with-changes parked)"

thrash_disposition() { case "$1:$2" in resolved:return|rejected:return|push-back:return) echo ask ;; *) echo classify ;; esac; }
eq "resolved recurrence asks" ask "$(thrash_disposition resolved return)"
eq "push-back recurrence asks" ask "$(thrash_disposition push-back return)"
recurrence_contract() { [ "$(thrash_disposition "$1" "$2")" = ask ]; }
rejects recurrence_contract new return
printf '%s\n' 'push-back:return' > "$ROOT/recurrence.original"
sed 's/push-back/new/' "$ROOT/recurrence.original" > "$ROOT/recurrence.broken"
recurrence_file_contract() {
  local prior event
  prior="$(cut -d: -f1 "$1")"; event="$(cut -d: -f2 "$1")"
  recurrence_contract "$prior" "$event"
}
rejects recurrence_file_contract "$ROOT/recurrence.broken"
eq "recurrence source fixture remains restored" 'push-back:return' "$(cat "$ROOT/recurrence.original")"

publish_as_is() { [ "$1" = review-approve-with-changes ] && [ "$2" = "publish as-is" ]; }
publish_as_is review-approve-with-changes "publish as-is" && pass=$((pass + 1)) || fail=$((fail + 1))
rejects publish_as_is review-needs-rework "publish as-is"

after_apply_gate() { echo draft:none; }
eq "revision apply resets gate" draft:none "$(after_apply_gate)"

echo "revise-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
