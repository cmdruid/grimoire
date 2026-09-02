#!/usr/bin/env bash
# Disposable consuming-project proof for PACK.md's delivery-loop profile.
set -euo pipefail
repo="$(CDPATH='' cd "$(dirname "$0")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-config.XXXXXX")";trap 'rm -rf "$tmp"' EXIT
root="$tmp/project";mkdir -p "$root";git -C "$root" init -q;git -C "$root" config user.name Fixture;git -C "$root" config user.email fixture@example.invalid
printf '# Existing project\n'>"$root/README.md"
printf '# Existing agent instructions\n' >"$root/AGENTS.md"
git -C "$root" add README.md AGENTS.md;git -C "$root" commit -qm init
cp "$root/AGENTS.md" "$tmp/agents.before"
fail(){ echo "FAIL: $*" >&2;exit 1;}
auditor_sentinel="$tmp/auditor-invoked"

run_core_sweep(){
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/journal/scripts/standup.sh" setup "$root" --write-only \
 >"$tmp/journal-setup.out"
  AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" \
    "$repo/skills/backlog/scripts/backlog-setup.sh" "$root" --apply >/dev/null
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
[ -x "$root/.records/records.sh" ] || fail "Journal tool missing"
[ ! -e "$root/.spaces/journal" ] || fail "Journal setup created private workspace state"
[ ! -d "$root/.records/notes" ] || fail "Journal setup created a writer directory"
grep -qF 'Run `/journal repair`' "$root/.records/README.md" || fail "Journal repair guidance missing"
"$root/.records/records.sh" list >/dev/null || fail "Journal README provider is unusable"
[ -x "$root/.trackers/trackers.sh" ] || fail "Backlog provider missing"
for file in README.md trackers.sh history.tsv;do [ -f "$root/.trackers/$file" ]||fail "Backlog tracker layer missing: $file";done
for file in .gitkeep tasks.tsv issues.tsv feedback.tsv routines.tsv;do [ -f "$root/.trackers/tables/$file" ]||fail "Backlog tracker table missing: $file";done
[ ! -e "$root/.trackers/tracker-api.sh" ]||fail "Backlog installed the pre-cut provider"
cmp -s "$repo/skills/backlog/scripts/trackers.sh" "$root/.trackers/trackers.sh"||fail "Backlog provider is not byte-identical"
description="$($root/.trackers/trackers.sh describe)"
[ "$(printf '%s\n' "$description"|grep -c '^schema=')" -eq 1 ]||fail "Backlog provider has ambiguous schema discovery"
printf '%s\n' "$description"|grep -qxF 'schema=tracker@2'||fail "Backlog provider schema is wrong"
"$root/.trackers/trackers.sh" catalog >/dev/null||fail "Backlog catalog is unusable"
readme_facts="$("$repo/skills/backlog/scripts/tracker-readme-status.sh" \
  "$repo/skills/backlog/templates/trackers-readme-block.md" "$root/.trackers/README.md")"
grep -qxF 'readme_status=current' <(printf '%s\n' "$readme_facts")||fail "Backlog tracker guide is not current"
grep -q '^## tasks$' "$root/.trackers/DEBRIEF.md"||fail "Backlog cookbook missing tasks"
grep -q '^## routines$' "$root/.trackers/DEBRIEF.md"||fail "Backlog cookbook missing routines"
cmp -s "$tmp/agents.before" "$root/AGENTS.md" || fail "core setup changed the project front door"
hooks="$tmp/hooks.out";"$repo/skills/workstream/scripts/hooks.sh" parse --dir "$root/.spaces/workstream/hooks" --known feature-completion --known after-eventful-ship >"$hooks"
grep -q 'hook_feature_completion=empty' "$hooks"||fail "feature hook is not independent and empty"
grep -q 'hook_after_eventful_ship=empty' "$hooks"||fail "ship hook is not independent and empty"
grep -q 'proposed class' "$root/.spaces/delegate/hooks/byproducts.md"||fail "Delegate policy not readable"
"$repo/skills/workspace/scripts/workspace-check.sh" --root "$root" >"$tmp/workspace.out"
grep -q 'fails=0' "$tmp/workspace.out"||fail "Workspace check failed"
[ -z "$(find "$root/.spaces" -type d -name schemas -print -quit)" ]||fail "project schemas were deployed"
if grep -qE '^(agent-workspace|agent-records|agent-trackers|records-root):' "$root/AGENTS.md";then fail "default roots were declared";fi

# Derive the aggregate set from Git over approved destinations, not setup output.
git -C "$root" add -N -- .records .trackers .spaces/workstream .spaces/delegate
paths=();while IFS= read -r path;do [ -n "$path" ]&&paths+=("$path");done \
  < <(git -C "$root" diff --name-only -- .records .trackers .spaces/journal .spaces/workstream .spaces/delegate)
[ "${#paths[@]}" -gt 0 ]||fail "aggregate path set is empty"
git -C "$root" add -- "${paths[@]}";git -C "$root" commit -qm 'Configure Clankshop delivery loop' -- "${paths[@]}"
[ "$(git -C "$root" rev-list --count HEAD)" -eq 2 ]||fail "configuration did not make exactly one aggregate commit"
git -C "$root" show HEAD:AGENTS.md >"$tmp/committed-AGENTS.md"
cmp -s "$tmp/agents.before" "$tmp/committed-AGENTS.md" || fail "configuration commit changed AGENTS.md"

run_core_sweep;apply_delegate_policy
[ -z "$(git -C "$root" status --porcelain)" ]||{ git -C "$root" status --short >&2;fail "second sweep is not diff-free"; }
[ ! -e "$auditor_sentinel" ]||fail "second sweep invoked deferred Auditor"

# Backlog repair is provider/README-only in the consuming project.
printf '\n# stale-provider-fixture\n'>>"$root/.trackers/trackers.sh"
sed 's/## Use the tracker tool/## Stale tracker tool/' "$root/.trackers/README.md">"$tmp/backlog-readme.stale"
mv "$tmp/backlog-readme.stale" "$root/.trackers/README.md"
git -C "$root" add -- .trackers/trackers.sh .trackers/README.md
git -C "$root" commit -qm 'Seed Backlog repair fixture baseline'
cp "$root/.trackers/tables/tasks.tsv" "$tmp/backlog-repair-queue.before"
cp "$root/.trackers/history.tsv" "$tmp/backlog-repair-history.before"
cp "$root/.trackers/DEBRIEF.md" "$tmp/backlog-repair-hook.before"
cp "$root/AGENTS.md" "$tmp/backlog-repair-route.before"
"$repo/skills/backlog/scripts/backlog-setup.sh" "$root" repair >"$tmp/backlog-repair.out"
sed -n 's/^wrote=//p' "$tmp/backlog-repair.out"|sort -u>"$tmp/backlog-repair.paths"
printf '%s\n' '.trackers/README.md' '.trackers/trackers.sh'>"$tmp/backlog-repair.expected"
cmp -s "$tmp/backlog-repair.expected" "$tmp/backlog-repair.paths"||fail "Backlog repair reported a path outside provider/README"
git -C "$root" diff --name-only|sort>"$tmp/backlog-repair.diff"
cmp -s "$tmp/backlog-repair.expected" "$tmp/backlog-repair.diff"||fail "Backlog repair diff escaped provider/README"
cmp -s "$tmp/backlog-repair-queue.before" "$root/.trackers/tables/tasks.tsv"||fail "Backlog repair changed queue bytes"
cmp -s "$tmp/backlog-repair-history.before" "$root/.trackers/history.tsv"||fail "Backlog repair changed history bytes"
cmp -s "$tmp/backlog-repair-hook.before" "$root/.trackers/DEBRIEF.md"||fail "Backlog repair changed prompt bytes"
cmp -s "$tmp/backlog-repair-route.before" "$root/AGENTS.md"||fail "Backlog repair changed route bytes"
git -C "$root" add -- .trackers/trackers.sh .trackers/README.md;git -C "$root" commit -qm 'Repair Backlog managed surfaces'
rm "$root/.trackers/trackers.sh";"$repo/skills/backlog/scripts/backlog-setup.sh" "$root" repair >"$tmp/backlog-missing-provider.out"
[ -x "$root/.trackers/trackers.sh" ]||fail "Backlog repair did not restore a missing provider"
grep -qF 'wrote=.trackers/trackers.sh' "$tmp/backlog-missing-provider.out"||fail "Backlog missing provider was not reported"
[ -z "$(git -C "$root" status --porcelain)" ]||fail "Backlog byte-identical provider restoration left a diff"

# Repair is write-only inside the consuming-project sweep. Commit deliberately
# stale managed surfaces as the baseline so the aggregate diff can observe both
# allowed paths, while canaries prove every other owner remains byte-identical.
mkdir -p "$root/.records/notes"
cat >"$root/.records/notes/2026-08-28-repair-canary.md" <<'EOF'
---
doctype: notes
status: published
schema: notepad/note@1
tags: [fixture]
---

# Repair canary

record-byte-canary
EOF
printf '%s\n' '# stale-provider-fixture' >>"$root/.records/records.sh"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$root/.records/README.md"
rm "$root/.records/README.md.bak"
git -C "$root" add -- .records/records.sh .records/README.md \
  .records/notes/2026-08-28-repair-canary.md
git -C "$root" commit -qm 'Seed Journal repair fixture baseline'
cp "$root/.records/history.tsv" "$tmp/repair-history.before"
cp "$root/.records/notes/2026-08-28-repair-canary.md" "$tmp/repair-record.before"
cp "$root/.trackers/tables/tasks.tsv" "$tmp/repair-queue.before"
cp "$root/.trackers/DEBRIEF.md" "$tmp/repair-hook.before"
cp "$root/AGENTS.md" "$tmp/repair-route.before"
"$repo/skills/journal/scripts/standup.sh" repair "$root" --write-only \
 >"$tmp/journal-repair.out"
sed -n 's/^wrote: //p' "$tmp/journal-repair.out" | sort -u >"$tmp/journal-repair.paths"
printf '%s\n' '.records/README.md' '.records/records.sh' >"$tmp/journal-repair.expected"
cmp -s "$tmp/journal-repair.expected" "$tmp/journal-repair.paths" || fail "repair reported a path outside provider/README"
git -C "$root" diff --name-only | sort >"$tmp/journal-repair.diff"
cmp -s "$tmp/journal-repair.expected" "$tmp/journal-repair.diff" || fail "repair aggregate diff escaped provider/README"
cmp -s "$tmp/repair-history.before" "$root/.records/history.tsv" || fail "repair changed ledger bytes"
cmp -s "$tmp/repair-record.before" "$root/.records/notes/2026-08-28-repair-canary.md" || fail "repair changed record bytes"
cmp -s "$tmp/repair-queue.before" "$root/.trackers/tables/tasks.tsv" || fail "repair changed queue bytes"
cmp -s "$tmp/repair-hook.before" "$root/.trackers/DEBRIEF.md" || fail "repair changed hook bytes"
cmp -s "$tmp/repair-route.before" "$root/AGENTS.md" || fail "repair changed route bytes"
[ ! -e "$root/.spaces/journal" ] || fail "repair created private workspace state"
git -C "$root" add -- .records/records.sh .records/README.md
git -C "$root" commit -qm 'Repair Journal managed surfaces'

# Missing-provider restoration is a separate behavioral proof. Removing and
# restoring committed bytes leaves no aggregate diff, so it is not used as the
# path-boundary assertion above.
rm "$root/.records/records.sh"
"$repo/skills/journal/scripts/standup.sh" repair "$root" \
 >"$tmp/journal-missing-provider.out"
[ -x "$root/.records/records.sh" ] || fail "repair did not restore a missing provider"
grep -qF 'wrote: .records/records.sh' "$tmp/journal-missing-provider.out" || fail "missing provider was not reported"
[ -z "$(git -C "$root" status --porcelain)" ] || fail "byte-identical provider restoration left a diff"

# Red-proof the guard: direct instrumented invocation must trip it.
if AUDITOR_SETUP_TEST_INVOKED_SENTINEL="$auditor_sentinel" "$repo/skills/auditor/scripts/auditor-seed.sh" "$root" >/dev/null 2>&1;then fail "instrumented Auditor call unexpectedly succeeded";fi
[ -f "$auditor_sentinel" ]||fail "Auditor invocation guard cannot detect a direct call"

# Exercise Architect's opportunistic integration against Journal's actually deployed engine in a
# separate consuming project. Package-only outlines travel with the skill but deploy no Architect
# configuration of their own.
spike_root="$tmp/spike-project";mkdir -p "$spike_root"
"$repo/skills/journal/scripts/standup.sh" setup "$spike_root" \
 >/dev/null
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
  --root "$spike_root" \
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
