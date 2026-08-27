---
name: backlog
description: "Manage project-owned living follow-up trackers in a first-class tracker layer. Setup deploys the tracker@1 API and default queues; tracker add|remove|list manages extensible queues; file and debrief capture follow-ups; query pages them; curate updates or consumes them. Use for `/backlog ...`, filing or grooming follow-ups, and sweeping completed work before substantive context is lost."
---

# backlog — living follow-up trackers

Backlog is the format and lifecycle authority for `<agent-trackers>` (default `.trackers`). The
layer is public project state: `README.md`, package-managed `tracker-api.sh`, `receipts.tsv`, and one
`<stem>.tsv` per queue. Backlog's editable routing prompt remains owner-local at
`<agent-workspace>/backlog/hooks/debrief.md`.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| `/backlog setup` | `verbs/setup.md` | Deploy the API, default or selected queues, prompt, and route |
| `/backlog tracker add\|remove\|list` | `verbs/tracker.md` | Manage or inspect queue files |
| `/backlog file <stem> [text]` | `verbs/file.md` | Create one open item |
| `/backlog query [<stem>]` | `verbs/query.md` | Catalog or page tracker state |
| `/backlog debrief` | `verbs/debrief.md` | Route completed-work leftovers once |
| `/backlog curate [<stem>]` | `verbs/curate.md` | Update or consume current rows |

Bare `/backlog` asks which verb. Unknown verbs refuse; migration, import, complete, drop, and
reorder are not aliases.

## Shared discipline

- Resolve `<root>` as the project checkout. Resolve line-start `agent-records:`,
  `agent-workspace:`, and `agent-trackers:` from `AGENTS.md`, then `CLAUDE.md`; defaults are
  `.records`, `.spaces`, and `.trackers`. Only records accepts legacy `records-root:`.
- All three roots are repo-relative, non-dot paths without `.` or `..` components and are pairwise
  non-overlapping. Backlog owns tracker-layer validation; never ask Workspace to validate it.
- Except during setup and tracker administration, require executable
  `<agent-trackers>/tracker-api.sh`. Invoke it with `--root <root> --records-root <R> --workspace
  <W> --trackers-root <T>` followed by the public command. Missing or invalid provider state refuses
  with `reason=setup-required`; never run the bundled API against project data.
- Never edit queue or receipt TSV bytes directly. Use the API for catalog, paging, row mutation,
  observation, and consumption. `receipts.tsv` is reserved and is never a configurable queue.
- Setup and tracker add/remove run package-local `scripts/backlog-setup.sh` with the resolved roots.
  That helper is the only queue-file lifecycle writer and the only package path that refreshes the
  installed API.
- Standalone setup, tracker, file, and curate calls make one pathspec-scoped commit over unique
  reported `wrote=` / `removed=` paths through `scripts/scoped-commit.sh`. Inside debrief or an
  announced configuration sweep, remain write-only and return the paths to the caller. No changed
  paths means no commit.
- Resolve commit custody before committing: detached HEAD or an unheld `stream/*` / `feature/*`
  branch stops; a matching workstream hand-off commits in that worktree; otherwise commit in the
  current checkout. Never stage broadly.

## Project state and defaults

Bare setup initializes `tasks`, `issues`, `feedback`, and `routines`. An explicit selection replaces
that default set. `suggestions/*.md` supplies absent prompt sections; custom stems receive editable
stubs. Queue data, receipts, the layer README, and incumbent prompt bodies are preserved. Only the
installed API refreshes.

## Edges

<!-- edges:backlog -->
- produces: tracker — first-class project follow-up queues and receipt state
- handoff: — (none; rows remain queued until an explicit consumer selects them)
- consumes: — (debrief reads the caller's bounded completed-work context)
<!-- /edges:backlog -->

## Scope boundary

Backlog stores, routes, and exposes follow-ups. It does not diagnose defects, perform queued work,
mint records, define another skill's domain judgment, or store session/workstream resume state.

## Done when

The selected verb's done-when holds; every tracker mutation used the installed API or guarded
queue-lifecycle helper; the route and prompt population match configured queues; and standalone
changes used one exact pathspec-scoped commit.
