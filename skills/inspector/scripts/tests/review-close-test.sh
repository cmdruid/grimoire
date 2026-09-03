#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown code spans are literal throughout this fixture.
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
KINDS="$SKILL/kinds"
ROUTER="$SKILL/SKILL.md"
SPINE="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/docs/design/2026-08-21-architect-contractor-inspector.md"
README="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/README.md"
PACK="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/PACK.md"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

has "$REVIEW" 'Resolve review continuation.' "continuation resolver missing"
has "$REVIEW" 'Automatic entry.' "automatic continuation entry missing"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$REVIEW" 'No body, `status`, or `stage` changes before proposal confirmation.' "automatic no-write guard missing"
has "$REVIEW" 'offer accept/publish as-is or explicit revise' "recommended offered choice missing"
has "$REVIEW" 'Implementation textual action close' "implementation action close missing"
has "$REVIEW" 'The verdict itself is never confirmation' "implementation confirmation guard missing"
has "$REVIEW" 'fresh action close' "implementation re-review loop missing"
has "$REVIEW" 'Fix scope — choose one:' "textual fix scope missing"
has "$REVIEW" 'Reply with a combination such as `1-A-R`, `2-I-R`, or `4`.' "text reply contract missing"
has "$REVIEW" 'one unambiguous writable destination' "implementation destination resolver missing"
has "$REVIEW" 'label `I` as the only route' "inline route disclosure missing"
has "$REVIEW" 'modifiers are inert for a non-mutating scope' "inert modifier rule missing"
has "$REVIEW" 'writer-started partial or blocked work' "partial-package stop missing"
has "$REVIEW" 'has not passed Inspector review' "unreviewed-result disclosure missing"
has "$REVIEW" 'If you accept, this session will publish' "passing publish offer missing"
has "$REVIEW" 're-review queued by default' "offered revise does not carry re-review"
has "$SPINE" 'confirmed inline or isolated remediation' "responsibility spine action close missing"
has "$README" 'actionable post-verdict fix and re-review close' "README action close missing"
has "$PACK" 'confirmed implementation fixes and full re-review' "pack action close missing"

live_surface_clean() {
  ! grep -qFi 'implementation review remains verdict-only' "$1" \
    && ! grep -qFi 'implementation review → verdict only' "$1" \
    && ! grep -qFi 'implementation, any verdict | verdict only' "$1" \
    && ! grep -qFi 'implementation remediation is outside Inspector' "$1" \
    && ! grep -qFi 'implementation review never amends code, writes status' "$1"
}
for live_surface in "$ROUTER" "$REVIEW" "$KINDS/implementation.md" "$SPINE" "$README" "$PACK"; do
  if live_surface_clean "$live_surface"; then
    pass=$((pass + 1))
  else
    echo "FAIL stale implementation close in $live_surface" >&2
    fail=$((fail + 1))
  fi
done
cp "$SPINE" "$ROOT/live.original"
cp "$ROOT/live.original" "$ROOT/live.broken"
printf '%s\n' 'Implementation review remains verdict-only.' >> "$ROOT/live.broken"
eq "live-surface red-proof plants one retired claim" 1 \
  "$(grep -ciF 'Implementation review remains verdict-only.' "$ROOT/live.broken")"
rejects live_surface_clean "$ROOT/live.broken"
cmp -s "$SPINE" "$ROOT/live.original" && pass=$((pass + 1)) || fail=$((fail + 1))

resolve_policy() {
  local kind="$1" file="$2" count old_count value
  count="$(grep -c '^revision-after-review:' "$file" || true)"
  old_count="$(grep -c '^refinement-after-review:' "$file" || true)"
  [ "$old_count" -gt 0 ] && { echo invalid; return; }
  [ "$kind" = implementation ] && { echo unavailable; return; }
  [ "$count" -gt 1 ] && { echo invalid; return; }
  if [ "$count" -eq 1 ]; then
    value="$(sed -n 's/^revision-after-review:[[:space:]]*//p' "$file")"
    case "$value" in automatic-proposal|offered|unavailable) echo "$value" ;; *) echo invalid ;; esac
    return
  fi
  case "$kind" in spec|plan) echo automatic-proposal ;; *) echo offered ;; esac
}

