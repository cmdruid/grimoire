---
doctype: adr
status: published
schema: architect/adr@1
tags: [backlog, anchor, registration]
---

# Make Backlog anchor a managed project debrief route

- **Deciders:** Project owner, 2026-09-03
- **Related:** → `adr/2026-08-31-add-explicit-project-layer-discovery-anchors.md`;
  → `specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`;
  → `specs/2026-09-03-backlog-tracker-selection-failure-intake-and-project-debrief-routing.md`

## Context
Backlog owns project follow-up state under `.trackers/`, but a session can lose concrete leftovers
unless an always-loaded instruction tells the main agent when to run `/backlog debrief`. Manual
invocation remains available after the skill loads; it cannot supply a cold-start route before that
point.

Backlog previously installed a managed front-door route and universal debrief cadence as part of
setup. That mechanism was removed because setup silently claimed project `AGENTS.md`, mixed tracker
lifecycle with workflow composition, and gave projects no independent registration choice. A later
decision restored `/backlog anchor` only as an explicitly invoked, markerless discovery pointer to
`.trackers/README.md`. That pointer helps agents find tracker state but does not preserve follow-ups
at an end-of-work boundary, cannot evolve with route semantics, and has no safe removal lifecycle.

The global `skill-feedback` anchor demonstrates a narrower registration shape: an explicit verb owns
one versioned route block, previews changes, binds application to the previewed file identity, and
supports update and removal. Backlog needs those mechanics at project scope, with Git custody and
project-owned tracker boundaries instead of a private global store.

## Decision
1. **D1 — Register an opt-in project debrief route.** `/backlog anchor` manages one Backlog-owned
   block in the repository-root `AGENTS.md` under `## Skill routes (self-registered)`. The route tells
   the custodial main agent to invoke `/backlog debrief` once after substantive project work when
   unresolved project-owned follow-ups remain, before its final response or a healthy reset. It stays
   silent for pure Q&A, routine status, ordinary success with no leftovers, and child/delegate
   contexts. It sends reusable-skill observations to their skill feedback channel rather than project
   trackers. The block also points to `.trackers/README.md` for local discovery.
2. **D2 — Keep registration explicit and optional.** Bare `/backlog anchor` offers to install or
   refresh the route, remove it when present, or cancel. `/backlog anchor --debrief` selects
   installation or refresh without a choice prompt; `--remove` selects removal. First-time attended
   `/backlog setup` offers the same debrief route after tracker selection, defaulting to off.
   `/backlog setup --debrief` explicitly selects it. Unattended setup without the flag never changes
   `AGENTS.md`, and initialized setup never prompts for registration.
3. **D3 — Give the owned block a complete lifecycle.** The block uses
   `<!-- skill:backlog BEGIN built-against:<sha-or-version> -->` and
   `<!-- skill:backlog END -->`. Preview emits the complete diff and a SHA-256 identity for the
   current front door. Interactive application requires confirmation of that preview. `--debrief`
   is full consent to the canonical install or refresh, but still runs the same preview, identity,
   path-safety, malformed-block, concurrency, and competing-route checks. Removal deletes only a
   well-formed owned block and preserves the reserved heading and all surrounding bytes. Removal
   does not require a healthy tracker layer; a project must be able to withdraw a stale route after
   its `.trackers` state or source skill is damaged or removed.
4. **D4 — Preserve independent project surfaces.** Setup completes and commits tracker-layer changes
   before an optional anchor operation begins. Anchor failure never rolls back or invalidates setup.
   The anchor operation has its own exact `AGENTS.md` commit custody. Repair, migration, provider
   use, queue administration, and initialized setup without explicit `--debrief` remain front-door
   neutral. No Backlog path reads or changes `CLAUDE.md`.
5. **D5 — Migrate only recognizable prior output.** When the exact canonical markerless
   `## Project trackers` section is present, the managed-route preview replaces it as part of one
   confirmed cutover. `--debrief` authorizes that exact migration. Customized discovery prose is
   preserved. A competing behavioral route requires an explicit human cutover decision; malformed
   ownership markers refuse without a write.
6. **D6 — Supersede the Backlog pointer decision, not Journal's.** This decision supersedes the
   Backlog-specific absent-only, project-owned pointer provisions in
   `2026-08-31-add-explicit-project-layer-discovery-anchors.md`. That ADR remains authoritative for
   Journal's discovery pointer. It also leaves the prior removal of automatic setup registration,
   dynamic tracker-root declarations, and the old route subsystem in force except for the new
   explicit managed block defined here.

## Alternatives considered
- **Keep the discovery-only pointer.** This is enough when hidden-directory discovery is the only
  need, but it does not create the requested end-of-work capture behavior.
- **Restore automatic setup registration.** Automatic registration maximizes adoption but repeats
  the ownership failure that removed the old route. An attended choice or explicit flag provides the
  convenience without treating durable state as permission to claim the front door.
- **Offer separate discovery and debrief anchor modes.** Two anchor meanings create transition,
  refresh, and removal ambiguity. The debrief route can carry the fixed guide pointer in one block.
- **Use only Workstream or project-composer hooks.** Those routes cover selected workflows, not every
  substantive project session where follow-ups can surface.

## Consequences
Projects can opt into reliable project-follow-up capture without making Backlog registration a setup
prerequisite. The route stays short and cold-start readable, while `.trackers/DEBRIEF.md` and the
skill retain detailed classification judgment. Managed ownership allows Backlog to evolve or remove
its route safely and gives concurrency failures a deterministic boundary.

The change intentionally increases Backlog's front-door authority after explicit consent. It
requires a larger fixture matrix for shared headings, fenced examples, competing routes, stale
previews, exact legacy-pointer migration, removal, byte preservation, and commit custody. Existing
custom project prose cannot be normalized automatically. Grimoire remains patient zero: every
front-door mutation test runs in a throwaway repository, never against its authored `AGENTS.md`.
