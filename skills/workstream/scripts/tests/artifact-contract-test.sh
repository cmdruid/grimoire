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
expect "records isolated" '.records/streams/' "$SKILL/SKILL.md"
expect "helper classifies streams drafts" '$rec_re/streams/' "$SKILL/scripts/workstream-git.sh"
expect "migrate refuses directory plan sweep" 'never sweep it from a directory' "$SKILL/verbs/migrate.md"
expect "legacy template rename registered" '`plans.md` → `manifest.md`' "$SKILL/verbs/migrate.md"
expect_eq "generic prime helper exists" 1 "$([ -x "$SKILL/scripts/workstream-prime.sh" ] && echo 1 || echo 0)"
expect "prime helper documented" 'workstream-prime.sh' "$SKILL/SKILL.md"
for retired in \
  "$SKILL/verbs/resource.md" \
  "$SKILL/scripts/workstream-resource.sh" \
  "$SKILL/scripts/tests/resource-test.sh"
do
  expect_eq "retired resource-locking file absent: $(basename "$retired")" 0 \
    "$([ -e "$retired" ] && echo 1 || echo 0)"
done
resource_offenders="$(find "$SKILL" -type f ! -path "$SKILL/scripts/tests/*" \
  -exec grep -Eil 'workstream-resource|refs/workstream-resources|resource-lock|resource locks|resource[- ]claim|resource acquire' {} + 2>/dev/null || true)"
expect_eq "resource-locking surface is fully removed" "" "$resource_offenders"

expect "workstream lifecycle has explicit manual save seam" 'user manually invoking `save`' "$SKILL/flow.md"
expect "workstream lifecycle has explicit creation seam" 'every loop entry (`create` / `load` / `recycle`)' "$SKILL/SKILL.md"
expect "workstream recovery skips write-back" 'skip write-back' "$SKILL/flow.md"
if grep -Eq 'checkpoint-token|/checkpoint close|CHECKPOINT — file:' "$SKILL/templates/workstream-handoff.md"; then
  echo "FAIL: root Checkpoint token or Close semantics leaked into Workstream hand-off" >&2
  fail=$((fail + 1))
else pass=$((pass + 1)); fi

report "artifact-contract-test.sh"
