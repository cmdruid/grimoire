# Backlog debrief anchor harness acceptance

Disposition: promoted

## Problem or question

Does the implemented `debrief-anchor@1` reliably dispatch Backlog at each claimed observable
boundary under current Grok and Codex harnesses, while remaining silent for pure Q&A?

## Constraints and candidate approaches

Use six independent, freshly configured temporary Git projects: completion response, autonomous
two-unit transition, and pure Q&A for each harness. Install the current Backlog package into
`.agents/skills` and configure the tracker layer through package setup. Verify each harness discovers
the root `AGENTS.md` and project Backlog skill. Do not alter grimoire's root front door or add hosted
commands to deterministic test runners.

## Decisions and evidence

All six confirmed cells passed on 2026-08-29 under Grok 1.0.13 and codex-cli 0.150.1. Both
completion cells committed Unit One before a separate `Backlog: debrief` commit that captured the
exact deferred canary token without implementing the canary. Both transition cells performed the
Unit One debrief before their first Unit Two mutation and completed both units in order. Both Q&A
cells remained read-only and produced no debrief or tracker event. Transcript or rollout ordering,
queue state, exact result bytes, Git history, and final clean-tree checks supported each result.

The earlier Claude Code authentication failure remains historical evidence outside the replacement
gate. A preliminary Codex invocation was rejected locally because two CLI flags were mutually
exclusive; it started no thread, emitted no rollout, and touched no fixture, so the corrected
invocation is the attended cell. The published spike records all session and thread identifiers,
commit ordering, limitations, and the temporary evidence recipe.

## Open questions and next step

No acceptance question remains for this implementation baseline. The deterministic repository
gates are green and the published implementation plan is now `stage: implemented`; landing remains
with the host lane. Future Grok, Codex, or model upgrades should rerun the six-cell matrix because
the anchor is a behavioral prose contract rather than a mathematical guarantee.

## Spike notes

Budget consumed: six fresh fixtures and one attended model invocation per fixture. Baseline
versions: Grok 1.0.13 (`grok-4.6-build`) and codex-cli 0.150.1. Grok's initial read of both unit
briefs in the transition cell was classified as whole-request planning because no Unit Two mutation
occurred until after the Unit One debrief. Codex reported an unrelated expired Atlassian MCP OAuth
refresh in stderr but completed all cells without using that server.

Historical attempt, 2026-08-28: the superseded Claude completion cell stopped before model work
because its OAuth refresh token was invalid. Session ID:
`a9a6d43d-99e0-4e89-b621-35633a799128`. Its fixture remained byte-clean at baseline commit
`c598747`; no tracker or Backlog commit occurred. This observation explains the harness replacement
but is not part of the revised six-cell result.

## Related records

→ spikes/2026-08-29-backlog-debrief-anchor-harness-acceptance.md
