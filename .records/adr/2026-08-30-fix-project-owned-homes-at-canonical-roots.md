---
doctype: adr
status: published
schema: architect/adr@1
tags: [storage, paths]
---

# Fix project-owned homes at canonical roots

- **Deciders:** Project owner, 2026-08-30
- **Related:** → `specs/2026-08-25-agent-workspace-naming.md`;
  → `specs/2026-08-28-journal-records-provider-discoverability-and-durable-setup.md`;
  → `specs/2026-08-28-backlog-tracker-provider-discoverability.md`

## Context

Grimoire distinguishes three useful kinds of project state: typed records, owner-first skill
support, and public follow-up trackers. Their current defaults are `.records`, `.spaces`, and
`.trackers`, but each is also a front-door variable. Records accepts a second legacy spelling.

Those selectors make rare layout variation a permanent concern for every producer and consumer.
The library carries repeated declaration parsers, path arguments, precedence prose, overlap rules,
and fixtures. Workspace and tracker overrides have no demonstrated consuming-host population.
Records has genuine brownfield history, but its internal identities and links are records-root
relative. A dedicated records root can therefore move wholesale under Git without changing
ordinary record identity. A source mixed with unrelated project documents is not a safe target for
automatic surgery and remains a human-reviewed move.

Separately, Backlog's editable debrief routing file is stored under the workspace even though its
section population and lifecycle are coupled directly to queues in the tracker layer.

Earlier published specs encode the configurable-root and old debrief-location contracts. This ADR
retires only those path-selection clauses; it leaves their unrelated provider, schema, lifecycle,
and recovery requirements intact.

## Decision

1. **D1 — Fixed homes.** `.records/`, `.spaces/`, and `.trackers/` are canonical constants, not
   defaults behind front-door variables. The `agent-records:`, `records-root:`,
   `agent-workspace:`, and `agent-trackers:` declarations retire.
2. **D2 — Preserve semantic layers.** Fixed paths do not collapse ownership. Records, workspace,
   and trackers retain their distinct authorities and formats.
3. **D3 — Keep records migration thin.** Journal owns `/journal migrate [<source-root>]` for a
   clean Git worktree, an absent `.records`, and a dedicated, fully tracked records root. It
   previews the source, rechecks, moves the whole directory to `.records`, removes the retired
   records declaration, refreshes the fixed Journal tool layer, runs the records check, and commits
   the visible change. A mixed source refuses and lists the unrelated entries for manual handling.
   Git status is the interruption and recovery surface; Journal adds no migration manifest,
   digest protocol, compatibility provider, alias, fallback, or automatic rollback.
4. **D4 — No compatibility movers.** Workspace and tracker overrides receive no migration engine.
   Before their first post-cut Backlog setup, existing projects move the known prompt explicitly with
   `git mv .spaces/backlog/hooks/debrief.md .trackers/DEBRIEF.md`; Backlog runtime and setup contain
   no prior-path probe or adoption branch.
5. **D5 — Self-locating public tools.** Adjacent providers derive their fixed layer and project root
   from their canonical installed path. Root-selection arguments disappear from the public runtime
   contract.
6. **D6 — Supersession boundary.** This ADR supersedes earlier published requirements that treat
   `.records`, `.spaces`, or `.trackers` as configurable defaults; recognize their retired
   front-door declarations or root-selection arguments; support custom or coincident roots; or
   place Backlog's debrief prompt under `.spaces/backlog/hooks/`. Provider APIs, schemas, record
   identities, setup and repair recovery contracts, queue semantics, and other unrelated
   requirements remain authoritative.

## Alternatives considered

- **Keep all three variables.** Maximizes theoretical host freedom but taxes every ordinary action
  and leaves project instructions capable of splitting one logical layer across readers.
- **Keep only records dynamic.** Addresses demonstrated variance but makes a one-time brownfield
  concern permanent. Relative record identities make guarded relocation the better boundary.
- **Fix every path with no migration.** Simplest implementation, but strands real record history and
  makes even a normal dedicated records-root rename needlessly manual.
- **Collapse state under one root.** Removes top-level directories by weakening the meaningful
  public-data versus owner-local-support seam.
- **Discover legacy content automatically.** Risks treating an arbitrary documentation tree as
  Journal-managed state without explicit consent.
- **Build a transactional selective migration engine.** Checksummed manifests, automatic resume,
  reference rewriting, and mixed-root surgery would recreate a durable subsystem for a one-time
  move of Git-tracked text. The narrow whole-root move covers the ordinary case; Git and explicit
  human handling cover the exceptional case.

## Consequences

Every live skill and helper gains one predictable project layout. Resolver functions, declaration
precedence, dynamic overlap validation, and root-selection CLI arguments disappear. Project front
doors become smaller, providers are discoverable beside their data, and Backlog's complete routing
surface becomes cohesive.

The change is a coordinated mechanical hard cut across doctrine, current skill prose, scripts,
consumers, lint, and tests. Ordinary code constructs only `.records`, `.spaces`, and `.trackers`;
retired declarations are invalid configuration, never runtime selectors. Historical specs remain
unchanged as evidence. Clauses superseded by D6 are no longer governing; their unrelated
requirements remain authoritative.

Projects with a custom dedicated records root may use the narrow Journal move. A mixed records root
or custom workspace/tracker root requires an explicit human move; the library does not guess.
Existing Backlog prompts have one documented `git mv`. These constraints intentionally trade
automatic edge-case migration for a small implementation with no permanent compatibility debt.
