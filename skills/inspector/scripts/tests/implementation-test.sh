#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
KIND="$SKILL/kinds/implementation.md"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }
rejects() { if "$@"; then echo "FAIL expected rejection: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

# shellcheck disable=SC2016 # Markdown code spans are literal.
for needle in 'named diff, range, worktree, or commit' 'behavior matches the governing design' \
  'passing test could still encode the wrong implementation' 'claimed deletions and absence assertions' \
  'call sites and configuration' 'compatibility substrate forbidden by the design' \
  'None. Implementation never enters document `revise` or `refine`' \
  'The review phase never amends code'; do
  has "$KIND" "$needle" "implementation doctrine missing: $needle"
done
has "$REVIEW" 'Implementation target: inspect the full diff' "implementation review walk missing"
has "$REVIEW" '## Implementation textual action close' "implementation action tracer missing"
for needle in 'HEAD, staged diff, unstaged diff' 'reviewed untracked paths and contents' \
  'invent a snapshot or copy protocol' 'Render a fresh inline-only surface' \
  'same-pattern observations' 'full accumulated change'; do
  has "$REVIEW" "$needle" "implementation action doctrine missing: $needle"
done
for needle in 'control-flow complexity' 'changed authored functions' \
  'same analyzer identity and version' \
  'report the analyzer identity, version, configuration, population, and exclusions' \
  'function or method identity, repo-relative source location, and value at each endpoint' \
  'endpoint-unavailable' 'never apply the diff' 'raw value or threshold crossing'; do
  has "$KIND" "$needle" "implementation complexity doctrine missing: $needle"
done

review_fixture() {
  local file="$1" findings=0
  for marker in DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT \
    AVOIDABLE_BRANCHING_MISSING_PATHS; do
    if grep -qF "$marker" "$file"; then echo must-fix; findings=$((findings + 1)); fi
  done
  if grep -qF COMPLEXITY_RECOMMENDED "$file" || grep -qF RECOMMENDED "$file"; then
    echo recommended
    findings=$((findings + 1))
  fi
  [ "$findings" -gt 0 ] || echo clean
}
verdict() { case "$1" in *must-fix*) echo needs-rework ;; *recommended*) echo approve-with-changes ;; *) echo approve ;; esac; }

full_review_fixture() {
  local repository="$1" base="$2" after="$3" range_file="$ROOT/full-review.range" current_file="$ROOT/full-review.current"
  [ "$(git_head "$repository")" = "$after" ] || { echo endpoint-mismatch; return; }
  git -C "$repository" diff "$base" > "$range_file"
  grep -q '^+ORIGINAL_CHANGE$' "$range_file" || { echo baseline-too-narrow; return; }
  {
    cat "$repository/change.txt"
    cat "$repository/outside.txt"
  } > "$current_file"
  review_fixture "$current_file"
}
path_limited_review_fixture() {
  local repository="$1" current_file="$ROOT/path-limited.current"
  cp "$repository/change.txt" "$current_file"
  review_fixture "$current_file"
}
full_review_contract() {
  [ "$(full_review_fixture "$1" "$2" "$3")" != baseline-too-narrow ]
}

