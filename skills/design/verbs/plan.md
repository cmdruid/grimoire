# `/design plan` — sequence a design-evolution campaign

Sequences how a seed change becomes reality: which specs get revised, which systems get
prepped/regenerated, and in what order — a **seed-altitude roadmap**, not a build plan. See
`docs/DOCTRINE.md` for the durability gradient this verb sequences across, and
`verbs/brainstorm.md` for the verb that usually feeds it a starting change.

## The altitude discriminator

`plan` is the other verb name `/design` shares with `/feature`. Same seam as `brainstorm`:

> `/feature brainstorm|plan` mutate **code** (a change you build against the seed).
> `/design brainstorm|plan` mutate **the seed itself** (the foundation you later regenerate code
> from). *Changing the foundation → `/design`. Building on it → `/feature`.*

`/design plan` never produces an implementation plan — it produces a **sequence of seed work and
seed-driven downstream work**, expressed as references to other verbs, not as steps a developer
codes directly.

## What this verb references but does not perform

A design-evolution campaign spans work at two different altitudes, and `plan` only ever authors
the top one:

- **Seed-altitude work** (`plan` performs this itself, or hands directly to `brainstorm`): which
  `design/` files get revised, and in what order — e.g. "retire the `combat.md` contract's old
  hit-resolution invariant before touching `inventory.md`'s drop-table seam, since the latter
  depends on the former."
- **Per-system readiness + build work** (`plan` only *references* this — it is Plan B's job, not
  this verb's): for each system the campaign touches, whether it needs `/design prep` first
  (code already exists and is in the way, or a seam needs hardening before a feature attaches) and
  then an ordinary `/feature plan` → `/feature build` cycle. `plan` names *that this step exists
  and in what order it runs*, and stops there — it does not scope the prep brief, does not write
  the feature plan, and does not touch code. Per `docs/DOCTRINE.md` § The keystone, the clear run
  and the build run are separate `/feature` executions regardless of what `plan` says; `plan`'s
  job ends at naming the sequence.

If a step in the campaign turns out not to need `prep` at all (pure greenfield — the system has no
code yet), say so in the sequence rather than inserting a no-op prep step.

## Procedure

1. **Establish the input.** Usually a freshly-edited standing spec from `/design brainstorm` (the
   tenet/contract/seam/vision change already landed in `design/`) whose blast radius needs
   sequencing. It can also be a seed change the human made by hand, or a set of several related
   `brainstorm` edits landed separately that now need reconciling into one campaign. Read the
   edited file(s) directly — don't work from a description of the change.

2. **Compute the blast radius from `MAP.md`.** Walk the seam graph from the changed tenet,
   contract, or system outward: which systems' contracts cite the changed invariant, which seams
   connect to the changed boundary, which systems' `design/src/<system>.md` reference-architecture
   pointers assume the old shape. A tenet change in `PHILOSOPHY.md` can touch every system; a
   single seam redraw in `MAP.md` touches only the two systems on either end. Don't rely on the
   brainstorm session's own blast-radius guess (§4 of `verbs/brainstorm.md`) without re-deriving
   it from `MAP.md` — that guess was made mid-dialogue and may be incomplete.

3. **Sequence the spec revisions.** For each affected system, decide whether its
   `design/src/<system>.md` needs a direct edit (a small contract update `plan` can make inline,
   the same document-edit discipline `brainstorm` uses) or a full `brainstorm` pass of its own
   (the change there is itself foundational enough to need dialogue, not just propagation). Order
   these by dependency, not by convenience — a system's contract can't be correctly revised before
   the tenet or seam it depends on is settled.

4. **Sequence the per-system readiness + build work.** For each system whose *code* will need to
   change once its spec is settled, note in order: does it need `/design prep` (code exists, needs
   clearing or a hardened seam) or does it go straight to `/feature plan` (no code yet, or the
   change is additive enough that no readiness pass is needed)? Record this as a reference —
   "system X: prep (replace) → feature build" — not as an executed step. Sequence across systems
   by their `MAP.md` dependency order: a system other systems depend on generally clears/rebuilds
   before its dependents, so a dependent's build run lands against an already-settled seam.

5. **Author the campaign doc, and land it in the right home.** The campaign doc is the sequence
   itself: the ordered list of spec revisions (Step 3) and referenced prep/build work (Step 4),
   with the dependency reasoning that produced the order. It is **not** a standing spec — it's a
   snapshot of a plan of action, temporally scoped to this one campaign, closer in kind to the
   change-records `docs/DOCTRINE.md` keeps out of `design/` than to the present-tense specs that
   belong there. Two candidate homes, and the choice isn't free:
   - **`design/` (e.g. `design/plans/<slug>.md`)** — only if the project has no existing
     roadmap/plan convention of its own. Simple, portable default for a fixture or a
     brand-new project.
   - **The project's own roadmap location** (`<project: dev/plans/<date>-<slug>.md, indexed
     from ROADMAP.md>`; conventions vary) — **the recommended default**
     whenever the project already has one. A design-evolution campaign is a plan of forthcoming
     change, exactly the shape `dev/`'s operational history already exists to hold, and landing it
     there keeps it discoverable next to the ordinary feature roadmap instead of forking a second
     planning surface inside the seed.

   State which home was used and why in the report — don't silently default without recording the
   reasoning, since the next `/design prep` invocation needs to find this document.

6. **Stop at the campaign doc — this verb never executes the sequence.** `plan` doesn't invoke
   `/design prep`, doesn't invoke `/feature`, and doesn't touch code. Handing the campaign doc to
   the human (or to `/dev`/`/workstream` as the project's own orchestration layer) to actually walk
   the sequence is the next step, and it's outside this verb.

## Report

Close `plan` with: the input change(s) the campaign sequences, the blast radius computed from
`MAP.md` (Step 2), the ordered spec-revision list (Step 3), the ordered prep/build reference list
(Step 4) — each item tagged with its recommended mode (prep replace / prep extend / straight to
`/feature`, or none needed), where the campaign doc landed and why (Step 5), and an explicit
reminder that nothing in the sequence has been executed yet.