eq "bundled spec is automatic" automatic-proposal "$(resolve_policy spec "$KINDS/spec.md")"
eq "bundled plan is automatic" automatic-proposal "$(resolve_policy plan "$KINDS/plan.md")"
eq "bundled founding is offered" offered "$(resolve_policy founding "$KINDS/founding.md")"
eq "bundled ADR is offered" offered "$(resolve_policy adr "$KINDS/adr.md")"
eq "bundled roadmap is offered" offered "$(resolve_policy roadmap "$KINDS/roadmap.md")"
eq "bundled runbook is offered" offered "$(resolve_policy runbook "$KINDS/runbook.md")"
eq "bundled implementation is unavailable" unavailable "$(resolve_policy implementation "$KINDS/implementation.md")"
printf '%s\n' '# workspace spec replacement' > "$ROOT/spec.md"
printf '%s\n' '# workspace plan replacement' > "$ROOT/plan.md"
cp "$ROOT/plan.md" "$ROOT/plan.before"
printf '%s\n' '# host-added kind' > "$ROOT/brief.md"
printf '%s\n' '# override' '' 'revision-after-review: offered' > "$ROOT/override.md"
printf '%s\n' '# host opt-in' '' 'revision-after-review: automatic-proposal' > "$ROOT/host-auto.md"
printf '%s\n' '# invalid' '' 'revision-after-review: sometimes' > "$ROOT/invalid.md"
printf '%s\n' '# conflict' '' 'revision-after-review: offered' 'revision-after-review: unavailable' > "$ROOT/conflict.md"
printf '%s\n' '# retired' '' 'refinement-after-review: offered' > "$ROOT/retired.md"
printf '%s\n' '# both' '' 'revision-after-review: offered' 'refinement-after-review: offered' > "$ROOT/both.md"
eq "workspace spec omission keeps kind default" automatic-proposal "$(resolve_policy spec "$ROOT/spec.md")"
eq "workspace plan omission keeps kind default" automatic-proposal "$(resolve_policy plan "$ROOT/plan.md")"
cmp -s "$ROOT/plan.md" "$ROOT/plan.before" && pass=$((pass + 1)) || fail=$((fail + 1))
eq "legacy host kind defaults offered" offered "$(resolve_policy brief "$ROOT/brief.md")"
eq "recognized override wins" offered "$(resolve_policy spec "$ROOT/override.md")"
eq "host-added kind may opt in" automatic-proposal "$(resolve_policy brief "$ROOT/host-auto.md")"
eq "unknown selector is invalid" invalid "$(resolve_policy spec "$ROOT/invalid.md")"
eq "conflicting selectors are invalid" invalid "$(resolve_policy spec "$ROOT/conflict.md")"
eq "retired selector is invalid" invalid "$(resolve_policy spec "$ROOT/retired.md")"
eq "old and new selectors are invalid" invalid "$(resolve_policy spec "$ROOT/both.md")"
eq "implementation remains reserved" unavailable "$(resolve_policy implementation "$ROOT/override.md")"

policy_contract() { [ "$(resolve_policy "$1" "$2")" = "$3" ]; }
cp "$KINDS/spec.md" "$ROOT/spec.original"
cp "$ROOT/spec.original" "$ROOT/broken-spec.md"
sed 's/revision-after-review: automatic-proposal/revision-after-review: offered/' \
  "$ROOT/broken-spec.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/broken-spec.md"
rejects policy_contract spec "$ROOT/broken-spec.md" automatic-proposal
cmp -s "$KINDS/spec.md" "$ROOT/spec.original" && pass=$((pass + 1)) || fail=$((fail + 1))
cp "$KINDS/plan.md" "$ROOT/plan.original"
cp "$ROOT/plan.original" "$ROOT/broken-plan.md"
sed 's/revision-after-review: automatic-proposal/revision-after-review: offered/' \
  "$ROOT/broken-plan.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/broken-plan.md"
rejects policy_contract plan "$ROOT/broken-plan.md" automatic-proposal
cmp -s "$KINDS/plan.md" "$ROOT/plan.original" && pass=$((pass + 1)) || fail=$((fail + 1))

declared_policy() { sed -n 's/^revision-after-review:[[:space:]]*//p' "$1"; }
for pair in \
  "spec:automatic-proposal" "plan:automatic-proposal" "founding:offered" "adr:offered" \
  "roadmap:offered" "runbook:offered" "implementation:unavailable"
do
  kind="${pair%%:*}" expected="${pair#*:}"
  eq "$kind declares its bundled policy" "$expected" "$(declared_policy "$KINDS/$kind.md")"
done

implementation_declaration_contract() { [ "$(declared_policy "$1")" = unavailable ]; }
cp "$KINDS/implementation.md" "$ROOT/implementation.original"
sed 's/revision-after-review: unavailable/revision-after-review: automatic-proposal/' \
  "$ROOT/implementation.original" > "$ROOT/implementation.broken"
