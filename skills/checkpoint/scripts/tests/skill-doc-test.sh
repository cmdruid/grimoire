#!/usr/bin/env bash
# skill-doc-test.sh — hard-cut single-root contract and exported boundary.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LIVE_SKILL="$(cd "$DIR/../.." && pwd)"
SKILL="${CHECKPOINT_SKILL_UNDER_TEST:-$LIVE_SKILL}"
case "$SKILL" in /*) ;; *) echo "FAIL: CHECKPOINT_SKILL_UNDER_TEST must be absolute" >&2; exit 2 ;; esac
[ -d "$SKILL" ] && [ ! -L "$SKILL" ] || { echo "FAIL: invalid Checkpoint skill under test" >&2; exit 2; }
ROOT="$(cd "$LIVE_SKILL/../.." && pwd)"
. "$DIR/lib.sh"

LIVE="$SKILL/SKILL.md $SKILL/verbs/save.md $SKILL/verbs/resume.md $SKILL/verbs/close.md"
for needle in '.checkpoints/' 'resume <name>' 'done <name>' 'checkpoint-store.sh' 'verbs/list.md'; do
  if grep -Fq "$needle" $LIVE; then
    echo "FAIL: live Checkpoint surface still contains $needle" >&2; fail=$((fail + 1))
  else pass=$((pass + 1)); fi
done

retired_close='done'
for path in "$SKILL/verbs/list.md" "$SKILL/scripts/checkpoint-store.sh" \
  "$SKILL/scripts/checkpoint-token.sh" "$SKILL/scripts/tests/store-test.sh" \
  "$SKILL/scripts/tests/token-test.sh" "$SKILL/verbs/$retired_close.md"; do
  if [ -e "$path" ]; then echo "FAIL: obsolete path remains: $path" >&2; fail=$((fail + 1))
  else pass=$((pass + 1)); fi
done

expect "single root target documented" '<root>/CHECKPOINT.md' "$SKILL/SKILL.md"
expect "four-verb save dispatch" '| `save [next: ...]` |' "$SKILL/SKILL.md"
expect "four-verb resume dispatch" '| `resume` |' "$SKILL/SKILL.md"
expect "four-verb close dispatch" '| `close` |' "$SKILL/SKILL.md"
expect "four-verb anchor dispatch" '| `anchor` |' "$SKILL/SKILL.md"

SAVE="$SKILL/verbs/save.md"
expect "foreign occupancy uses body-free probe" 'checkpoint-file.sh occupancy <root>' "$SAVE"
expect "overwrite offer is valid-only" 'Only `checkpoint_occupancy=valid` may' "$SAVE"
expect "valid foreign occupancy offers overwrite" 'offer to overwrite' "$SAVE"
expect "overwrite confirmation uses fingerprint" 'checkpoint-file.sh overwrite <root> <expected-fingerprint>' "$SAVE"
expect "overwrite confirmation requires fresh token" 'fresh token' "$SAVE"
expect "overwrite rejection is non-mutating" 'rejection performs no mutation' "$SAVE"
expect "unsafe occupancy refuses" 'Unsafe or malformed occupancy refuses' "$SAVE"
expect "unsafe occupancy receives no offer" 'overwrite offer.' "$SAVE"

expect "save is explicit enrollment" 'Successful explicit Save enrolls the session.' "$SAVE"
expect "save does not schedule first write" 'A request merely to maintain Checkpoint schedules' "$SAVE"

RESUME="$SKILL/verbs/resume.md"
expect "resume invocation authorizes claim" 'Invocation authorizes' "$RESUME"
expect "resume claims in one command" 'no second confirmation turn.' "$RESUME"
expect "resume asks ambiguity after custody" 'ask only after the new stable' "$RESUME"

CLOSE="$SKILL/verbs/close.md"
expect "close is explicit-only" 'Checkpoint never invokes' "$CLOSE"
expect "close preserves abandonment gate" 'requires explicit confirmation before abandonment' "$CLOSE"

if grep -Eq 'first-save-early|asks this session to maintain|routes to `done`|verbs/done\.md|\| `done` \|' $LIVE; then
  echo "FAIL: retired activation or Done route remains" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi

expect "quiet recovery without exact root handle" 'no exact-root handle, do nothing' "$SKILL/SKILL.md"
expect "matching recovery is read-only" 'Recovery never writes the' "$SKILL/SKILL.md"
expect "exact-root mismatch is visible" 'tell the user Recovery failed' "$SKILL/SKILL.md"
expect "lifecycle has three post-enrollment moments" 'After enrollment, refresh only at the three Lifecycle moments' "$SKILL/SKILL.md"
expect "lifecycle does not infer completion" 'never infers completion or suggests closure' "$SKILL/SKILL.md"

DISC="$SKILL/references/disciplines.md"
if grep -Eq 'CHECKPOINT\.md|checkpoint-token|/checkpoint anchor|confers ownership|one-owner' "$DISC"; then
  echo "FAIL: exported disciplines leak Checkpoint identity or custody" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi
expect "generic lifecycle starts at owner event" 'owner defines its explicit enrollment or creation event' "$DISC"
expect "generic lifecycle is completion-neutral" 'remains active until its explicit close procedure runs' "$DISC"
expect "generic recovery is read-only" 'Recovery itself never writes the save-state.' "$DISC"
if grep -Eq 'forgotten close|Landed work routes|Write-back\.' "$DISC"; then
  echo "FAIL: exported disciplines retain closure inference or Recovery write-back" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi

ANCHOR="$SKILL/templates/recovery-anchor.md"
expect "anchor is v2" '<!-- checkpoint:recovery-anchor@2 -->' "$ANCHOR"
expect "anchor owns lifecycle and recovery" '## Checkpoint lifecycle and recovery' "$ANCHOR"
expect "anchor enrollment is explicit" 'successful explicit `/checkpoint save`' "$ANCHOR"
expect "anchor lifecycle is completion-neutral" 'never infers that work is' "$ANCHOR"
expect "anchor quiet without handle" 'without a complete stable handle' "$ANCHOR"
expect "anchor Recovery is read-only" 'write nothing' "$ANCHOR"

ANCHOR_VERB="$SKILL/verbs/anchor.md"
expect "anchor dispatch recognizes generic conflict" '`conflict`' "$ANCHOR_VERB"
expect "anchor preview names AGENTS path" 'selected `AGENTS.md` path' "$ANCHOR_VERB"
expect "anchor preview shows old bytes" 'exact bounded current' "$ANCHOR_VERB"
expect "anchor preview shows v2 replacement" 'exact version-2 replacement' "$ANCHOR_VERB"
expect "anchor reclassifies changed preview" 'reclassify and re-propose' "$ANCHOR_VERB"
expect "unsafe anchor collision receives no offer" 'without an extent or replacement offer' "$ANCHOR_VERB"

expect "save reports missing anchor" 'missing anchor' "$SAVE"
expect "save reports drifted v2 anchor" 'drifted-v2 anchor' "$SAVE"
expect "save reports generic anchor conflict" 'generic conflict' "$SAVE"
versioned_word='versioned'; unversioned_word='unversioned'; retired_generation=1
retired_anchor_re="obsolete-${versioned_word}|obsolete-${unversioned_word}|recovery-anchor@${retired_generation}"
if grep -Eq "$retired_anchor_re" \
  "$SKILL/SKILL.md" "$SKILL/verbs/save.md" "$SKILL/verbs/anchor.md" \
  "$SKILL/templates/recovery-anchor.md" "$SKILL/scripts/anchor-status.sh"; then
  echo "FAIL: live Checkpoint anchor surface retains legacy-specific behavior" >&2
  fail=$((fail + 1))
else pass=$((pass + 1)); fi

if grep -Eq 'named root checkpoint|named checkpoint|\.checkpoints/' \
  "$ROOT/README.md" "$ROOT/PACK.md" "$ROOT/skills/foreman/verbs/goal.md" \
  "$ROOT/skills/workstream/SKILL.md"; then
  echo "FAIL: downstream live prose still advertises named checkpoints" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi

finish "checkpoint skill docs"
