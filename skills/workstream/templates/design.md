---
kind: workstream-template
---

# Design workstream -- template

_A reusable template for a `design` workstream: collaborative design-partner work -- turn an idea into
an argued spec, **inside a worktree**, shipping the design artifacts (specs, ADRs, roadmap entries) to
the integration trunk as docs-only commits. **Durable and instance-agnostic by design** -- it holds the timeless
design knowledge (mission, the spine, the grounding discipline, conventions, doc pointers). The LIVE
per-instance state -- which feature is being designed, the open forks, what's shipped -- belongs in
the worktree's `WORKSTREAM.md`, NOT here. Tracked (version-controlled); edit this to evolve how every
design session starts._

## How to use this template
- **Create a new design workstream:**
  `/workstream create design`
  -> seeds a worktree + a `WORKSTREAM.md` whose brief comes from this template; `create` adds the
  generic scaffolding (Coordinates, START HERE). Then set the queue: the feature(s) to design this
  session.
- **Refresh an existing design workstream:** re-apply the durable sections below into the worktree's
  `WORKSTREAM.md`, **preserving its Coordinates + live state** (the feature in flight, the open forks,
  what shipped). The template is the source of truth for the durable parts.
- **Keep the split clean:** anything that changes per session (the feature, a decision just made) goes
  in the WORKSTREAM instance. Anything timeless (the spine, a discipline, a pointer) goes here.

## Mission
Turn a feature idea from fuzzy to an argued, written spec ready to plan and build. Run a
brainstorm-to-design spine to validate the approach, then land the design artifact (spec, ADRs,
roadmap/backlog updates) so a future build stream can pick it up cold. Design work lives here --
**in a worktree** -- so the brainstorming/iteration scratch never dirties the trunk (a dirty trunk
blocks every stream's `ship`).

## The governing principle (why this stream exists, and how to design well)
- **Ground before designing.** Read the project vision doc + the core design principles doc and skim
  the relevant code BEFORE opening the brainstorm -- the project's foundational architecture often
  makes the core decision unusually clean. The right grounding turns a hard design into an obvious one.
  `<project: vision doc, design principles doc, and key invariants -- see host AGENTS.md + .agents/dev/MEMORY.md>`
- **Lead with the load-bearing fork.** Find the one decision the whole architecture hangs on and put
  it to the user first, each option elaborated with a recommendation up front -- don't bury it under
  detail.
- **Honor the design pillars:**
  `<project: the host project's design pillars -- see host AGENTS.md + the host design principles doc>`
  General: keep abstractions earned (extract at the 2nd consumer); leave zero tech debt in alpha.

## Starting a design session
1. **Brainstorm before designing.** Run a structured brainstorm to validate the approach before writing
   a spec -- it gates implementation behind an approved, written design.
2. **Ground:** read the project vision + design principles docs, skim the code paths the feature
   touches, check the roadmap + backlog for prior intent and any owning stream (avoid designing into
   another stream's territory).
   `<project: vision doc, roadmap, backlog location -- see host AGENTS.md>`
3. **Run the spine:** brainstorm the idea -> fork-driven dialogue -> write the argued spec.
   Optionally produce an implementation plan if this stream also owns turning the design into tasks;
   otherwise hand the design to a build stream.
4. **Land the artifacts** per *Where designs land*, then run the debrief sweep to route follow-ups.

## The toolbox (durable reference -> depth in the docs)
- **The design spine:** brainstorm (idea -> validated approach), design (argued spec), plan
  (task-by-task implementation plan), build (gate-green code), review (independent verdict on any
  artifact, callable anytime).
  `<project: planning tier docs -- see host AGENTS.md>`
- **Templates:** `<project: spec, ADR, roadmap, implementation plan templates -- see host .agents/dev/templates/ or equivalent>`
  Match the host repo's frontmatter schema (type / status / updated fields).
- **Change router:** `<project: change router doc (classifies any change -> the right lane) -- see host AGENTS.md>`
- **Capture:** file feature follow-ups to the backlog; dev-tool friction to the issues tracker;
  qualitative notes to feedback; defects to the bug tracker. Run the debrief sweep at the end of a
  body of work.
  `<project: capture commands -- see host AGENTS.md dev workflow section>`

## Hard-won lessons (durable)
- **The project keystone is a design tool, not just a constraint.** The foundational architecture
  invariant often makes a feature's core decision unusually clean -- ask "can this be derived instead
  of stored?" early.
  `<project: keystone invariant -- see host AGENTS.md + .agents/dev/MEMORY.md>`
- **The product fork hides the architecture fork.** A seemingly UX-level question (e.g., a UX-level
  choice that dictates whether any state needs to be stored at all) often dictates whether state is
  persisted at all. Surface that coupling explicitly.
- **Design for the build stream's cold start.** The spec must let a fresh agent build without
  re-deriving decisions -- record the chosen approach AND the rejected alternatives + why.
- **Don't re-brainstorm settled decisions.** Once a design/ADR lands, the build stream executes it; a
  resumed session reads the approved design, it doesn't relitigate it.
- `<project: additional hard-won design lessons -- see host .agents/dev/MEMORY.md>`

## Where designs land
- Design artifacts are **docs-only** -> land on the integration trunk pathspec-scoped
  (`<project: pathspec-scoped commit command -- see host AGENTS.md>`); the **doc-linter is the only
  relevant check** -- **skip the full build gate**. Root index is contended -- never `git add -A`.
- Artifacts: the design spec (with frontmatter) in `<project: design specs location -- e.g. .records/plans/>`;
  any decision in a new ADR (index it in the dev index); roadmap/backlog updates marking the feature
  designed.
  `<project: ADR location, dev index -- see host AGENTS.md>`
- **Hand off to a build stream:** a designed feature becomes a `/workstream` whose queue is the plan --
  the build runs the full gate in its own worktree. Don't build here.

## Durable orientation pointers
- **Vision/spine:** `<project: vision doc, design principles doc, roadmap -- see host AGENTS.md>`
- **Design docs:** `<project: design docs location (e.g. docs/design/) and ADR location -- see host AGENTS.md repo-map>`
- **Workflow:** `<project: planning doc, change router doc, dev index, front-door AGENTS.md -- see host AGENTS.md>`
- **Stream status:** `/workstream status` (check who owns what before designing into it).

## The user (honor these)
`<project: user name, git handle, collaboration style -- read the host "The user" section if present>`
On every fork question, elaborate each option with a **recommendation up front**, unprompted.
Discipline: pathspec-scoped root commits, docs-only commits skip the build gate, alpha = leave zero
tech debt; keep abstractions earned.