git_head() { git -C "$1" rev-parse HEAD; }
git_status() { git -C "$1" status --porcelain=v1 --untracked-files=all; }
destination_clean_at() {
  [ "$(git_head "$1")" = "$2" ] && [ -z "$(git_status "$1")" ]
}
capture_identity() {
  local destination="$1" output="$2" path
  {
    git_head "$destination"
    git -C "$destination" diff --cached --binary
    git -C "$destination" diff --binary
    git_status "$destination"
    git -C "$destination" ls-files --others --exclude-standard | while IFS= read -r path; do
      printf 'untracked:%s:' "$path"
      shasum "$destination/$path"
    done
  } > "$output"
}
same_identity() {
  local destination="$1" expected="$2" actual="$3"
  capture_identity "$destination" "$actual"
  cmp -s "$expected" "$actual"
}
start_isolated() {
  local destination="$1" expected_head="$2" isolated="$3"
  destination_clean_at "$destination" "$expected_head" || return 1
  [ ! -e "$isolated" ] || return 1
  git -C "$destination" worktree add -q "$isolated" -b fixture/isolated-fix "$expected_head"
}
integrate_returned() {
  local destination="$1" captured_head="$2" returned_commit="$3"
  git -C "$destination" diff --check "$captured_head..$returned_commit" >/dev/null || return 1
  git -C "$destination" show "$returned_commit:change.txt" | grep -qF ORIGINAL_CHANGE || return 1
  git -C "$destination" show "$returned_commit:change.txt" | grep -qF DESIGN_MISMATCH && return 1
  destination_clean_at "$destination" "$captured_head" || return 1
  git -C "$destination" merge --ff-only "$returned_commit" >/dev/null
}
normalize_trace_code() {
  local answer compact
  answer="$(printf '%s' "$1" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr '[:lower:]' '[:upper:]')"
  compact="$(printf '%s' "$answer" | LC_ALL=C tr -d '[:space:],-')"
  [ "$compact" = 1AR ] || return 1
  printf '%s\n' '1-A-R'
}
route_from_repository() {
  local destination="$1" endpoint="$2" isolated="$3"
  if command -v git >/dev/null 2>&1 && destination_clean_at "$destination" "$endpoint" \
    && [ ! -e "$isolated" ]; then
    echo isolated
  else
    echo inline
  fi
}
destination_route() {
  local destination="$1" endpoint="$2" isolated="$3"
  git -C "$destination" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo reduced-surface; return; }
  route_from_repository "$destination" "$endpoint" "$isolated"
}
replace_isolated_with_inline() {
  printf '%s\n' "$1" | sed 's/-A-/-I-/'
}
prewriter_isolation_attempt() {
  local destination="$1" expected_identity="$2" current_identity="$3" endpoint="$4"
  local isolated="$5" executor="$6" confirmed="$7" inline
  same_identity "$destination" "$expected_identity" "$current_identity" \
    || { echo fresh-review:drift; return; }
  if ! command -v "$executor" >/dev/null 2>&1; then
    inline="$(replace_isolated_with_inline "$confirmed")"
    printf 'reconfirm:%s\n' "$inline"
    return
  fi
  if ! start_isolated "$destination" "$endpoint" "$isolated" 2>/dev/null; then
    inline="$(replace_isolated_with_inline "$confirmed")"
    printf 'reconfirm:%s\n' "$inline"
    return
  fi
  echo writer-ready
}
writer_failure_transition() {
  local isolated="$1"
  [ -f "$isolated/.writer-started" ] && echo stop:partial:unreviewed || echo pre-writer
}
apply_two_finding_package() {
  local checkout="$1" marker
  for marker in FINDING_ONE FINDING_TWO; do
    if [ "$marker" = FINDING_TWO ]; then return 1; fi
    printf '%s\n' "$marker" >> "$checkout/change.txt"
  done
}
trace_contract() {
  local trace="$1" base="$2" reviewed_after="$3" returned="$4" fresh_verdict="$5" expected
  expected="$(printf '%s\n' \
    'verdict:needs-rework' \
    'confirmed:1-A-R' \
    "pre-write:$reviewed_after:clean" \
    "isolated-start:$reviewed_after" \
    "writer-return:$returned:verified" \
    "primary-inspect:$returned" \
    "primary-verify:$returned" \
    "pre-integration:$reviewed_after:clean" \
    "integrated:$returned" \
    "re-review-base:$base" \
    "re-review-after:$returned" \
    're-review-scope:complete' \
    "fresh-verdict:$fresh_verdict" \
    "fresh-action-close:$fresh_verdict")"
  [ "$(cat "$trace")" = "$expected" ]
}

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
printf '%s\n' DESIGN_MISMATCH FALSE_GREEN MISSED_CALL_SITE FORBIDDEN_COMPAT RECOMMENDED > "$ROOT/bad.diff"
before="$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
result="$(review_fixture "$ROOT/bad.diff")"
eq "five implementation findings" 5 "$(printf '%s\n' "$result" | wc -l | tr -d ' ')"
eq "four must-fix findings" 4 "$(printf '%s\n' "$result" | grep -c '^must-fix$')"
eq "one recommended finding" 1 "$(printf '%s\n' "$result" | grep -c '^recommended$')"
eq "must-fix implementation verdict" needs-rework "$(verdict "$result")"
eq "implementation fixture unmodified" "$before" "$(shasum "$ROOT/bad.diff" | awk '{print $1}')"
printf '%s\n' RECOMMENDED > "$ROOT/recommended.diff"
eq "recommended implementation verdict" approve-with-changes "$(verdict "$(review_fixture "$ROOT/recommended.diff")")"
: > "$ROOT/clean.diff"
eq "clean implementation verdict" approve "$(verdict "$(review_fixture "$ROOT/clean.diff")")"

