---
name: architect
description: "The design-system engine — a project's `.agents/architect/` seed: present-tense, regenerable design code builds from. `/architect init` stands up `.agents/architect/` (compiles a PROJECT.md brief, or migrates existing docs). `/architect extract` is the brownfield onramp — recover a provisional design draft from code into `.records/design-draft/`. `/architect brainstorm` and `/architect plan` do seed-altitude (foundational, not feature-scope) design work. `/architect distill` collapses accreted ADRs/plans into clean present-tense specs. `/architect calibrate` drains captured design-flavored dev-experience signal into targeted seed edits (external signal in; `distill` compacts internal accretion). `/architect check` validates seed health; `/architect reconcile` reports deep semantic seed↔code drift to `.records/reports/`. `/architect prep` (Plan B) plans clearing retired code for a fresh rebuild. Use when the user runs `/architect ...`, sets up a design-doc system, or makes a foundational design change."
---

# architect — the design-system engine

A skill over a project's `.agents/architect/` **seed**: the clean, present-tense, regenerable source of
truth that code is the disposable build output of. This `SKILL.md` is a thin **router**; each verb
lives in `verbs/<verb>.md`; the portable doctrine lives in `docs/DOCTRINE.md`.

## Altitude — what this skill owns
- `/architect` owns the **seed-altitude standing design**: it *authors* the seed and never writes
  executable code (it may *read* `src/` for `prep`). Feature-scope change and execution live elsewhere.
- The altitude seam (who owns which) is in the runbook (`packs/clankshop.md`); the seed is the shared
  contract (`docs/DOCTRINE.md`).

## Verbs
| verb | file | one-liner |
|---|---|---|
| `init` | `verbs/init.md` | compile a PROJECT.md brief (or migrate existing docs) into `.agents/architect/` |
| `extract` | `verbs/extract.md` | brownfield onramp: recover a descriptive, provisional design draft from code into `.records/design-draft/` |
| `brainstorm` | `verbs/brainstorm.md` | foundation-altitude ideation on the seed (radical, alpha-licensed) |
| `plan` | `verbs/plan.md` | sequence a design-evolution campaign |
| `distill` | `verbs/distill.md` | collapse accreted change-records into clean present-tense specs |
| `calibrate` | `verbs/calibrate.md` | drain captured design-flavored signal (tracker entries about the seed) into targeted seed edits |
| `check` | `verbs/check.md` | validate seed health (runs `scripts/architect-check.sh`) |
| `reconcile` | `verbs/reconcile.md` | deep semantic seed↔code drift check; writes a report to `.records/reports/` (recommends, never applies) |
| `prep` | *(verb file pending — method in `docs/DOCTRINE.md`)* | *(Plan B)* plan the clearing of retired code so `/feature` can rebuild |

## Discipline every verb shares
1. Author plans; never write executable code (you may read `src/` for `prep`).
2. Respect the durability gradient (`docs/DOCTRINE.md`): the spine is law; reference-arch is
   disposable and pointer-heavy.
3. Portable methodology stays in this package; project content stays in the project's `.agents/architect/`.

## Edges

Architect's **typed edges** -- its place in a workflow declared as artifact *types*, never as sibling
names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). A composer derives
cross-skill seams by matching these types against other skills' edges; architect names no successor.

<!-- edges:architect -->
- produces: design, roadmap — design specs (`brainstorm`/`plan`/`distill`) and roadmaps (`plan`)
- handoff: — (none in the core loop; the seed is a standing source others drain, not a baton architect passes)
- consumes: design, tracker-entry — `distill`/`reconcile` read architect's own accreted specs (intra-skill: same skill on both ends); `calibrate` drains captured design-flavored signal
<!-- /edges:architect -->

**The `consumes: design` pair is intra-skill, not a seam.** `distill`/`reconcile` read specs *this
skill* produced (`brainstorm`/`plan`) — a composer must **exclude** this produces↔consumes pair from
seam derivation, the same rule `feature`'s `design -> plan -> build` chain established (F2).

**Two candidate handoffs stay deferred, by design.** `/architect prep` (verb file still pending) would
terminate expecting a rebuild — a `handoff: plan`/`roadmap` to settle once `prep` is actually authored,
not before. `/architect reconcile` writes a drift report to `.records/reports/` — a candidate
`produces: audit-finding` (coarse-shared with `auditor`) *if* a drain seam is later wanted, but no
consumer has asked for one yet. Both stay out of `v0` (lightweight over configurable, per F5 -- the
starter vocabulary holds, no new types); a future consumer surfacing is what would settle either.
