---
doctype: specs
status: published
schema: architect/spec@1
tags: [backlog, routines, debrief, foreman]
---

# Backlog routines and universal debriefing — Spec

## Problem

Projects repeatedly rediscover how development work is performed, but Backlog has no tracker for
capturing those recurring patterns as candidates for standardization. Tasks, issues, and feedback
record outcomes, defects, and friction; none expresses “when this trigger occurs, we repeatedly need
this response.” Foreman can turn such knowledge into procedures and workflows, but it has no durable
candidate queue to inspect and curate.

The current delivery-loop glue runs Backlog debriefs from Workstream-specific hooks and tells a
Workstream session to preserve surfaced follow-ups in its hand-off until a feature boundary. That
places tracker-oriented accumulation pressure on a file whose proper job is resuming one stream.
It also leaves ordinary root, debugging, design, and other agent sessions without the same regular
debrief cadence.

## Goal

Establish trackers as a first-class project layer under `<agent-trackers>` (default `.trackers`),
add a default `routines` tracker that holds deduplicated candidates for recurring development work,
and make debriefing a Backlog-owned, always-visible discipline that applies to every custodial main
session. Session and Workstream save-states retain only facts needed to resume their primary work;
the tracker layer provides the durable cross-session accumulation surface.

## Approach

Bare `/backlog setup` stands up `<agent-trackers>` with its public contract and generic API,
initializes the default tracker set—`tasks`, `issues`, `feedback`, and `routines`—and updates
Backlog's absent-only, project-editable routing prompt at
`<agent-workspace>/backlog/hooks/debrief.md` and its delimited root-`AGENTS.md` block. The block
advertises the universal debrief cadence:

> After a human-visible work unit completes, and before a healthy reset or hand-off would discard
> substantive context, run `/backlog debrief` once over the work since the previous debrief.

An explicit tracker selection replaces the default set. Defaults are convenience, not policy:
projects may enable any subset or supply custom tracker stems, and may later change the population
through Backlog's tracker-management surface.

Bare setup honors an existing `agent-trackers:` declaration and otherwise uses the implicit
`.trackers` default without writing a declaration. On first setup only,
`/backlog setup --trackers-root <repo-relative-path>` may write an absent declaration; an incumbent
declaration must match the flag exactly. Once tracker state exists, setup never changes the
declaration, moves the layer, or initializes a competing root. Any conflicting override refuses
before touching either location.

This feature is a hard cut. Only `<agent-trackers>` is canonical after the change. Setup and normal
operations do not probe, import, alias, or migrate prior tracker records or
`<agent-workspace>/backlog/trackers/`; old surfaces remain untouched but unread. The implementation
removes legacy assumptions from current consumers rather than carrying a compatibility ladder.

The hard cut includes the complete live seam. Backlog drops its legacy migration verb and internal
import machinery and rewrites its own file, query, debrief, and curation paths over `tracker@1`.
Analyst stops probing record-owned tracker locations and reads the new layer. Foreman adds its
tracker consumer edge and runtime `tune` verb. Portable skill doctrine, the library README, lint
rules, and Workspace drop the owner-local `trackers` kind and document the independent tracker
root. The pack runbook removes its Backlog-specific Workstream hook bodies and describes universal
debriefing plus the tracker-to-operation seam instead. Generic Workstream hook points remain intact.

The cadence applies from any main agent session with repository and commit custody. It does not fire
for pure Q&A, routine status updates, every response, or child/delegate contexts; delegates return
byproducts to their caller, which owns routing and mutation.

At a healthy boundary, the general sequence is:

```text
work body → Backlog debrief → session/stream save → reset or hand-off
```

Involuntary compaction and context-pressure emergencies prioritize preserving and recovering the
primary work. Their next safe boundary performs any deferred debrief; the exception does not create
an alternate tracker buffer inside the save-state.

Workstream continues to own feature-completion, eventful-ship, and reset events, but no longer owns
Backlog integration. Its hand-off may retain an unresolved engineering fact needed to resume work;
it does not retain a list of tracker candidates, occurrence counters, routing metadata, or a
debrief cursor. Backlog-specific Workstream hook bodies become unnecessary, while Workstream's
generic project hook points remain available for unrelated host policy.

Alternatives rejected at draft weight:

- Accumulate tracker candidates in `WORKSTREAM.md` or a root checkpoint. Save-states are scoped,
  rewritten, ignored scratch optimized for resumption rather than durable project queues.
