---
doctype: adr
status: published
schema: architect/adr@1
tags: [discovery, front-door]
---

# Add explicit project-layer discovery anchors

- **Deciders:** Project owner, 2026-08-31
- **Related:** → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`;
  → `adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md`

## Context

The fixed `.records/` and `.trackers/` layers are public project state with self-locating tools and
local guides. An agent that has Journal or Backlog installed can discover those layers through the
skill, but an agent without the owning skill may never inspect either hidden directory. The project
therefore loses access to durable records and follow-up state even though the installed
`records.sh` and `trackers.sh` providers remain usable without their source packages.

Both layers already publish package-managed README contracts beside their providers. Journal's
guide covers the record discriminator and complete lifecycle, while Backlog's guide exercises each
command family but leaves some observation, consumption, unobserved-page, and cursor semantics to
the skill. Their recovery text also assumes the owning skill is available. A project-local pointer
is useful only if the referenced guide and adjacent provider are sufficient for safe ordinary use.

The prior Backlog anchor was different: it registered a skill route and debrief cadence through a
managed front-door block. That subsystem was deliberately removed. The fixed-homes cut also retired
front-door path declarations. A discovery pointer must not restore either behavior or turn the
canonical paths back into configuration.

## Decision

1. **D1 — Add explicit owner-local anchors.** Journal exposes `/journal anchor`; Backlog exposes
   `/backlog anchor`. Each verb targets only the repository-root `AGENTS.md` and its own fixed local
   guide: `.records/README.md` or `.trackers/README.md`. It first verifies that the corresponding
   initialized layer, README, and adjacent provider are safe and current; previews the exact
   front-door addition; obtains confirmation; rechecks; and then writes. A missing `AGENTS.md` may
   be created. Standalone use makes one path-scoped commit containing only `AGENTS.md`; an announced
   configuration sweep may retain write custody instead.
2. **D2 — Install absent-only project prose, not a managed block.** The canonical additions are:

   ```markdown
   ## Project records

   Durable project decisions, plans, reports, and notes live in `.records/`. Read `.records/README.md` before searching or changing record state; it defines what counts as a record and explains the adjacent lifecycle tool.
   ```

   ```markdown
   ## Project trackers

   Actionable project follow-ups live in `.trackers/`, with queue tables for current items and lifecycle history for observations and resolutions. Read `.trackers/README.md` before inspecting or changing tracker state; it explains the local contract and adjacent tracker tool.
   ```

   The pointer becomes project-owned as soon as it is written. It has no begin/end tags, build
   stamp, version, refresh, replacement, or removal protocol. If the literal README path already
   appears in `AGENTS.md`, anchor is a no-op regardless of surrounding wording. If the canonical H2
   exists without that path, anchor refuses rather than appending a duplicate heading. Unsafe or
   non-regular incumbents also refuse without a write.
3. **D3 — Keep anchoring independent from layer lifecycle.** Setup, repair, migration, ordinary
   runtime, and tracker administration never install, refresh, inspect as a prerequisite, or remove
   an anchor. The anchors name no skill route, verb roster, callback, hook, cadence, dynamic root,
   or workflow composition. They only describe project state and point to its fixed local guide.
4. **D4 — Make each installed layer independently operable.** The README plus adjacent provider
   must let an agent without the owning skill safely perform ordinary work. For records, that means
   discovering, querying, validating, creating, updating, relocating, and closing records through
   `.records/records.sh`. For trackers, it means describing and cataloging queues, paging queues and
   history, creating and updating items, and observing and consuming items through
   `.trackers/trackers.sh`. The guide or provider's own help must expose the complete ordinary
   command forms and explain purpose, layout, lifecycle semantics, direct-edit prohibitions,
   mutation output, and Git custody. If maintenance is required and the skill is unavailable, the
   guide tells the agent to stop and report that requirement rather than improvise a repair.
5. **D5 — Leave structural and judgment work with the skills.** Standalone layer use does not
   include setup, repair, brownfield migration, tracker-table creation or removal, debrief routing,
   records curation, or other owner-level judgment. The READMEs explain this ceiling without making
   the owning skill a prerequisite for ordinary provider operations. Package-managed delimiters
   remain appropriate inside the layer READMEs because those contracts evolve with their adjacent
   providers; the stable project-owned `AGENTS.md` pointers do not need them.
6. **D6 — Supersede only the front-door prohibition this feature replaces.** This ADR supersedes
   the tracker-history ADR's prohibition on every Backlog front-door write only for the explicitly
   invoked `/backlog anchor`; its route-registration and debrief-anchor removal remains in force.
   It does not weaken the fixed-homes ADR: `agent-records:`, `records-root:`, `agent-trackers:`, and
   other selectors remain retired, and neither anchor reads them. Portable doctrine may distinguish
   this absent-only project pointer from refreshable route registration, but persistence alone still
   does not authorize front-door projection. In Grimoire itself, both verbs are tested only against
   throwaway repositories and never modify the library's authored `AGENTS.md`.

## Alternatives considered

- **Rely on skill discovery or hidden-directory scans.** Keeps the front door smallest, but fails
  precisely when the skill is not installed and agents do not enumerate dot-directories.
- **Install the pointers from setup.** Improves default visibility by coupling durable-state setup
  to front-door policy, recreating the ownership mistake the explicit verbs are meant to avoid.
- **Use versioned begin/end blocks.** Supports package refresh and removal, but the stable pointer
  has no package-owned lifecycle after installation. Marker overhead and reconciliation code would
  exceed the content they protect.
- **Let both skills edit one shared project-data section.** Saves one heading at the cost of shared
  ownership, ordering, and collision rules. Separate project-owned sections keep each installation
  independent.
- **Copy the complete layer contracts into `AGENTS.md`.** Makes every session pay for command and
  schema detail, duplicates the provider-coupled READMEs, and creates two drift surfaces.

## Consequences

Projects may opt into durable discovery with two short, human-editable sections. Agents can find
and use records and tracker state after the source skills are removed, while front doors remain free
of command rosters and workflow cadence. Fixed literal paths make the installed prose stable enough
to become project-owned immediately.

Journal and Backlog gain one explicit front-door verb apiece and must maintain stronger deployed
README contracts and standalone fixture coverage. Backlog's local guide and possibly its provider
help need enough detail to expose observation, consumption, unobserved paging, and cursors without
consulting `SKILL.md`. Both guides need a skill-unavailable maintenance stop. These changes enlarge
the deployed guides, not the always-loaded pointers.

Because anchors never refresh project prose, later wording improvements do not rewrite existing
front doors. That is intentional: a present fixed-path reference already satisfies discovery, while
substantive path changes remain explicit hard-cut migrations. A project that removes a layer owns
removing its now-project-owned pointer.