eq "implementation red-proof plants one automatic selector" 1 \
  "$(grep -c '^revision-after-review: automatic-proposal$' "$ROOT/implementation.broken")"
rejects implementation_declaration_contract "$ROOT/implementation.broken"
cmp -s "$KINDS/implementation.md" "$ROOT/implementation.original" && pass=$((pass + 1)) || fail=$((fail + 1))

ownership_clean() {
  ! grep -qF 'Kind files can never select a stop boundary.' "$1" &&
    ! grep -qF 'A failing review stops.' "$1"
}
ownership_clean "$ROUTER" && ownership_clean "$SPINE" && pass=$((pass + 1)) || fail=$((fail + 1))
cp "$SPINE" "$ROOT/spine.original"
cp "$ROOT/spine.original" "$ROOT/spine.broken"
printf '%s\n' 'A failing review stops.' >> "$ROOT/spine.broken"
eq "ownership red-proof plants one stale claim" 1 "$(grep -cF 'A failing review stops.' "$ROOT/spine.broken")"
rejects ownership_clean "$ROOT/spine.broken"
cmp -s "$SPINE" "$ROOT/spine.original" && pass=$((pass + 1)) || fail=$((fail + 1))

close_review() {
  local kind="$1" verdict="$2" mode="$3"
  if [ "$kind" = implementation ]; then
    case "$verdict" in
      needs-rework|approve-with-changes) echo implementation-action-close ;;
      approve) echo direct-return ;;
      *) echo invalid ;;
    esac
    return
  fi
  case "$verdict:$mode" in
    approve:*) echo publish-offer ;;
    approve-with-changes:automatic-proposal|needs-rework:automatic-proposal) echo auto-revise-queued ;;
    approve-with-changes:offered) echo offer-publish-or-revise ;;
    approve-with-changes:unavailable) echo publish-as-is-offer ;;
    needs-rework:offered) echo revise-offer ;;
    needs-rework:unavailable) echo verdict-only ;;
    *) echo invalid ;;
  esac
}
eq "clean approval still offers publish" publish-offer "$(close_review document approve automatic-proposal)"
eq "automatic recommended enters revise" auto-revise-queued "$(close_review document approve-with-changes automatic-proposal)"
eq "automatic must-fix enters revise" auto-revise-queued "$(close_review document needs-rework automatic-proposal)"
eq "offered recommended exposes choice" offer-publish-or-revise "$(close_review document approve-with-changes offered)"
eq "offered must-fix stops at offer" revise-offer "$(close_review document needs-rework offered)"
eq "unavailable recommended can publish unchanged" publish-as-is-offer "$(close_review document approve-with-changes unavailable)"
eq "unavailable must-fix is verdict only" verdict-only "$(close_review document needs-rework unavailable)"
eq "implementation needs-rework opens action close" implementation-action-close \
  "$(close_review implementation needs-rework unavailable)"
eq "implementation recommendation opens optional action close" implementation-action-close \
  "$(close_review implementation approve-with-changes unavailable)"
eq "implementation approval offers direct return" direct-return \
  "$(close_review implementation approve unavailable)"

render_surface() {
  local verdict="$1" recommendations="$2" isolation="$3"
  case "$verdict" in
    approve)
      printf '%s\n' 'approve — Implementation ready' '' '1. Return to the calling workflow'
      return
      ;;
    needs-rework)
      printf '%s\n' 'needs-rework — Next actions' '' 'Fix scope — choose one:' \
        '1. Fix must-fix findings only (default)'
      [ "$recommendations" = yes ] && printf '%s\n' \
        '2. Fix all findings' '3. Fix recommended changes only'
      printf '%s\n' '4. Make no changes'
      ;;
    approve-with-changes)
      printf '%s\n' 'approve-with-changes — Next actions' '' 'Fix scope — choose one:' \
        '1. Return as-is (default)' '2. Fix recommended changes'
      ;;
    *) return 1 ;;
  esac
  if [ "$verdict" = approve-with-changes ]; then
    printf '\n%s\n' 'Execution — if fixing, choose one:'
  else
    printf '\n%s\n' 'Execution — choose one:'
  fi
  if [ "$isolation" = yes ]; then
    [ "$verdict" = approve-with-changes ] \
      && printf '%s\n' 'A. Use an isolated implementation agent (default if fixing)' \
      || printf '%s\n' 'A. Use an isolated implementation agent (default)'
    printf '%s\n' 'I. Work inline'
  else
    [ "$verdict" = approve-with-changes ] \
      && printf '%s\n' 'I. Work inline (only route; default if fixing)' \
      || printf '%s\n' 'I. Work inline (only route; default)'
  fi
  if [ "$verdict" = approve-with-changes ]; then
    printf '\n%s\n' 'Afterward — if fixing, choose one:' \
      'R. Re-review the complete implementation (default if fixing)' 'N. Stop without re-review'
  else
    printf '\n%s\n' 'Afterward — choose one:' \
      'R. Re-review the complete implementation (default)' 'N. Stop without re-review'
  fi
}