- Add harness-specific session hooks. They could be more automatic but would sacrifice the portable
  skill contract and still need a project-owned policy surface.
- Add a durable per-session debrief ledger immediately. It would turn Backlog into an event log
  before missed or duplicate sweeps have demonstrated that need.

## Mechanism

Backlog defines a small debrief discipline in its own package and projects its concise cadence into
the always-loaded block written by `register-route.sh`. The full procedure remains in Backlog; the
front door carries only enough policy to trigger it without loading another workflow skill.

The human-editable routing prompt remains
`<agent-workspace>/backlog/hooks/debrief.md`, a Backlog-owned overlay on its own loop rather than a
tracker-provider concern or a Workstream hook. It contains one `## <stem>` section per configured
queue. Setup supplies the default sections, including the strict `routines` criteria; adding a
custom tracker appends an editable stub, removing a tracker removes its section, and incumbent
section bodies are never overwritten. Debrief compiles these sections before routing. Neither the
generic tracker API nor consumer skills read this prompt.

Each debrief scopes itself to the bounded work since the previous successful debrief in the current
context. It gathers that body's visible conversation, bounded repository changes, tests, and
unresolved decisions. The current objective, resume instructions, and ordinary in-flight work are
not leftovers. Zero filed rows is a valid debrief.

`routines` uses the common tracker row schema. One open row represents one
deduplicated routine candidate, not one sighting. A candidate states:

1. a recognizable trigger;
2. the repeated response or rediscovered decision;
3. the cost, risk, or confusion worth reducing;
4. an observable completion or verification boundary.

The row's evidence field identifies the strongest available evidence. Before adding a candidate,
debrief lists the existing open `routines` rows and updates a matching candidate rather than
duplicating it.
All four criteria are required, but their sufficiency is a judgment call: no minimum occurrence
count gates capture. The agent may rely on repeated observation, explicit project knowledge, or a
well-grounded expectation of recurrence. When recurrence is inferred rather than observed, the row
states that basis instead of presenting it as historical fact.

Routing follows intended disposition: a one-time outcome is a task; something wrong or risky is an
issue; useful development-experience friction is feedback; a repeatable response to a recognizable
trigger is a routine. One concrete leftover routes once, though one observation may yield genuinely
distinct outcomes when their future dispositions differ.

### Tracker provider API

Trackers become a peer project layer rather than a private Backlog workspace kind. Resolve
`<agent-trackers>` from the first line-start `agent-trackers:` declaration in the project front
door, else `.trackers`. Backlog is the layer's format and lifecycle authority: it owns the public
tracker contract, root README, generic API, and guarded mutation semantics. It does not
own the domain judgment of every skill that reads or drains tracker rows.

The resolved root is repo-relative, is not `.`, contains no `..` segment, and is pairwise
non-overlapping with `<agent-records>` and `<agent-workspace>`: none may equal, contain, or be
contained by another. They may share a neutral ancestor. This keeps records, trackers, and
owner-local support as distinct project layers and lets each authority validate its own surface.

Backlog validates this layer itself on setup and before every API operation. Any symlinked existing
root component or target, non-directory parent, or incompatible target refuses before that write.
Setup inventories its complete write set before creating anything and immediately rechecks parents
and destinations before each write. `README.md`, routing-prompt bodies, `receipts.tsv`, and queue
TSVs are absent-only or incumbent-preserving project content. Only package-managed
`tracker-api.sh`, whose refresh behavior is explicit, may be replaced by setup. A later refusal
reports earlier safe writes so a rerun can preserve them and finish.

The layer has one fixed, discoverable shape:

```text
<agent-trackers>/
  README.md
  tracker-api.sh
  receipts.tsv
  <stem>.tsv
```

The tracker files and their schema are public and inspectable rather than private implementation
bytes. Skills may read and cite them directly when that is sufficient, but use the layer API for
cataloging, paging, and mutation. TSV remains canonical; SQLite is unnecessary unless measured scale
later justifies an ignored, rebuildable query cache.

An ordinary tracker is a current-state TSV with one row per item. A row carries a generated stable
ID, creation time, text, and optional evidence reference. Creating an item adds a row; updating it
rewrites that row. Consumption does not delete it. The repository's Git history—not a tracker
revision graph—provides prior versions, merge handling, rollback, and recovery.

