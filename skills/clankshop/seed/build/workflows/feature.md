# The feature lane — idea to landed, gate-green code

Turn an idea into landed code: validate the approach, argue the design, plan task-by-task,
build to the green gate, land, close the books. Planning weight scales with the work (INV-12):
a **small feature** takes one brief that doubles as its plan; larger work — more than one phase,
or a decision worth an ADR — takes a roadmap written once, then a plan and build per phase.

**Enter from:** the routing walk's everything-else row — new behavior, several coupled changes,
or a design decision at stake.

**Policy:** the gate plus a relevant end-to-end check before each commit (INV-1); scoped
commits (INV-3); plans land in `.records/plans/`, ADRs in `.records/adr/`; done means landed on
`<trunk>` (INV-2); a dated plan or ADR is never retroactively edited (INV-9). A design decision
at stake goes to the design station **before** planning against it (INV-14). `/blueprint`,
where installed, writes the spec. **One phase, spec already implementable** (has slices or
is accepted as the plan) → this lane walks those slices; do **not** require
`/contractor plan`. **Sequencing required** (second phase, blocking edges, or a tracer
sequence) → `/contractor plan` (and `runbook` / `build` as needed). The stream still
`ship`s.

## The walk

1. Validate the approach before any spec: purpose, constraints, 2–3 candidate approaches, pick
   one with the human. Classify the weight (INV-12) — brief, or roadmap-then-phases.
2. Write the design: problem, goal, approach (+ alternatives rejected), mechanism,
   verification. Anything spec-level lands in `.records/design/`; have it reviewed before
   planning against it.
3. Plan task-by-task against the live tree — exact paths, complete code per step, riskiest
   piece spiked first. Re-verify every load-bearing signature at `HEAD` before sizing.
4. Build task-by-task, red-first: failing test → minimal implementation → `<gate>` green →
   **host formatter/cheap lint on the touched files** → scoped commit (INV-1, INV-3). The fmt
   step is load-bearing when transcribing plan-embedded literal code — a plan pins the author's
   hand formatting, not the formatter's, and the drift otherwise goes red at the full gate a
   cycle later (4 recurrences across independent streams). A **guard/absence test** ("X never
   happens") also needs a one-time red-proof: disable the guarded mechanism and watch the test
   fail — a fixture whose world cannot contain X stays green with the guard deleted. Pause only
   at a blocker or a genuine fork.
5. Land on `<trunk>` (rebase, re-verify the gate, merge); close the shipped plan
   (`records.sh done`).
6. Close the books: sweep follow-ups, learnings, and friction to the trackers; a cross-cutting
   decision that surfaced gets its ADR.

**Done when:** the change is landed on `<trunk>` with the gate green, the plan's tasks are all
checked or explicitly dropped, the plan's ledger line is written, and the debrief sweep has
captured every follow-up.
