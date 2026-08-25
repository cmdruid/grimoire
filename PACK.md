---
name: clankshop
version: 3.0.0
description: "Independent agent skills with a faceless composition runbook"
required: journal
optional: analyst, auditor, backlog, architect, contractor, inspector, debugger, delegate, checkpoint, mailbox, notepad, scheduler, shopbook, workstream
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

- Work leads: `architect`, `contractor`, and `inspector`.
- Project knowledge and follow-up: `journal`, `backlog`, `notepad`, and `analyst`.
- Development operations: `workstream`, `auditor`, `debugger`, and `shopbook`.
- Utilities: `delegate`, `mailbox`, `checkpoint`, and `scheduler`.

`skill-builder` is intentionally outside the pack. It maintains skills
libraries; it is not part of a project's development toolkit.

## Composition seams

- A specification can hand work to a job plan when sequencing is necessary;
  review judges either artifact without owning it.
- A workstream owns its `WORKSTREAM.md` save-state. A root session may instead
  use the repository-level checkpoint file; one session never uses both.
- Delegate chooses whether and how to dispatch work. Mailbox is transport for a
  returned artifact, not the dispatch decision.
- Records, workspace files, hooks, doctrine, and review kinds remain owned by
  the skill that defines them. Pack installation never projects those files
  into a project.

Install, inspect, or remove the pack with:

```text
./install.sh --pack clankshop
./install.sh --check --pack clankshop
./install.sh --remove --pack clankshop
```