render_reduced_surface() {
  local verdict="$1" recommendations="$2"
  case "$verdict" in
    needs-rework)
      printf '%s\n' 'needs-rework — Next actions' '' 'Fix scope — choose one:' \
        '1. Fix must-fix findings only (default)'
      [ "$recommendations" = yes ] && printf '%s\n' \
        '2. Fix all findings' '3. Fix recommended changes only'
      printf '%s\n' '4. Make no changes' '' \
        'A fixing choice requires a writable destination before execution or re-review can be confirmed.'
      ;;
    approve-with-changes)
      printf '%s\n' 'approve-with-changes — Next actions' '' 'Fix scope — choose one:' \
        '1. Return as-is (default)' '2. Fix recommended changes' '' \
        'A fixing choice requires a writable destination before execution or re-review can be confirmed.'
      ;;
    *) return 1 ;;
  esac
}

scope_available() {
  case "$1:$2:$3" in
    needs-rework:yes:1|needs-rework:yes:2|needs-rework:yes:3|needs-rework:yes:4) return 0 ;;
    needs-rework:no:1|needs-rework:no:4) return 0 ;;
    approve-with-changes:*:1|approve-with-changes:*:2|approve:*:1) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_code() {
  local answer verdict recommendations isolation trimmed compact scope rest route after no_space
  answer="$1" verdict="$2" recommendations="$3" isolation="$4"
  trimmed="$(printf '%s' "$answer" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr '[:lower:]' '[:upper:]')"
  [ -n "$trimmed" ] || return 1
  printf '%s' "$trimmed" | LC_ALL=C grep -qE '^[0-9AIRN[:space:],-]+$' || return 1
  no_space="$(printf '%s' "$trimmed" | LC_ALL=C tr -d '[:space:]')"
  case "$no_space" in *--*|*,,*|*-,*|*,-*|[-,]*|*[-,]) return 1 ;; esac
  compact="$(printf '%s' "$trimmed" | LC_ALL=C tr -d '[:space:],-')"
  scope="$(printf '%s' "$compact" | cut -c1)"
  scope_available "$verdict" "$recommendations" "$scope" || return 1
  rest="$(printf '%s' "$compact" | cut -c2-)" route='' after=''
  case "$rest" in A*|I*) route="$(printf '%s' "$rest" | cut -c1)"; rest="$(printf '%s' "$rest" | cut -c2-)" ;; esac
  case "$rest" in R*|N*) after="$(printf '%s' "$rest" | cut -c1)"; rest="$(printf '%s' "$rest" | cut -c2-)" ;; esac
  [ -z "$rest" ] || return 1
  if [ "$verdict:$scope" = needs-rework:4 ] || [ "$verdict:$scope" = approve-with-changes:1 ] \
    || [ "$verdict" = approve ]; then
    printf '%s\n' "$scope"
    return
  fi
  [ -n "$route" ] || { [ "$isolation" = yes ] && route=A || route=I; }
  [ "$route" != A ] || [ "$isolation" = yes ] || return 1
  [ -n "$after" ] || after=R
  printf '%s-%s-%s\n' "$scope" "$route" "$after"
}

implementation_answer() {
  local answer="$1" default="$2" pending="${3:-}" normalized
  case "$answer" in
    yes|proceed|go|'do it'|ok) printf 'confirmed:%s\n' "${pending:-$default}" ;;
    stop|'not yet'|cancel|dismiss) echo no-write ;;
    *)
      normalized="$(normalize_code "$answer" needs-rework yes yes)" || { echo ask; return; }
      printf 'confirmed:%s\n' "$normalized"
      ;;
  esac
}

