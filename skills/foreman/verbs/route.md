# `/foreman` (route) — classify a change and dispatch it

The default verb: with no argument (or a change description), `/foreman` is the **change router**. It
reads the host's deployed `.agents/foreman/docs/DEVELOPMENT.md` as the source of truth (it does **not** restate
the decision-walk) and dispatches the change to the lane that owns it.

If the host project has **no `.agents/foreman/` system yet**, run `init` first (`verbs/init.md`), then route
through it.

## Procedure

1. **Classify** the change — bug / patch / feature / spike / **seed-altitude design** — by
   `.agents/foreman/docs/DEVELOPMENT.md`'s rules, plus the altitude discriminator below for the design case.
2. **Route**, dispatching to the verb or skill that owns the lane:
   - **bug** → `/backlog bug` — diagnose + file a report under the host's bug store.
   - **patch** → land on the trunk (the inline lane; no skill).
   - **feature** → the host's `PLANNING.md` tier decision → `/feature` (the plan+build engine:
     `brainstorm | design | plan | build`), built in a `/workstream` when it needs isolation.
   - **foundational / seed-altitude design change** (a `PHILOSOPHY` tenet, a system contract, a
     seam, the `VISION` — not a feature to build) → `/architect brainstorm` (then `/architect plan` to
     sequence the rollout). See *altitude discriminator* below for the test.
   - **distilling accreted ADRs/plans** back into a coherent present-tense spec → `/architect distill`.
   - **capture a follow-up** → `/backlog task` (a thing to build) · `/backlog issue` (a project
     problem/concern/limitation) · `/backlog note` (a durable project fact) · `/backlog feedback` (a
     dev-experience observation). A defect → `/backlog bug`.
   - **finished a body of work** → `/backlog debrief`; **calibrate the dev system** → `/foreman calibrate`;
     **validate the setup** → `/foreman check`; **code-quality** → `/auditor`; **context snapshot** →
     `/handoff`.
3. Where a lane's skill isn't installed, fall back to "do it by hand per the deployed doc." `/foreman`
   owns the routing *policy*; the verbs and companion skills own the *operations*.

## Relationship to neighboring lanes

- `route` dispatches to `/backlog`'s capture verbs (`task`, `bug`, `issue`, `feedback`, `note`, `debrief`, `curate`)
  and to the companion skills `/feature`, `/architect`, `/workstream`, `/auditor`, `/handoff` when the
  host has them.
- `/feature` is the feature-lane **plan+build engine** — it executes the host's `PLANNING.md` spine
  as verbs and stops at gate-green; landing + capture stay with `/workstream` + `/backlog debrief`.
- `/architect` is the **seed-altitude design engine** — a peer to `/feature`, not a subset of it. The
  seam is **altitude**, not docs-vs-code (`/feature design`/`plan` already produce documents too):
  `/feature brainstorm|plan` mutate **code** (a change you build against the seed); `/architect
  brainstorm|plan` mutate **the seed itself** (the foundation you later regenerate code from).
  *Changing the foundation → `/architect`. Building on it → `/feature`.* Without this check, the
  router silently keeps sending foundational work down the incremental `/feature` lane — route
  there whenever the change is asking "should this tenet/contract/seam even be this way," not
  "how do I build the next thing on top of it." See the `architect` skill's bundled `docs/DOCTRINE.md` for
  the full doctrine.
- `/auditor` is the code-quality analogue (it scores project code + invariants); `/foreman` routes the
  dev workflow and deploys/calibrates the doc-system. Keep them distinct.

## Done when

The change is classified and dispatched to the right lane/skill (or the by-hand fallback named) per
the host's `DEVELOPMENT.md`.
