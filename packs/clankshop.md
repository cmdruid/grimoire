---
name: clankshop
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, and audit both code quality and doc ergonomics."
skills: architect auditor backlog chiropractor delegate feature foreman handoff mailbox workstream
---

# clankshop — the disciplined development loop (a `/foreman init` runbook)

This file is a **runbook**, not a brochure. To stand up this constellation in a project, run
**`/foreman init`** — it consumes this file as the **composition** and instantiates the glue.

**Mechanism vs. composition.** `/foreman` is the **oven** (the mechanism: how to instantiate *any*
composition — pack-agnostic, it never names a specific skill). This file is the **recipe** (the
composition: which skills, and the seams that bind them). The pack **calls** the tool; the tool
never depends on the pack. On a bare install with no pack, `/foreman init` **baselines** —
introspects the installed skills, wires the ones it recognizes, and names by-hand fallbacks for the
rest. This runbook is the *enrichment* that baseline can't derive: the cross-skill seams live
*between* skills, in no single skill's frontmatter, so they must live here.

## The composition foreman instantiates

Ten skills in four layers. `/foreman init` deploys the `.agents/dev/` glue, wires `AGENTS.md`, and
lists these as the constellation the deployed doctrine resolves to.

```
  workflow      foreman ──── the hub/router: classify a change, deploy/operate the .agents/dev/ system
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

- **`foreman`** — the dev-workflow hub. A thin router + verbs (`route` default, `init`, `tune`,
  `check`). Deploys and operates a project's `.agents/dev/` development-docs system.
- **`backlog`** — the capture desk. Files each follow-up by kind (`task`, `bug`, `issue`,
  `feedback`, `note`), sweeps finished work (`debrief`), and curates the trackers (`curate`).
- **`architect`** — the design-system engine: maintains a project's regenerable `.agents/design/`
  seed; verbs `init`/`brainstorm`/`plan`/`prep`/`distill`/`check`. Seed-altitude peer to `feature`.
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

## The seam contracts (the architecture is in the seams)

The layers describe *what each skill is*; the **seams** describe *how they compose without
overlapping*. These are what `/foreman init` records as the composition, and what `/foreman check`
validates for drift. The load-bearing invariant: **no skill crosses another's seam.**

| seam | contract |
|---|---|
| `backlog` ↔ `foreman` | `backlog` **captures** (single front-door, uniform); `foreman tune` **drains** the system-relevant slice into doctrine. Inbox vs. curator. |
| `foreman` ↔ `clankshop` (this pack) | `foreman` = mechanism (oven); this runbook = composition (recipe). The pack **calls** foreman; foreman never depends on the pack. |
| `foreman` ↔ `chiropractor` | `foreman` **authors** the `AGENTS.md` workflow-glue section; `chiropractor` **audits** the whole front-door's ergonomics. Author vs. auditor. |
| `architect` ↔ `chiropractor` | `architect`'s GLOSSARY = **domain** terms (part of the seed); `chiropractor`'s concern = a **navigational** glossary/index exists and is linked. Domain vs. navigation. |
| `architect` ↔ `feature` | `architect` authors the seed (seed altitude); `feature` builds a change against it (feature scope). The altitude seam. |
| `feature` ↔ `workstream` ↔ `backlog` | `feature` ends at gate-green; `workstream` lands; `backlog debrief` captures. Three seams, one rule: none crosses another's. |

## The glue-workflows (how the seams run in practice)

- **Make a change.** `/foreman` (route) classifies it — bug / patch / feature / spike — and
  dispatches to the lane. A feature routes through `/feature` (plan → build to gate-green), then
  `/workstream` lands it, then `/backlog debrief` captures the follow-ups. No hand re-does another's
  step.
- **Ship continuously.** `/workstream create` opens a stream in its own worktree and loops:
  `/feature build` per queue item → land per the stream's mode → `/backlog debrief` → advance. The
  worktree and hand-off **persist** across ships; teardown is rare.
- **Design at seed altitude.** `/architect` maintains the regenerable `.agents/design/` seed;
  `/feature design` builds a change *against* that seed. Seed altitude vs. feature scope.
- **Delegate without polluting context.** `/delegate` decides delegate-or-not and picks the route;
  `mailbox` is the worktree-safe transport for the out-of-band result. Grunt work goes to a cheap
  model; the orchestrator keeps its context lean.
- **Survive a reset.** `/handoff save` snapshots the root session; `/handoff resume` picks it up.
  `/workstream save`/`load` reuse the same discipline for worktree streams.
- **Tune the system from its own signal.** `/backlog` captures friction; `/foreman tune` drains the
  system-relevant slice back into the deployed doctrine + `AGENTS.md` — the self-growing curation
  loop. `/foreman check` is the cheap drift validator between ships.

## Which audit?

Project *code* → `auditor`. The repo's *doc spine* (links, entry door, navigability) →
`chiropractor`. A deployed *`.agents/dev/` docs system's* health (trackers, drains, staleness) →
`/foreman tune` / `/foreman check`. Three domains, three tools — they don't overlap.

## Install

From the clone root:

```
./install.sh --pack clankshop
```

Then, in a target project, run **`/foreman init`** — it consumes this runbook as the composition and
stands up the `.agents/dev/` glue.
