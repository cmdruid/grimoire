---
name: clankshop
description: "The clankshop development system — one skill carrying the pack's doctrine, runbook, role hats, and verbs. System verbs: setup (greenfield bootstrap), migrate (brownfield onramp), check (assembly validation). Intent verbs, each worn with its role hat: design (the architect — seed-altitude design), route (the foreman — classify a change, dispatch it to its lane), verify (the guardian — gate/CI/diagnostics stewardship and verification judgment), calibrate + docs (the chiropractor — the improvement loop and docs-quality audits). ask <role> puts a hat on for discussion. Use when asked to set up/migrate/check the system, route a change, do seed-altitude design, harden the gate, audit the docs, calibrate the system, or talk to a role."
---

# clankshop — the development system

The face of the **clankshop pack**: one atomically-versioned skill carrying the whole
development system — the **doctrine** (the pack's seed content, in the spine format), the
**runbook** (the methodology narrative), the **role hats** (the pack's expertise layer), and the
**verbs** that operate it all. Separate pack members remain only where a skill earns a
standalone life (the instruments, pipelines, and helpers — see *The pack*, below).

Whole-system assembly belongs to this skill alone: the pack bootstraps, nothing else does. This
`SKILL.md` is a thin router — each verb's procedure lives in `verbs/`, read on demand; when a
verb is selected, read its file and follow it.

Design docs: `docs/design/2026-08-06-clankshop-pack.md` (the pack design, layered on
`docs/design/2026-08-04-agent-framework.md`, the framework mechanics) as amended by
`docs/design/2026-08-10-clankshop-role-merge.md` (roles merged into the face) and
`docs/design/2026-08-10-doctrine-sync-removal.md`; rollout plan
`docs/design/2026-08-06-clankshop-pack-plan.md`.

## Verbs and hats — the two-layer contract

**Routes are intent verbs; expertise is a hat the verb inherits.** A hat (`roles/<role>.md`) is
a small instruction file — identity, standing judgments, domain — and the dispatch rule is:
**read the hat first, then the verb file; you operate the verb wearing that hat.** Role names
never appear as procedure routes; routes never carry the expertise; `ask` is the one route that
addresses a hat directly.

| verb | hat | does |
|---|---|---|
| `setup` | — | greenfield bootstrap: facts by script, decisions by interview, project the doctrine, stamp (`verbs/setup.md`) |
| `migrate` | — | brownfield onramp: generic inventory, one confirmed mapping table, stamp (`verbs/migrate.md`) |
| `check` | — | whole-system assembly validation — facts only (`verbs/check.md`) |
| `design [<verb>]` | architect | seed-altitude design. Bare = seed work (bootstrap/migrate the design chapter, `verbs/design/seed.md`); subverbs `brainstorm` · `plan` · `extract` · `distill` · `reconcile` · `health` (`verbs/design/`); `prep` pending (method: `docs/DESIGN-DOCTRINE.md`) |
| `route [<change>]` | foreman | classify a change, apply the promotion bar, dispatch it to its lane; tend the rulebook (`verbs/route.md`) |
| `verify tend\|judge` | guardian | tend the testing chapters; make the verification call — defect vs flake, verification depth (`verbs/verify/`) |
| `calibrate [intake\|doctrine]` | chiropractor | the improvement loop: drain captured signal into dispatched improvements; the doctrine seam (`verbs/calibrate/`; default `intake`) |
| `docs [<scope>]` | chiropractor | audit and tune the documentation spine — scan → diagnose → adjust (`verbs/docs.md`) |
| `ask <role> [<prompt>]` | the named hat | put a hat on for a discussion — expertise without a procedure (`verbs/ask.md`) |

The fact partition: `check` owns **assembly** facts; document-shape facts are `docs`'s; code
quality is the standalone auditor's. Scripts compute facts; verb prose owns judgment.

## The pack — the members

`clankshop` is the pack's face and carries the four hats (architect, foreman, guardian,
chiropractor — see `roles/`). The remaining members are skills with standalone lives of their
own; the full roster is the **team roster** in `doctrine/README.md`:

- **instruments** — invokable procedures whose operator exercises the judgment: `backlog` (the
  records instrument), `debugger` (the diagnostic instrument), `auditor` (the code-quality
  instrument).
- **pipelines** — the work processes the system supports: `feature` (idea to gate-green code),
  `workstream` (shipping lanes).
- **helpers** — portable plumbing keeping the full independence discipline: `delegate`,
  `mailbox`, `handoff` (plus the optional `/bug` and `/task` capture proxies).

Core members (face + instruments + pipelines) reference each other and the deployed layout
directly — atomic versioning is what makes that safe.

## Assets

| asset | where | is |
|---|---|---|
| doctrine | `doctrine/` | the pack's seed content: `rules/`, `workflows/`, `testing/` chapters; index + registry + roster + door profile (`doctrine/README.md`) |
| runbook | `docs/RUNBOOK.md` | the methodology narrative — the flow of a change, when which hat, the three altitudes, escalation, the improvement loop |
| hats | `roles/` | the expertise layer: architect, foreman, guardian, chiropractor |
| design doctrine | `docs/DESIGN-DOCTRINE.md` | the seed contract and method behind `design` (+ `templates/design/`) |
| doc rubric | `docs/DOC-RUBRIC.md` | the 12-dimension spine rubric behind `docs` (+ `templates/doc-drift.md`) |
| pack manifest | `PACK.md` beside this SKILL.md | the release manifest `install.sh --pack` resolves and preflights |

The manifest is pack-as-skill, `docs/spec/pack-format.md` format 1: `name:` and `version:`
(semver), the `required:` and `optional:` comma-separated member lists, plus the `core:`
extension key (the lint gate's core-member exemption). Installs are recorded in the sidecar
`grimoire.lock`.

The doctrine's declaration blocks carry `doctrine: clankshop` + `doctrine-version:`. Seeding is
copying content through the project's facts, with file-level provenance: whole-file assets land
with a path-qualified `origin:` stamp (`clankshop:workflows/patch`), and RECORDS lands stamped
`built-against:` its doctrine version — enough for a later reconcile pass to compare a deployed
chapter against the current doctrine and judge.
