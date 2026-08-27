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
    "$repo/skills/backlog/scripts/backlog-setup.sh" "$root" --workspace .spaces --records-root .records --apply >/dev/null
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/workstream/scripts/workstream-setup.sh" --write-only "$root" >/dev/null
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/delegate/scripts/delegate-setup.sh" --write-only "$root" >/dev/null
}

apply_delegate_policy(){
  printf '%s\n' 'Return each actionable byproduct with a proposed class (`task`, `issue`, or `feedback`), an evidence' \
    'path or other concrete evidence, and why it matters. Do not file it directly; the calling workflow' \
    'owns routing.' > "$root/.spaces/delegate/hooks/byproducts.md"
}

before="$(git -C "$root" rev-parse HEAD)";run_core_sweep;apply_delegate_policy
[ ! -e "$auditor_sentinel" ] || fail "core sweep invoked deferred Auditor"
[ "$before" = "$(git -C "$root" rev-parse HEAD)" ] || fail "a member setup committed during the sweep"
[ -x "$root/.spaces/journal/scripts/records.sh" ] || fail "Journal tool missing"
[ -x "$root/.trackers/tracker-api.sh" ] || fail "Backlog provider missing"
for file in README.md tracker-api.sh receipts.tsv tasks.tsv issues.tsv feedback.tsv routines.tsv;do [ -f "$root/.trackers/$file" ]||fail "Backlog tracker layer missing: $file";done
grep -q '^## tasks$' "$root/.spaces/backlog/hooks/debrief.md"||fail "Backlog cookbook missing tasks"
grep -q '^## routines$' "$root/.spaces/backlog/hooks/debrief.md"||fail "Backlog cookbook missing routines"
grep -q '^<!-- skill:backlog BEGIN' "$root/AGENTS.md"||fail "Backlog route missing"
hooks="$tmp/hooks.out";"$repo/skills/workstream/scripts/hooks.sh" parse --dir "$root/.spaces/workstream/hooks" --known feature-completion --known after-eventful-ship >"$hooks"
grep -q 'hook_feature_completion=empty' "$hooks"||fail "feature hook is not independent and empty"
grep -q 'hook_after_eventful_ship=empty' "$hooks"||fail "ship hook is not independent and empty"
grep -q 'proposed class' "$root/.spaces/delegate/hooks/byproducts.md"||fail "Delegate policy not readable"
"$repo/skills/workspace/scripts/workspace-check.sh" --root "$root" --workspace .spaces --records-root .records >"$tmp/workspace.out"
grep -q 'fails=0' "$tmp/workspace.out"||fail "Workspace check failed"
[ -z "$(find "$root/.spaces" -type d -name schemas -print -quit)" ]||fail "project schemas were deployed"
if grep -qE '^(agent-workspace|agent-records|agent-trackers|records-root):' "$root/AGENTS.md";then fail "default roots were declared";fi

# Derive the aggregate set from Git over approved destinations, not setup output.
git -C "$root" add -N -- AGENTS.md .records .trackers .spaces/journal .spaces/backlog .spaces/workstream .spaces/delegate
paths=();while IFS= read -r path;do [ -n "$path" ]&&paths+=("$path");done \
  < <(git -C "$root" diff --name-only -- AGENTS.md .records .trackers .spaces/journal .spaces/backlog .spaces/workstream .spaces/delegate)
[ "${#paths[@]}" -gt 0 ]||fail "aggregate path set is empty"
git -C "$root" add -- "${paths[@]}";git -C "$root" commit -qm 'Configure Clankshop delivery loop' -- "${paths[@]}"
[ "$(git -C "$root" rev-list --count HEAD)" -eq 2 ]||fail "configuration did not make exactly one aggregate commit"

run_core_sweep;apply_delegate_policy
[ -z "$(git -C "$root" status --porcelain)" ]||{ git -C "$root" status --short >&2;fail "second sweep is not diff-free"; }
[ ! -e "$auditor_sentinel" ]||fail "second sweep invoked deferred Auditor"

# Red-proof the guard: direct instrumented invocation must trip it.
if AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" "$repo/skills/auditor/scripts/auditor-seed.sh" "$root" >/dev/null 2>&1;then fail "instrumented Auditor call unexpectedly succeeded";fi
[ -f "$auditor_sentinel" ]||fail "Auditor invocation guard cannot detect a direct call"

# Exercise Architect's opportunistic integration against Journal's actually deployed engine in a
# separate consuming project. Package-only outlines travel with the skill but deploy no Architect
# configuration of their own.
spike_root="$tmp/spike-project";mkdir -p "$spike_root"
"$repo/skills/journal/scripts/standup.sh" "$spike_root" --workspace .spaces --records-root .records >/dev/null
spike_body="$tmp/spike-body.md"
awk '
  NR == 1 { sub(/<title>/, "Filesystem feasibility") }
  { print }
  $0 == "## Question and decision relevance" { print ""; print "Question: can the filesystem path preserve the required write boundary?" }
  $0 == "## Executor, baseline, and environment" { print ""; print "Executor: integration fixture; baseline: fixture repository; environment: temporary project." }
  $0 == "## Hypothesis, success criterion, and budget" { print ""; print "Hypothesis: yes. Success: one published record. Budget: one helper call." }
  $0 == "## Method, reproduction commands, and observations" { print ""; print "Method: invoke the helper through deployed Journal. Observation: the record was created." }
  $0 == "## Conclusion, limitations, and remaining uncertainty" { print ""; print "Result: positive. Limitation: fixture scope only." }
' "$repo/skills/architect/templates/spikes.md" >"$spike_body"
spike_out="$tmp/spike.out"
"$repo/skills/architect/scripts/architect-artifacts.sh" spike-publish \
  --root "$spike_root" --records-root .records \
  --records-tool "$spike_root/.spaces/journal/scripts/records.sh" \
  --title 'Filesystem feasibility' --body "$spike_body" >"$spike_out"
spike_rel="$(sed -n 's/^path=//p' "$spike_out")";spike_file="$spike_root/$spike_rel"
[ -f "$spike_file" ]||fail "Architect did not publish through deployed Journal"
for field in 'doctype: spikes' 'status: published' 'schema: architect/spike@1' 'tags: [spike, feasibility]';do
  grep -qxF "$field" "$spike_file"||fail "published spike metadata missing: $field"
done
[ "$(grep -Ec '^##[[:space:]]+[^[:space:]]' "$spike_file")" -eq 5 ]||fail "published spike body does not have five sections"
[ ! -e "$spike_root/.spaces/architect" ]||fail "spike publication deployed Architect workspace configuration"
[ ! -e "$spike_root/AGENTS.md" ]||fail "spike publication created a front door"
echo "configure-clankshop-test: ok"
