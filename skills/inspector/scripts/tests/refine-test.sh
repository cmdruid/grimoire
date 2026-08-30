#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REPO="$(CDPATH='' cd -P "$SKILL/../.." && pwd)"
REFINE="$SKILL/verbs/refine.md"
README="$REPO/README.md"
PACK="$REPO/PACK.md"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
pass=0 fail=0

has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

has "$REFINE" 'only specs and plans' "supported kinds are not bounded"
# shellcheck disable=SC2016 # Markdown code span is literal.
has "$REFINE" 'belongs to `revise`' "findings refusal does not name revise"
has "$REFINE" 'No invocation token skips this proposal boundary.' "proposal boundary missing"
has "$REFINE" 'cannot cancel the mandatory review' "mandatory review cancellation guard missing"
has "$REFINE" 'style-only shortening is out of scope' "copyedit boundary missing"
has "$REFINE" 'state cross-product' "branch-multiplication check missing"
has "$REFINE" 'never runs a code analyzer' "document metric boundary missing"
has "$REFINE" 'must not assign a cyclomatic-complexity score' "numeric document guard missing"
has "$README" 'revise folds supported document findings, refine simplifies specs and plans' \
  "README verb split is stale"
has "$PACK" 'Inspector reviews documents, revises supported' "pack revision seam is stale"
has "$PACK" 'and may simplify a spec or plan' "pack refinement seam is stale"

proposal_rows() {
  local row
  for row in "$@"; do case "$row" in change:*) printf '%s\n' "${row#change:}" ;; esac; done
}
eq "proposal lists only supported edits" duplicate-removal \
  "$(proposal_rows keep:required change:duplicate-removal keep:boundary)"

target_allowed() { [ "$1" = spec ] || [ "$1" = plan ]; }
target_allowed spec && pass=$((pass + 1)) || fail=$((fail + 1))
target_allowed plan && pass=$((pass + 1)) || fail=$((fail + 1))
rejects target_allowed founding
rejects target_allowed implementation

resolve_target() {
  local named="$1" readable="$2" named_kind="$3" last_kind="$4"
  if [ "$named" = true ]; then
    [ "$readable" = true ] || { echo ask; return; }
    if target_allowed "$named_kind"; then echo "named-$named_kind"; else echo refuse; fi
    return
  fi
  case "$last_kind" in spec|plan) echo "last-$last_kind" ;; *) echo ask ;; esac
}
eq "named readable spec wins" named-spec "$(resolve_target true true spec none)"
eq "named readable plan wins" named-plan "$(resolve_target true true plan spec)"
eq "last session plan resolves" last-plan "$(resolve_target false false none plan)"
eq "no named or session target asks" ask "$(resolve_target false false none none)"
eq "unreadable named target asks" ask "$(resolve_target true false spec plan)"
eq "unsupported named kind refuses" refuse "$(resolve_target true true founding plan)"

input_route() {
  case "$1" in
    findings|findings-file|correct-review) echo refuse-use-revise ;;
    spec|plan) echo analyze ;;
    *) echo refuse-unsupported ;;
  esac
}
eq "findings refuse and name revise" refuse-use-revise "$(input_route findings)"
eq "spec enters analysis" analyze "$(input_route spec)"
eq "implementation refuses" refuse-unsupported "$(input_route implementation)"

entry_state() {
  local pending="$1" source="$2"
  [ "$pending" = true ] && { echo wait-for-revision; return; }
  case "$source" in
    missing|ambiguous) echo ask-for-source ;;
    present|not-applicable) echo analyze ;;
    *) echo invalid ;;
  esac
}
eq "pending correction holds refinement" wait-for-revision "$(entry_state true present)"
eq "missing plan source asks" ask-for-source "$(entry_state false missing)"
eq "ambiguous plan source asks" ask-for-source "$(entry_state false ambiguous)"
eq "settled artifact proceeds" analyze "$(entry_state false present)"
eq "spec needs no governing plan source" analyze "$(entry_state false not-applicable)"

analysis_result() {
  if [ "$1" -eq 0 ]; then echo no-op:no-write:no-review:no-status-change; else echo proposal:no-write; fi
}
eq "no-op has no ceremony" no-op:no-write:no-review:no-status-change "$(analysis_result 0)"
eq "supported simplification proposes without writing" proposal:no-write "$(analysis_result 1)"

before_confirm() { case "$1" in question|proposal) echo no-write ;; accepted) echo apply ;; esac; }
eq "question writes nothing" no-write "$(before_confirm question)"
eq "proposal writes nothing" no-write "$(before_confirm proposal)"
eq "acceptance applies" apply "$(before_confirm accepted)"

