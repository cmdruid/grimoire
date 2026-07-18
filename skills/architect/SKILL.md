---
name: architect
description: "The design-system engine — verbs over a project's `.agents/architect/` seed: the present-tense, regenerable design that code is a build output of. `/architect init` stands up `.agents/architect/` (compiles a PROJECT.md brief, or migrates existing docs). `/architect extract` is the brownfield onramp — recover a provisional design draft from code into `.records/design-draft/`. `/architect brainstorm` and `/architect plan` do seed-altitude (foundational, not feature-scope) design work. `/architect distill` collapses accreted ADRs/plans into clean present-tense specs. `/architect check` validates seed health (spine, drift, distill-debt); `/architect reconcile` reports deep semantic seed↔code drift to `.records/reports/`. `/architect prep` (Plan B) plans clearing retired code so a fresh rebuild can follow. Use when the user runs `/architect ...`, sets up a design-doc system, or makes a foundational (not feature-scope) design change."
---

# architect — the design-system engine

A skill over a project's `.agents/architect/` **seed**: the clean, present-tense, regenerable source of
truth that code is the disposable build output of. This `SKILL.md` is a thin **router**; each verb
lives in `verbs/<verb>.md`; the portable doctrine lives in `docs/DOCTRINE.md`.

## The seam this skill lives on
- The seam is **altitude**: `/architect` owns the *seed-altitude standing design*; `/feature` owns
  *feature-scope change + execution*.
- `/architect` authors plans; `/feature` executes them. A *derived* property: `/architect` never writes
  executable code (it may *read* `src/` for `prep`).
- The seed is the shared contract. See `docs/DOCTRINE.md`.

## Verbs
| verb | file | one-liner |
|---|---|---|
| `init` | `verbs/init.md` | compile a PROJECT.md brief (or migrate existing docs) into `.agents/architect/` |
| `extract` | `verbs/extract.md` | brownfield onramp: recover a descriptive, provisional design draft from code into `.records/design-draft/` |
| `brainstorm` | `verbs/brainstorm.md` | foundation-altitude ideation on the seed (radical, alpha-licensed) |
| `plan` | `verbs/plan.md` | sequence a design-evolution campaign |
| `distill` | `verbs/distill.md` | collapse accreted change-records into clean present-tense specs |
| `check` | `verbs/check.md` | validate seed health (runs `scripts/architect-check.sh`) |
| `reconcile` | `verbs/reconcile.md` | deep semantic seed↔code drift check; writes a report to `.records/reports/` (recommends, never applies) |
| `prep` | *(verb file pending — method in `docs/DOCTRINE.md`)* | *(Plan B)* plan the clearing of retired code so `/feature` can rebuild |

## Discipline every verb shares
1. Author plans; never write executable code (you may read `src/` for `prep`).
2. Respect the durability gradient (`docs/DOCTRINE.md`): the spine is law; reference-arch is
   disposable and pointer-heavy.
3. Portable methodology stays in this package; project content stays in the project's `.agents/architect/`.
