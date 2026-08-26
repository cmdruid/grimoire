#!/usr/bin/env bash
# Disposable consuming-project proof for PACK.md's delivery-loop profile.
set -euo pipefail
repo="$(CDPATH='' cd "$(dirname "$0")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-config.XXXXXX")";trap 'rm -rf "$tmp"' EXIT
root="$tmp/project";mkdir -p "$root";git -C "$root" init -q;git -C "$root" config user.name Fixture;git -C "$root" config user.email fixture@example.invalid
printf '# Existing project\n'>"$root/README.md";git -C "$root" add README.md;git -C "$root" commit -qm init
fail(){ echo "FAIL: $*" >&2;exit 1;}
auditor_sentinel="$tmp/auditor-invoked"

run_core_sweep(){
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/journal/scripts/standup.sh" "$root" --workspace .spaces --records-root .records >/dev/null
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/backlog/scripts/backlog-setup.sh" "$root" --workspace .spaces --apply tasks issues feedback >/dev/null
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/workstream/scripts/workstream-setup.sh" --write-only "$root" >/dev/null
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/delegate/scripts/delegate-setup.sh" --write-only "$root" >/dev/null
}

apply_glue(){
  printf '%s\n' '# Workstream — feature completion' '' \
    'Before shipping or saving a completed feature, run `/backlog debrief` over that feature. Include' \
    'actionable byproducts returned by Delegate during the feature. The debrief owns routing; do not file' \
    'the same leftover directly from this hook.' > "$root/.spaces/workstream/hooks/feature-completion.md"
  printf '%s\n' '# Workstream — after an eventful ship' '' \
    'Run `/backlog debrief` over ship-specific friction only. Do not refile leftovers already handled by' \
    'the feature-completion debrief.' > "$root/.spaces/workstream/hooks/after-eventful-ship.md"
  printf '%s\n' 'Return each actionable byproduct with a proposed class (`task`, `issue`, or `feedback`), an evidence' \
    'path or other concrete evidence, and why it matters. Do not file it directly; the calling workflow' \
    'owns routing.' > "$root/.spaces/delegate/hooks/byproducts.md"
}

before="$(git -C "$root" rev-parse HEAD)";run_core_sweep;apply_glue
[ ! -e "$auditor_sentinel" ] || fail "core sweep invoked deferred Auditor"
[ "$before" = "$(git -C "$root" rev-parse HEAD)" ] || fail "a member setup committed during the sweep"
[ -x "$root/.spaces/journal/scripts/records.sh" ] || fail "Journal tool missing"
[ -x "$root/.spaces/backlog/scripts/trackers.sh" ] || fail "Backlog tool missing"
for stem in tasks issues feedback;do [ -f "$root/.spaces/backlog/trackers/$stem.tsv" ]||fail "Backlog tracker missing: $stem";done
grep -q '^## tasks$' "$root/.spaces/backlog/hooks/debrief.md"||fail "Backlog cookbook missing tasks"
hooks="$tmp/hooks.out";"$repo/skills/workstream/scripts/hooks.sh" parse --dir "$root/.spaces/workstream/hooks" --known feature-completion --known after-eventful-ship >"$hooks"
grep -q 'hook_feature_completion=filled' "$hooks"||fail "feature hook not readable"
grep -q 'hook_after_eventful_ship=filled' "$hooks"||fail "ship hook not readable"
grep -q 'proposed class' "$root/.spaces/delegate/hooks/byproducts.md"||fail "Delegate policy not readable"
"$repo/skills/workspace/scripts/workspace-check.sh" --root "$root" --workspace .spaces --records-root .records >"$tmp/workspace.out"
grep -q 'fails=0' "$tmp/workspace.out"||fail "Workspace check failed"
[ -z "$(find "$root/.spaces" -type d -name schemas -print -quit)" ]||fail "project schemas were deployed"
if grep -qE '^(agent-workspace|agent-records|records-root):' "$root/AGENTS.md";then fail "default roots were declared";fi

# Derive the aggregate set from Git over approved destinations, not setup output.
git -C "$root" add -N -- AGENTS.md .records .spaces/journal .spaces/backlog .spaces/workstream .spaces/delegate
paths=();while IFS= read -r path;do [ -n "$path" ]&&paths+=("$path");done \
  < <(git -C "$root" diff --name-only -- AGENTS.md .records .spaces/journal .spaces/backlog .spaces/workstream .spaces/delegate)
[ "${#paths[@]}" -gt 0 ]||fail "aggregate path set is empty"
git -C "$root" add -- "${paths[@]}";git -C "$root" commit -qm 'Configure Clankshop delivery loop' -- "${paths[@]}"
[ "$(git -C "$root" rev-list --count HEAD)" -eq 2 ]||fail "configuration did not make exactly one aggregate commit"

run_core_sweep;apply_glue
[ -z "$(git -C "$root" status --porcelain)" ]||{ git -C "$root" status --short >&2;fail "second sweep is not diff-free"; }
[ ! -e "$auditor_sentinel" ]||fail "second sweep invoked deferred Auditor"

# Red-proof the guard: direct instrumented invocation must trip it.
if AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" "$repo/skills/auditor/scripts/auditor-seed.sh" "$root" >/dev/null 2>&1;then fail "instrumented Auditor call unexpectedly succeeded";fi
[ -f "$auditor_sentinel" ]||fail "Auditor invocation guard cannot detect a direct call"
echo "configure-clankshop-test: ok"