natural_adjustment() {
  case "$1:$2" in
    needs-rework:'fix must-fix inline') echo 1-I-R ;;
    needs-rework:'fix all findings inline') echo 2-I-R ;;
    needs-rework:'fix recommendations inline and stop') echo 3-I-N ;;
    approve-with-changes:'fix recommendations inline and stop') echo 2-I-N ;;
    approve-with-changes:'return as-is') echo 1 ;;
    *) return 1 ;;
  esac
}

action_reply() {
  local answer="$1" verdict="$2" recommendations="$3" isolation="$4" default="$5"
  local pending="${6:-}" normalized
  case "$answer" in
    yes|proceed|go|'do it'|ok) printf 'confirmed:%s\n' "${pending:-$default}" ;;
    stop|'not yet'|cancel|dismiss) echo no-write:cleared ;;
    *)
      if normalized="$(normalize_code "$answer" "$verdict" "$recommendations" "$isolation")"; then
        printf 'confirmed:%s\n' "$normalized"
      elif normalized="$(natural_adjustment "$verdict" "$answer")"; then
        printf 'reflect:%s\n' "$normalized"
      else
        printf 'ask:%s\n' "${pending:-none}"
      fi
      ;;
  esac
}

reduced_reply() {
  local answer="$1" verdict="$2" recommendations="$3" scope
  case "$answer" in
    stop|'not yet'|cancel|dismiss) echo no-write:cleared; return ;;
    yes|proceed|go|'do it'|ok)
      [ "$verdict" = approve-with-changes ] && { echo unchanged:1; return; }
      echo pending-scope:1
      return
      ;;
    'make no changes') scope=4 ;;
    'return as-is') scope=1 ;;
    'fix must-fix findings') scope=1 ;;
    'fix all findings') scope=2 ;;
    'fix recommended changes') [ "$verdict" = needs-rework ] && scope=3 || scope=2 ;;
    *)
      printf '%s' "$answer" | LC_ALL=C grep -qE '^[0-9]$' || { echo ask:no-write; return; }
      scope="$answer"
      ;;
  esac
  scope_available "$verdict" "$recommendations" "$scope" || { echo ask:no-write; return; }
  if [ "$verdict:$scope" = needs-rework:4 ] || [ "$verdict:$scope" = approve-with-changes:1 ]; then
    printf 'unchanged:%s\n' "$scope"
  else
    printf 'pending-scope:%s\n' "$scope"
  fi
}

resolve_pending_scope() {
  local scope="$1" isolation="$2" route
  [ "$isolation" = yes ] && route=A || route=I
  printf 'pending-selection:%s-%s-R:confirm-required\n' "$scope" "$route"
}

needs_surface="$(render_surface needs-rework yes yes)"
has <(printf '%s\n' "$needs_surface") '1. Fix must-fix findings only (default)' "needs-rework default missing"
has <(printf '%s\n' "$needs_surface") '2. Fix all findings' "all-findings scope missing"
has <(printf '%s\n' "$needs_surface") '3. Fix recommended changes only' "recommendations-only scope missing"
has <(printf '%s\n' "$needs_surface") '4. Make no changes' "no-change scope missing"
has <(printf '%s\n' "$needs_surface") 'A. Use an isolated implementation agent (default)' "isolated default missing"
has <(printf '%s\n' "$needs_surface") 'R. Re-review the complete implementation (default)' "re-review default missing"
recommended_surface="$(render_surface approve-with-changes yes yes)"
has <(printf '%s\n' "$recommended_surface") '1. Return as-is (default)' "return default missing"
has <(printf '%s\n' "$recommended_surface") 'Execution — if fixing, choose one:' "conditional execution label missing"
approve_surface="$(render_surface approve no yes)"
eq "approve offers only direct return" "$(printf '%s\n' 'approve — Implementation ready' '' '1. Return to the calling workflow')" "$approve_surface"
without_recommendations="$(render_surface needs-rework no yes)"
has <(printf '%s\n' "$without_recommendations") '1. Fix must-fix findings only (default)' "must-fix default missing"
has <(printf '%s\n' "$without_recommendations") '4. Make no changes' "no-change gap missing"
if ! printf '%s\n' "$without_recommendations" | grep -qE '^[23]\.'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
inline_surface="$(render_surface needs-rework yes no)"
has <(printf '%s\n' "$inline_surface") 'I. Work inline (only route; default)' "inline-only default missing"
if ! printf '%s\n' "$inline_surface" | grep -qF 'A. Use an isolated'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
if ! printf '%s\n' "$approve_surface" | grep -qF 'Execution —'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
if ! printf '%s\n' "$approve_surface" | grep -qF 'Afterward —'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