after_accept() {
  local accepted="$1" cancellation="$2"
  [ "$accepted" = true ] || { echo wait; return; }
  case "$cancellation" in none|apply-only|without-re-review) ;; *) echo invalid; return ;; esac
  echo apply-then-review
}
eq "accepted refinement always reviews" apply-then-review "$(after_accept true none)"
eq "apply-only cannot cancel review" apply-then-review "$(after_accept true apply-only)"
eq "without-re-review cannot cancel review" apply-then-review "$(after_accept true without-re-review)"
eq "unaccepted proposal waits" wait "$(after_accept false none)"

apply_refinement_gate() {
  local file="$1" next="$1.next"
  sed -e 's/^status: published$/status: draft/' -e '/^stage: approved$/d' "$file" > "$next"
  mv "$next" "$file"
}
printf '%s\n' '---' 'status: published' 'stage: approved' '---' '# Target' > "$ROOT/target.md"
printf '%s\n' '---' 'status: published' 'stage: approved' '---' '# Other' > "$ROOT/other.md"
cp "$ROOT/other.md" "$ROOT/other.before"
apply_refinement_gate "$ROOT/target.md"
has "$ROOT/target.md" 'status: draft' "accepted refinement did not return target to draft"
if grep -q '^stage: approved$' "$ROOT/target.md"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
has "$ROOT/target.md" '# Target' "accepted refinement did not amend the same artifact"
cmp -s "$ROOT/other.md" "$ROOT/other.before" && pass=$((pass + 1)) || fail=$((fail + 1))

spec_fixture_valid() {
  local file="$1" requirement
  while IFS= read -r requirement; do
    grep -q "^mechanism:[^:]*:$requirement$" "$file" || return 1
    grep -q "^verify:[^:]*:$requirement$" "$file" || return 1
  done < <(sed -n 's/^goal://p' "$file")
}
printf '%s\n' 'goal:R1' 'mechanism:core:R1' 'mechanism:duplicate:R1' \
  'mechanism:speculative:-' 'verify:test:R1' > "$ROOT/spec.full"
grep -vE '^mechanism:(duplicate|speculative):' "$ROOT/spec.full" > "$ROOT/spec.simplified"
spec_fixture_valid "$ROOT/spec.simplified" && pass=$((pass + 1)) || fail=$((fail + 1))
grep -v '^mechanism:core:' "$ROOT/spec.simplified" > "$ROOT/spec.broken"
rejects spec_fixture_valid "$ROOT/spec.broken"

design_branch_valid() {
  local original="$1" candidate="$2" branch
  ! grep -q '^complexity-score:' "$candidate" || return 1
  ! grep -q ':avoidable$' "$candidate" || return 1
  while IFS= read -r branch; do
    grep -qF "$branch" "$candidate" || return 1
  done < <(grep ':required$' "$original")
}
printf '%s\n' 'branch:flag-cross-product:avoidable' 'branch:redundant-fallback:avoidable' \
  'branch:substrate-alternative:avoidable' 'branch:safety-stop:required' \
  'branch:failure-outcome:required' > "$ROOT/design.full"
printf '%s\n' 'branch:safety-stop:required' 'branch:failure-outcome:required' \
  > "$ROOT/design.simplified"
design_branch_valid "$ROOT/design.full" "$ROOT/design.simplified" \
  && pass=$((pass + 1)) || fail=$((fail + 1))
: > "$ROOT/design.broken"
rejects design_branch_valid "$ROOT/design.full" "$ROOT/design.broken"
printf '%s\n' 'branch:safety-stop:required' 'complexity-score:2' > "$ROOT/design.broken"
rejects design_branch_valid "$ROOT/design.full" "$ROOT/design.broken"
printf '%s\n' 'branch:safety-stop:required' 'branch:failure-outcome:required' \
  'branch:redundant-fallback:avoidable' > "$ROOT/design.broken"
rejects design_branch_valid "$ROOT/design.full" "$ROOT/design.broken"
grep -v '^verify:test:' "$ROOT/spec.simplified" > "$ROOT/spec.broken"
rejects spec_fixture_valid "$ROOT/spec.broken"

plan_fixture_valid() {
  local file="$1" requirement record id covered role gate dependency extra seen=" " tracer=false
  while IFS=: read -r record id covered role gate dependency extra; do
    [ "$record" = slice ] || continue
    [ -n "$id" ] && [ -n "$covered" ] && [ "$gate" = verify ] && [ -z "$extra" ] || return 1
    case "$seen" in *" $id "*) return 1 ;; esac
    if [ "$dependency" != - ]; then
      case "$seen" in *" $dependency "*) ;; *) return 1 ;; esac
    fi
    [ "$role" = tracer ] && [ "$dependency" = - ] && tracer=true
    seen="$seen$id "
  done < "$file"
  [ "$tracer" = true ] || return 1
  while IFS= read -r requirement; do
    grep -q "^slice:[^:]*:$requirement:" "$file" || return 1
  done < <(sed -n 's/^requirement://p' "$file")
}

