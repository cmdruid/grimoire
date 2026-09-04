#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown code spans are literal throughout this fixture.
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
KINDS="$SKILL/kinds"
ROUTER="$SKILL/SKILL.md"
README="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/README.md"
PACK="$(CDPATH='' cd -P "$SKILL/../.." && pwd)/PACK.md"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
missing() { if grep -qF -- "$2" "$1"; then echo "FAIL $3" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

has "$REVIEW" 'Resolve review continuation.' "continuation resolver missing"
missing "$REVIEW" 'Automatic entry.' "automatic continuation entry still present"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$REVIEW" 'No body, `status`, or `stage` changes before proposal confirmation.' "automatic no-write guard missing"
missing "$ROUTER" 'material + automatic-proposal' "automatic-proposal still a dispatch default"
missing "$ROUTER" 'The automatic `review` → `revise` handoff is not a stop' "automatic entry still taught as not a stop"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$ROUTER" 'every document kind, including spec, plan,' "missing-declaration default is not offered"
# shellcheck disable=SC2016 # Markdown code spans are literal.
missing "$ROUTER" '`spec` and `plan` → `automatic-proposal`' "spec/plan still default to automatic-proposal"
has "$REVIEW" 'offer accept/publish as-is or explicit revise' "recommended offered choice missing"
has "$REVIEW" '## Implementation close' "implementation close heading missing"
has "$REVIEW" 'The verdict itself is never confirmation' "implementation confirmation guard missing"
has "$REVIEW" 'same fresh close' "implementation re-review loop missing"
has "$REVIEW" 'not this tree, refuse to apply' "foreign-tree refuse missing"
has "$REVIEW" 'fix must-fix findings in this tree' "needs-rework English close missing"
has "$REVIEW" 'then look again' "look-again close missing"
has "$REVIEW" 'stand as-is, or apply the recommended changes here' "approve-with-changes English close missing"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$REVIEW" '`yes` / `fix them` / `stop`' "English reply tokens missing"
has "$REVIEW" 'Render no option, action surface, confirmation request, or internal caller seam' "approve has a menu"
has "$REVIEW" 'If you accept, this session will publish' "passing publish offer missing"
has "$REVIEW" 're-review queued by default' "offered revise does not carry re-review"
has "$ROUTER" 'ask in English to fix in this checkout' "router English close missing"
has "$README" 'English close asks to fix in this checkout' "README English close missing"
has "$PACK" 'English close for implementation fixes in this checkout' "pack English close missing"
missing "$ROUTER" 'text-coded implementation' "router still advertises text-coded close"
missing "$README" 'numbered/lettered' "README still advertises numbered/lettered close"
missing "$PACK" 'numbered/lettered' "PACK still advertises numbered/lettered close"
# shellcheck disable=SC2016 # Markdown code spans are literal.
has "$KINDS/implementation.md" 'None. Implementation never enters document `revise` or `refine`' "implementation revise refusal missing"
has "$KINDS/implementation.md" 'English close, inline, in this checkout' "implementation kind English close missing"
missing "$REVIEW" '1-A-R' "1-A-R still in review close"
missing "$REVIEW" 'isolated implementation agent' "isolated-fixer preflight still in review close"
missing "$REVIEW" 'one unambiguous writable destination' "destination-identity protocol still in review close"
missing "$KINDS/implementation.md" '1-A-R' "1-A-R still in implementation kind"
missing "$KINDS/implementation.md" 'numbered scope' "numbered close still in implementation kind"

live_surface_clean() {
  ! grep -qFi 'implementation review remains verdict-only' "$1" \
    && ! grep -qFi 'implementation review → verdict only' "$1" \
    && ! grep -qFi 'implementation, any verdict | verdict only' "$1" \
    && ! grep -qFi 'implementation remediation is outside Inspector' "$1" \
    && ! grep -qFi 'implementation review never amends code, writes status' "$1" \
    && ! grep -qFi 'native multi-select' "$1" \
    && ! grep -qFi 'textual fallback' "$1" \
    && ! grep -qFi 'checkbox syntax' "$1" \
    && ! grep -qFi 'first and focused' "$1" \
    && ! grep -qFi 'unchecked means inline' "$1" \
    && ! grep -qF 'Return to the calling workflow' "$1" \
    && ! grep -qFi 'defaults on Enter' "$1" \
    && ! grep -qFi 'as-is on Enter' "$1"
}
for live_surface in "$ROUTER" "$REVIEW" "$KINDS/implementation.md" "$README" "$PACK"; do
  if live_surface_clean "$live_surface"; then
    pass=$((pass + 1))
  else
    echo "FAIL stale implementation close in $live_surface" >&2
    fail=$((fail + 1))
  fi
done
cp "$REVIEW" "$ROOT/live.original"
for retired in 'Implementation review remains verdict-only.' 'native multi-select' \
  'textual fallback' 'checkbox syntax' 'first and focused' 'unchecked means inline' \
  'Return to the calling workflow' 'defaults on Enter' 'as-is on Enter'; do
  cp "$ROOT/live.original" "$ROOT/live.broken"
  printf '%s\n' "$retired" >> "$ROOT/live.broken"
  eq "live-surface red-proof plants one retired claim" 1 \
    "$(grep -ciF "$retired" "$ROOT/live.broken")"
  rejects live_surface_clean "$ROOT/live.broken"
done
cmp -s "$REVIEW" "$ROOT/live.original" && pass=$((pass + 1)) || fail=$((fail + 1))

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
  echo offered
}