All TSV string fields are single-line. Tabs and newlines refuse rather than introducing an escaping
grammar; the API otherwise preserves supplied text verbatim.

`receipts.tsv` is the reserved system tracker and shared receipt ledger for every `<stem>.tsv` in
the layer. It records simple `observed` and `consumed` events with a receipt ID, time, consumer key,
source tracker, item ID, and—for consumption—a required resolution plus optional result reference.
It is directly inspectable and queryable through the same API, but cannot itself be observed or
consumed. Repeating an observation or consumption that already stands is a successful no-op. No
receipt revisions, parents, lifecycle events, merge driver, or competing-consumer arbitration are
introduced; ordinary Git behavior handles concurrent edits.

A skill that declares `consumes: tracker` resolves `<agent-trackers>` and asks its fixed API to
describe the versioned `tracker@1` contract. Foreman, Analyst, and later consumers therefore know
the tracker layer, not Backlog's verbs or workspace namespace. No `/foreman setup`, provider
registration, or per-consumer adapter binds the two. Without a stood-up tracker layer, a consumer
remains usable with tracker data supplied directly by the caller. Analyst's status and briefing
facts use this contract instead of probing `.records/trackers`; Foreman's `consumes: tracker` edge
and `tune` verb use the same provider without naming Backlog as a dependency.

The installed provider self-locates from its canonical position inside `<agent-trackers>` and is
invoked directly as shown below. It neither scans the front door nor accepts unrelated records or
workspace roots. Mutation reports use paths relative to `<agent-trackers>`.

The first contract stays deliberately small:

```text
tracker-api describe
tracker-api catalog
tracker-api create --tracker <stem> --text <text> [--evidence <artifact-ref>]
tracker-api page --tracker <stem> --status open|consumed|all --limit <n> [--after <cursor>]
                 [--consumer <key> --unobserved]
tracker-api update --tracker <stem> --id <id> [--text <text>] [--evidence <artifact-ref>]
tracker-api observe --consumer <key> --tracker <stem> --ids <id>...
tracker-api consume --consumer <key> --tracker <stem> --ids <id>...
                    --resolution <text> [--result <artifact-ref>]
```

`catalog` lists the available tracker files and basic counts. `page` returns an ordered batch and a
simple continuation cursor; the cursor is traversal convenience, not durable state or a snapshot
lock. Paging `receipts` requires `--status all`; queue-only `--consumer` and `--unobserved` filters
refuse for that system tracker. `update` changes only an open row. An
observation is advisory and scoped to a stable caller-owned consumer key such as `foreman/tune`;
`--unobserved` omits items that key has already observed. Updating an item leaves those observations
in effect; the consumer may query all open items whenever it wants a fresh review.

Paging or directly reading a tracker is side-effect free and never creates a receipt. The API is the
sole receipt writer: `observe` automatically appends the corresponding observation receipts, and
`consume` automatically appends the corresponding consumption receipts. Callers never edit
`receipts.tsv` themselves.

`consume` is the draining operation. It appends a receipt for each still-open named item and leaves
the source row in place. The existence of a valid consumed receipt derives global consumed status.
Consumption also counts as observation by that consumer; it does not need a second receipt.
Several items may point to the same result, and a dismissal needs only its resolution. The API
reports missing and already-consumed IDs plainly and processes the rest; it does not implement
leases, batch transactions, stale snapshots, or conflict arbitration.

Backlog's tracker-management verbs stay equally literal: `tracker add` creates `<stem>.tsv`,
`tracker remove` deletes it, and `tracker list` lists the current files. Removing a tracker does not
rewrite `receipts.tsv`; Git is the recovery and history mechanism if the project later wants the
deleted tracker back. The reserved `receipts` stem is not part of the configurable tracker
population, and add/remove refuse it. Add/remove also add or remove only that tracker's section in
Backlog's debrief prompt. Individual queue rows have no delete verb because consumption is their
normal exit from the open queue.

Backlog's human verbs are thin views over the same provider: `file` calls `create`, `query` wraps
`catalog` and `page`, `debrief` routes through its compiled prompt and then calls `create` or
`update`, and `curate` uses `update` or `consume`. Retired `drop`, `reorder`, `complete`, migration,
and import entrypoints do not survive the hard cut.

