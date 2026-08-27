#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${WORKSTREAM_SKILL_UNDER_TEST:-}" ]; then
  case "$WORKSTREAM_SKILL_UNDER_TEST" in
    /*) SKILL="$WORKSTREAM_SKILL_UNDER_TEST" ;;
    *) echo "WORKSTREAM_SKILL_UNDER_TEST must be absolute" >&2; exit 2 ;;
  esac
else
  SKILL="$(cd "$DIR/../.." && pwd)"
fi
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
expect "resource verb dispatched" 'resource acquire|status|release' "$SKILL/SKILL.md"
expect "resource helper documented" 'workstream-resource.sh' "$SKILL/SKILL.md"
expect "resource section bundled" '## Resource locks' "$SKILL/templates/workstream-handoff.md"
expect "load validates resources" 'workstream-resource.sh validate' "$SKILL/verbs/load.md"
expect "close releases resources" 'workstream-resource.sh release-all' "$SKILL/verbs/close.md"
expect "force cannot bypass resources" '`--force` never bypasses the resource gate' "$SKILL/verbs/close.md"
expect "teardown guards resources" 'workstream-resource.sh' "$SKILL/scripts/worktree-teardown.sh"
expect "attended break dispatched" 'resource acquire|status|release|break' "$SKILL/SKILL.md"
expect "attended break procedure" '## `break <resource>`' "$SKILL/verbs/resource.md"
expect "break requires named confirmation" 'confirmation naming that exact resource' "$SKILL/verbs/resource.md"
expect "save preserves resource inventory" 'complete single `## Resource locks` span byte-for-byte' "$SKILL/verbs/save.md"
expect "recycle preserves resource inventory" 'complete single `## Resource locks` span byte-for-byte' "$SKILL/verbs/recycle.md"
expect "close cleans inventory atomically" 'one atomic rewrite' "$SKILL/verbs/close.md"
offenders="$(find "$SKILL" -type f ! -path "$SKILL/scripts/workstream-resource.sh" ! -path "$SKILL/scripts/tests/*" -exec grep -lF 'git update-ref refs/workstream-resources/' {} + 2>/dev/null || true)"
expect_eq "resource namespace mutation is helper-only" "" "$offenders"

report "artifact-contract-test.sh"