for spelling in yes 1 1AR 1-A-R '1 A R' '1,A,R' '1-A R'; do
  if [ "$spelling" = yes ]; then
    actual="$(implementation_answer "$spelling" 1-A-R)"
  else
    actual="confirmed:$(normalize_code "$spelling" needs-rework yes yes)"
  fi
  eq "default spelling normalizes: $spelling" confirmed:1-A-R "$actual"
done
eq "direct inline code confirms once" confirmed:2-I-R \
  "$(implementation_answer 2-I-R 1-A-R)"
eq "pending selection wins over old default" confirmed:3-I-N \
  "$(implementation_answer yes 1-A-R 3-I-N)"
eq "implementation rejection writes nothing" no-write \
  "$(implementation_answer stop 1-A-R)"
eq "unclear implementation answer asks" ask \
  "$(implementation_answer maybe 1-A-R)"

for pair in \
  '1ar|1-A-R' '  1-A-R  |1-A-R' '2|2-A-R' '2-A|2-A-R' '2-R|2-A-R' \
  '2 i n|2-I-N' '2,i-r|2-I-R' '4-A-N|4'; do
  spelling="${pair%%|*}" expected="${pair#*|}"
  eq "complete grammar normalizes: $spelling" "$expected" \
    "$(normalize_code "$spelling" needs-rework yes yes)"
done
eq "inline-only number acquires displayed defaults" 1-I-R \
  "$(normalize_code 1 needs-rework no no)"
eq "approve-with-changes no-change modifiers are inert" 1 \
  "$(normalize_code 1-A-N approve-with-changes yes yes)"
for invalid in '' A-R '1--A' '1,,A' '1-,A' '1-A-' '1-X-R' '1-A-I' '1-R-A' \
  '1-R-N' '1-2-A' '9-A-R'; do
  rejects normalize_code "$invalid" needs-rework yes yes
done
rejects normalize_code 2-A-R needs-rework no yes
rejects normalize_code 1-A-R needs-rework yes no
eq "natural adjustment reflects exact pending code" reflect:3-I-N \
  "$(action_reply 'fix recommendations inline and stop' needs-rework yes yes 1-A-R)"
eq "acceptance confirms pending adjustment, not old default" confirmed:3-I-N \
  "$(action_reply yes needs-rework yes yes 1-A-R 3-I-N)"
eq "direct code replaces and confirms pending adjustment" confirmed:2-I-R \
  "$(action_reply 2-I-R needs-rework yes yes 1-A-R 3-I-N)"
eq "invalid input preserves pending selection" ask:3-I-N \
  "$(action_reply '1--A' needs-rework yes yes 1-A-R 3-I-N)"
eq "rejection clears pending selection" no-write:cleared \
  "$(action_reply stop needs-rework yes yes 1-A-R 3-I-N)"
eq "approve-with-changes yes returns unchanged" confirmed:1 \
  "$(action_reply yes approve-with-changes yes yes 1)"

reduced_needs="$(render_reduced_surface needs-rework yes)"
has <(printf '%s\n' "$reduced_needs") '4. Make no changes' "reduced needs-rework exit missing"
if ! printf '%s\n' "$reduced_needs" | grep -qF 'Execution —'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
if ! printf '%s\n' "$reduced_needs" | grep -qF 'Afterward —'; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
eq "reduced approve-with-changes yes returns unchanged" unchanged:1 \
  "$(reduced_reply yes approve-with-changes yes)"
eq "reduced needs-rework yes records only default scope" pending-scope:1 \
  "$(reduced_reply yes needs-rework yes)"
eq "reduced numeric no-change returns without destination" unchanged:4 \
  "$(reduced_reply 4 needs-rework yes)"
eq "reduced natural no-change returns without destination" unchanged:4 \
  "$(reduced_reply 'make no changes' needs-rework yes)"
eq "reduced numeric fix stores only scope" pending-scope:2 \
  "$(reduced_reply 2 needs-rework yes)"
eq "reduced natural fix stores only scope" pending-scope:3 \
  "$(reduced_reply 'fix recommended changes' needs-rework yes)"
eq "reduced surface rejects route prose" ask:no-write \
  "$(reduced_reply 'fix must-fix inline' needs-rework yes)"
eq "reduced surface rejects afterward prose" ask:no-write \
  "$(reduced_reply 'fix must-fix then re-review' needs-rework yes)"
eq "resolved eligible scope becomes pending complete code" pending-selection:2-A-R:confirm-required \
  "$(resolve_pending_scope 2 yes)"
