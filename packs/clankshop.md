---
name: clankshop
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, and audit both code quality and doc ergonomics."
skills: architect auditor backlog chiropractor delegate feature foreman handoff mailbox workstream
---

# clankshop — the disciplined development loop

Ten skills in four layers. The seam contracts between them are the architecture: **`/feature`
ends at gate-green; `/workstream` lands; `/backlog` captures** — no skill crosses another's seam.

```
  workflow      foreman ──── the hub/router: classify a change, deploy/operate the dev/ system
                backlog ──── the capture desk: file follow-ups to trackers, sweep finished work
  engines       architect ── the design-system engine: maintains a project's regenerable `design/` seed
                feature ─── the planning spine: brainstorm → design → plan → build (+ review)
                workstream ─ the loop orchestrator: one worktree, one stream, ship after ship

  delegation    delegate ── the front-door: delegate-or-not, mechanism, route confirmation
                mailbox ─── the transport: out-of-band slot handoff, worktree-safe

  session       handoff ─── save/resume disciplines (root sessions; workstream reuses them)

  auditors      auditor ─── project CODE quality (rubric + metrics + findings → trackers)
                chiropractor ─ doc-SPINE ergonomics (scan → diagnose → adjust)
```

## The skills

- **`foreman`** — the dev-workflow hub. A thin router + verbs (`route` default, `init`, `tune`,
  `check`). Deploys and operates a project's `dev/` development-docs system.
- **`backlog`** — the capture desk. Files each follow-up into its tracker (`bug`, `backlog`,
  `issue`, `feedback`), sweeps finished work (`debrief`), and grooms the trackers (`groom`).
- **`architect`** — the design-system engine: maintains a project's regenerable `design/` seed;
  verbs `init`/`brainstorm`/`plan`/`prep`/`distill`/`check`. Seed-altitude peer to `feature`.
- **`feature`** — the planning spine as verbs: `brainstorm | design | plan | build`, plus the
  cross-cutting `review`. Never lands or debriefs.
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

## Which audit?

Project *code* → `auditor`. The repo's *doc spine* (links, entry door, navigability) →
`chiropractor`. A deployed *dev/ docs system's* health (trackers, drains, staleness) →
`/foreman tune`. Three domains, three tools — they don't overlap.

## Install

From the clone root:

```
./install.sh --pack clankshop
```
