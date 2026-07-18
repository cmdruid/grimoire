# Planning -- how to plan a change, and how much

Reached from `DEVELOPMENT.md` once you know you're building something. This doc decides *how
much* planning a change needs, sets the rules for each planning artifact, and keeps you friendly
to whatever planning skills you have active. The walk is `DEVELOPMENT.md` -> here -> a template in
`.agents/dev/templates/`.

## Pick a tier

Match the planning weight to the work -- over-planning a small change wastes as much as
under-planning a large one.

| Tier | When | Artifact(s) |
|---|---|---|
| **Patch** | a fix, a tweak, one self-contained change | none -- land on `main` (`DEVELOPMENT.md` -> *Fixes & patches*) |
| **Small feature** | one coherent feature, a single worktree's worth | one **feature brief** (prose: problem + task list + done-when) |
| **Track** | multi-phase, or a cross-cutting architecture call | a **roadmap** (`templates/roadmap.md`) + per-phase **implementation plans**, plus one **ADR** if it makes an architecture decision |

The line between small feature and track: **more than one phase, or a decision worth recording in
an ADR -> track.** Otherwise it's a small feature. When unsure, start with a brief and promote to
a track the moment a second phase or a cross-cutting decision appears.

## The artifacts

Most link to a template in `.agents/dev/templates/`. Copy it, or have your planning skill produce its shape
(see *Working with your planning skills*). All planning docs live in `.records/plans/`; ADRs in `.records/adr/`.
Every artifact instance carries the uniform frontmatter block -- types, per-type status sets, and
search recipes are the **capture taxonomy** `/backlog` owns and deploys (don't restate them here).

- **Feature brief** -- the small-feature fast path (no template, just prose): problem & approach in
  a few sentences, a task list (files / change / verify each), and a done-when. If it earns a
  worktree, the brief doubles as the hand-off.
- **Design / spec** (`templates/plan-design.md`) -- when a feature's approach is contested or
  large enough that the *why* must be argued before the *how*: problem, chosen approach,
  alternatives rejected, mechanism, verification. A track's design is its roadmap; a standalone
  design is rare outside a track.
- **Roadmap** (`templates/roadmap.md`) -- a track's spec: the phase sequence, shared foundations,
  and per-phase goal / scope / done-when / risks. Written **once** for the whole track and kept
  live in `.records/plans/` until it ships. The roadmap settles the design for *all* phases -- a phase
  is not re-brainstormed.
- **Implementation plan** (`templates/plan-implementation.md`) -- the task-by-task brief an
  implementer executes: each task's files, change, verify, plus a done-when. A small feature
  folds this into its brief; a track writes one per phase
  (`plans/<track>-phaseN-implementation.md`).
- **ADR** (`templates/adr.md`) -- a Nygard record of a cross-cutting architecture decision:
  context, decision, alternatives, consequences. Write one **only** when a choice shapes the
  system beyond the feature and is worth remembering -- one per track, not per phase. It lands in
  `.records/adr/NNNN-<slug>.md` and stays live after the feature ships. (`WORKTREES.md` covers where
  the file sits in the git flow.)

## Writing plans -- pitfalls that recur

Lessons from real plan execution. All were caught cheaply by red-first TDD, so the value is in
pre-empting them, not alarm:

- **The design ages well; the *literal API/data* ages fast.** A plan written without checking
  against the live tree drifts at the API/arity layer. Name the load-bearing live-API gotchas in
  the plan's Global Constraints -- the source list is the project's gotchas doc -- and re-verify
  each against the worktree's `HEAD` before editing (the plan is a snapshot; `main` moves).
- **Re-measure before you size -- a snapshot count is a guess.** Any figure a plan sizes or
  sequences work from -- a lint/warning count, a diff size, a benchmark number, a library's
  current API -- drifts as `main` moves. Run the actual tool against `HEAD` and read the real
  output before estimating. Staleness bites metrics, not just APIs.
- **TDD fixtures must respect the rule's *full* dimensionality.** A fixture written from a
  simplified mental model of a multi-dimensional rule bakes in wrong geometry. Sanity-check
  fixture *setup* -- not just its dependencies -- against what the behaviour actually exercises.
- **Spike the riskiest/newest tech first, and verify it *visually* or *end-to-end* in isolation.**
  Make the one genuinely-new piece Task 1, proven on its own, before the work that depends on it --
  a green unit test can hide a blank render or a silent failure in an integration path. Default for
  any plan that introduces a new tech boundary.

## Working with your planning skills

If you have planning skills active (brainstorming, writing-plans, and the like), **use them** --
they own the *process*. The templates here define the *output*: its shape, its required bits, and
where it lands. They are not a competing process.

- **Don't double-plan.** Run your skill, then map its output onto the repo convention -- don't
  run a skill *and* re-fill a template by hand. The template is the shape your plan lands as, not
  extra busywork.
- **Land in `.records/plans/`, never a skill-default path.** Some skills default to their own output
  dirs; this system requires `.records/plans/` (and `.records/adr/` for ADRs). Redirect the output there.
- **Carry the repo bits.** However it was produced, a planning doc needs its status line and links
  to its ADR/roadmap.
- **Spend planning effort by tier.** A patch needs none; a small feature rarely needs a full
  brainstorm -- a brief is enough; a track earns one real brainstorm for the roadmap, then a light
  per-phase plan. No active planning skill? Copy the template directly -- same destination.

## When a plan completes -- debrief

When an implementation plan or feature brief meets its **Done when** -- or a roadmap phase its
**Definition of done** -- run **`/backlog debrief`** (if available) before the work is considered
finished, while the session still holds everything it surfaced. It sweeps the completed work and
routes each byproduct to its one home in `.records/`: a thing to build -> `tasks.md`, a
project problem / concern / limitation -> `issues.md`, a defect -> a linked report in `bugs/`, a
dev-experience observation -> `feedback.md`, and a durable project fact (including a would-be
invariant or gotcha) **parked as a `note`** (capture never promotes; `/foreman tune` later promotes
it into `.agents/foreman/MEMORY.md` / `.agents/foreman/GOTCHAS.md`), with any long-form context spilled to a
linked `.records/notes/` file (the canonical taxonomy is `/backlog`'s `docs/TAXONOMY.md`).

This trigger is the work being **done**, not *landing* it: run it at completion -- before you
commit / merge / ship -- never as a step of the transport. If no `/backlog debrief` skill is available,
run the same sweep manually before closing the session.

## Multi-phase tracks -- plan once, advance cheaply

A track is brainstormed and spec'd **once** into a roadmap, then built in **one** worktree that
persists across *all* phases. You do **not** re-spec or re-create the worktree per phase -- that
repetition is the waste this avoids.

**Policy per phase:** write the phase's implementation plan from the roadmap, build it, and when it
meets its done-when run **`/backlog debrief`** (the phase is finished -- capture what it surfaced while
context is rich, per *When a plan completes*); then **`ship`** it to `main` so it's reviewable --
**without tearing the worktree down**. Record what shipped (archive
the finished phase's plan to `plans/archive/`, and write a dated `.records/archive/<YYYY-MM-DD>-<slug>.md`
with commit refs), advance the hand-off to the next phase, and draft N+1's plan from the roadmap.
The roadmap and worktree live on; only the hand-off advances. Tear down (run `close` manually, or via `/workstream close` if available) only
when the queue is exhausted or the stream is paused. (`/workstream` automates this whole loop if available:
`ship` lands a phase and advances; `close` is the rare teardown.)
