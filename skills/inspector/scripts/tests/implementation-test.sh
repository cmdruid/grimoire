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
# shellcheck disable=SC2016 # Markdown code spans are literal.
for needle in 'HEAD, staged diff, unstaged diff' 'reviewed untracked paths and contents' \
  'invent a snapshot or copy protocol' 'Render a fresh inline-only surface' \
  'same-pattern observations' 'full accumulated change' \
  'Offer `A` only when an isolated executor exists' \
  'state the specific failed eligibility reason'; do
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
  local repository="$1" base="$2" after="$3" path
  local range_file="$ROOT/full-review.range" current_file="$ROOT/full-review.current"
  [ "$(git_head "$repository")" = "$after" ] || { echo endpoint-mismatch; return; }
  git -C "$repository" diff "$base..$after" > "$range_file"
  grep -q '^+ORIGINAL_CHANGE$' "$range_file" || { echo baseline-too-narrow; return; }
  : > "$current_file"
  git -C "$repository" diff --name-only "$base..$after" | while IFS= read -r path; do
    printf 'path:%s\n' "$path"
    git -C "$repository" show "$after:$path" 2>/dev/null || printf 'deleted:%s\n' "$path"
  done > "$current_file"
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
full_review_worktree_population() {
  local repository="$1" base="$2"
  git -C "$repository" diff --name-only "$base..HEAD" | sed 's/^/committed:/'
  git -C "$repository" diff --cached --name-only | sed 's/^/staged:/'
  git -C "$repository" diff --name-only | sed 's/^/unstaged:/'
  git -C "$repository" ls-files --others --exclude-standard | sed 's/^/untracked:/'
}
full_review_worktree_fixture() {
  local repository="$1" base="$2" path
  local range_file="$ROOT/inline-review.range" paths_file="$ROOT/inline-review.paths"
  local current_file="$ROOT/inline-review.current"
  git -C "$repository" cat-file -e "$base^{commit}" 2>/dev/null \
    || { echo endpoint-mismatch; return; }
  git -C "$repository" diff "$base..HEAD" > "$range_file"
  grep -q '^+ORIGINAL_CHANGE$' "$range_file" || { echo baseline-too-narrow; return; }
  {
    git -C "$repository" diff --name-only "$base..HEAD"
    git -C "$repository" diff --cached --name-only
    git -C "$repository" diff --name-only
    git -C "$repository" ls-files --others --exclude-standard
  } | sort -u > "$paths_file"
  : > "$current_file"
  while IFS= read -r path; do
    printf 'path:%s\n' "$path"
    if [ -f "$repository/$path" ]; then
      cat "$repository/$path"
    else
      printf 'deleted:%s\n' "$path"
    fi
  done < "$paths_file" > "$current_file"
  review_fixture "$current_file"
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
verify_selected_package() {
  local repository="$1" captured_head="$2" returned_commit="$3" manifest="$4"
  local operation path marker expected="$ROOT/expected-paths.$$" actual="$ROOT/actual-paths.$$"
  local returned_blob="$ROOT/returned-blob.$$"
  : > "$expected"
  while IFS='|' read -r operation path marker; do
    [ -n "$operation" ] && [ -n "$path" ] && [ -n "$marker" ] || return 1
    printf '%s\n' "$path" >> "$expected"
    case "$operation" in
      remove)
        if git -C "$repository" show "$returned_commit:$path" 2>/dev/null | grep -qF "$marker"; then
          return 1
        fi
        ;;
      require)
        git -C "$repository" show "$returned_commit:$path" 2>/dev/null | grep -qF "$marker" \
          || return 1
        ;;
      exact)
        git -C "$repository" show "$returned_commit:$path" > "$returned_blob" 2>/dev/null \
          || return 1
        cmp -s "$marker" "$returned_blob" || return 1
        ;;
      *) return 1 ;;
    esac
  done < "$manifest"
  git -C "$repository" diff --name-only "$captured_head..$returned_commit" | sort -u > "$actual"
  sort -u "$expected" -o "$expected"
  cmp -s "$expected" "$actual"
}
inspect_returned_package() {
  local repository="$1" captured_head="$2" returned_commit="$3" manifest="$4"
  git -C "$repository" diff --check "$captured_head..$returned_commit" >/dev/null \
    && verify_selected_package "$repository" "$captured_head" "$returned_commit" "$manifest"
}
integrate_returned() {
  local destination="$1" captured_head="$2" returned_commit="$3" manifest="$4"
  inspect_returned_package "$destination" "$captured_head" "$returned_commit" "$manifest" || return 1
  destination_clean_at "$destination" "$captured_head" || return 1
  git -C "$destination" merge --ff-only "$returned_commit" >/dev/null
}
normalize_trace_code() {
  local answer compact
  answer="$(printf '%s' "$1" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr '[:lower:]' '[:upper:]')"
  compact="$(printf '%s' "$answer" | LC_ALL=C tr -d '[:space:],-')"
  case "$compact" in
    1AR) printf '%s\n' '1-A-R' ;;
    1IR) printf '%s\n' '1-I-R' ;;
    *) return 1 ;;
  esac
}
owns_endpoint() {
  local destination="$1" endpoint="$2" branch
  git -C "$destination" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  git -C "$destination" cat-file -e "$endpoint^{commit}" 2>/dev/null || return 1
  branch="$(git -C "$destination" branch --show-current)"
  [ -n "$branch" ] || return 1
  [ "$(git_head "$destination")" = "$endpoint" ] || return 1
  git -C "$destination" merge-base --is-ancestor "$endpoint" "$branch"
}
resolve_destination() {
  local endpoint="$1" candidate resolved='' count=0
  shift
  for candidate in "$@"; do
    if owns_endpoint "$candidate" "$endpoint"; then
      resolved="$candidate"
      count=$((count + 1))
    fi
  done
  [ "$count" -eq 1 ] || return 1
  printf '%s\n' "$resolved"
}
route_from_repository() {
  local destination="$1" endpoint="$2" isolated="$3" executor="$4" parent
  command -v "$executor" >/dev/null 2>&1 || { echo inline:executor-unavailable; return; }
  git -C "$destination" cat-file -e "$endpoint^{commit}" 2>/dev/null \
    || { echo inline:endpoint-not-committed; return; }
  destination_clean_at "$destination" "$endpoint" \
    || { echo inline:destination-not-clean-at-endpoint; return; }
  case "$isolated" in */*) parent="${isolated%/*}" ;; *) parent=. ;; esac
  if [ -e "$isolated" ] || [ ! -d "$parent" ] || [ ! -w "$parent" ] \
    || ! git -C "$destination" worktree list --porcelain >/dev/null 2>&1; then
    echo inline:checkout-unavailable
    return
  fi
  echo isolated
}
render_route_reason() {
  case "$1" in
    isolated) echo 'A. Use an isolated implementation agent (default)' ;;
    inline:*)
      printf 'Isolation unavailable: %s.\n' \
        "$(printf '%s' "${1#inline:}" | tr '-' ' ')"
      ;;
    *) return 1 ;;
  esac
}
destination_route() {
  local endpoint="$1" isolated="$2" executor="$3" destination
  shift 3
  destination="$(resolve_destination "$endpoint" "$@")" \
    || { echo reduced-surface:destination-unresolved; return; }
  route_from_repository "$destination" "$endpoint" "$isolated" "$executor"
}
reduced_state_transition() {
  local answer="$1" verdict="$2" recommendations="$3" scope
  case "$answer" in
    yes)
      [ "$verdict" = approve-with-changes ] && { echo unchanged:1; return; }
      scope=1
      ;;
    'fix must-fix findings') scope=1 ;;
    'fix all findings') scope=2 ;;
    'fix recommended changes') [ "$verdict" = needs-rework ] && scope=3 || scope=2 ;;
    'make no changes') scope=4 ;;
    'return as-is') scope=1 ;;
    1|2|3|4) scope="$answer" ;;
    *) echo ask:no-write; return ;;
  esac
  case "$verdict:$recommendations:$scope" in
    needs-rework:yes:1|needs-rework:yes:2|needs-rework:yes:3|needs-rework:yes:4|needs-rework:no:1|needs-rework:no:4|approve-with-changes:*:1|approve-with-changes:*:2) ;;
    *) echo ask:no-write; return ;;
  esac
  case "$verdict:$scope" in
    needs-rework:4|approve-with-changes:1) printf 'unchanged:%s\n' "$scope" ;;
    *) printf 'pending-scope:%s\n' "$scope" ;;
  esac
}
assert_reduced_no_write() {
  local label="$1" destination="$2" expected="$3" answer="$4" verdict="$5" recommendations="$6"
  local before="$ROOT/reduced-$label.before" after="$ROOT/reduced-$label.after" actual
  capture_identity "$destination" "$before"
  actual="$(reduced_state_transition "$answer" "$verdict" "$recommendations")"
  eq "reduced $label transition" "$expected" "$actual"
  if same_identity "$destination" "$before" "$after"; then
    pass=$((pass + 1))
  else
    echo "FAIL reduced $label changed repository identity" >&2
    fail=$((fail + 1))
  fi
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
EXECUTOR="$ROOT/isolated-executor"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$EXECUTOR"
chmod +x "$EXECUTOR"
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
PREFLIGHT_HOOKS="$ROOT/preflight-hooks"
PREFLIGHT_HOOK_MARKER="$ROOT/preflight-hook-ran"
mkdir "$PREFLIGHT_HOOKS"
printf '#!/bin/sh\n: > "%s"\n' "$PREFLIGHT_HOOK_MARKER" > "$PREFLIGHT_HOOKS/post-checkout"
chmod +x "$PREFLIGHT_HOOKS/post-checkout"
git -C "$DESTINATION" config core.hooksPath "$PREFLIGHT_HOOKS"
git -C "$DESTINATION" worktree list --porcelain > "$ROOT/worktrees.before"
eligible_route="$(destination_route "$reviewed_after" "$ISOLATED" "$EXECUTOR" "$DESTINATION")"
eq "real destination resolves eligible isolation" isolated \
  "$eligible_route"
git -C "$DESTINATION" worktree list --porcelain > "$ROOT/worktrees.after"
cmp -s "$ROOT/worktrees.before" "$ROOT/worktrees.after" && pass=$((pass + 1)) || fail=$((fail + 1))
if [ ! -e "$PREFLIGHT_HOOK_MARKER" ]; then
  pass=$((pass + 1))
else
  echo "FAIL eligibility preflight ran checkout hook" >&2
  fail=$((fail + 1))
fi
git -C "$DESTINATION" config --unset core.hooksPath
eq "missing destination renders reduced surface" reduced-surface:destination-unresolved \
  "$(destination_route "$reviewed_after" "$ISOLATED" "$EXECUTOR" "$ROOT/not-a-repository")"

SECOND_OWNER="$ROOT/second-owner"
git clone -q "$DESTINATION" "$SECOND_OWNER"
eq "ambiguous destination ownership renders reduced surface" reduced-surface:destination-unresolved \
  "$(destination_route "$reviewed_after" "$ISOLATED" "$EXECUTOR" "$DESTINATION" "$SECOND_OWNER")"
DETACHED_OWNER="$ROOT/detached-owner"
git clone -q "$DESTINATION" "$DETACHED_OWNER"
git -C "$DETACHED_OWNER" checkout --detach -q "$reviewed_after"
eq "detached endpoint does not establish ownership" reduced-surface:destination-unresolved \
  "$(destination_route "$reviewed_after" "$ISOLATED" "$EXECUTOR" "$DETACHED_OWNER")"
UNOWNED="$ROOT/unowned"
git clone -q "$DESTINATION" "$UNOWNED"
git -C "$UNOWNED" checkout -q -B fixture/unowned "$base_endpoint"
eq "branch at another endpoint does not establish ownership" reduced-surface:destination-unresolved \
  "$(destination_route "$reviewed_after" "$ISOLATED" "$EXECUTOR" "$UNOWNED")"

assert_reduced_no_write needs-yes "$DESTINATION" pending-scope:1 yes needs-rework yes
assert_reduced_no_write needs-one "$DESTINATION" pending-scope:1 1 needs-rework yes
assert_reduced_no_write needs-all "$DESTINATION" pending-scope:2 2 needs-rework yes
assert_reduced_no_write needs-recommended "$DESTINATION" pending-scope:3 \
  'fix recommended changes' needs-rework yes
assert_reduced_no_write needs-exit "$DESTINATION" unchanged:4 4 needs-rework yes
assert_reduced_no_write recommended-yes "$DESTINATION" unchanged:1 yes approve-with-changes yes
assert_reduced_no_write recommended-fix "$DESTINATION" pending-scope:2 2 approve-with-changes yes
assert_reduced_no_write unavailable-scope "$DESTINATION" ask:no-write 2 needs-rework no
assert_reduced_no_write route-prose "$DESTINATION" ask:no-write \
  'fix must-fix inline' needs-rework yes

eq "missing executor states inline-only reason" inline:executor-unavailable \
  "$(route_from_repository "$DESTINATION" "$reviewed_after" "$ROOT/missing-executor-probe" fixture-command-that-does-not-exist)"
eq "derived executor reason reaches inline-only surface" \
  'Isolation unavailable: executor unavailable.' \
  "$(render_route_reason "$(route_from_repository "$DESTINATION" "$reviewed_after" "$ROOT/reason-executor" fixture-command-that-does-not-exist)")"
eq "uncommitted endpoint states inline-only reason" inline:endpoint-not-committed \
  "$(route_from_repository "$DESTINATION" WORKTREE "$ROOT/uncommitted-probe" "$EXECUTOR")"
eq "derived endpoint reason reaches inline-only surface" \
  'Isolation unavailable: endpoint not committed.' \
  "$(render_route_reason "$(route_from_repository "$DESTINATION" WORKTREE "$ROOT/reason-endpoint" "$EXECUTOR")")"

DIRTY_ROUTE="$ROOT/dirty-route"
git clone -q "$DESTINATION" "$DIRTY_ROUTE"
printf '%s\n' DIRTY_ROUTE >> "$DIRTY_ROUTE/change.txt"
eq "dirty destination states inline-only reason" inline:destination-not-clean-at-endpoint \
  "$(route_from_repository "$DIRTY_ROUTE" "$reviewed_after" "$ROOT/dirty-route-isolated" "$EXECUTOR")"
eq "derived clean-state reason reaches inline-only surface" \
  'Isolation unavailable: destination not clean at endpoint.' \
  "$(render_route_reason "$(route_from_repository "$DIRTY_ROUTE" "$reviewed_after" "$ROOT/reason-dirty" "$EXECUTOR")")"
CHECKOUT_ROUTE_BLOCKED="$ROOT/checkout-route-blocked"
mkdir "$CHECKOUT_ROUTE_BLOCKED"
eq "blocked checkout states inline-only reason" inline:checkout-unavailable \
  "$(route_from_repository "$DESTINATION" "$reviewed_after" "$CHECKOUT_ROUTE_BLOCKED" "$EXECUTOR")"
eq "derived checkout reason reaches inline-only surface" \
  'Isolation unavailable: checkout unavailable.' \
  "$(render_route_reason "$(route_from_repository "$DESTINATION" "$reviewed_after" "$CHECKOUT_ROUTE_BLOCKED" "$EXECUTOR")")"

eligibility_matrix() {
  printf '%s\n' \
    "eligible:$(route_from_repository "$DESTINATION" "$reviewed_after" "$ROOT/matrix-eligible" "$EXECUTOR")" \
    "executor:$(route_from_repository "$DESTINATION" "$reviewed_after" "$ROOT/matrix-executor" fixture-command-that-does-not-exist)" \
    "endpoint:$(route_from_repository "$DESTINATION" WORKTREE "$ROOT/matrix-endpoint" "$EXECUTOR")" \
    "clean:$(route_from_repository "$DIRTY_ROUTE" "$reviewed_after" "$ROOT/matrix-dirty" "$EXECUTOR")" \
    "checkout:$(route_from_repository "$DESTINATION" "$reviewed_after" "$CHECKOUT_ROUTE_BLOCKED" "$EXECUTOR")" \
    "ambiguous:$(destination_route "$reviewed_after" "$ROOT/matrix-ambiguous" "$EXECUTOR" "$DESTINATION" "$SECOND_OWNER")" \
    "detached:$(destination_route "$reviewed_after" "$ROOT/matrix-detached" "$EXECUTOR" "$DETACHED_OWNER")" \
    "unowned:$(destination_route "$reviewed_after" "$ROOT/matrix-unowned" "$EXECUTOR" "$UNOWNED")"
}
eligibility_matrix_contract() { [ "$(cat "$1")" = "$(eligibility_matrix)" ]; }
eligibility_matrix > "$ROOT/eligibility.original"
cp "$ROOT/eligibility.original" "$ROOT/eligibility.saved"
for mutation in \
  'eligible:isolated|eligible:inline:checkout-unavailable' \
  'executor:inline:executor-unavailable|executor:isolated' \
  'endpoint:inline:endpoint-not-committed|endpoint:isolated' \
  'clean:inline:destination-not-clean-at-endpoint|clean:isolated' \
  'checkout:inline:checkout-unavailable|checkout:isolated' \
  'ambiguous:reduced-surface:destination-unresolved|ambiguous:isolated' \
  'detached:reduced-surface:destination-unresolved|detached:isolated' \
  'unowned:reduced-surface:destination-unresolved|unowned:isolated'; do
  before_row="${mutation%%|*}" after_row="${mutation#*|}"
  sed "s/^$before_row$/$after_row/" "$ROOT/eligibility.original" > "$ROOT/eligibility.broken"
  eq "eligibility red-proof plants one invalid route" 1 \
    "$(grep -cF "$after_row" "$ROOT/eligibility.broken")"
  rejects eligibility_matrix_contract "$ROOT/eligibility.broken"
done
cmp -s "$ROOT/eligibility.original" "$ROOT/eligibility.saved" \
  && pass=$((pass + 1)) || fail=$((fail + 1))

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
selected_route="$(route_from_repository "$DESTINATION" "$reviewed_after" "$ISOLATED" "$EXECUTOR")"
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
SELECTED_FINDINGS="$ROOT/selected-findings.tsv"
EXPECTED_CHANGE="$ROOT/expected-change.txt"
printf '%s\n' ORIGINAL_CHANGE > "$EXPECTED_CHANGE"
printf '%s\n' 'remove|change.txt|DESIGN_MISMATCH' \
  'require|change.txt|ORIGINAL_CHANGE' \
  "exact|change.txt|$EXPECTED_CHANGE" > "$SELECTED_FINDINGS"
grep -qF RECOMMENDED "$ISOLATED/outside.txt" && ! grep -qF DESIGN_MISMATCH "$ISOLATED/change.txt" \
  && writer_verified=yes || writer_verified=no
eq "isolated writer verification" yes "$writer_verified"
eq "writer leaves destination head" "$reviewed_after" "$(git_head "$DESTINATION")"
eq "writer leaves destination clean" "" "$(git_status "$DESTINATION")"
eq "writer leaves destination bytes" "$destination_before" \
  "$(shasum "$DESTINATION/change.txt" | awk '{print $1}')"
printf '%s\n' "writer-return:$returned_commit:verified" >> "$TRACE"

if inspect_returned_package "$DESTINATION" "$reviewed_after" "$returned_commit" "$SELECTED_FINDINGS"; then
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
  rejects integrate_returned "$drift_repo" "$reviewed_after" "$returned_commit" "$SELECTED_FINDINGS"
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

ALL_FINDINGS="$ROOT/all-findings.tsv"
printf '%s\n' 'remove|change.txt|DESIGN_MISMATCH' \
  'remove|outside.txt|RECOMMENDED' > "$ALL_FINDINGS"
OMITTED_DESTINATION="$ROOT/omitted-finding-destination"
git clone -q "$DESTINATION" "$OMITTED_DESTINATION"
rejects integrate_returned "$OMITTED_DESTINATION" "$reviewed_after" "$returned_commit" "$ALL_FINDINGS"
eq "omitted selected finding leaves return unapplied" "$reviewed_after" \
  "$(git_head "$OMITTED_DESTINATION")"

SAME_PATH_RETURN="$ROOT/same-path-return"
git -C "$DESTINATION" worktree add -q "$SAME_PATH_RETURN" -b fixture/same-path-return "$returned_commit"
printf '%s\n' FORBIDDEN_COMPAT >> "$SAME_PATH_RETURN/change.txt"
git -C "$SAME_PATH_RETURN" add change.txt
git -C "$SAME_PATH_RETURN" commit -qm same-path-widening
same_path_commit="$(git_head "$SAME_PATH_RETURN")"
eq "same-path widening keeps the expected path set" 1 \
  "$(git -C "$DESTINATION" diff --name-only "$reviewed_after..$same_path_commit" | wc -l | tr -d ' ')"
rejects inspect_returned_package "$DESTINATION" "$reviewed_after" "$same_path_commit" "$SELECTED_FINDINGS"
SAME_PATH_DESTINATION="$ROOT/same-path-destination"
git clone -q "$DESTINATION" "$SAME_PATH_DESTINATION"
rejects integrate_returned "$SAME_PATH_DESTINATION" "$reviewed_after" "$same_path_commit" "$SELECTED_FINDINGS"
eq "same-path semantic widening remains unapplied" "$reviewed_after" \
  "$(git_head "$SAME_PATH_DESTINATION")"
git -C "$DESTINATION" worktree remove "$SAME_PATH_RETURN"

UNEXPECTED_RETURN="$ROOT/unexpected-return"
git -C "$DESTINATION" worktree add -q "$UNEXPECTED_RETURN" -b fixture/unexpected-return "$returned_commit"
printf '%s\n' UNEXPECTED_MATERIAL_MUTATION > "$UNEXPECTED_RETURN/surprise.txt"
git -C "$UNEXPECTED_RETURN" add surprise.txt
git -C "$UNEXPECTED_RETURN" commit -qm unexpected-return
unexpected_commit="$(git_head "$UNEXPECTED_RETURN")"
eq "unexpected return contains a third-path mutation" 2 \
  "$(git -C "$DESTINATION" diff --name-only "$reviewed_after..$unexpected_commit" | wc -l | tr -d ' ')"
UNEXPECTED_DESTINATION="$ROOT/unexpected-destination"
git clone -q "$DESTINATION" "$UNEXPECTED_DESTINATION"
rejects integrate_returned "$UNEXPECTED_DESTINATION" "$reviewed_after" "$unexpected_commit" "$SELECTED_FINDINGS"
eq "unexpected path leaves returned package unapplied" "$reviewed_after" \
  "$(git_head "$UNEXPECTED_DESTINATION")"
git -C "$DESTINATION" worktree remove "$UNEXPECTED_RETURN"

printf '%s\n' "pre-integration:$reviewed_after:clean" >> "$TRACE"
integrate_returned "$DESTINATION" "$reviewed_after" "$returned_commit" "$SELECTED_FINDINGS"
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
eq "full review population derives both changed paths" \
  "$(printf '%s\n' change.txt outside.txt)" \
  "$(git -C "$DESTINATION" diff --name-only "$base_endpoint..$returned_commit")"
THIRD_PATH_REVIEW="$ROOT/third-path-review"
git clone -q "$DESTINATION" "$THIRD_PATH_REVIEW"
git -C "$THIRD_PATH_REVIEW" config user.name fixture
git -C "$THIRD_PATH_REVIEW" config user.email fixture@example.invalid
printf '%s\n' DESIGN_MISMATCH > "$THIRD_PATH_REVIEW/third.txt"
git -C "$THIRD_PATH_REVIEW" add third.txt
git -C "$THIRD_PATH_REVIEW" commit -qm third-path-mutation
third_path_commit="$(git_head "$THIRD_PATH_REVIEW")"
eq "full review population expands to every changed path" 3 \
  "$(git -C "$THIRD_PATH_REVIEW" diff --name-only "$base_endpoint..$third_path_commit" | wc -l | tr -d ' ')"
eq "full re-review sees committed third-path mutation" needs-rework \
  "$(verdict "$(full_review_fixture "$THIRD_PATH_REVIEW" "$base_endpoint" "$third_path_commit")")"

assert_inline_full_review() {
  local kind="$1" marker="$2" path="$3" repository selection committed_verdict worktree_verdict
  local before after
  repository="$ROOT/inline-$kind"
  before="$ROOT/inline-$kind.before"
  after="$ROOT/inline-$kind.after"
  git clone -q "$DESTINATION" "$repository"
  capture_identity "$repository" "$before"
  selection="$(normalize_trace_code 1-I-R)"
  eq "inline $kind selection confirms" 1-I-R "$selection"
  case "$kind" in
    staged)
      printf '%s\n' "$marker" > "$repository/$path"
      git -C "$repository" add "$path"
      ;;
    unstaged) printf '%s\n' "$marker" >> "$repository/$path" ;;
    untracked) printf '%s\n' "$marker" > "$repository/$path" ;;
    *) return 1 ;;
  esac
  if same_identity "$repository" "$before" "$after"; then
    echo "FAIL inline $kind remediation did not change repository identity" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
  eq "inline $kind population is enumerated" 1 \
    "$(full_review_worktree_population "$repository" "$base_endpoint" | grep -c "^$kind:$path$")"
  committed_verdict="$(verdict "$(full_review_fixture "$repository" "$base_endpoint" "$returned_commit")")"
  eq "committed-only review misses inline $kind mutation" approve-with-changes "$committed_verdict"
  worktree_verdict="$(verdict "$(full_review_worktree_fixture "$repository" "$base_endpoint")")"
  eq "same-base full review finds inline $kind mutation" needs-rework "$worktree_verdict"
}
assert_inline_full_review staged FALSE_GREEN staged.txt
assert_inline_full_review unstaged FORBIDDEN_COMPAT outside.txt
assert_inline_full_review untracked MISSED_CALL_SITE untracked.txt

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
partial_head_before="$(git_head "$PARTIAL")"
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
eq "partial package produces no returned commit" "$partial_head_before" "$(git_head "$PARTIAL")"
eq "partial package produces no integration evidence" 0 \
  "$(find "$PARTIAL" -name '.integrated' -o -name '.returned-package' | wc -l | tr -d ' ')"
eq "partial package never starts re-review" 0 \
  "$(find "$PARTIAL" -name '.re-review-started' | wc -l | tr -d ' ')"

assert_bad_return() {
  local kind="$1" bad_worktree="$ROOT/bad-$1-return" bad_destination="$ROOT/bad-$1-destination"
  local bad_commit result bad_manifest="$ROOT/bad-$kind-findings.tsv"
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
  printf '%s\n' 'require|change.txt|ORIGINAL_CHANGE' > "$bad_manifest"
  git clone -q "$DESTINATION" "$bad_destination"
  if integrate_returned "$bad_destination" "$returned_commit" "$bad_commit" "$bad_manifest"; then
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
