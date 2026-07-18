# Development -- what kind of change, and where to go

The **router** for making any change in this project. The lightweight lanes (bug, patch, spike) are
right here; planning and building a feature live behind their gates in `PLANNING.md` and
`WORKTREES.md`. **Start here for any change -- including when you're resuming a hand-off or
driving with planning skills. Neither exempts you from the router, and the steps below run in
order.**

## What kind of change is this?

- **A bug** -- something's broken, wrong, or flaky -> **diagnose first** (if the project has a
  `DIAGNOSTICS.md`, start there), check any gotchas doc (it may be a known trap, not a bug), then
  file/track it (*When it's a bug*).
- **A small, self-contained change** -- a fix, a typo, a config bump, a doc tweak -> land it
  **directly on `main`, committed promptly** (*Fixes & patches*). No worktree, no plan.
- **A feature** -- any multi-commit scope that earns its own branch -> **plan it** (`PLANNING.md`),
  then **build it** (`WORKTREES.md`).
- **A spike / throwaway experiment** -- explore in a worktree if it might yield committable
  work, but **don't merge exploratory code**; capture the *learnings* (a plan, an ADR, a
  `FEEDBACK` / `ISSUES` note), then build it properly as a feature.

**The line: if it earns its own branch, it's a feature; otherwise it's a patch.**

## When it's a bug -- diagnose, then file or fix

A **bug** is an observed defect (crash, wrong output, dropped state, flaky behavior). That's
distinct from `tasks.md` ("build X") and `issues.md` (a project problem / concern / limitation).

1. **Diagnose** -- observe -> reproduce -> isolate. Check any gotchas doc: it may be a known trap
   (working-as-coded but surprising), not a bug.
2. **File a report** into `.records/bugs/` -- `.records/bugs/YYYY-MM-DD-<slug>.md` from
   `.agents/dev/templates/bug-report.md`: the **repro** (`<stack: a deterministic repro + evidence
   artifact>`), **expected vs actual** with evidence, **status + severity**. Capture while fresh;
   reports can run large -- that's what the store is for.
3. **Then fix or defer** -- fixing now -> fix (patch or feature, by size), note the commit,
   `git mv` the report to `.records/bugs/archive/`. Deferring -> add a `tasks.md` item that
   **links** the report. Working-as-coded -> promote to the gotchas doc, drop the report.

**`.records/bugs/` is a report *store*, not a work queue** -- file reports there; track the fix from
a linked `tasks.md` item / task / plan. Don't fish in it for work.

## Fixes & patches (on `main`)

Small, self-contained changes -- bug fixes, small refactors, doc/config tweaks -- land directly
on `main`: make the change, run `<gate>`, commit promptly. No worktree, no plan, no hand-off;
just don't leave uncommitted churn on the shared root (it throws off other agents). If a "fix"
starts sprawling -- many commits, a real design question, a plan -- promote it to a feature; it
earned a branch.

## Features -- plan, then build

A feature is any multi-commit scope that earns its own branch. Two steps, two gates:

- **Plan it -> `PLANNING.md`.** It picks the planning tier (a brief for a small feature; a
  roadmap + per-phase plans, plus maybe an ADR, for a multi-phase track) and sets the rules for
  each planning doc -- friendly to whatever planning skills you have active.
- **Build it.** Anything that earns a branch builds in an isolated **worktree** -- when to use one
  and the load-bearing rules are in `WORKTREES.md`; integration is a local rebase + ff-merge back to
  `main`. Multi-phase tracks keep one worktree across phases (`PLANNING.md` -> *Multi-phase tracks*).

**Driving with planning skills (brainstorm -> plan -> execute)?** They own the *process*, but they
tend to run everything in one session on whatever tree you're on. The policy still holds: anything
that earns a branch builds in its **worktree**, not inline on `main`; advance a multi-phase track
per `PLANNING.md`. Don't let skill-momentum run a whole track on `main`.

**In a worktree, a bare `cd` does not stick** -- file ops must use absolute worktree paths and
commands `git -C <worktree>`, or edits silently hit `main`. The full rule, and the other worktree
invariants, are in `WORKTREES.md`.

## Capture follow-ups

A change always surfaces more than it fixes. Every follow-up has **exactly one home**. The **capture
bureau `/backlog`** owns those homes -- the trackers (`tasks.md`, `bugs/`, `issues.md`, `notes/`,
`feedback.md`) and the canonical **capture taxonomy** (its `docs/TAXONOMY.md`) that says which signal
goes where, its per-store frontmatter schema, and the shape each store takes. Capture with `/backlog`
(`/backlog task | bug | issue | note | feedback`) and route by that taxonomy rather than restating it
here. In shorthand: a thing to build -> `task`; a reproducible defect -> `bug`; a project problem /
concern / limitation -> `issue`; a durable project fact -> `note`; a dev-experience observation
(skills / tooling / env) -> `feedback`.

The boundary that matters: **`bugs/` and `notes/` are stores, not work queues** -- file into them and
track the actionable item from a linked tracker line; don't fish in them for work. Capture never
drains: the periodic *draining* of these trackers into doctrine is `/foreman tune`'s job
(`MAINTENANCE.md`), and keeping the lists tidy is `/backlog curate`.

`notes/` is a **first-class capture kind** (`/backlog note` -- a durable project fact: rationale, a
worked example, design context that isn't an ADR) that can *also* hold **spillover**: when a tracker
or `MEMORY.md` entry needs more than a line, write the long form to a
**`.records/notes/<slug>.md`** and link it from that entry. A note is reached through its link,
never browsed; a *standalone* investigation you'd open on its own is a `reports/` doc, not a note.

Running this whole sweep at the **moment a plan completes** -- while the session still holds
everything it surfaced -- is what **`/backlog debrief`** automates (if available). See `PLANNING.md` ->
*When a plan completes* (it's tied to the work being done, not to landing it).

## Invariants that always apply

Whatever the change, don't break the load-bearing invariants in `.agents/dev/MEMORY.md` (`<keystone>`),
and keep abstractions earned -- extract a trait at the *second* consumer, not the first.
