#!/usr/bin/env bash
# skill-doc-test.sh — grep gates on the live architect package.
# Read-only against the skill tree.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

# --- spine verbs live in verbs/; SKILL.md does not keep their H2s ---
for v in brainstorm grill spec spike; do
  if [ -f "$SKILL/verbs/$v.md" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

hits=$(grep -E '^## (brainstorm|grill|spec) ' "$SKILL/SKILL.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md still has spine verb H2s:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- dispatch cites every verb file (lint check 6 coverage) ---
for v in brainstorm grill spec spike new deploy; do
  if grep -qF "\`verbs/$v.md\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: SKILL.md does not cite verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

# --- spec self-review runs this package's ground-check ---
if grep -qF 'scripts/ground-check.sh' "$SKILL/verbs/spec.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/spec.md does not invoke scripts/ground-check.sh" >&2
  fail=$((fail + 1))
fi

# --- spikes are bounded direct evidence, not reviewed proposals ---
for f in templates/draft.md templates/spikes.md scripts/architect-artifacts.sh; do
  if [ -e "$SKILL/$f" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing $f" >&2
    fail=$((fail + 1))
  fi
done
spike_text="$(cat "$SKILL/verbs/spike.md")"
expect_match "spike requires explicit confirmation" 'explicit confirmation' "$spike_text"
expect_match "spike keeps experiment disposable" 'disposable temporary area' "$spike_text"
expect_match "spike publishes stable account" '`published` means stable and citable' "$spike_text"
expect_match "spike does not claim endorsement" 'not independently endorsed' "$spike_text"
expect_absent_match "spike has no review gate" 'review gate|passing review' "$spike_text"

# --- brainstorm persistence is explicit and spec promotion is ordered ---
brainstorm_text="$(cat "$SKILL/verbs/brainstorm.md")"
expect_match "bare brainstorm is write-free" 'Bare `brainstorm` and `brainstorm \[topic\]` work in conversation only' "$brainstorm_text"
expect_match "save is parsed as a command" 'Parse `brainstorm save \[name\]` before treating `save` as a topic' "$brainstorm_text"
expect_match "resume stays contained" 'beneath the canonical' "$brainstorm_text"
expect_match "save heuristics are forbidden" 'not duration, importance, open questions, multiple agents' "$brainstorm_text"
expect_match "brainstorm creates no record" 'Brainstorm never creates a record' "$brainstorm_text"

spec_text="$(cat "$SKILL/verbs/spec.md")"
expect_match "workspace draft is recognized" '<agent-workspace>/architect/drafts/' "$spec_text"
expect_match "spec exists before promotion" 'Promote a workspace draft after the spec exists' "$spec_text"
expect_match "failed spec leaves draft active" 'spec creation fails, leave the' "$spec_text"
expect_match "transient spike material is excluded" 'Do not copy raw spike notes, transient experiment code' "$spec_text"
expect_match "historical draft specs remain inputs" 'Existing draft spec records remain ordinary spec inputs' "$spec_text"

router_text="$(tr '\n' ' ' <"$SKILL/SKILL.md")"
expect_match "workspace resolution names front-door order" 'agent-workspace:.*AGENTS\.md.*CLAUDE\.md.*else `.spaces`' "$router_text"
expect_match "records resolution names front-door order" 'agent-records:.*records-root:.*same file order.*else `.records`' "$router_text"
expect_match "brainstorm uses shared home resolution" 'SKILL.md \*Project homes\*' "$brainstorm_text"
expect_match "spike uses shared home resolution" 'SKILL.md \*Project homes\*' "$spike_text"
expect_match "spec uses shared home resolution" 'SKILL.md \*Project homes\*' "$spec_text"

ideal_text="$(cat "$SKILL/docs/ideal-use.md")"
expect_match "worked arc shows no-artifact branch" 'conversation was enough' "$ideal_text"
expect_match "worked arc shows explicit save" 'brainstorm save report-json' "$ideal_text"
expect_match "worked arc keeps spec as baton" "sole feature baton" "$ideal_text"

# --- lock-in template is specs.md (store-named; not spec.md) ---
if [ -f "$SKILL/templates/specs.md" ] && [ ! -e "$SKILL/templates/spec.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: expected templates/specs.md and no templates/spec.md" >&2
  fail=$((fail + 1))
fi
if grep -qF -- '- `specs.md`' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: Project templates list does not name specs.md" >&2
  fail=$((fail + 1))
fi
project_templates="$(sed -n '/^## Project templates$/,/^## /p' "$SKILL/SKILL.md")"
expect_absent_match "draft outline is not deployed" '^- `draft\.md`' "$project_templates"
expect_absent_match "spike outline is not deployed" '^- `spikes\.md`' "$project_templates"

# --- no design.md stub changelog ---
hits=$(grep -n 'design.md was a front-matter' "$SKILL/SKILL.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md still carries the design.md stub footnote:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- description is trigger, not process summary ---
desc=$(awk 'BEGIN{p=0} /^---$/{c++; next} c==1 && /^description:/{p=1} c>=2{exit} p{print}' "$SKILL/SKILL.md")
if printf '%s' "$desc" | grep -qE 'Turns an idea|grill is the interview primitive'; then
  echo "FAIL: description still summarizes the process:" >&2
  echo "$desc" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

finish