DESTINATION="$ROOT/destination"
ISOLATED="$ROOT/isolated"
TRACE="$ROOT/trace"
mkdir "$DESTINATION"
git -C "$DESTINATION" init -q
git -C "$DESTINATION" config user.name fixture
git -C "$DESTINATION" config user.email fixture@example.invalid
printf '%s\n' BASE > "$DESTINATION/change.txt"
printf '%s\n' OUTSIDE_BASE > "$DESTINATION/outside.txt"
git -C "$DESTINATION" add change.txt outside.txt
git -C "$DESTINATION" commit -qm base
base_endpoint="$(git_head "$DESTINATION")"
printf '%s\n' DESIGN_MISMATCH ORIGINAL_CHANGE > "$DESTINATION/change.txt"
printf '%s\n' OUTSIDE_BASE RECOMMENDED > "$DESTINATION/outside.txt"
git -C "$DESTINATION" add change.txt outside.txt
git -C "$DESTINATION" commit -qm reviewed
reviewed_after="$(git_head "$DESTINATION")"
destination_before="$(shasum "$DESTINATION/change.txt" | awk '{print $1}')"
capture_identity "$DESTINATION" "$ROOT/reviewed.identity"
eq "real destination resolves eligible isolation" isolated \
  "$(destination_route "$DESTINATION" "$reviewed_after" "$ISOLATED")"
eq "missing destination renders reduced surface" reduced-surface \
  "$(destination_route "$ROOT/not-a-repository" "$reviewed_after" "$ISOLATED")"

DIRTY_ROUTE="$ROOT/dirty-route"
git clone -q "$DESTINATION" "$DIRTY_ROUTE"
printf '%s\n' DIRTY_ROUTE >> "$DIRTY_ROUTE/change.txt"
eq "dirty destination derives inline-only route" inline \
  "$(destination_route "$DIRTY_ROUTE" "$reviewed_after" "$ROOT/dirty-route-isolated")"

assert_isolation_start_drift() {
  local kind="$1" drift_repo="$ROOT/drift-$1" drift_isolated="$ROOT/drift-$1-isolated"
  git clone -q "$DESTINATION" "$drift_repo"
  git -C "$drift_repo" config user.name fixture
  git -C "$drift_repo" config user.email fixture@example.invalid
  case "$kind" in
    head)
      printf '%s\n' HEAD_DRIFT > "$drift_repo/head.txt"
      git -C "$drift_repo" add head.txt
      git -C "$drift_repo" commit -qm head-drift
      eq "head drift plants one commit" 1 \
        "$(git -C "$drift_repo" rev-list --count "$reviewed_after..HEAD")"
      ;;
    staged)
      printf '%s\n' STAGED_DRIFT > "$drift_repo/staged.txt"
      git -C "$drift_repo" add staged.txt
      eq "staged drift plants one path" 1 \
        "$(git -C "$drift_repo" diff --cached --name-only | grep -c '^staged.txt$')"
      ;;
    unstaged)
      printf '%s\n' UNSTAGED_DRIFT >> "$drift_repo/change.txt"
      eq "unstaged drift plants one path" 1 \
        "$(git -C "$drift_repo" diff --name-only | grep -c '^change.txt$')"
      ;;
    untracked)
      printf '%s\n' UNTRACKED_DRIFT > "$drift_repo/untracked.txt"
      eq "untracked drift plants one path" 1 \
        "$(git -C "$drift_repo" ls-files --others --exclude-standard | grep -c '^untracked.txt$')"
      ;;
  esac
  rejects start_isolated "$drift_repo" "$reviewed_after" "$drift_isolated"
  if [ ! -e "$drift_isolated" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL $kind drift created isolation" >&2
    fail=$((fail + 1))
  fi
}
for drift_kind in head staged unstaged untracked; do
  assert_isolation_start_drift "$drift_kind"