eq "bundled spec is offered" offered "$(resolve_policy spec "$KINDS/spec.md")"
eq "bundled plan is offered" offered "$(resolve_policy plan "$KINDS/plan.md")"
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
eq "workspace spec omission defaults offered" offered "$(resolve_policy spec "$ROOT/spec.md")"
eq "workspace plan omission defaults offered" offered "$(resolve_policy plan "$ROOT/plan.md")"
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
sed 's/revision-after-review: offered/revision-after-review: automatic-proposal/' \
  "$ROOT/broken-spec.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/broken-spec.md"
rejects policy_contract spec "$ROOT/broken-spec.md" offered
cmp -s "$KINDS/spec.md" "$ROOT/spec.original" && pass=$((pass + 1)) || fail=$((fail + 1))
cp "$KINDS/plan.md" "$ROOT/plan.original"
cp "$ROOT/plan.original" "$ROOT/broken-plan.md"
sed 's/revision-after-review: offered/revision-after-review: automatic-proposal/' \
  "$ROOT/broken-plan.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/broken-plan.md"
rejects policy_contract plan "$ROOT/broken-plan.md" offered
cmp -s "$KINDS/plan.md" "$ROOT/plan.original" && pass=$((pass + 1)) || fail=$((fail + 1))

declared_policy() { sed -n 's/^revision-after-review:[[:space:]]*//p' "$1"; }
for pair in \
  "spec:offered" "plan:offered" "founding:offered" "adr:offered" \
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
ownership_clean "$ROUTER" && pass=$((pass + 1)) || fail=$((fail + 1))
cp "$ROUTER" "$ROOT/router.original"
cp "$ROOT/router.original" "$ROOT/router.broken"
printf '%s\n' 'A failing review stops.' >> "$ROOT/router.broken"
eq "ownership red-proof plants one stale claim" 1 "$(grep -cF 'A failing review stops.' "$ROOT/router.broken")"
rejects ownership_clean "$ROOT/router.broken"
cmp -s "$ROUTER" "$ROOT/router.original" && pass=$((pass + 1)) || fail=$((fail + 1))

close_review() {
  local kind="$1" verdict="$2" mode="$3"
  if [ "$kind" = implementation ]; then
    case "$verdict" in
      needs-rework|approve-with-changes) echo implementation-action-close ;;
      approve) echo resume-caller ;;
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
eq "clean approval still offers publish" publish-offer "$(close_review document approve offered)"
eq "declared automatic-proposal recommended enters revise" auto-revise-queued "$(close_review document approve-with-changes automatic-proposal)"
eq "declared automatic-proposal must-fix enters revise" auto-revise-queued "$(close_review document needs-rework automatic-proposal)"
eq "offered recommended exposes choice" offer-publish-or-revise "$(close_review document approve-with-changes offered)"
eq "offered must-fix stops at offer" revise-offer "$(close_review document needs-rework offered)"
eq "unavailable recommended can publish unchanged" publish-as-is-offer "$(close_review document approve-with-changes unavailable)"
eq "unavailable must-fix is verdict only" verdict-only "$(close_review document needs-rework unavailable)"
eq "implementation needs-rework opens action close" implementation-action-close \
  "$(close_review implementation needs-rework unavailable)"
eq "implementation recommendation opens optional action close" implementation-action-close \
  "$(close_review implementation approve-with-changes unavailable)"
eq "implementation approval resumes caller automatically" resume-caller \
  "$(close_review implementation approve unavailable)"

english_close() {
  local verdict="$1" answer="$2" tree="${3:-this}"
  [ "$tree" = this ] || { echo refuse-apply; return; }
  case "$verdict" in
    approve) echo ready; return ;;
  esac
  case "$verdict:$answer" in
    needs-rework:yes|needs-rework:'fix them') echo fix-here-then-look-again ;;
    approve-with-changes:yes|approve-with-changes:'stand as-is') echo stand-as-is ;;
    approve-with-changes:'fix them') echo apply-recommended-here ;;
    *:stop) echo stop ;;
    *) echo ask ;;
  esac
}
eq "approve has no menu" ready "$(english_close approve yes)"
eq "foreign tree refuses apply" refuse-apply "$(english_close needs-rework 'fix them' other)"
eq "needs-rework yes fixes here then looks again" fix-here-then-look-again \
  "$(english_close needs-rework yes)"
eq "needs-rework stop writes nothing" stop "$(english_close needs-rework stop)"
eq "recommended yes stands as-is" stand-as-is "$(english_close approve-with-changes yes)"
eq "recommended fix them applies here" apply-recommended-here \
  "$(english_close approve-with-changes 'fix them')"
eq "unclear implementation answer asks" ask "$(english_close needs-rework maybe)"

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
