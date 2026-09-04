#!/usr/bin/env bash
# proportionality-test.sh — keep Architect's default path useful and bounded.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

router=$(cat "$SKILL/SKILL.md")
brainstorm=$(cat "$SKILL/verbs/brainstorm.md")
grill=$(cat "$SKILL/verbs/grill.md")
spec=$(cat "$SKILL/verbs/spec.md")
template=$(cat "$SKILL/templates/specs.md")
brainstorm_flat=$(tr '\n' ' ' < "$SKILL/verbs/brainstorm.md")

expect_match "router carries proportionality guard" '^## Proportionality' "$router"
expect_match "whole spine is optional" 'Do not run the whole spine' "$router"

expect_match "brainstorm discovery is targeted" 'targeted context' "$brainstorm"
expect_match "one approach can suffice" 'One clear path may need only a recommendation' "$brainstorm_flat"
expect_absent_match "no exhaustive repo probe" 'inspect every path or registry' "$brainstorm"

expect_match "grill asks only material questions" 'material decision' "$grill"
expect_match "grill permits harmless uncertainty" 'non-blocking uncertainty' "$grill"
expect_absent_match "grill is not relentless" 'Relentless questioning|every decision branch resolves' "$grill"

expect_match "spec grills material gaps" 'material gaps' "$spec"
expect_match "review is conditional" 'Independent review is useful when' "$spec"
expect_match "metric attribution is conditional" 'metric population is ambiguous' "$spec"
expect_absent_match "review is not default ceremony" 'recommended by default' "$spec"
expect_absent_match "incident scar is not universal law" 'needs a population ATTRIBUTION' "$spec"

expect_match "template permits proportionate detail" 'Use only the detail the decision needs' "$template"
expect_absent_match "template does not demand total closure" 'every section argued, no open questions left' "$template"
expect_absent_match "spec does not become an implementation plan" '^## Slices|double as its plan' "$template"

finish
