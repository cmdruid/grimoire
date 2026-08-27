#!/usr/bin/env bash
# skill-doc-test.sh — hard-cut single-root contract and exported boundary.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
ROOT="$(cd "$SKILL/../.." && pwd)"
. "$DIR/lib.sh"

LIVE="$SKILL/SKILL.md $SKILL/verbs/save.md $SKILL/verbs/resume.md $SKILL/verbs/done.md"
for needle in '.checkpoints/' 'resume <name>' 'done <name>' 'checkpoint-store.sh' 'verbs/list.md'; do
  if grep -Fq "$needle" $LIVE; then
    echo "FAIL: live Checkpoint surface still contains $needle" >&2; fail=$((fail + 1))
  else pass=$((pass + 1)); fi
done

for path in "$SKILL/verbs/list.md" "$SKILL/scripts/checkpoint-store.sh" \
  "$SKILL/scripts/checkpoint-token.sh" "$SKILL/scripts/tests/store-test.sh" \
  "$SKILL/scripts/tests/token-test.sh"; do
  if [ -e "$path" ]; then echo "FAIL: obsolete path remains: $path" >&2; fail=$((fail + 1))
  else pass=$((pass + 1)); fi
done

expect "single root target documented" '<root>/CHECKPOINT.md' "$SKILL/SKILL.md"
expect "four-verb save dispatch" '| `save [next: ...]` |' "$SKILL/SKILL.md"
expect "four-verb resume dispatch" '| `resume` |' "$SKILL/SKILL.md"
expect "four-verb done dispatch" '| `done` |' "$SKILL/SKILL.md"
expect "four-verb anchor dispatch" '| `anchor` |' "$SKILL/SKILL.md"

DISC="$SKILL/references/disciplines.md"
if grep -Eq 'CHECKPOINT\.md|checkpoint-token|/checkpoint anchor|confers ownership|one-owner' "$DISC"; then
  echo "FAIL: exported disciplines leak Checkpoint identity or custody" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi

ANCHOR="$SKILL/templates/recovery-anchor.md"
expect "anchor is first published root version" '<!-- checkpoint:recovery-anchor@1 -->' "$ANCHOR"
expect "fresh session requires explicit Resume" 'fresh session' "$ANCHOR"
expect "presence never admits" 'Presence of root `CHECKPOINT.md` never authorizes a read.' "$ANCHOR"

if grep -Eq 'named root checkpoint|named checkpoint|\.checkpoints/' \
  "$ROOT/README.md" "$ROOT/PACK.md" "$ROOT/skills/foreman/verbs/goal.md" \
  "$ROOT/skills/workstream/templates/workstream-handoff.md"; then
  echo "FAIL: downstream live prose still advertises named checkpoints" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi

finish "checkpoint skill docs"
