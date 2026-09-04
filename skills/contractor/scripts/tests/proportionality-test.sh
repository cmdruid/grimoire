#!/usr/bin/env bash
# proportionality-test.sh — regression gates for Contractor's scope and ceremony budget.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

router=$(cat "$SKILL/SKILL.md")
plan=$(cat "$SKILL/verbs/plan.md")
build=$(cat "$SKILL/verbs/build.md")
roadmap=$(cat "$SKILL/verbs/roadmap.md")
runbook=$(cat "$SKILL/verbs/runbook.md")
template=$(cat "$SKILL/templates/plan.md")
roadmap_template=$(cat "$SKILL/templates/roadmap.md")
router_flat=$(tr '\n' ' ' < "$SKILL/SKILL.md")
plan_flat=$(tr '\n' ' ' < "$SKILL/verbs/plan.md")

# A clear user request is enough to plan. Records and review belong to the
# explicit formal path, not the bounded default.
expect_match "router has scope firewall" '^## Scope firewall' "$router"
expect_match "router names proportional modes" '^## Operating levels' "$router"
expect_match "request can establish scope" 'clear user request' "$router_flat"
expect_match "metadata records approval" 'metadata records approval; it does not create it' "$router_flat"
expect_match "bounded work defaults atomic" 'An atomic plan is the default' "$plan"
expect_match "plan may stay conversational" 'conversation by default' "$plan"
expect_match "build accepts explicit authorization" 'explicit user authorization' "$build"

# Incident scars must not remain universal requirements.
expect_absent_match "no mandatory spec refusal" 'raw conversation with no spec.*not this verb' "$plan"
expect_absent_match "no universal Task 0" 'literal Task 0' "$plan"
expect_absent_match "no default sub-agent sweep" 'Dispatch a sub-agent when' "$plan"
expect_absent_match "no complete-code mandate" 'complete code in every slice' "$plan"
expect_absent_match "no default independent review" 'recommended by default' "$plan"
expect_absent_match "no metadata-writing waiver" 'caller.*writes the.*same.*gate' "$build"

# Durable orchestration remains available, but only when selected for a
# concrete reason. It is not an automatic successor or build prerequisite.
expect_match "roadmap is explicitly durable" 'explicit durable workflow' "$roadmap"
expect_match "runbook is explicitly durable" 'explicit durable workflow' "$runbook"
expect_absent_match "roadmap does not auto-start planning" 'Terminal step:.*plan' "$roadmap"
expect_absent_match "runbook is not a build prerequisite" 'Compile a runbook first' "$build"

# The default scaffold is deliberately small.
expect_match "template has scope" '^## Scope$' "$template"
expect_match "template has implementation" '^## Implementation$' "$template"
expect_absent_match "template does not force tracer slices" 'Tracer-bullet|Slice 2' "$template"
expect_absent_match "template does not force global ceremony" 'Global Constraints|close-the-books' "$template"
expect_absent_match "roadmap template accepts non-spec sources" '^Spec:|governing spec' "$roadmap_template"
expect_absent_match "roadmap template has no universal review or closure" 'passing host.s review|close-the-books' "$roadmap_template"

# Two concrete regression scenarios anchor the distinction. These are policy
# examples, not an expanding classifier.
expect_match "bounded Docker example stays light" 'local Docker readiness fix.*atomic plan' "$plan_flat"
expect_match "irreversible migration earns formal controls" 'irreversible production data migration.*durable plan.*rollback' "$plan_flat"

finish