slice_present() {
  awk -F: -v wanted="$2" '
    $1 == "slice" && $2 == wanted { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

slice_dependency() {
  awk -F: -v wanted="$2" '
    $1 == "slice" && $2 == wanted { print $6; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$1"
}

plan_refinement_valid() {
  local original="$1" candidate="$2" record id covered role gate dependency extra candidate_dependency
  plan_fixture_valid "$candidate" || return 1
  while IFS=: read -r record id covered role gate dependency extra; do
    [ "$record" = slice ] || continue
    if slice_present "$candidate" "$id"; then
      candidate_dependency="$(slice_dependency "$candidate" "$id")" || return 1
      [ "$candidate_dependency" = "$dependency" ] || return 1
    fi
  done < "$original"
}

printf '%s\n' 'requirement:R1' 'slice:S1:R1:tracer:verify:-' \
  'slice:S2:R1:widen:verify:S1' > "$ROOT/plan.full"
printf '%s\n' 'requirement:R1' 'slice:S1:R1:tracer:verify:-' > "$ROOT/plan.consolidated"
plan_refinement_valid "$ROOT/plan.full" "$ROOT/plan.full" \
  && pass=$((pass + 1)) || fail=$((fail + 1))
plan_refinement_valid "$ROOT/plan.full" "$ROOT/plan.consolidated" \
  && pass=$((pass + 1)) || fail=$((fail + 1))
printf '%s\n' 'requirement:R1' 'slice:S1:R2:tracer:verify:-' > "$ROOT/plan.broken"
rejects plan_fixture_valid "$ROOT/plan.broken"
printf '%s\n' 'requirement:R1' 'slice:S1:R1:widen:verify:-' > "$ROOT/plan.broken"
rejects plan_fixture_valid "$ROOT/plan.broken"
printf '%s\n' 'requirement:R1' 'slice:S1:R1:tracer:missing:-' > "$ROOT/plan.broken"
rejects plan_fixture_valid "$ROOT/plan.broken"
printf '%s\n' 'requirement:R1' 'slice:S1:R1:tracer:verify:self' > "$ROOT/plan.broken"
rejects plan_fixture_valid "$ROOT/plan.broken"
printf '%s\n' 'requirement:R1' 'slice:S2:R1:widen:verify:S1' \
  'slice:S1:R1:tracer:verify:-' > "$ROOT/plan.broken"
rejects plan_fixture_valid "$ROOT/plan.broken"
printf '%s\n' 'requirement:R1' 'slice:S1:R1:tracer:verify:-' \
  'slice:S2:R1:widen:verify:-' > "$ROOT/plan.broken"
rejects plan_refinement_valid "$ROOT/plan.full" "$ROOT/plan.broken"

contract_clean() {
  ! grep -qF 'Refinement may correct review findings.' "$1" \
    && ! grep -qF 'A proposal may edit before confirmation.' "$1" \
    && ! grep -qF 'Required content may be removed.' "$1" \
    && ! grep -qF 'Mandatory review may be canceled.' "$1" \
    && ! grep -qF 'Refinement may guess a target from Git state.' "$1" \
    && ! grep -qF 'An ambiguous plan source may proceed.' "$1" \
    && ! grep -qF 'A no-op may produce a proposal.' "$1" \
    && ! grep -qF 'Refinement may change another artifact.' "$1" \
    && ! grep -qF 'Style-only shortening is allowed.' "$1" \
    && ! grep -qF 'Refinement may assign a cyclomatic-complexity score to a document.' "$1" \
    && ! grep -qF 'Refinement may remove a required safety branch.' "$1"
}
cp "$REFINE" "$ROOT/refine.original"
red_proof() {
  local sentence="$1"
  cp "$ROOT/refine.original" "$ROOT/refine.broken"
  printf '%s\n' "$sentence" >> "$ROOT/refine.broken"
  eq "red-proof plants one defect" 1 "$(grep -cF "$sentence" "$ROOT/refine.broken")"
  rejects contract_clean "$ROOT/refine.broken"
}
red_proof 'Refinement may correct review findings.'
red_proof 'A proposal may edit before confirmation.'
red_proof 'Required content may be removed.'
red_proof 'Mandatory review may be canceled.'
red_proof 'Refinement may guess a target from Git state.'
red_proof 'An ambiguous plan source may proceed.'
red_proof 'A no-op may produce a proposal.'
red_proof 'Refinement may change another artifact.'
red_proof 'Style-only shortening is allowed.'
red_proof 'Refinement may assign a cyclomatic-complexity score to a document.'
red_proof 'Refinement may remove a required safety branch.'
cmp -s "$REFINE" "$ROOT/refine.original" && pass=$((pass + 1)) || fail=$((fail + 1))

echo "refine-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
