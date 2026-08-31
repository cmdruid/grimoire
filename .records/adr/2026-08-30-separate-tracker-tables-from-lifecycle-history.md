---
doctype: adr
status: published
schema: architect/adr@1
tags: [trackers, storage]
---

# Separate tracker tables from lifecycle history

- **Deciders:** Project owner, 2026-08-30; amended 2026-08-31
- **Related:** → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`;
  → `specs/2026-08-27-backlog-routines-and-universal-debrief.md`;
  → `specs/2026-08-28-backlog-tracker-provider-discoverability.md`

## Context

Backlog's fixed `.trackers` layer currently keeps its adjacent provider, guide, routing prompt,
queue tables, and `receipts.tsv` in one flat directory. Queue discovery therefore scans every TSV
at the layer root and special-cases receipts even though receipts is not a queue. The public catalog
and paging API reinforce that mismatch by exposing receipts as a reserved pseudo-tracker.

The receipt data already behaves more like history than current queue state. It is an append-only
ledger of consumer-scoped `observed` events and terminal `consumed` events. Queue rows remain in
their source tables, while the provider derives open or consumed state and per-consumer observation
state from the ledger. Creation timestamps live with the rows, ordinary row edits remain visible in
Git, and receipts do not attempt to duplicate that history.

Now that `.trackers` is a canonical fixed home, its internal structure should express these two
different responsibilities directly. The change affects persisted project data and the public
provider contract, so it must not masquerade as a compatible implementation detail.

The original hard cut documented brownfield conversion as a manual procedure. That keeps runtime
small, but leaves no discoverable command for safely moving a recognized older installation to the
current format.

## Decision

1. **D1 — Separate tables from history.** Configurable tracker tables live only at
   `.trackers/tables/<stem>.tsv`. The tracker-layer root contains `README.md`, `DEBRIEF.md`, the
   package-managed `trackers.sh`, `history.tsv`, and the `tables/` directory. No queue TSV lives
   directly under `.trackers`.
2. **D2 — Make history a lifecycle ledger.** `.trackers/history.tsv` is the sole append-only ledger
   for tracker lifecycle events. Its rows identify an event, timestamp, consumer, tracker, item,
   action, resolution, and result. Event IDs use `event-<positive-integer>`. The initial actions are
   `observed` and `consumed`; an observation has no resolution or result, while consumption requires
   a resolution and may name a result.
3. **D3 — Preserve derived state.** Observation is scoped to `(consumer, tracker, item)` and is
   idempotent for that tuple. Different consumers may observe the same item. Consumption is the
   tracker-wide terminal transition and also counts as observation by the consuming consumer.
   Consumed rows remain in their table; the provider derives open, consumed, and unobserved views
   from `history.tsv`. Removing a tracker removes its table but preserves its history. Recreating a
   stem continues numbering past matching item IDs in history so no historical event binds to a new
   row; deleted items that never entered history reserve no ID.
4. **D4 — Publish a `tracker@2` boundary.** The adjacent provider describes `tracker@2`.
   `catalog` and queue `page` discover only `.trackers/tables/*.tsv`; history is never a tracker,
   catalog row, or `page --tracker` target. The bounded read form is
   `history --limit <n> [--after <event-id>]`; it emits `schema=tracker@2`, `next=`, `--`, then the
   eight-column history TSV headed `id`, `created`, `consumer`, `tracker`, `item`, `action`,
   `resolution`, and `result`. Other history filters are deferred. Mutations report paths relative
   to `.trackers`, including `tables/<stem>.tsv` and `history.tsv`. Lifecycle mutations identify
   each newly appended history row as `event=event-N`. Configurable tracker stems use the ordinary
   stem grammar without any ledger-name reservation. Receipt terminology, receipt IDs, and the
   receipt pseudo-tracker leave the live contract.
5. **D5 — Hard cut with an explicit migration edge.** Setup, repair, and runtime recognize only the
   current layout and `tracker@2`; root-level queue TSVs and `receipts.tsv` remain incompatible
   incumbent data and cause a write-free refusal. `/backlog migrate [<source-root>]` is the sole
   legacy reader. It previews and, after explicit confirmation, converts one exact recognized
   tracker@1 TSV installation to tracker@2 in a clean Git worktree. The initial converter accepts
   tracker@1 at `.trackers`, or one explicitly supplied safe repo-relative prior tracker root that
   is dedicated and fully tracked. For an external source, `.trackers` must be absent; migration
   moves the complete source there. It then moves queues under `tables/`, moves `receipts.tsv` to
   `history.tsv`, rewrites only receipt IDs to event IDs, and reconciles the current provider and
   guide. No Backlog command reads, writes, removes, or commits `AGENTS.md`, `CLAUDE.md`, or another
   project front door; retired declarations and installed route blocks are cleanup outside this
   migration. Unknown, mixed, untracked, colliding, malformed, record-based, and Markdown formats
   refuse without best-effort conversion. There is no alias, dual read, fallback, automatic
   adoption, or runtime version bridge. Git is the recovery surface, and conversion preserves row
   order and every non-ID field byte.
6. **D6 — Supersede only the replaced contract.** This ADR supersedes the related specs' flat queue
   layout, receipts path and vocabulary, receipt pseudo-tracker, receipt-specific stem reservation,
   `tracker@1` marker and command roster, initialization-boundary path, and path-bearing output.
   It also supersedes the fixed-homes ADR's prohibition on a tracker migration engine only for this
   explicitly invoked, dedicated-root Backlog migration. Fixed canonical homes, retired runtime
   selectors, the prohibition on workspace movers, and every other fixed-homes clause remain
   authoritative. It supersedes Backlog route-registration and debrief-anchor requirements: the
   tracker layer is self-described by `.trackers/README.md`, while workflow composition is external
   to Backlog and deferred. The related specs' queue schema, setup and repair recovery, README
   ownership, consumer keys, lifecycle behavior, safety guards, and other unrelated requirements
   also remain authoritative.

## Alternatives considered

- **Keep the flat layout and rename only receipts.** Changes the noun while retaining root scans,
  reserved-file exclusions, and the misleading co-location of current tables with lifecycle state.
- **Move queues but retain `receipts.tsv`.** Improves discovery but keeps receipt terminology and a
  pseudo-tracker contract that no longer describes the file's role.
- **Move consumed rows out of their tables.** Makes history an archive rather than a lifecycle
  ledger, requires a multi-file move for every consumption, and makes stable item lookup and Git
  conflict recovery harder.
- **Log creation and every update.** Turns the provider into a full event-sourcing system and
  duplicates history already carried by table rows and Git. The ledger needs only the events from
  which runtime lifecycle views are derived.
- **Detect or migrate old layouts from setup or repair.** Reduces the immediate operator step by
  making legacy discovery and compatibility a permanent concern in ordinary reconciliation and
  runtime recovery.

## Consequences

The tracker root gains a legible boundary: `tables/` is the open-ended queue population and
`history.tsv` is shared lifecycle state. Queue discovery no longer needs to exclude a special TSV,
catalog output names only actual trackers, and history receives its own read surface. Observation
and consumption retain their current useful semantics without adding mutable status columns or
physically archiving table rows.

This is an atomic breaking change across Backlog's provider, setup and recovery classifier,
runtime guard, verbs, managed README block, doctrine, consumers, deployed project files, and tests.
Every live `tracker@1`, root-level queue, and receipts assumption must change together. Existing
receipt-page cursors and receipt IDs do not survive conversion; item IDs and all substantive ledger
fields do.

Brownfield conversion is deliberate operator work and must happen before ordinary Backlog use. The
generic migration command is discoverable, while its converter remains version-specific and outside
the steady-state setup, repair, and runtime paths. The initial scope is tracker@1 TSV data only;
supporting another historical format requires another explicit converter. `.records/history.tsv`
and `.trackers/history.tsv` share a filename but not an authority: the former is Journal's
record-closure ledger, while the latter is Backlog's tracker-lifecycle ledger, so operative prose
and diagnostics name them with their layer-qualified paths.