done

DIRTY_DESTINATION="$ROOT/dirty-destination"
git clone -q "$DESTINATION" "$DIRTY_DESTINATION"
printf '%s\n' DIRTY_REVIEW_STATE >> "$DIRTY_DESTINATION/change.txt"
cp "$DIRTY_DESTINATION/change.txt" "$ROOT/dirty.before"
capture_identity "$DIRTY_DESTINATION" "$ROOT/dirty.identity"
dirty_status="$(git_status "$DIRTY_DESTINATION")"
sed 's/DIRTY_REVIEW_STATE/DIRTY_CHANGED_STATE/' "$DIRTY_DESTINATION/change.txt" \
  > "$ROOT/dirty.next"
mv "$ROOT/dirty.next" "$DIRTY_DESTINATION/change.txt"
eq "dirty-content drift keeps status-path population" "$dirty_status" \
  "$(git_status "$DIRTY_DESTINATION")"
rejects same_identity "$DIRTY_DESTINATION" "$ROOT/dirty.identity" "$ROOT/dirty.current"
cp "$ROOT/dirty.before" "$DIRTY_DESTINATION/change.txt"
if same_identity "$DIRTY_DESTINATION" "$ROOT/dirty.identity" "$ROOT/dirty.current"; then
  pass=$((pass + 1))
else
  echo "FAIL dirty identity not restored" >&2
  fail=$((fail + 1))
fi

eq "missing executor preserves scope and N while replacing route" reconfirm:2-I-N \
  "$(prewriter_isolation_attempt "$DESTINATION" "$ROOT/reviewed.identity" \
    "$ROOT/prewriter.current" "$reviewed_after" "$ROOT/missing-executor-isolated" \
    fixture-command-that-does-not-exist 2-A-N)"
CHECKOUT_BLOCKED="$ROOT/checkout-blocked"
mkdir "$CHECKOUT_BLOCKED"
eq "checkout creation failure preserves scope and R while replacing route" reconfirm:1-I-R \
  "$(prewriter_isolation_attempt "$DESTINATION" "$ROOT/reviewed.identity" \
    "$ROOT/prewriter.current" "$reviewed_after" "$CHECKOUT_BLOCKED" git 1-A-R)"
printf '%s\n' FALLBACK_DRIFT >> "$DESTINATION/change.txt"
eq "destination drift refuses pre-writer fallback" fresh-review:drift \
  "$(prewriter_isolation_attempt "$DESTINATION" "$ROOT/reviewed.identity" \
    "$ROOT/prewriter.current" "$reviewed_after" "$ROOT/drift-fallback-isolated" git 1-A-R)"
git -C "$DESTINATION" restore change.txt
if same_identity "$DESTINATION" "$ROOT/reviewed.identity" "$ROOT/current.identity"; then
  pass=$((pass + 1))
else
  echo "FAIL fallback drift identity not restored" >&2
  fail=$((fail + 1))
fi

: > "$TRACE"
raw_reply='1-A-R'
normalized_selection="$(normalize_trace_code "$raw_reply")"
eq "raw reply normalizes before remediation" 1-A-R "$normalized_selection"
selected_route="$(route_from_repository "$DESTINATION" "$reviewed_after" "$ISOLATED")"
eq "real repository selects isolated route" isolated "$selected_route"
case "$normalized_selection:$selected_route" in
  1-A-R:isolated) ;;
  *) echo "FAIL normalized selection did not select the derived route" >&2; fail=$((fail + 1)) ;;
esac
printf '%s\n' 'verdict:needs-rework' \
  "confirmed:$normalized_selection" >> "$TRACE"

cp "$DESTINATION/change.txt" "$ROOT/change.before"
printf '%s\n' PRE_WRITE_DRIFT >> "$DESTINATION/change.txt"
eq "pre-write drift plant count" 1 "$(grep -c '^PRE_WRITE_DRIFT$' "$DESTINATION/change.txt")"
rejects start_isolated "$DESTINATION" "$reviewed_after" "$ISOLATED"
if [ ! -e "$ISOLATED" ]; then
  pass=$((pass + 1))
