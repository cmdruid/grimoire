---
doctype: streams
status: archived
schema: workstream/plan@1
tags: [plan]
---

# Grimoire Phase 2 declarative state and planner kernel

Queue source:
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`, Phase 2.

Governing contract:
`.records/specs/2026-08-31-grimoire-symlink-package-manager.md`.

## Objective

Establish project/global desired state, deterministic locked resolution, and one pure domain
planner before introducing any filesystem executor.

## Scope boundary

Include scope discovery, comment-preserving manifest edits, hard-cut JSON locks, pack resolution
and request roots, optional-member states, immutable world state, typed requests, plans, blockers,
preconditions, and exit-class facts.

Exclude Git and network access, source/snapshot custody, trust persistence, link mutation,
transaction recovery, and CLI/TUI rendering.

## Planning gate

Ground the phase against the landed inventory API, then turn this manifest into a reviewed,
slice-ordered implementation plan before changing production code. Preserve the roadmap's hard-cut
constraint: alpha lock and operation types are deleted, never adapted or wrapped.

## Phase gate

- Manifest and lock goldens are deterministic and machine-portable.
- Alpha lock input is a hard error with no compatibility reader.
- Resolution matrices cover project/global scope, pack requests, optional states, collisions, and
  shadowing.
- Pure planner tests prove complete actions, blockers, preconditions, and destructiveness without
  ambient reads or filesystem writes.
- Former agent-target, live-library, install-log, and immediate-operation domain types remain
  absent.