eq "resolved inline scope becomes pending complete code" pending-selection:2-I-R:confirm-required \
  "$(resolve_pending_scope 2 no)"

reduced_matrix() {
  printf '%s\n' \
    "recommended-yes:$(reduced_reply yes approve-with-changes yes)" \
    "needs-yes:$(reduced_reply yes needs-rework yes)" \
    "no-change:$(reduced_reply 4 needs-rework yes)" \
    "pending:$(reduced_reply 2 needs-rework yes)" \
    "resolved:$(resolve_pending_scope 2 yes)"
}
reduced_matrix_contract() { [ "$(cat "$1")" = "$(reduced_matrix)" ]; }
reduced_matrix > "$ROOT/reduced.original"
cp "$ROOT/reduced.original" "$ROOT/reduced.saved"
for mutation in \
  'recommended-yes:unchanged:1|recommended-yes:pending-scope:2' \
  'needs-yes:pending-scope:1|needs-yes:confirmed:1-A-R' \
  'no-change:unchanged:4|no-change:pending-scope:4' \
  'pending:pending-scope:2|pending:confirmed:2-A-R' \
  'resolved:pending-selection:2-A-R:confirm-required|resolved:confirmed:2-A-R'; do
  before_row="${mutation%%|*}" after_row="${mutation#*|}"
  sed "s/^$before_row$/$after_row/" "$ROOT/reduced.original" > "$ROOT/reduced.broken"
  eq "reduced-state red-proof plants one unsafe transition" 1 \
    "$(grep -cF "$after_row" "$ROOT/reduced.broken")"
  rejects reduced_matrix_contract "$ROOT/reduced.broken"
done
cmp -s "$ROOT/reduced.original" "$ROOT/reduced.saved" && pass=$((pass + 1)) || fail=$((fail + 1))

grammar_matrix() {
  printf '%s\n' \
    "default:$(normalize_code 1 needs-rework yes yes)" \
    "inline:$(normalize_code 1 needs-rework no no)" \
    "no-change:$(normalize_code 4-A-N needs-rework yes yes)" \
    "pending:$(action_reply yes needs-rework yes yes 1-A-R 3-I-N)" \
    "invalid:$(action_reply '1--A' needs-rework yes yes 1-A-R 3-I-N)"
}
grammar_matrix_contract() { [ "$(cat "$1")" = "$(grammar_matrix)" ]; }
grammar_matrix > "$ROOT/grammar.original"
cp "$ROOT/grammar.original" "$ROOT/grammar.saved"
for mutation in \
  'default:1-A-R|default:1-I-R' \
  'inline:1-I-R|inline:1-A-R' \
  'no-change:4|no-change:4-A-N' \
  'pending:confirmed:3-I-N|pending:confirmed:1-A-R' \
  'invalid:ask:3-I-N|invalid:confirmed:1-A-R'; do
  before_row="${mutation%%|*}" after_row="${mutation#*|}"
  sed "s/^$before_row$/$after_row/" "$ROOT/grammar.original" > "$ROOT/grammar.broken"
  eq "grammar red-proof plants one wrong transition" 1 \
    "$(grep -cF "$after_row" "$ROOT/grammar.broken")"
  rejects grammar_matrix_contract "$ROOT/grammar.broken"
done
cmp -s "$ROOT/grammar.original" "$ROOT/grammar.saved" && pass=$((pass + 1)) || fail=$((fail + 1))

review_action_contract() {
  local file="$1" needle
  for needle in 'needs-rework — Next actions' '1. Fix must-fix findings only (default)' \
    'approve-with-changes' '1. Return as-is (default)' '1. Return to the calling workflow' \
    'A. Use an isolated implementation agent (default)' 'I. Work inline' \
    'R. Re-review the complete implementation (default)' 'N. Stop without re-review' \
    'A direct valid code on a complete surface is explicit confirmation' \
    'repeated punctuation, or trailing punctuation' \
    'pending normalized selection' 'preserve any existing pending value' \
    'stores only a pending scope' 'require a fresh confirmation' \
    'Render a fresh inline-only surface' 'changing only `A` to `I`' \
    'writer-started partial or blocked work' \
    'The verdict itself is never confirmation'; do
    grep -qF "$needle" "$file" || return 1
  done
}
review_action_contract "$REVIEW" && pass=$((pass + 1)) || fail=$((fail + 1))
cp "$REVIEW" "$ROOT/review-action.original"
for needle in 'needs-rework — Next actions' '1. Return as-is (default)' \
  'A direct valid code on a complete surface is explicit confirmation' \
  'repeated punctuation, or trailing punctuation' 'pending normalized selection' \
  'stores only a pending scope' 'Render a fresh inline-only surface'; do
  awk -v needle="$needle" 'index($0, needle) == 0 { print }' \
    "$ROOT/review-action.original" > "$ROOT/review-action.broken"
  eq "review contract red-proof removes one clause" 0 \
    "$(grep -cF "$needle" "$ROOT/review-action.broken" || true)"
  rejects review_action_contract "$ROOT/review-action.broken"
