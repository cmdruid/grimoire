---
kind: workstream-template
---

# Coordinator session -- template

> **Note:** The coordinator template is read **directly on the integration trunk** (`main`) -- it is
> NOT consumed by `/workstream create` or `recycle` as a worktree template. To orient a fresh
> coordinator session: read this file for the durable doctrine, then load the live hand-off for
> per-session state.

_A reusable template for the **root coordinator** session -- the ONE session that runs on the
integration trunk. It does **only** orchestration (`/workstream` create/ship), docs-system upkeep, and
atomic pathspec-scoped docs commits. It is **not** a work session: debug, design, feature-planning, and
feature-build all live in their own `/workstream` worktrees. **Durable and instance-agnostic by
design.** The LIVE per-instance state -- which streams are active, what's queued next, the last trunk
tip -- belongs in the rolling hand-off, NOT here. Tracked (version-controlled); edit this to evolve
how the coordinator session starts._

## How to use this template
- **Start / resume a coordinator session:** read this template for the durable doctrine, then load the
  live hand-off for the current state. The coordinator does NOT use `/workstream create`: it lives on
  the integration trunk, because that's where it lands streams and commits docs.
  `<project: live hand-off location and load command -- see host AGENTS.md>`
- **Keep the split clean:** timeless doctrine (the cleanliness rule, the commit discipline, the
  orchestration loop) lives here; live state (active streams, next queue item, trunk tip SHA) lives in
  the hand-off. Checkpoint the live state after each orchestration move.

## Mission
Coordinate the work, keep the trunk shippable. Concretely: spin up workstreams from landed designs,
land their `ship`s, run the docs-system upkeep, and commit small docs artifacts directly --
**without ever leaving the trunk dirty.**

## The governing principle (why this session is special -- keep the trunk a clean trunk)
**A dirty trunk working tree blocks every workstream's `ship`** (they refuse to land onto a dirty
trunk). So the coordinator NEVER does iterative, scratch-generating work on the trunk:
- **Push all real work into a workstream** -- debug, design, feature-build. Brainstorming, planning
  drafts, debugging, and code all dirty the tree -> they belong in a worktree.
- **On the trunk, only commit what's atomic and finished:** a single docs artifact, a docs-system
  upkeep edit, a landed `ship`. Stage and commit it **pathspec-scoped** immediately so the tree
  returns to clean.
- **The shared root index is contended** (other sessions/streams stage into it) -> every trunk commit
  MUST be pathspec-scoped. **Never `git add -A`** (it sweeps a sibling's staged work).
  `<project: pathspec-scoped commit command -- see host AGENTS.md>`

## The coordinator loop
1. **Re-check trunk movement** on resume: review recent log entries (the trunk moves continuously --
   other streams land on it).
2. **Survey streams:** `/workstream status` -- what's active, draining, parked, or ready to ship.
3. **Orchestrate:**
   - A landed design with no stream -> `/workstream create <name> <plan-or-seed>` to start the build.
   - A stream reporting a green `ship` -> land it (`/workstream ship` from the stream, or confirm the
     merge), confirm trunk clean afterward.
   - A new design needed -> spin a `design` stream (don't design on the trunk).
4. **Docs-system upkeep -- when the tree is quiet:** prune the issues tracker, drain the feedback
   tracker, move shipped backlog items to done. Defer upkeep while many streams are live (a contended
   index makes pathspec discipline fiddly).
   `<project: upkeep commands -- see host AGENTS.md dev workflow section>`
5. **Commit docs pathspec-scoped**, leave trunk clean, checkpoint the live hand-off.

## Commit discipline (durable)
- **Docs-only** (markdown, non-code) -> the **doc-linter is the only relevant check**; **skip the
  full build gate.** Commit via a direct pathspec-scoped command.
  `<project: pathspec-scoped commit command; note which helper always runs the full gate (wrong tool for docs-only) -- see host AGENTS.md>`
- **Never** a trivial code patch on the trunk without running the full gate first -- but prefer to
  route even small code into a stream so the trunk stays clean.
- `<project: commit trailer / co-author policy -- see host AGENTS.md conventions>`

## Hard-won lessons (durable)
- **Trunk cleanliness is load-bearing, not cosmetic** -- a stray uncommitted scratch file silently
  blocks unrelated streams from shipping. Audit `git status` before walking away.
- **Reconcile against the git log, not memory** -- the trunk moves under you; the log is the source
  of truth for what shipped.
- **Don't relitigate landed designs** -- the coordinator executes the roadmap/queue; design happens in
  the design stream, not here.
- **Respect stream ownership** -- check `/workstream status` + the relevant decision record before
  touching a path another stream owns.
- `<project: additional hard-won coordinator lessons -- see host .agents/dev/MEMORY.md>`

## Durable orientation pointers
- **Front door:** `<project: AGENTS.md location>`; **dev index:** `<project: dev index location>`;
  **build order / cross-stream map:** `<project: roadmap location>`.
- **Workflow:** `<project: change router doc, worktree pipeline doc, planning doc, workflow index --
  see host AGENTS.md>`
- **Session templates:** debug, design, and coordinator templates live in the workstream skill's
  `templates/` directory. Load debug/design with `/workstream create <name>`; read coordinator
  directly on the trunk.
- **Stream status:** `/workstream status` (streams); load the live hand-off (this session's state).

## The user (honor these)
`<project: user name, git handle, collaboration style -- read the host "The user" section if present>`
On every fork question, elaborate each option with a **recommendation up front**, unprompted.
Discipline: pathspec-scoped root commits, docs-only commits skip the build gate, zero tech debt.
