# The feature lane — idea to landed, gate-green code

<!-- spine-doc v1
kind: workflow
doctrine: clankshop
doctrine-version: 2
refs: .handbook/**
budget: 60 lines
-->

Turn an idea into landed code through the planning spine: validate the approach, argue the design,
plan task-by-task, build to the green gate, land, close the books. Planning weight scales with the
work (INV-11): a **small feature** takes one brief that doubles as its plan; a **track** (more
than one phase, or a decision worth an ADR) takes a roadmap written once, then a plan and build
per phase.

**Enter from:** the routing walk's everything-else row — new behavior, several coupled changes, or
a design decision at stake.

**Project policy:** the gate plus a relevant end-to-end check before each commit (INV-1); scoped
commits (INV-3); planning artifacts land in `.records/plans/` (ADRs in `.records/adr/`) per the
record formats; done means landed on `<trunk>` (INV-2); a dated plan or ADR is never
retroactively edited (INV-8).

**Seam glue:** with the pipeline installed, `/feature` runs the spine (brainstorm → design →
plan → build) and stops at gate-green — landing and the debrief sweep stay with whoever
orchestrates the lane (a workstream, or this walk by hand). A foundational design decision at
stake → work that piece as the architect (`/clankshop design`) before planning against it. A
preference / scope / sign-off call only the human can make → `/backlog promote` per the promotion
bar. After landing, sweep the finished work to the trackers (`/backlog debrief`) and complete the
queue item's done-log line.

## The walk

1. Validate the approach before any spec: purpose, constraints, 2–3 candidate approaches, pick
   one with the human. Classify the tier (INV-11) — brief, or roadmap-then-phases.
2. Write the design: problem, goal, approach (+ alternatives rejected), mechanism, verification.
   Land it in `.records/plans/`; have it reviewed before planning against it.
3. Plan task-by-task against the live tree — exact paths, complete code per step, riskiest piece
   spiked first. Re-verify every load-bearing signature at `HEAD` before sizing.
4. Build task-by-task, red-first: failing test → minimal implementation → `<gate>` green → scoped
   commit (INV-1, INV-3). Pause only at a blocker or a genuine fork.
5. Land on `<trunk>` (rebase, re-verify the gate, merge); archive the shipped plan per its store's
   convention.
6. Close the books: done-log line for the item (INV-2); sweep follow-ups, learnings, and
   dev-experience signal to the trackers; a cross-cutting decision that surfaced gets its ADR.

**Done when:** the change is landed on `<trunk>` with the gate green, the plan's tasks are all
checked or explicitly dropped, the done-log line is written, and the debrief sweep has captured
every follow-up.