This makes the ordinary draining loop intentionally boring: request a page of open rows, process it,
observe the deferred subset, consume the resolved subset, and follow the next cursor when the run
should inspect more. A later run can request only item identities that consumer has not observed,
so it needs no durable positional cursor. Consumers that want to reconsider updated
or previously deferred rows can simply page all open items. A human-facing `/backlog query` may wrap
`catalog` and `page`, but other skills use the layer API directly.

`/foreman tune <tracker>` is a runtime curation verb, not one-time integration setup. It resolves
the `tracker@1` layer API, requests a bounded page, and reasons over the batch as a whole: clustering
related observations, matching incumbent operations, and proposing procedures, workflows, or
doctrine. Once the selected proposals or dismissals are accepted, Foreman consumes the source rows
it actually resolved and observes insufficient candidates without closing them. Many source rows may
resolve to one operation, and one page may produce several operations. Accepted workflows provide
the authoritative reference graph; the routines tracker remains raw evidence rather than a process
graph or workflow runtime.

The typed edge remains the coarse `tracker`; first-class resolution supplies its common physical
home and `tracker@1` supplies its behavior. This avoids both sibling-specific coupling and an
expanding matrix of consumer-specific setup instructions. The existing owner-local `trackers`
workspace kind is retired rather than leaving two canonical tracker homes. Workspace remains solely
the validator of `<agent-workspace>` owner/kind shape and treats an owner-local `trackers` kind as
invalid; it does not resolve or validate `<agent-trackers>`. Backlog's setup and provider API own
that validation.

No durable last-debrief cursor is introduced initially. Within one context, the agent scopes from
its last successful sweep; after a deliberate reset, the new body begins at resume. Tracker history,
merges, and recovery belong to Git rather than to session or Workstream save-states or the API.

## Verification

The design should be proven against throwaway project fixtures, never by registering Backlog into
grimoire's authored root `AGENTS.md`.

Setup fixtures should demonstrate all four defaults, the receipt ledger, API, editable debrief
prompt, and bounded cadence block. Reruns preserve tracker data, `README.md`, and incumbent routing
bodies while refreshing only the managed executable. Malformed route blocks, symlinked root
components, incompatible entries, root overlap, and late relocation conflicts refuse without
touching the unsafe destination; an injected later failure reports any earlier safe writes and a
rerun completes. Removing the final queue removes the route block while retaining the layer and
receipt ledger.

Debrief fixtures should cover root and Workstream-shaped contexts, zero-result sweeps, once-only
bounded scope, routine deduplication, custom routing stubs, preserved prompt edits, and the
delegate-caller custody rule. Workstream fixtures should prove that neither a tracker buffer nor a
cursor is required in the hand-off, the pack installs no Backlog-specific Workstream hook body, and
generic Workstream hooks remain independent.

Provider fixtures should cover the public TSV schemas, line-safe field refusal, create/update,
side-effect-free multi-page traversal, stable per-consumer observations that survive row updates,
API-authored receipts, receipt-derived consumed status, and queryable receipts. Receipt paging must
accept `--status all` and reject queue-only filters; observing or consuming `receipts` must refuse.
Consumption fixtures should cover required resolutions, optional results, several rows sharing one
result, dismissal without a result, preservation of original evidence, consumption counting as
observation, idempotent repeats, and plain partial reporting for missing or already-consumed IDs.

Tracker-management fixtures should prove literal add/list/remove behavior, matching debrief-prompt
sections, preservation of unrelated receipts, reserved-stem refusal, and final-queue route-block
removal. Root fixtures should cover the implicit `.trackers` default, a safe first-setup override,
`.`, traversal, equality, and both directions of nesting against the other first-class roots.
Consumer fixtures should prove stable cross-session keys, independent purposes, Analyst reading
`tracker@1`, and Foreman paging, observing, and consuming through its generic tracker edge.

The hard cut needs a red-proof fixture: plant uniquely recognizable rows in both legacy
`.records/trackers` and `<agent-workspace>/backlog/trackers`, then prove Backlog setup, catalog,
page, debrief, and Analyst cannot surface them. Retired migration, import, completion, drop, and
reorder entrypoints must be absent or refuse as unknown. Doctrine, README, lint, Workspace, and pack
fixtures should reject the owner-local tracker kind, document the third independent root, and contain
no deployed Workstream-to-Backlog glue. Ordinary Git tests, not tracker fixtures, cover file history,
merges, and recovery.

## Open questions

None.
