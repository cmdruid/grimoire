#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

expect "manifest template declared" '- `manifest.md`' "$SKILL/SKILL.md"
expect "debrief template declared" '- `debrief.md`' "$SKILL/SKILL.md"
expect_eq "manifest template exists" 1 "$([ -f "$SKILL/templates/manifest.md" ] && echo 1 || echo 0)"
expect_eq "debrief template exists" 1 "$([ -f "$SKILL/templates/debrief.md" ] && echo 1 || echo 0)"
expect_eq "legacy plans shell absent" 0 "$([ -e "$SKILL/templates/plans.md" ] && echo 1 || echo 0)"
expect_eq "legacy reports shell absent" 0 "$([ -e "$SKILL/templates/reports.md" ] && echo 1 || echo 0)"
expect "plan schema minted" 'schema workstream/plan@1' "$SKILL/verbs/create.md"
expect "debrief schema minted" 'schema workstream/debrief@1' "$SKILL/verbs/ship.md"
expect "records isolated" '<agent-records>/streams/' "$SKILL/SKILL.md"
expect "helper classifies streams drafts" '$rec_re/streams/' "$SKILL/scripts/workstream-git.sh"
expect "migrate refuses directory plan sweep" 'never sweep it from a directory' "$SKILL/verbs/migrate.md"
expect "legacy template rename registered" '`plans.md` → `manifest.md`' "$SKILL/verbs/migrate.md"
expect_eq "generic prime helper exists" 1 "$([ -x "$SKILL/scripts/workstream-prime.sh" ] && echo 1 || echo 0)"
expect "prime helper documented" 'workstream-prime.sh' "$SKILL/SKILL.md"

report "artifact-contract-test.sh"
