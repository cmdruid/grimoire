#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
KINDS="$SKILL/kinds"
ROUTER="$SKILL/SKILL.md"
SPINE="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/docs/design/2026-08-21-architect-contractor-inspector.md"
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
has "$REVIEW" 'Implementation needs-rework action' "implementation action close missing"
has "$REVIEW" 'The verdict itself is never confirmation' "implementation confirmation guard missing"
has "$REVIEW" 'fresh action close' "implementation re-review loop missing"
has "$REVIEW" 'native multi-select' "native presentation adapter missing"
has "$REVIEW" 'textual fallback' "textual presentation adapter missing"
has "$REVIEW" 'one unambiguous writable destination' "implementation destination resolver missing"
has "$REVIEW" 'omit the isolation row' "inline route disclosure missing"
has "$REVIEW" 'no selected fix row' "inert modifier rule missing"
has "$REVIEW" 'partially applied' "partial-package stop missing"
has "$REVIEW" 'has not passed Inspector review' "unreviewed-result disclosure missing"
has "$REVIEW" 'If you accept, this session will publish' "passing publish offer missing"
has "$REVIEW" 're-review queued by default' "offered revise does not carry re-review"

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

implementation_defaults() {
  local verdict="$1" recommendations="$2" isolation="$3"
  [ "$verdict" = approve ] && { printf '%s\n' 'return:Return to the calling workflow'; return; }
  [ "$recommendations" = yes ] && printf '%s\n' 'off:focused:Also fix recommended changes'
  [ "$verdict" = needs-rework ] && printf '%s\n' 'on:-:Fix all must-fix findings'
  printf '%s\n' 'on:-:After selected fixes, re-review the complete implementation'
  if [ "$isolation" = yes ]; then
    printf '%s\n' 'on:-:For selected fixes, use an isolated implementation agent'
  else
    printf '%s\n' 'route:inline:Selected fixes will run inline'
  fi
}
present_defaults() {
  local presentation="$1"
  shift
  case "$presentation" in native|textual) implementation_defaults "$@" ;; *) return 1 ;; esac
}

implementation_answer() {
  case "$1" in
    yes|proceed|approved|ok) echo confirmed:must-fix:isolated:full-re-review ;;
    stop|'not yet'|cancel|dismiss) echo no-write ;;
    *) echo ask ;;
  esac
}

expected_defaults="$(printf '%s\n' \
  'off:focused:Also fix recommended changes' \
  'on:-:Fix all must-fix findings' \
  'on:-:After selected fixes, re-review the complete implementation' \
  'on:-:For selected fixes, use an isolated implementation agent')"
eq "implementation defaults preserve exact order and selection" "$expected_defaults" \
  "$(implementation_defaults needs-rework yes yes)"
expected_recommended="$(printf '%s\n' \
  'off:focused:Also fix recommended changes' \
  'on:-:After selected fixes, re-review the complete implementation' \
  'on:-:For selected fixes, use an isolated implementation agent')"
eq "recommended verdict accepts as-is by default" "$expected_recommended" \
  "$(implementation_defaults approve-with-changes yes yes)"
expected_inline="$(printf '%s\n' \
  'on:-:Fix all must-fix findings' \
  'on:-:After selected fixes, re-review the complete implementation' \
  'route:inline:Selected fixes will run inline')"
eq "no recommendations suppresses empty row and discloses inline" "$expected_inline" \
  "$(implementation_defaults needs-rework no no)"
eq "approve has no meaningless checklist" 'return:Return to the calling workflow' \
  "$(implementation_defaults approve no yes)"
eq "native and textual adapters share semantic rows" \
  "$(present_defaults native needs-rework yes yes)" \
  "$(present_defaults textual needs-rework yes yes)"
rejects present_defaults unsupported needs-rework yes yes

rows_contract() { [ "$(cat "$1")" = "$2" ]; }
printf '%s\n' "$expected_defaults" > "$ROOT/defaults.original"
cp "$ROOT/defaults.original" "$ROOT/defaults.saved"
awk 'NR == 1 { first=$0; next } NR == 2 { print; print first; next } { print }' \
  "$ROOT/defaults.original" > "$ROOT/defaults.broken"
eq "row-order red-proof swaps one focused row" 1 \
  "$(grep -c '^on:-:Fix all must-fix findings$' "$ROOT/defaults.broken")"
rejects rows_contract "$ROOT/defaults.broken" "$expected_defaults"
printf '%s\n' "$expected_inline" > "$ROOT/inline.original"
cp "$ROOT/inline.original" "$ROOT/inline.saved"
cp "$ROOT/inline.original" "$ROOT/inline.broken"
printf '%s\n' 'off:focused:Also fix recommended changes' >> "$ROOT/inline.broken"
eq "absent-class red-proof plants one recommendation row" 1 \
  "$(grep -c '^off:focused:Also fix recommended changes$' "$ROOT/inline.broken")"
rejects rows_contract "$ROOT/inline.broken" "$expected_inline"
cp "$ROOT/defaults.original" "$ROOT/textual.broken"
printf '%s\n' 'route:inline:Selected fixes will run inline' >> "$ROOT/textual.broken"
eq "presentation red-proof plants one route mismatch" 1 \
  "$(grep -c '^route:inline:Selected fixes will run inline$' "$ROOT/textual.broken")"
rejects rows_contract "$ROOT/textual.broken" "$(cat "$ROOT/defaults.original")"
cmp -s "$ROOT/defaults.original" "$ROOT/defaults.saved" && pass=$((pass + 1)) || fail=$((fail + 1))
cmp -s "$ROOT/inline.original" "$ROOT/inline.saved" && pass=$((pass + 1)) || fail=$((fail + 1))
eq "default confirmation excludes recommendations" confirmed:must-fix:isolated:full-re-review \
  "$(implementation_answer yes)"
eq "implementation rejection writes nothing" no-write "$(implementation_answer stop)"
eq "unclear implementation answer asks" ask "$(implementation_answer maybe)"

selection_result() {
  local fixes="$1" complete="$2" rereview="$3" route="$4"
  [ "$fixes" = none ] && { echo unchanged:return; return; }
  [ "$complete" = complete ] || { echo stopped:partial:unreviewed; return; }
  [ "$rereview" = yes ] || { echo "$route:applied:unreviewed"; return; }
  echo "$route:applied:full-re-review"
}
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