else
  echo "FAIL drift created isolation" >&2
  fail=$((fail + 1))
fi
cp "$ROOT/change.before" "$DESTINATION/change.txt"
eq "pre-write drift restoration" "$destination_before" \
  "$(shasum "$DESTINATION/change.txt" | awk '{print $1}')"
if destination_clean_at "$DESTINATION" "$reviewed_after"; then
  pass=$((pass + 1))
else
  echo "FAIL destination not restored" >&2
  fail=$((fail + 1))
fi

printf '%s\n' SAME_PATH_DRIFT >> "$DESTINATION/change.txt"
eq "same-path drift preserves status population" ' M change.txt' "$(git_status "$DESTINATION")"
rejects same_identity "$DESTINATION" "$ROOT/reviewed.identity" "$ROOT/current.identity"
cp "$ROOT/change.before" "$DESTINATION/change.txt"
if same_identity "$DESTINATION" "$ROOT/reviewed.identity" "$ROOT/current.identity"; then
  pass=$((pass + 1))
else
  echo "FAIL identity not restored" >&2
  fail=$((fail + 1))
fi

start_isolated "$DESTINATION" "$reviewed_after" "$ISOLATED"
printf '%s\n' "pre-write:$reviewed_after:clean" "isolated-start:$reviewed_after" >> "$TRACE"
awk '$0 != "DESIGN_MISMATCH"' "$ISOLATED/change.txt" > "$ROOT/next"
mv "$ROOT/next" "$ISOLATED/change.txt"
git -C "$ISOLATED" add change.txt
git -C "$ISOLATED" commit -qm fix
returned_commit="$(git_head "$ISOLATED")"
grep -qF RECOMMENDED "$ISOLATED/outside.txt" && ! grep -qF DESIGN_MISMATCH "$ISOLATED/change.txt" \
  && writer_verified=yes || writer_verified=no
eq "isolated writer verification" yes "$writer_verified"
eq "writer leaves destination head" "$reviewed_after" "$(git_head "$DESTINATION")"
eq "writer leaves destination clean" "" "$(git_status "$DESTINATION")"
eq "writer leaves destination bytes" "$destination_before" \
  "$(shasum "$DESTINATION/change.txt" | awk '{print $1}')"
printf '%s\n' "writer-return:$returned_commit:verified" >> "$TRACE"

if git -C "$DESTINATION" diff --check "$reviewed_after..$returned_commit"; then
  inspected=yes
else
  inspected=no
fi
if git -C "$DESTINATION" show "$returned_commit:change.txt" | grep -qF ORIGINAL_CHANGE \
  && ! git -C "$DESTINATION" show "$returned_commit:change.txt" | grep -qF DESIGN_MISMATCH; then
  primary_verified=yes
else
  primary_verified=no
fi
eq "primary inspection derives from returned diff" yes "$inspected"
eq "primary verification derives from returned content" yes "$primary_verified"
printf '%s\n' "primary-inspect:$returned_commit" "primary-verify:$returned_commit" >> "$TRACE"

