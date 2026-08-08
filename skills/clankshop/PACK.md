---
name: clankshop
version: 1.0.0
description: "The full development loop as a skill pack: route a change, design at seed altitude, plan and build features gate-green, ship them from long-lived workstreams, delegate work without polluting context, keep sessions resumable, root-cause bugs before patching them, and audit both code quality and doc ergonomics."
required: architect, auditor, backlog, calibrator, chiropractor, debugger, delegate, feature, foreman, guardian, handoff, mailbox, workstream
optional: bug, task
# core: is a grimoire author extension (spec §2 unknown key, ignored by tools) — the
# lint gate's core-member exemption rule; helpers = the members not listed here.
core: clankshop, architect, auditor, backlog, calibrator, chiropractor, debugger, feature, foreman, guardian, workstream
---

# clankshop — the disciplined development loop

The frontmatter above is the pack's **manifest** (spec format 1) — the machine surface
`install.sh` and the lint gate read. The pack's content lives beside this file in
`skills/clankshop/`:

- `SKILL.md` — the pack face: the `setup` / `migrate` / `check` verbs.
- `doctrine/` — the seed content `setup` and `migrate` project, through a project's facts, into
  its `.handbook/`; the doctrine index (`doctrine/README.md`) carries the chapter registry, the
  team roster, and the door profile.
- `docs/RUNBOOK.md` — the universal methodology: how a change flows through a deployed
  installation, when to assume which role, how the system improves itself.

Install from the clone root: `./install.sh --pack clankshop`. Then, in the target project,
`/clankshop setup` (greenfield) or `/clankshop migrate` (brownfield) — both end with the
installation block stamped, the handbook projected, and `check` green.

**One library skill is deliberately not a member:** `skill-builder`, the toolmaker steward for
the skills library itself. It scaffolds and audits the skills doing the deploying — a
maintainer's tool for whoever authors skills, not part of the development loop this pack
composes for a consuming project. It stays outside the manifest by design.