done
cmp -s "$REVIEW" "$ROOT/review-action.original" && pass=$((pass + 1)) || fail=$((fail + 1))

selection_result() {
  local fixes="$1" complete="$2" rereview="$3" route="$4"
  [ "$fixes" = none ] && { echo unchanged:return; return; }
  [ "$complete" = complete ] || { echo stopped:partial:unreviewed; return; }
  [ "$rereview" = yes ] || { echo "$route:applied:unreviewed"; return; }
  echo "$route:applied:full-re-review"
}
rows_contract() { [ "$(cat "$1")" = "$2" ]; }
eq "route and review modifiers are inert without fixes" unchanged:return \
  "$(selection_result none complete yes isolated)"
eq "partial package never queues review" stopped:partial:unreviewed \
  "$(selection_result must-fix partial yes inline)"
eq "deselected review reports unreviewed result" inline:applied:unreviewed \
  "$(selection_result recommended complete no inline)"
eq "complete package uses exactly selected route" isolated:applied:full-re-review \
  "$(selection_result must-fix complete yes isolated)"
printf '%s\n' stopped:partial:unreviewed > "$ROOT/partial.original"
cp "$ROOT/partial.original" "$ROOT/partial.saved"
printf '%s\n' isolated:applied:full-re-review > "$ROOT/partial.broken"
eq "partial red-proof plants one premature review" 1 \
  "$(grep -c '^isolated:applied:full-re-review$' "$ROOT/partial.broken")"
rejects rows_contract "$ROOT/partial.broken" "$(cat "$ROOT/partial.original")"
cmp -s "$ROOT/partial.original" "$ROOT/partial.saved" && pass=$((pass + 1)) || fail=$((fail + 1))

answer_offer() {
  local verdict="$1" answer="$2"
  case "$answer" in
    revise|amend|fold) echo revise-queued ;;
    "publish as-is"|"publish as is") [ "$verdict" = approve-with-changes ] && echo publish-reviewed || echo no-write ;;
    stop|"not yet") echo no-write ;;
    *) echo ask ;;
  esac
}
eq "offered recommendation may revise" revise-queued "$(answer_offer approve-with-changes revise)"
eq "offered recommendation may publish as-is" publish-reviewed "$(answer_offer approve-with-changes 'publish as-is')"
eq "needs-rework cannot publish as-is" no-write "$(answer_offer needs-rework 'publish as-is')"

answer_passing() {
  local kind="$1" answer="$2"
  case "$answer" in
    refine) case "$kind" in spec|plan) echo refine-no-publish ;; *) echo no-write ;; esac ;;
    approve|approved|yes) echo publish ;;
    stop|"not yet") echo no-write ;;
    *) echo ask ;;
  esac
}
eq "clean spec may refine without publishing" refine-no-publish "$(answer_passing spec refine)"
eq "clean plan may refine without publishing" refine-no-publish "$(answer_passing plan refine)"
eq "unsupported clean kind cannot refine" no-write "$(answer_passing adr refine)"
eq "clean approval still publishes" publish "$(answer_passing spec approved)"

publish_gate() {
  case "$1" in plan|roadmap|runbook) echo published:approved ;; founding) echo draft:none ;; *) echo published:none ;; esac
}
eq "accepted spec publishes without stage" published:none "$(publish_gate spec)"
eq "accepted plan publishes approved" published:approved "$(publish_gate plan)"
eq "founding stays draft" draft:none "$(publish_gate founding)"

printf '%s\n' '---' 'status: draft' 'updated: 2026-08-01' '---' > "$ROOT/reviewed.md"
cp "$ROOT/reviewed.md" "$ROOT/other.md"
sed -e 's/status: draft/status: published/' -e 's/updated: 2026-08-01/updated: 2026-08-24/' \
  "$ROOT/reviewed.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/reviewed.md"
has "$ROOT/reviewed.md" 'status: published' "accepted artifact not published"
has "$ROOT/other.md" 'status: draft' "acceptance changed another artifact"

echo "review-close-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
