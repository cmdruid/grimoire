---
name: backlog
description: "Manage project-owned living follow-up trackers in a first-class tracker layer. Setup deploys the tracker@2 API, lifecycle history, and selected packaged tables; migrate converts one exact tracker@1 installation; anchor manages an explicit project route; tracker add|remove|list manages extensible queues; file and debrief capture follow-ups; query pages them; curate updates or consumes them. Use for `/backlog ...`, filing or grooming follow-ups, managing the tracker layer route, and sweeping completed work before substantive context is lost."
---

# backlog — living follow-up trackers

Backlog is the format and lifecycle authority for the fixed `.trackers` layer. The
layer is public project state: `README.md`, package-managed `trackers.sh`, `history.tsv`, and one
`tables/<stem>.tsv` per queue. Backlog's editable routing prompt lives at `.trackers/DEBRIEF.md`.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| `/backlog setup [--trackers <stems>] [--debrief]` | `verbs/setup.md` | Initialize a selected packaged set or reconcile the tracker layer |
| `/backlog repair` | `verbs/repair.md` | Restore the provider and managed tracker-root guide |
| `/backlog migrate [<source-root>]` | `verbs/migrate.md` | Convert one exact tracker@1 TSV installation |
| `/backlog anchor [--debrief|--remove]` | `verbs/anchor.md` | Install, refresh, or remove the managed project debrief route |
| `/backlog tracker add\|remove\|list` | `verbs/tracker.md` | Manage or inspect queue files |
| `/backlog file <stem> [text]` | `verbs/file.md` | Create one open item |
| `/backlog query [<stem>\|--history]` | `verbs/query.md` | Catalog or page tracker and lifecycle state |
| `/backlog debrief` | `verbs/debrief.md` | Route completed-work leftovers once |
| `/backlog curate [<stem>]` | `verbs/curate.md` | Update or consume current rows |

Bare `/backlog` asks which verb. Unknown verbs refuse; import, complete, drop, and reorder are not
aliases.

## Shared discipline

- Resolve `<root>` as the project checkout. Records, owner-local support, and trackers live only at
  `<root>/.records`, `<root>/.agents/skilldata`, and `<root>/.trackers`.
- Backlog owns tracker-layer validation; do not delegate it to a whole-tree support-path validator.
- Before a Backlog verb invokes the provider, run package-local
  `scripts/tracker-runtime-check.sh --root <root>`. On success, invoke only the exact installed
  `provider=` path it returns. On failure, pass through its recovery diagnostic and stop. Runtime
  verbs never reproduce the classifier-to-diagnostic mapping, resume setup, or run bundled provider
  bytes against project data. Provider `wrote=` values are relative to `.trackers`.
- Never edit table or history TSV bytes directly. Use the API for catalog, paging, row mutation,
  observation, consumption, and bounded lifecycle-history reads.
- Setup, repair, and tracker add/remove run package-local `scripts/backlog-setup.sh <root>`.
  That helper is the only queue-file lifecycle writer and the only package path that refreshes the
  installed API.
- Migrate runs package-local `scripts/migrate-trackers.sh`; it is the only tracker@1 reader. All
  other Backlog commands remain tracker@2-only.
- Only the public anchor procedure and package-local `scripts/trackers-anchor.sh` may write
  repository-root `AGENTS.md`. They own exactly the `skill:backlog` block, bind every mutation to
  previewed base and candidate digests, and support removal without tracker health. Setup may invoke
  that same procedure only after explicit route consent; repair, migration, provider use, queue
  administration, and debrief never require or mutate the front door. No Backlog path reads
  `CLAUDE.md`.
- Standalone setup, repair, tracker, file, and curate calls make one pathspec-scoped commit over unique
  reported `wrote=` / `reconciled=` / `removed=` paths through `scripts/scoped-commit.sh`. Inside debrief or an
  announced configuration sweep, remain write-only and return the paths to the caller. No changed
  paths means no commit.
- Resolve commit custody before committing: detached HEAD or an unheld `stream/*` / `feature/*`
  branch stops; a matching workstream hand-off commits in that worktree; otherwise commit in the
  current checkout. Never stage broadly.

## Project state and defaults

First setup initializes a nonempty selection from the packaged order
`tasks`, `issues`, `failures`, `feedback`, `routines`; attended setup offers all five selected,
explicit `--trackers` supplies the exact subset, and unattended setup defaults to all five. A valid
`history.tsv` is the initialization boundary. Before it, `.setup-selection` is temporary recovery
evidence that distinguishes omitted queues from incomplete writes; setup removes it only after full
validation, and runtime directs a valid cleanup state back to setup. Initialized setup preserves the
incumbent queue population and data—including former four-queue layers—while reconciling the
provider, managed README block, and missing prompt sections for incumbent queues. Repair touches only
the provider and managed README block.

After a completed first initialization, attended setup may offer the managed project debrief route
and defaults that independent choice off. Unattended setup never installs it without `--debrief`;
initialized setup never offers it, although an explicit `--debrief` may invoke the same public
anchor procedure after reconciliation. Tracker and front-door mutations retain separate custody.

The `failures` queue holds unresolved test, build, and project-tool behavior without prematurely
asserting a diagnosed defect. The `feedback` queue is project-owned: its default title is `Project
Feedback`, and its remedy must belong in the repository. Debrief applies that subject boundary before
editable prompt text. An observation whose remedy belongs in a reusable installed skill is returned
to the custodial caller as a skill-tagged byproduct for the skill's home feedback channel and never
enters `.trackers`.

Within project-owned leftovers, route by knowledge state: chosen outcomes to `tasks`, established
negative conditions to `issues`, unresolved operational sightings to `failures`, qualitative
development experience to `feedback`, and repeatable trigger/response candidates to `routines`.
Failure-family matching remains agent judgment over the component or command, stable signature, and
observed behavior; the tracker@2 provider schema does not change.

## Edges

<!-- edges:backlog -->
- produces: tracker — first-class project follow-up tables and lifecycle history
- handoff: — (none; rows remain queued until an explicit consumer selects them)
- consumes: — (debrief reads the caller's bounded completed-work context)
<!-- /edges:backlog -->

## Scope boundary

Backlog stores, routes, and exposes follow-ups. It does not diagnose defects, perform queued work,
mint records, define another skill's domain judgment, or store session/workstream resume state.

## Project templates

None. The tracker README block, `agents-route.md`, and retained exact-migration input
`agents-pointer.md` are package-only resources. Setup refreshes only the managed tracker README
block; the anchor path manages project front-door prose.

## Done when

The selected verb's done-when holds; every tracker mutation used the installed API, guarded
queue-lifecycle helper, or bounded migration helper; the prompt population matches configured
queues; no front door changed except through explicit anchor; and standalone changes used one exact
pathspec-scoped commit.
