---
name: clankshop
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, and audit both code quality and doc ergonomics."
skills: architect auditor backlog chiropractor delegate feature foreman handoff mailbox workstream
---

# clankshop — the disciplined development loop (a `/foreman init` runbook)

This file is a **runbook**, not a brochure — the composition that configures `foreman` and the rest
of the constellation into a coherent system, and prepares a project's codebase to use them together.
Run **`/foreman init`** to apply it: `foreman` is the mechanism that reads this recipe and stamps the
glue — the seams, the initial `AGENTS.md` wiring, each skill's own self-init dispatch.

**Mechanism vs. composition.** `/foreman` is the **oven** (the mechanism: how to instantiate *any*
composition — pack-agnostic, it never names a specific skill). This file is the **recipe** (the
composition: which skills, and the seams that bind them). The pack **calls** the tool; the tool
never depends on the pack. **The recipe owns the glue content and *births* the constellation; the
oven *stamps* that glue at `init` and *grows* it afterward via `calibrate` — it never authors the
pack-specific glue.** On a bare install with no pack, `/foreman init` **baselines** —
introspects the installed skills, wires the ones it recognizes, and names by-hand fallbacks for the
rest.

**Since Phase 5's typed-edge rollout (`docs/design/2026-07-18-skill-self-init-model.md`), a real
subset of cross-skill wiring lives in each skill's *own* `## Edges` block and is mechanically
**derivable** — `scripts/foreman-health.sh derive-seams <skills-root>` reads every installed skill's
edges and reports the control-flow `seam:`s and data `dep:`s that fall out of matching
produces/handoff against consumes (model §2.1, §5.1). This runbook is now the *enrichment* that
edge-matching **can't** derive: an altitude/scope boundary (who owns *which layer*, not who reads
whose typed output), a role split with no shared artifact type, or a framing metaphor a bare `X reads
Y's T` fact doesn't carry. Where a row below restates a fact `derive-seams` already reports
mechanically, it's marked **(derived)** — kept for the human-readable narrative, not because the
wiring itself still needs hand-authoring here.

## The composition foreman instantiates

Ten skills in four layers. `/foreman init` deploys the `.agents/foreman/` glue, wires `AGENTS.md`, and
lists these as the constellation the deployed doctrine resolves to.

```
  workflow      foreman ──── the hub/router: classify a change, deploy/operate the .agents/foreman/ system
                backlog ──── the capture desk: file follow-ups to trackers, sweep finished work
  engines       architect ── the design-system engine: maintains a project's regenerable design/ seed
                feature ─── the planning spine: brainstorm → design → plan → build (+ review)
                workstream ─ the loop orchestrator: one worktree, one stream, ship after ship
  delegation    delegate ── the front-door: delegate-or-not, mechanism, route confirmation
                mailbox ─── the transport: out-of-band slot handoff, worktree-safe
  session       handoff ─── save/resume disciplines (root sessions; workstream reuses them)
  auditors      auditor ─── project CODE quality (rubric + metrics + findings → trackers)
                chiropractor ─ doc-SPINE ergonomics (scan → diagnose → adjust)
```

### The members

- **`foreman`** — the dev-workflow hub. A thin router + verbs (`route` default, `init`, `migrate`,
  `calibrate`, `check`). Deploys and operates a project's `.agents/foreman/` development-docs system —
  `init` on a greenfield project (nothing there yet), `migrate` as the brownfield onramp (locate an
  existing `dev/`/ad-hoc setup, propose a relocation mapping, confirm, `git mv`, scaffold the gaps).
- **`backlog`** — the capture desk. Files each follow-up by kind (`task`, `bug`, `issue`,
  `feedback`, `note`), sweeps finished work (`debrief`), and curates the trackers (`curate`).