assert_integration_drift() {
  local kind="$1" drift_repo="$ROOT/integration-$1"
  git clone -q "$DESTINATION" "$drift_repo"
  git -C "$drift_repo" config user.name fixture
  git -C "$drift_repo" config user.email fixture@example.invalid
  git -C "$drift_repo" cat-file -e "$returned_commit^{commit}"
  case "$kind" in
    head)
      printf '%s\n' HEAD_DRIFT > "$drift_repo/head.txt"
      git -C "$drift_repo" add head.txt
      git -C "$drift_repo" commit -qm head-drift
      eq "integration head drift plants one commit" 1 \
        "$(git -C "$drift_repo" rev-list --count "$reviewed_after..HEAD")"
      ;;
    staged)
      printf '%s\n' STAGED_DRIFT > "$drift_repo/staged.txt"
      git -C "$drift_repo" add staged.txt
      eq "integration staged drift plants one path" 1 \
        "$(git -C "$drift_repo" diff --cached --name-only | grep -c '^staged.txt$')"
      ;;
    unstaged)
      printf '%s\n' UNSTAGED_DRIFT >> "$drift_repo/change.txt"
      eq "integration unstaged drift plants one path" 1 \
        "$(git -C "$drift_repo" diff --name-only | grep -c '^change.txt$')"
      ;;
    untracked)
      printf '%s\n' UNTRACKED_DRIFT > "$drift_repo/untracked.txt"
      eq "integration untracked drift plants one path" 1 \
        "$(git -C "$drift_repo" ls-files --others --exclude-standard | grep -c '^untracked.txt$')"
      ;;
  esac
  rejects integrate_returned "$drift_repo" "$reviewed_after" "$returned_commit"
  if git -C "$drift_repo" merge-base --is-ancestor "$returned_commit" HEAD; then
    echo "FAIL $kind integration drift applied returned commit" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}
for drift_kind in head staged unstaged untracked; do
  assert_integration_drift "$drift_kind"
done

printf '%s\n' "pre-integration:$reviewed_after:clean" >> "$TRACE"
integrate_returned "$DESTINATION" "$reviewed_after" "$returned_commit"
printf '%s\n' "integrated:$returned_commit" \
  "re-review-base:$base_endpoint" \
  "re-review-after:$returned_commit" \
  're-review-scope:complete' >> "$TRACE"
fresh_result="$(full_review_fixture "$DESTINATION" "$base_endpoint" "$returned_commit")"
fresh_verdict="$(verdict "$fresh_result")"
eq "full re-review keeps original change" 1 "$(grep -c '^ORIGINAL_CHANGE$' "$DESTINATION/change.txt")"
eq "full re-review sees remaining recommendation" approve-with-changes "$fresh_verdict"
eq "path-limited mutant misses outside recommendation" approve \
  "$(verdict "$(path_limited_review_fixture "$DESTINATION")")"
eq "fix-delta baseline is rejected as too narrow" baseline-too-narrow \
  "$(full_review_fixture "$DESTINATION" "$reviewed_after" "$returned_commit")"
rejects full_review_contract "$DESTINATION" "$reviewed_after" "$returned_commit"
printf '%s\n' OUTSIDE_FIX_MUTATION DESIGN_MISMATCH >> "$DESTINATION/outside.txt"
eq "full re-review sees mutation outside fix delta" needs-rework \
  "$(verdict "$(full_review_fixture "$DESTINATION" "$base_endpoint" "$returned_commit")")"
git -C "$DESTINATION" restore outside.txt
printf '%s\n' "fresh-verdict:$fresh_verdict" "fresh-action-close:$fresh_verdict" >> "$TRACE"
if trace_contract "$TRACE" "$base_endpoint" "$reviewed_after" "$returned_commit" "$fresh_verdict"; then
  pass=$((pass + 1))
else
  echo "FAIL implementation action trace" >&2
  fail=$((fail + 1))
fi

cp "$TRACE" "$ROOT/trace.original"
awk -v row="pre-write:$reviewed_after:clean" '$0 != row' "$TRACE" > "$ROOT/trace.broken"
eq "pre-write trace red-proof removes one row" 0 \
  "$(grep -cF "pre-write:$reviewed_after:clean" "$ROOT/trace.broken" || true)"
rejects trace_contract "$ROOT/trace.broken" "$base_endpoint" "$reviewed_after" "$returned_commit" "$fresh_verdict"
awk -v row="pre-integration:$reviewed_after:clean" '$0 != row' "$TRACE" > "$ROOT/trace.broken"
eq "pre-integration trace red-proof removes one row" 0 \
  "$(grep -cF "pre-integration:$reviewed_after:clean" "$ROOT/trace.broken" || true)"
rejects trace_contract "$ROOT/trace.broken" "$base_endpoint" "$reviewed_after" "$returned_commit" "$fresh_verdict"
awk -v row="re-review-base:$base_endpoint" '$0 != row' "$TRACE" > "$ROOT/trace.broken"
eq "same-base red-proof removes one row" 0 \
  "$(grep -cF "re-review-base:$base_endpoint" "$ROOT/trace.broken" || true)"
