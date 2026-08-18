---
name: clankshop
description: "Set up or migrate an agentic workshop around a code project: doctrine (.handbook/), records (.records/), and the AGENTS.md door. Verbs: setup (greenfield bootstrap: seed the handbook, stand up records via journal, write the door), migrate (brownfield onramp: inventory, one confirmed mapping table, adopt), check (assembly validation), and persona summons (architect/foreman/guardian/admin). Use when asked to set up or migrate the workshop/handbook on a project, validate its assembly, or talk to a station persona."
---

# clankshop — the workshop system

The face of the **clankshop pack**: the skill that stands up an **agentic workshop** around a
code project — a deployed structure of doctrine, records, and routing that lets agents (and
humans) work the project through a well-defined lifecycle, with the right context loaded at
the right time. Design: `docs/design/2026-08-12-clankshop-v2.md` (repo-root provenance
citation).

The workshop is a line of four **stations** — `design` (the architect), `build` (the foreman),
`test` (the guardian), `review` (the admin). A station merges place and actor: an agent works
a station by loading its context. Personas are **project-resident doctrine**, not machinery —
each station's chapter opens in its persona's voice; nothing routes on the names.

Three deployed surfaces carry it: **`.handbook/`** (doctrine — how we work),
**`.records/`** (work products, including the living design spec), and **`AGENTS.md`** (the
door: a thin routing table plus the handbook pointer). Once seeded, all three are the
**project's** documents — provenance is one install stamp line in `.handbook/README.md`, and
upgrades are a judgment-assisted diff against the current seed.

This `SKILL.md` is a thin router: each verb's procedure lives in `verbs/`, read on demand —
when a verb is selected, read its file and follow it.

## Verbs

| invocation | verb file | does |
|---|---|---|
| `setup` | `verbs/setup.md` | greenfield bootstrap: seed the handbook, records standup via `journal`, write the door, `check` green |
| `migrate` | `verbs/migrate.md` | brownfield onramp: scripted inventory, one confirmed mapping table, mechanical moves + judgment merges |
| `check` | `verbs/check.md` | assembly validation — load sets, stamp, slots, links, records conformance |
| `<persona> [prompt]` | `verbs/persona.md` | summon a station's voice for discussion — judgment only, no procedure |

Shared discipline: resolve the project root first (a directory the conversation references,
else the working directory, else ask); get the real date with `date +%Y-%m-%d`, never guess
it; scripts compute facts, verbs own judgment.

## Assets

| asset | where | is |
|---|---|---|
| the seed | `seed/` | the template handbook — mirrors a deployed `.handbook/` exactly (README, `core/`, four station chapters, `seed/scripts/context.sh`) |
| seeding mechanics | `scripts/seed.sh` | projects `seed/` into a target root: copy, slot fill, install stamp, self-check |
| migration preflight | `scripts/migrate-scan.sh` | brownfield inventory facts for `migrate` |
| pack manifest | `PACK.md` beside this SKILL.md | the roster `install.sh --pack` resolves (`docs/spec/pack-format.md`, repo-root) |

The records layer — `records.sh`, templates, `.records/` scaffolding — is deliberately **not**
here: it belongs to `journal`, a required pack member; `setup` delegates records standup to
it. The load rule, layout, and precedence rules live in the seed's own `README.md` — the
deployed handbook documents itself.