- **`architect`** — the design-system engine: maintains a project's regenerable `.agents/architect/`
  seed as layer-steward — stand up (`init`, `extract` the brownfield onramp), evaluate (`check`),
  drift-correct (`reconcile`), evolve (`distill`/`plan`/`brainstorm`), plus `prep` (Plan B). Seed-altitude
  peer to `feature`.
- **`feature`** — the planning spine as verbs: `brainstorm | design | plan | build`, plus the
  cross-cutting `review`. Ends at gate-green; never lands or debriefs.
- **`workstream`** — drive a long-lived stream in a git worktree (create → save/load → sync →
  ship → recycle → close). Orchestrates `feature` (build) + `/backlog debrief` (capture) + `handoff`
  disciplines; owns landing and the reset ritual.
- **`delegate`** — the delegation front-door: recognize delegable work and route it (inline
  sub-agent / mailbox / external executor / parallel fan-out / isolated worktree) for speed, token
  cost, or context hygiene. Proactive on *whether* to delegate; confirms the *route* with the
  human, since live cost/availability is unobservable.
- **`mailbox`** — out-of-band sub-agent handoff: the delegate writes its result to a git-excluded
  `.mailbox/` slot and returns a handle; the parent applies a patch (tokenless) or consumes a doc.
  The worktree-safe transport `delegate` routes to; canonical home of the single-writer rule.
- **`handoff`** — save/resume a session snapshot; provides the Save/Resume disciplines the other
  skills reuse.
- **`auditor`** — code-quality audit framework (per-dimension rubric, metrics, findings → trackers).
- **`chiropractor`** — audit and tune a repository's documentation *spine* (the link tree rooted
  at the agent entry door) for agent ergonomics: scan → diagnose → adjust. Self-contained; runs
  in any repo.

### Outside this pack: `skill-builder`

One more skill lives in this library, deliberately **not** in the `skills:` manifest above:
`skill-builder`, the toolmaker steward for the skill library itself (scaffold new skills, audit
boundary health, distill the authoring doctrine — `docs/design/2026-07-19-phase7-skill-builder.md`).
It's a maintainer tool for whoever *authors* skills, not a member of the development loop this pack
composes for a consuming project — the same "toolmaker workflow, not a `/foreman` verb" line that
put the boundary audit outside `/foreman` in the first place.

## The canonical layout foreman init instantiates

`/foreman init` stands up **two roots**, then writes an **ownership index** (`.agents/README.md` +
`.records/README.md`, plus a front-door pointer) — load-bearing here because the paths no longer
encode ownership, so a cold agent needs the index to learn *what lives where, and who stewards it*.

```
.agents/                  the SEEDS root -- hand-curated source of truth, one home per steward
  architect/              the design seed                          (steward: /architect -- distill)
  foreman/                dev doctrine + MEMORY + GOTCHAS + docs/   (steward: /foreman -- calibrate)
  auditor/                the audit rubric: GUIDE, rules/, metrics.sh  (steward: /auditor)
.records/                 the RECORDS root -- every typed record
  design-draft/           provisional design draft (brownfield onramp) (writer: /architect extract)
  tasks.md · issues.md · feedback.md · bugs/ · notes/             (steward: /backlog)
  plans/                  design plans / roadmaps                  (writer: /feature)
  archive/                shipped / done records                   (writer: /workstream)
  adr/                    architecture decision records            (writer: /feature; distilled into seed by /architect)
  reports/ · logs/        research findings / run artifacts / seed<->code drift reports  (foreman / various; drift reports writer: /architect reconcile)
  audit/                  FINDINGS · metrics.csv · history/        (writer: /auditor)
```

Session hand-offs are **gitignored scratch** (root `HANDOFF.md`; concurrent named sessions under
`.sessions/`), stewarded by `handoff` — deliberately *not* a `.records/` store. The mechanics of the
tree live in `foreman`'s `BOOTSTRAP.md` (§4 + §4.1); this runbook supplies the steward map, which is
the composition `init` records and `/foreman check` validates for drift.

## The seam contracts (the architecture is in the seams)

