---
name: backlog
description: "Manage project-owned living follow-up trackers in a first-class tracker layer. Setup deploys the tracker@1 API and default queues; tracker add|remove|list manages extensible queues; file and debrief capture follow-ups; query pages them; curate updates or consumes them. Use for `/backlog ...`, filing or grooming follow-ups, and sweeping completed work before substantive context is lost."
---

# backlog — living follow-up trackers

Backlog is the format and lifecycle authority for the fixed `.trackers` layer. The
layer is public project state: `README.md`, package-managed `trackers.sh`, `receipts.tsv`, and one
`<stem>.tsv` per queue. Backlog's editable routing prompt lives beside those queues at
`.trackers/DEBRIEF.md`.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| `/backlog setup` | `verbs/setup.md` | Initialize or reconcile the tracker layer |
| `/backlog repair` | `verbs/repair.md` | Restore the provider and managed tracker-root guide |
| `/backlog tracker add\|remove\|list` | `verbs/tracker.md` | Manage or inspect queue files |
| `/backlog file <stem> [text]` | `verbs/file.md` | Create one open item |
| `/backlog query [<stem>]` | `verbs/query.md` | Catalog or page tracker state |
| `/backlog debrief` | `verbs/debrief.md` | Route completed-work leftovers once |
| `/backlog curate [<stem>]` | `verbs/curate.md` | Update or consume current rows |

Bare `/backlog` asks which verb. Unknown verbs refuse; migration, import, complete, drop, and
reorder are not aliases.

## Shared discipline

- Resolve `<root>` as the project checkout. Records, owner-local support, and trackers live only at
  `<root>/.records`, `<root>/.spaces`, and `<root>/.trackers`.
- Backlog owns tracker-layer validation; never ask Workspace to validate it.
- Before a Backlog verb invokes the provider, run package-local
  `scripts/tracker-runtime-check.sh --root <root>`. On success, invoke only the exact installed
  `provider=` path it returns. On failure, pass through its recovery diagnostic and stop. Runtime
  verbs never reproduce the classifier-to-diagnostic mapping, resume setup, or run bundled provider
  bytes against project data. Provider `wrote=` values are relative to `.trackers`.
- Never edit queue or receipt TSV bytes directly. Use the API for catalog, paging, row mutation,
  observation, and consumption. `receipts.tsv` is reserved and is never a configurable queue.
- Setup, repair, and tracker add/remove run package-local `scripts/backlog-setup.sh <root>`.
  That helper is the only queue-file lifecycle writer and the only package path that refreshes the
  installed API.
- Standalone setup, repair, tracker, file, and curate calls make one pathspec-scoped commit over unique
  reported `wrote=` / `reconciled=` / `removed=` paths through `scripts/scoped-commit.sh`. Inside debrief or an
  announced configuration sweep, remain write-only and return the paths to the caller. No changed
  paths means no commit.
- Resolve commit custody before committing: detached HEAD or an unheld `stream/*` / `feature/*`
  branch stops; a matching workstream hand-off commits in that worktree; otherwise commit in the
  current checkout. Never stage broadly.

## Project state and defaults

First setup always initializes `tasks`, `issues`, `feedback`, and `routines`; queue population changes
only through `tracker add|remove` after initialization. A valid `receipts.tsv` is the initialization
boundary. Initialized setup preserves the incumbent queue population and data while reconciling the
provider, managed README block, and missing prompt sections for incumbent queues. Repair touches only
the provider and managed README block.

## Edges

<!-- edges:backlog -->
- produces: tracker — first-class project follow-up queues and receipt state
- handoff: — (none; rows remain queued until an explicit consumer selects them)
- consumes: — (debrief reads the caller's bounded completed-work context)
<!-- /edges:backlog -->

## Scope boundary

Backlog stores, routes, and exposes follow-ups. It does not diagnose defects, perform queued work,
mint records, define another skill's domain judgment, or store session/workstream resume state.

## Project templates

None. `debrief-anchor.md` is package-only and is reconciled into Backlog's bounded root route; it is
never deployed as a project-editable template.

## Done when

The selected verb's done-when holds; every tracker mutation used the installed API or guarded
queue-lifecycle helper; the route and prompt population match configured queues; and standalone
changes used one exact pathspec-scoped commit.
