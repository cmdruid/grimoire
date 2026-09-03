#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
SKILL="${WORKSTREAM_SKILL_UNDER_TEST:-$(cd "$DIR/../.." && pwd)}"
for file in streams-config.md streams-readme-block.md streams-gitignore workstream-runbook.md compaction-anchor.md coordinator.md debug.md design.md; do
  expect_eq "required template exists: $file" 1 "$([ -f "$SKILL/templates/$file" ] && echo 1 || echo 0)"
done
for retired in flow.md templates/workstream-handoff.md templates/manifest.md templates/debrief.md scripts/hooks.sh scripts/workstream-setup.sh; do
  expect_eq "retired runtime absent: $retired" 0 "$([ -e "$SKILL/$retired" ] && echo 1 || echo 0)"
done
expect 'tracker is helper-owned' 'never read or edit the TSV directly' "$SKILL/SKILL.md"
expect 'only plan and roadmap consumed' 'consumes: plan, roadmap' "$SKILL/SKILL.md"
expect 'no produced record edge' 'produces: —' "$SKILL/SKILL.md"
expect 'history is internal' 'internal control ledger' "$SKILL/SKILL.md"
expect 'zero setup is explicit' 'Setup is optional' "$SKILL/SKILL.md"
expect 'recycle source is constrained' 'tracked regular file' "$SKILL/verbs/recycle.md"
expect_eq 'package migration helper exists' 1 "$([ -x "$SKILL/scripts/workstream-migrate.sh" ] && echo 1 || echo 0)"
expect_absent 'installed runtime does not dispatch migration' 'cmd_migrate' "$SKILL/scripts/workstream.sh"
expect_absent 'installed runtime does not source migration helper' 'workstream-migrate' "$SKILL/scripts/workstream.sh"
bytes="$(wc -c <"$SKILL/SKILL.md" | tr -d ' ')"
if [ "$bytes" -le 10000 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: SKILL.md is $bytes bytes" >&2; fi
report 'artifact-contract-test.sh'
