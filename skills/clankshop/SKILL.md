---
name: clankshop
description: "The clankshop pack's executable face: the pack's doctrine and runbook home, plus the three system verbs that stand the framework up and validate it. setup is the greenfield bootstrap — interrogate the project, interview only genuine decisions, project the doctrine into AGENTS.md + .handbook/ + .records/, stamp the installation block. migrate is the brownfield onramp — generic discovery and classification of whatever exists, one confirmed mapping table, ends stamped. check is whole-system assembly validation — installation block, stamps and projections, chapter presence, cross-store integrity, pack lock vs installed set. Use when asked to set up the project, migrate this repo onto the framework, or check the system."
---

# clankshop — the pack's executable face

The entry skill of the **clankshop pack**: one atomically-versioned skill pack carrying the whole
development system — roles, instruments, pipelines, and helpers — as one unit. `clankshop` itself
is the pack-tier member: it carries the **doctrine** (the pack's seed content, in the spine
format), the **runbook** (the methodology narrative), and the three **system verbs** that assemble
and validate an installation.

Whole-system assembly belongs to this skill alone: the pack bootstraps, roles never do. The one
narrower exception is a role's bare *domain* self-init — its own seat and stores, never the
system — governed by the pre-stamp dispatch table (the pack design, §3.4).

Design docs: `docs/design/2026-08-06-clankshop-pack.md` (the pack design, layered on
`docs/design/2026-08-04-agent-framework.md`, the framework mechanics); rollout plan
`docs/design/2026-08-06-clankshop-pack-plan.md`.

## The pack — the roster

`clankshop` is the pack's face; the members split into four tiers. The full roster — each
member's charge, one table — is the **team roster** in `doctrine/README.md`; in brief:

- **roles** — expertise an agent inherits (standing judgments over a domain): `architect` design,
  `foreman` operations, `guardian` verification, `auditor` code quality, `chiropractor` docs
  quality, `calibrator` the improvement loop.
- **instruments** — invokable procedures whose operator exercises the judgment: `backlog` (the
  records instrument), `debugger` (the diagnostic instrument).
- **pipelines** — the work processes the system supports: `feature` (idea to gate-green code),
  `workstream` (shipping lanes).
- **helpers** — portable plumbing keeping the full independence discipline: `delegate`,
  `mailbox`, `handoff` (plus the optional `/bug` and `/task` capture proxies).

Core members (face + roles + instruments + pipelines) reference each other and the deployed
layout directly — atomic versioning is what makes that safe.

## Assets

| asset | where | is |
|---|---|---|
| doctrine | `doctrine/` | the pack's seed content: `rules/`, `workflows/`, `testing/` chapters; index + registry + roster + door profile (`doctrine/README.md`); the base archive (`doctrine/BASES.md`) |
| runbook | `docs/RUNBOOK.md` | the methodology narrative — the flow of a change, when to assume which role, the three altitudes, escalation, the improvement loop |
| pack manifest | `PACK.md` beside this SKILL.md | the release manifest `install.sh --pack` resolves and preflights |

The manifest is pack-as-skill, `docs/spec/pack-format.md` format 1: `name:` and `version:`
(semver), the `required:` and `optional:` comma-separated member lists, plus the `core:`
extension key (the lint gate's core-member exemption). Installs are recorded in the sidecar
`grimoire.lock`.

The doctrine's declaration blocks carry `doctrine: clankshop` + `doctrine-version:`; every
seedable entry has a stable origin ID (`clankshop:INV-4`), so seeding is copying entries under the
projection protocol — provenance-stamped, base-recorded, mechanically diffable.

## Verbs

| verb | does | status |
|---|---|---|
| `setup` | greenfield bootstrap: facts by script, decisions by interview, project the doctrine through the facts into `AGENTS.md` + `.handbook/` + `.records/`; write the installation block, the compiled tier-0 table, the stewardship maps, each member's door registration | `verbs/setup.md` |
| `migrate` | brownfield onramp: preconditions → generic inventory → content classification → one confirmed mapping table → worktree execution with rollback → aliases preserved → nothing-dropped check → stamp | `verbs/migrate.md` |
| `check` | whole-system assembly validation: installation block, every stamped projection vs its named input, chapter presence, cross-store foreign-key integrity, mirror drift, seats, lock vs installed set — facts only | `verbs/check.md` |

The fact partition: `check` owns **assembly** facts; document-shape facts (entry conformance,
citation resolution, budgets) are the docs-quality role's; code quality is the auditor's. Scripts
compute facts; verb prose owns judgment.
