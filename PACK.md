---
name: clankshop
version: 3.1.1
description: "Independent agent skills with a faceless composition runbook"
required: journal
optional: analyst, auditor, backlog, architect, contractor, inspector, debugger, delegate, checkpoint, mailbox, notepad, scheduler, shopbook, workspace, workstream
---

# clankshop — the faceless skills pack

The frontmatter is the format-1 pack manifest. `clankshop` is a distribution
identity, not a skill: there is no same-named skill directory, and installing
the pack adds no implicit face member.

The pack installs independent skills. It does not seed doctrine, publish project
flows or hooks, write a project front door, initialize records or trackers, or
validate a deployed workshop. A skill that owns durable project state exposes
and owns its own setup procedure.

## Members

`journal` is required because it is the records format and tool-layer authority.
All other members are optional and default-installed:

- Work leads: `architect`, `contractor`, and `inspector`; Inspector reviews documents and completed
  implementations, publishes only accepted passing documents, and owns its project kind setup.
- Project knowledge and follow-up: `journal`, `backlog`, `notepad`, and `analyst`.
- Development operations: `workstream`, `auditor`, `debugger`, and `shopbook`.
- Utilities: `delegate`, `mailbox`, `checkpoint`, `scheduler`, and `workspace`.

Three skills are intentionally outside the pack: `skill-builder` maintains skills libraries,
`agent-council` is a standalone cross-vendor panel, and `google-developer-style` is a standalone
house-style guide. None is part of the project's `clankshop` toolkit.

## Composition seams

- Architect produces the argued specification. Inspector reviews or refines specifications and
  job artifacts without taking ownership; after the caller accepts a passing document review,
  Contractor sequences an approved specification only when a plan is useful and can walk that job.
- Contractor plans and roadmaps are queue sources for Workstream. Workstream owns isolation,
  landing, and the live stream loop; Contractor never ships.
- Journal defines the record contract. Notepad writes notes, Auditor and Debugger write reports,
  and Analyst reads records, reports, Backlog trackers, and git history into cited briefings.
- A workstream owns its `WORKSTREAM.md` save-state. A root session may instead
  use the repository-level checkpoint file; one session never uses both.
- Backlog may suggest `tasks`, `issues`, and `feedback` during explicit setup; the pack
  installs no tracker, script, route, or debrief policy.
- Delegate chooses whether and how to dispatch work and may expose its own optional
  `delegate/hooks/byproducts.md` policy through explicit setup. The pack never fills it.
  Mailbox is transport for a returned artifact, not the dispatch decision.
- Workspace validates the owner-first layout without creating or repairing it. Shopbook owns only
  host procedure discovery and stubs; Scheduler owns only local recurring-run state.
- Records, workspace files, hooks, doctrine, and review kinds remain owned by
  the skill that defines them. Coarse owner-local edge types do not compose across owners merely
  because their names match. Pack installation never projects those files into a project.

Install, inspect, or remove the pack with:

```text
./install.sh --pack clankshop
./install.sh --check --pack clankshop
./install.sh --remove --pack clankshop
```
