# Workflows

A map of the common things you'll do in this repo and where the authoritative how-to lives.
Each entry is a pointer -- follow the linked doc for detail.

## Start or resume a work stream
Bootstrap in order: root project doc (e.g. `PROJECT.md`) -> `.agents/foreman/MEMORY.md` + root `AGENTS.md`
-> `.agents/foreman/README.md` -> `.agents/foreman/docs/` + `.records/plans/` as needed. To resume a specific stream:
`/workstream load <name>` for an active stream, or read its roadmap in `.records/plans/`. `/handoff`
saves/loads a temporary `HANDOFF.md` for the one stream you're actively on.

## Work in parallel without clobbering
Use a git worktree for anything that earns a feature branch (patches + small work stay on
`main`). When to use one, create/tear-down, the rebase-onto-`main` finish, and subagent limits
are all in `.agents/foreman/docs/WORKTREES.md`.

## Develop a feature
Routed by `.agents/foreman/docs/DEVELOPMENT.md` (*Features*): **plan it** -> `.agents/foreman/docs/PLANNING.md` (pick a
tier), **build it** -> `.agents/foreman/docs/WORKTREES.md` (worktree rules; tracks keep one worktree across
phases). If available, **`/workstream`** automates the seed -> drive -> land loop in a worktree,
run continuously per stream (create / save / load / sync / ship / close); see your `/workstream`
skill docs (if available).

## `<stack: run an end-to-end scenario>`
`<stack: describe the E2E/integration harness, the script format, where artifacts land, and a
quick-start command.>`

## `<stack: debug a visual / integration output (fast path)>`
`<stack: describe any isolation / inspector tooling that surfaces swallowed errors and writes a
fingerprint artifact; note the gotchas doc for known traps.>`

## `<stack: check performance>`
`<stack: describe the perf tooling (profiler, benchmarks, flight/load scenario), conventions,
and where to record perf logs.>`

## Diagnose a bug
Full playbook (observe -> reproduce -> isolate -> file): `.agents/foreman/docs/DIAGNOSTICS.md` (if present).
Classifying and filing the defect into `.records/bugs/`: `.agents/foreman/docs/DEVELOPMENT.md` (*When it's a bug*).
If available, **`/backlog bug`** runs the diagnose -> file-from-template -> link-from-tracker flow.

## Audit code quality
`<stack: describe any project audit rubric or tooling; note the distinction from the .agents/foreman/
docs-system health sweep.>` If available, **`/auditor`** drives a pass.

## Capture follow-ups
The capture taxonomy (the five kinds, what goes where + each store's shape) is `/backlog`'s
`docs/TAXONOMY.md`; `.agents/foreman/docs/DEVELOPMENT.md` -> *Capture follow-ups* points there. Quick: a
thing to build -> `.records/tasks.md`; a project problem/concern -> `.records/issues.md`;
a dev-experience observation -> `.records/feedback.md`; a durable project fact -> `.records/notes/`.
When an entry needs more than a line, spill the long form to a linked `.records/notes/<slug>.md`. At the
end of a body of work, **`/backlog debrief`** (if available) sweeps everything surfaced to its one home in
a single pass -- it fires at plan completion (`.agents/foreman/docs/PLANNING.md` -> *When a plan completes*).

## Prune / archive completed work
Keep the live docs lean -- archive shipped/stale material and record it in dated `.records/archive/`
files. The full how-to (what moves where: plans, reports, bugs, backlog, issues, memory) is in
`.agents/foreman/docs/MAINTENANCE.md` -> *Prune & archive*.

## Ship a change
Run the gate (`<gate>`) before committing. Land work in focused commits (imperative subject +
body). Feature/plan-scoped work goes in a worktree branch and merges; small unrelated patches land
directly on `main` -- either way, commit promptly so the shared root doesn't accumulate uncommitted
changes that throw off other agents. See `.agents/foreman/docs/WORKTREES.md`.

## Maintain the .agents/foreman/ system (validate, calibrate, drain)
Periodic upkeep that keeps the living docs honest *and* lean: **validate** the deployed glue
(`/foreman check` -- spine coverage, stale refs, glue-vs-skills drift), **calibrate** the doctrine from
accumulated signal (`/foreman calibrate`), and **drain** the trackers (`/backlog curate` for list hygiene;
`/foreman calibrate` promotes durable notes; archive shipped work). See `.agents/foreman/docs/MAINTENANCE.md`. (Docs-system health -- distinct from
code-quality audits.)
