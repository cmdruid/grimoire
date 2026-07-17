---
type: implementation
status: draft
updated: <YYYY-MM-DD>
related: [<dev/plans/<feature>-design.md>]
---

# <Feature> — Implementation Plan

## Global Constraints (verify vs HEAD before editing) — the plan gate (PLANNING.md -> Writing plans)
<Cross-cutting rules every task must honor — fill in, or delete the section if none:
- **Invariants:** what no task may break (the project's sacred keystone — see `dev/MEMORY.md`).
- **Live-API gotchas:** signatures / paths / lints that drift — the plan is a snapshot, so re-read
  each file against the worktree's HEAD before editing (the trunk moves; PLANNING.md -> *Writing plans*).
- **Coexisting work:** other active worktrees/streams this overlaps; the expected rebase seams.
- **CI-safety / scope limits:** what must stay green, platform-scoped, or opt-in.>

## Tasks
- [ ] **Task 1: <name>**
  - Files: <create / modify — exact paths>
  - Change: <what to do>
  - Verify: <command + expected result>
- [ ] **Task 2: <name>**
  - ...

## Done when
<The end-state condition and how it is verified (gate green, tests pass, ...).>

_On completion (before landing the work), run `/backlog debrief` to route what it surfaced to its
trackers (PLANNING.md -> When a plan completes)._
