---
doctype: plans
status: open
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [plan]
---

# <Feature> — Implementation Plan

<Tracer-bullet: slice 1 is the thinnest end-to-end path through the riskiest/newest ground;
later slices widen it. Each slice is independently testable and committable.>

Spec: <path to the governing spec / roadmap phase>

## Global Constraints (verify vs HEAD before editing — the plan gate)
<Cross-cutting rules every slice must honor — fill in, or delete the section if none:
- **Invariants:** what no slice may break (workshop: `core/INVARIANTS.md`).
- **Live-API gotchas:** signatures / paths / lints that drift (workshop: `core/GOTCHAS.md`) —
  the plan is a snapshot; re-read each cited file against the worktree's HEAD before editing.
- **Coexisting work:** other active worktrees/streams this overlaps; the expected rebase seams.
- **CI-safety / scope limits:** what must stay green, platform-scoped, or opt-in.>

## Slices
- [ ] **Slice 1: <name — the tracer>** <requires: —>
  - Files: <create / modify — exact paths>
  - Change: <what to do — complete code, no "similar to slice N">
  - Verify: <command + expected result>
- [ ] **Slice 2: <name>** <requires: 1, or — if parallel-eligible>
  - ...

## Done when
<The end-state condition and how it is verified (gate green, tests pass, ...).>

_On completion (before landing), run `/backlog debrief` to route what the build surfaced._