rejects trace_contract "$ROOT/trace.broken" "$base_endpoint" "$reviewed_after" "$returned_commit" "$fresh_verdict"
awk -v row="fresh-action-close:$fresh_verdict" '$0 != row' "$TRACE" > "$ROOT/trace.broken"
eq "fresh-close red-proof removes one row" 0 \
  "$(grep -cF "fresh-action-close:$fresh_verdict" "$ROOT/trace.broken" || true)"
rejects trace_contract "$ROOT/trace.broken" "$base_endpoint" "$reviewed_after" "$returned_commit" "$fresh_verdict"
cmp -s "$TRACE" "$ROOT/trace.original" && pass=$((pass + 1)) || fail=$((fail + 1))
git -C "$DESTINATION" worktree remove "$ISOLATED"

PARTIAL="$ROOT/partial-package"
git clone -q "$DESTINATION" "$PARTIAL"
printf '%s\n' started > "$PARTIAL/.writer-started"
if apply_two_finding_package "$PARTIAL"; then
  partial_result=complete
else
  partial_result="$(writer_failure_transition "$PARTIAL")"
fi
eq "second-finding failure stops partial package" stop:partial:unreviewed "$partial_result"
eq "partial package applied first finding" 1 "$(grep -c '^FINDING_ONE$' "$PARTIAL/change.txt")"
eq "partial package did not apply second finding" 0 \
  "$(grep -c '^FINDING_TWO$' "$PARTIAL/change.txt" || true)"
eq "partial package never starts re-review" 0 \
  "$(find "$PARTIAL" -name '.re-review-started' | wc -l | tr -d ' ')"

assert_bad_return() {
  local kind="$1" bad_worktree="$ROOT/bad-$1-return" bad_destination="$ROOT/bad-$1-destination"
  local bad_commit result
  git -C "$DESTINATION" worktree add -q "$bad_worktree" -b "fixture/bad-$kind" "$returned_commit"
  case "$kind" in
    inspection) printf 'TRAILING_SPACE \n' >> "$bad_worktree/change.txt" ;;
    verification)
      awk '$0 != "ORIGINAL_CHANGE"' "$bad_worktree/change.txt" > "$ROOT/bad-return.next"
      mv "$ROOT/bad-return.next" "$bad_worktree/change.txt"
      ;;
  esac
  git -C "$bad_worktree" add change.txt
  git -C "$bad_worktree" commit -qm "bad-$kind"
  bad_commit="$(git_head "$bad_worktree")"
  git clone -q "$DESTINATION" "$bad_destination"
  if integrate_returned "$bad_destination" "$returned_commit" "$bad_commit"; then
    result=integrated
  else
    result="stop:$kind:unreviewed"
  fi
  eq "failed primary $kind stops without fallback" "stop:$kind:unreviewed" "$result"
  eq "failed primary $kind leaves result unapplied" "$returned_commit" \
    "$(git_head "$bad_destination")"
  git -C "$DESTINATION" worktree remove "$bad_worktree"
}
assert_bad_return inspection
assert_bad_return verification

safety_matrix() {
  printf '%s\n' \
    'missing-executor:reconfirm:2-I-N' \
    'checkout-failure:reconfirm:1-I-R' \
    'destination-drift:fresh-review:drift' \
    'writer-started:stop:partial:unreviewed' \
    'inspection:stop:inspection:unreviewed' \
    'verification:stop:verification:unreviewed'
}
safety_matrix_contract() { [ "$(cat "$1")" = "$(safety_matrix)" ]; }
safety_matrix > "$ROOT/safety.original"
cp "$ROOT/safety.original" "$ROOT/safety.saved"
for mutation in \
  'missing-executor:reconfirm:2-I-N|missing-executor:inline-now' \
  'checkout-failure:reconfirm:1-I-R|checkout-failure:reconfirm:1-I-N' \
  'destination-drift:fresh-review:drift|destination-drift:reconfirm:1-I-R' \
  'writer-started:stop:partial:unreviewed|writer-started:reconfirm:1-I-R' \
  'inspection:stop:inspection:unreviewed|inspection:reconfirm:1-I-R' \
  'verification:stop:verification:unreviewed|verification:reconfirm:1-I-R'; do
  before_row="${mutation%%|*}" after_row="${mutation#*|}"
  sed "s/^$before_row$/$after_row/" "$ROOT/safety.original" > "$ROOT/safety.broken"
  eq "failure red-proof plants one unsafe transition" 1 \
    "$(grep -cF "$after_row" "$ROOT/safety.broken")"
  rejects safety_matrix_contract "$ROOT/safety.broken"
