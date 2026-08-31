---
doctype: adr
status: published
schema: architect/adr@1
tags: [workstream, storage]
---

# Give Workstream a dedicated streams control home

- **Deciders:** Project owner, 2026-08-31
- **Related:** → `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`;
  → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`

## Context

Grimoire fixes typed records, owner-local support, and public trackers at `.records`, `.spaces`, and
`.trackers`. Workstream does not fit entirely within any one of those semantic layers. It owns
ignored runtime worktree directories and handoffs under `.workstreams`, project hooks and templates
under `.spaces/workstream`, and execution manifests and debriefs under `.records/streams`.

The split makes one workflow depend on three lifecycle and migration regimes. It also prevents the
runtime parent from carrying tracked project defaults, validation tooling, human guidance, and a
brief activity ledger. Keeping those files elsewhere would preserve path machinery whose only
purpose is accommodating the old split.

Workstream is unusual among skills: entering it gives one session exclusive custody of a durable
development loop and often a Git worktree. Its runtime parent therefore has a stronger identity
than ordinary owner-local support or scratch space. The root must remain fixed and narrowly owned;
making project paths configurable would recreate the selection complexity that the canonical-home
decision removed.

## Decision

1. **D1 — Add one fixed Workstream root.** `.streams/` is the canonical home for Workstream's
   tracked control surface and ignored runtime stream directories. It is a narrow exception to the
   three general project homes, not a configurable fourth storage layer available to other skills.
2. **D2 — Keep control and runtime visibly distinct.** Only declared top-level control files may be
   tracked. Immediate child directories are runtime streams and are ignored. Topology and Git
   registry guards enforce that distinction independently of ignore configuration.
3. **D3 — Hard-cut the old layout.** Live Workstream code reads and writes only `.streams`.
   Existing `.workstreams` instances move through an explicit project-wide migration; runtime has
   no fallback reader, alias, symlink, or mixed-root mode. Historical artifacts retain the prior
   spelling.
4. **D4 — Retire the split support stores.** Workstream stops owning `.spaces/workstream` and
   `.records/streams`. Project configuration and hook bodies live in `.streams/CONFIG.md`; concise
   shipment history lives in `.streams/history.tsv`. Durable plans and reports remain with their
   actual authoring authorities.
5. **D5 — Amend, do not undo, fixed-home doctrine.** This ADR supersedes only the claim in
   `2026-08-30-fix-project-owned-homes-at-canonical-roots.md` that all project-owned skill state must
   fit the three listed roots. That ADR's fixed-path, no-selector, semantic-ownership, hard-cut, and
   conservative-migration decisions remain authoritative.

## Alternatives considered

- **Keep `.workstreams` as an ignored runtime-only root.** Avoids a rename but leaves configuration,
  tooling, and history scattered elsewhere and keeps the misleading long form after the concept has
  standardized on streams.
- **Put all Workstream support under `.spaces/workstream`.** Fits the owner-first grammar but cannot
  naturally contain linked Git worktrees, and nesting runtime beneath tracked workspace support
  obscures the safety boundary.
- **Track control files under `.workstreams`.** Avoids migration but changes a root whose incumbent
  contract is wholesale ignore and perpetuates the old name in every coordinate and recovery guard.
- **Use `.stream/` singular.** Reads like one singleton instance even though the root is a registry
  and parent for multiple concurrent streams.
- **Keep manifests and debriefs as records.** Preserves detailed archives at the cost of schemas,
  templates, closure rules, and duplicated state that the development history and handoff already
  supply.
- **Make the root configurable.** Offers theoretical host flexibility while taxing every custody,
  migration, recovery, and nested-state check with permanent path selection.

## Consequences

Workstream gains one discoverable, self-contained project surface. Configuration, helper recovery,
runtime topology, and brief history share an owner and can be explained by one README. Agents
outside streams do not need to load that surface; agents inside a stream receive a resolved snapshot
through `WORKSTREAM.md`.

Tracked `.streams` control files appear inside linked worktrees. Implementations and tests must
distinguish those legitimate files from nested runtime directories rather than treating any
`.streams` presence as corruption. Safety continues to rely on canonical coordinates, Git registry
agreement, tracked-path allowlists, and exact deletion targets—not on ignore rules.

The change requires a coordinated hard cut across Workstream prose, helpers, tests, README and pack
inventory, skill-building doctrine, and live recovery instructions. Existing streams require one
explicit migration. Existing `.spaces/workstream` customizations and `.records/streams` artifacts
are neither adopted nor deleted automatically.
