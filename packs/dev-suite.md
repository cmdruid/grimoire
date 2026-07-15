---
name: dev-suite
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, and audit both code quality and doc ergonomics."
skills: audit chiropractor delegate design dev feature handoff mailbox workstream
---

# dev-suite — the disciplined development loop

Nine skills in four layers. The seam contracts between them are the architecture: **`/feature`
ends at gate-green; `/workstream` lands; `/dev` captures** — no skill crosses another's seam.

```
  workflow      dev ─────── the hub/router: classify a change, deploy/operate the dev/ system
  engines       design ──── the design-system engine: maintains a project's regenerable `design/` seed
                feature ─── the planning spine: brainstorm → design → plan → build (+ review)
                workstream ─ the loop orchestrator: one worktree, one stream, ship after ship

  delegation    delegate ── the front-door: delegate-or-not, mechanism, route confirmation
                mailbox ─── the transport: out-of-band slot handoff, worktree-safe

  session       handoff ─── save/resume disciplines (root sessions; workstream reuses them)

  auditors      audit ───── project CODE quality (rubric + metrics + findings → trackers)
                chiropractor ─ doc-SPINE ergonomics (scan → diagnose → adjust)
```

## The skills

- **`dev`** — the dev-workflow umbrella. A thin router + verbs (`route` default, `init`, `bug`,
  `backlog`, `issue`, `feedback`, `debrief`, `upkeep`). Deploys and operates a project's `dev/`
  development-docs system.
- **`design`** — the design-system engine: maintains a project's regenerable `design/` seed;
  verbs `init`/`brainstorm`/`plan`/`prep`/`distill`/`check`. Seed-altitude peer to `feature`.
- **`feature`** — the planning spine as verbs: `brainstorm | design | plan | build`, plus the
  cross-cutting `review`. Never lands or debriefs.
- **`workstream`** — drive a long-lived stream in a git worktree (create → save/load → sync →
  ship → recycle → close). Orchestrates `feature` (build) + `dev debrief` (capture) + `handoff`
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
- **`audit`** — code-quality audit framework (per-dimension rubric, metrics, findings → trackers).
- **`chiropractor`** — audit and tune a repository's documentation *spine* (the link tree rooted
  at the agent entry door) for agent ergonomics: scan → diagnose → adjust. Self-contained; runs
  in any repo.

## Which audit?

Project *code* → `audit`. The repo's *doc spine* (links, entry door, navigability) →
`chiropractor`. A deployed *dev/ docs system's* health (trackers, drains, staleness) →
`dev upkeep`. Three domains, three tools — they don't overlap.

## Install

From the clone root:

```
./install.sh --pack dev-suite
```