done
cmp -s "$ROOT/safety.original" "$ROOT/safety.saved" && pass=$((pass + 1)) || fail=$((fail + 1))

printf '%s\n' AVOIDABLE_BRANCHING_MISSING_PATHS > "$ROOT/complex.diff"
eq "avoidable branching is material" needs-rework "$(verdict "$(review_fixture "$ROOT/complex.diff")")"
printf '%s\n' RAW_SCORE_ONLY > "$ROOT/raw-score.diff"
eq "raw score is not a finding" approve "$(verdict "$(review_fixture "$ROOT/raw-score.diff")")"
printf '%s\n' JUSTIFIED_EXHAUSTIVE_DISPATCH > "$ROOT/exhaustive.diff"
eq "justified exhaustive dispatch is not a finding" approve "$(verdict "$(review_fixture "$ROOT/exhaustive.diff")")"
printf '%s\n' ANALYZER_UNAVAILABLE > "$ROOT/unavailable.diff"
eq "unavailable analyzer is not a finding" approve "$(verdict "$(review_fixture "$ROOT/unavailable.diff")")"

delta_route() {
  case "$1:$2" in
    materialized:materialized|absent:materialized|materialized:absent) echo compare-read-only ;;
    *) echo qualitative:endpoint-unavailable ;;
  esac
}
eq "materialized endpoints compare" compare-read-only "$(delta_route materialized materialized)"
eq "added function uses absent before" compare-read-only "$(delta_route absent materialized)"
eq "deleted function uses absent after" compare-read-only "$(delta_route materialized absent)"
eq "missing endpoint falls back" qualitative:endpoint-unavailable "$(delta_route unavailable materialized)"

analyzer_delta_valid() {
  [ "$1" = "$6" ] && [ "$2" = "$7" ] && [ "$3" = "$8" ] \
    && [ "$4" = "$9" ] && [ "$5" = "${10}" ]
}
analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a src generated \
  && pass=$((pass + 1)) || fail=$((fail + 1))
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-b v2 cfg-a src generated
rejects analyzer_delta_valid tool-a v1 cfg-a src generated tool-a v2 cfg-a src generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-b src generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a lib generated
rejects analyzer_delta_valid tool-a v2 cfg-a src generated tool-a v2 cfg-a src vendor

contract_clean() {
  ! grep -qF 'A raw complexity score is automatically a finding.' "$1" \
    && ! grep -qF 'Apply the diff to construct an analyzer endpoint.' "$1" \
    && ! grep -qF 'Implementation review may remediate code before confirmation.' "$1" \
    && ! grep -qF 'A numeric delta may omit analyzer identity and population.' "$1" \
    && ! grep -qF 'A numeric complexity row may omit function identity and source location.' "$1"
}
cp "$KIND" "$ROOT/implementation.original"
red_proof() {
  local sentence="$1"
  cp "$ROOT/implementation.original" "$ROOT/implementation.broken"
  printf '%s\n' "$sentence" >> "$ROOT/implementation.broken"
  eq "complexity red-proof plants one defect" 1 \
    "$(grep -cF "$sentence" "$ROOT/implementation.broken")"
  rejects contract_clean "$ROOT/implementation.broken"
}
red_proof 'A raw complexity score is automatically a finding.'
red_proof 'Apply the diff to construct an analyzer endpoint.'
red_proof 'Implementation review may remediate code before confirmation.'
red_proof 'A numeric delta may omit analyzer identity and population.'
red_proof 'A numeric complexity row may omit function identity and source location.'
cmp -s "$KIND" "$ROOT/implementation.original" && pass=$((pass + 1)) || fail=$((fail + 1))

echo "implementation-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