The layers describe *what each skill is*; the **seams** describe *how they compose without
overlapping*. These are what `/foreman init` records as the composition, and what `/foreman check`
validates for drift. The load-bearing invariant: **no skill crosses another's seam.**

| seam | contract | edge-matching |
|---|---|---|
| `backlog` ↔ `foreman` | `backlog` **captures** (single front-door, uniform); `foreman calibrate` **drains** the system-relevant slice into doctrine. Inbox vs. curator. | **dep** — `foreman` reads `backlog`'s `tracker-entry` |
| `foreman` ↔ `clankshop` (this pack) | `foreman` = mechanism (oven); this runbook = composition (recipe). The pack **calls** foreman; foreman never depends on the pack. | — (this pack's own relationship to the tool, not a skill-to-skill artifact flow) |
| `foreman` ↔ `chiropractor` | `clankshop` **specifies** the `AGENTS.md` workflow-glue (content); `foreman` **stamps** it at `init` and **grows** it via `calibrate` (mechanism); `chiropractor` **audits** the front-door's ergonomics. Specify → stamp → audit — none authors another's part. | — (a maintenance-role split; neither skill declares a type the other consumes) |
| `architect` ↔ `chiropractor` | `architect`'s GLOSSARY = **domain** terms (part of the seed); `chiropractor`'s concern = a **navigational** glossary/index exists and is linked. Domain vs. navigation. | — (chiropractor's edges are all `—`; no shared type) |
| `architect` ↔ `feature` | `architect` authors the seed (seed altitude); `feature` builds a change against it (feature scope). The altitude seam. | **dep** — `feature` reads `architect`'s `design`, `architect` reads `feature`'s `design` (coarse-shared type, model §2.2) |
| `architect` ↔ `foreman` | `architect` owns the **design system** (the regenerable seed code builds from); `foreman` owns the **operational system** (how a change is routed, built, calibrated). Design vs. operation. | — (an altitude boundary; foreman doesn't consume `design`/`roadmap`) |
| `architect` ↔ `workstream` | A stream's queue can source **directly** from architect's roadmap — bypassing `feature` — when the work is already plan-shaped at seed altitude. | **dep** — `workstream` reads `architect`'s `roadmap` |
| `feature` ↔ `workstream` ↔ `backlog` | `feature` ends at gate-green; `workstream` lands; `backlog debrief` captures. Three seams, one rule: none crosses another's. | **seam** — `feature -> workstream (gate-green-code)` (a real control-flow arrow, `feature`'s `handoff` matched) **+ dep** — `workstream` reads `feature`'s `plan` (the other queue-source shape); the `backlog` leg stays hand-authored (no shared type — a debrief captures *about* the ship, it doesn't consume workstream's typed output) |
| `delegate` ↔ `mailbox` | `delegate` **decides** (delegate-or-not, mechanism, route, return contract); `mailbox` **carries** (the worktree-safe slot transport `delegate` routes to). Decision vs. transport. | — (both are pure-mechanism, deliberately no typed artifacts — exactly the case edge-matching can't and shouldn't derive) |
| `auditor` ↔ `chiropractor` | `auditor` scores **project code** against a quality rubric; `chiropractor` tunes the **doc spine's** ergonomics. Code vs. docs (see *"Which audit?"* below). | — (chiropractor's edges are all `—`; no shared type) |
| `foreman` ↔ `auditor` | `auditor` scores; `foreman calibrate` **drains** the scored signal into doctrine, the same drain relationship it has with `backlog`. Scorer vs. curator. | **dep** — `foreman` reads `auditor`'s `audit-finding` |

Four rows carry a **dep** or **seam** tag — those facts now come from `derive-seams`, not from hand-maintaining this table; the *contract* column's framing (why the wiring exists, which layer owns what) stays hand-authored regardless, since edge-matching reports only "`X` reads `Y`'s `T`," never the altitude/scope reasoning behind it. The remaining six rows are genuinely **not** derivable — a role/scope/altitude split with no shared typed artifact — and stay this runbook's to state. (Phase 6 re-ran `derive-seams` against the live tree and reshaped this table to match its full current output — `architect ↔ workstream` and `foreman ↔ auditor` were real deps the Phase 5 pass hadn't yet folded in.)

## Typed edge vocabulary (reference)

The **known types** in current use, for a human or composer scanning what strings mean something —
not a schema a skill must import (the vocabulary stays open-string, per the model doc §2.2). This
table is itself a **snapshot**: regenerate it from `scripts/foreman-health.sh derive-seams
<skills-root>` rather than trusting it once `## Edges` blocks drift.

| type | produced by | consumed by |
|---|---|---|
| `tracker-entry` | `backlog` | `foreman` (calibrate) |
| `design` | `architect` (brainstorm/plan/distill), `feature` (design) | `feature` (its own plan stage), `architect` (its own distill/reconcile) — each also reads the *other's* `design`, the derived cross-skill dep above |
| `plan` | `feature` (plan) | `feature` (its own build stage), `workstream` (queue source) |
| `gate-green-code` | `feature` (build) — also declared as a `handoff` | `workstream` (ship) |
| `roadmap` | `architect` (plan) | `workstream` (queue source) |
| `audit-finding` | `auditor` | `foreman` (calibrate) |
| `handoff-doc` | `handoff` (save) | `handoff` (resume) — intra-skill only; no cross-skill consumer yet (the standing orphan WARN, BL-4) |

## The glue-workflows (how the seams run in practice)

- **Make a change.** `/foreman` (route) classifies it — bug / patch / feature / spike — and
  dispatches to the lane. A feature routes through `/feature` (plan → build to gate-green), then
  `/workstream` lands it, then `/backlog debrief` captures the follow-ups. No hand re-does another's
  step.
- **Ship continuously.** `/workstream create` opens a stream in its own worktree and loops:
  `/feature build` per queue item → land per the stream's mode → `/backlog debrief` → advance. The
  worktree and hand-off **persist** across ships; teardown is rare.
- **Design at seed altitude.** `/architect` maintains the regenerable `.agents/architect/` seed;
  `/feature design` builds a change *against* that seed. Seed altitude vs. feature scope.
- **Delegate without polluting context.** `/delegate` decides delegate-or-not and picks the route;
  `mailbox` is the worktree-safe transport for the out-of-band result. Grunt work goes to a cheap
  model; the orchestrator keeps its context lean.
- **Survive a reset.** `/handoff save` snapshots the root session; `/handoff resume` picks it up.
  `/workstream save`/`load` reuse the same discipline for worktree streams.
- **Calibrate the system from its own signal.** `/backlog` captures friction; `/foreman calibrate` drains the
  system-relevant slice back into the deployed doctrine + `AGENTS.md` — the self-growing curation
  loop. `/foreman check` is the cheap drift validator between ships.

## Which audit?

Project *code* → `auditor`. The repo's *doc spine* (links, entry door, navigability) →
`chiropractor`. A deployed *`.agents/foreman/` docs system's* health (trackers, drains, staleness) →
`/foreman calibrate` / `/foreman check`. The *skill library's own skills* (boundary independence,
`## Edges` well-formedness, the lint gate) → `skill-builder check` — a **toolmaker** concern, distinct
from the other three (which audit a project this pack is deployed *onto*; `skill-builder` audits the
skills doing the deploying, and stays outside this pack for that reason — see *Outside this pack:
`skill-builder`* above). Four domains, four tools — they don't overlap.

## Install

From the clone root:

```
./install.sh --pack clankshop
```

Then, in a target project, run **`/foreman init`** (greenfield — nothing there yet) or **`/foreman
migrate`** (brownfield — an existing `dev/`/ad-hoc setup) — either reads this runbook as the
composition and stands the `.agents/foreman/` glue up to the same target state.
