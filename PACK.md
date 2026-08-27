---
name: clankshop
version: 4.0.0
description: "Independent agent skills with a faceless composition runbook"
required: journal
optional: analyst, auditor, backlog, architect, contractor, inspector, debugger, delegate, checkpoint, foreman, mailbox, notepad, scheduler, workspace, workstream
---

# clankshop — the faceless skills pack

The frontmatter is the format-1 pack manifest. `clankshop` is a distribution
identity, not a skill: there is no same-named skill directory, and installing
the pack adds no implicit face member.

The pack installs independent skills. It does not seed doctrine, publish project
operations or hooks, write a project front door, initialize records or trackers, or
validate a deployed workshop. A skill that owns durable project state exposes
and owns its own setup procedure.

## Members

`journal` is required because it is the records format and tool-layer authority.
All other members are optional and default-installed:

- Work leads: `architect`, `contractor`, and `inspector`; Inspector reviews documents and completed
  implementations, publishes only accepted passing documents, and owns its project kind setup.
- Project knowledge and follow-up: `journal`, `backlog`, `notepad`, and `analyst`.
- Development operations: `workstream`, `auditor`, `debugger`, and `foreman`.
- Utilities: `delegate`, `mailbox`, `checkpoint`, `scheduler`, and `workspace`.

Three skills are intentionally outside the pack: `skill-builder` maintains skills libraries,
`agent-council` is a standalone cross-vendor panel, and `developer-writing` is a standalone
developer-writing guide. None is part of the project's `clankshop` toolkit.

## Composition seams

- Architect produces the argued specification. Inspector reviews documents, revises supported
  findings, and may simplify a spec or plan without taking ownership; after the caller accepts a
  passing document review, Contractor sequences an approved specification only when a plan is
  useful and can walk that job.
- Contractor plans and roadmaps are queue sources for Workstream. Workstream owns isolation,
  landing, and the live stream loop; Contractor never ships.
- Journal defines the record contract. Notepad writes notes, Auditor and Debugger write reports,
  and Analyst reads records, reports, the first-class tracker provider, and git history into cited
  briefings.
- A workstream owns its `WORKSTREAM.md` save-state. The root checkout may instead carry one
  token-bound `CHECKPOINT.md`; one session never uses both lifecycles.
- Foreman compiles verified operation closures into immutable goal records. A root pursuit asks
  Checkpoint to own mutable progress; a stream pursuit reads Workstream's hand-off. The harness goal
  feature may drive either runbook, but Foreman never writes either runtime surface or expands tool
  permission.
- An opt-in stream launch treats one Foreman goal as one Workstream queue unit: the root coordinator
  proves the record closure reachable, seeds the stream, primes its existing hand-off through
  Workstream's generic helper, then loads that same stream. Normal Workstream use performs no
  Foreman checks.
- Backlog's explicit setup defaults to `tasks`, `issues`, `feedback`, and `routines`; it owns the
  first-class `<agent-trackers>` layer, its `tracker@1` provider, and a universally visible debrief
  cadence. The pack itself installs no tracker, script, route, or debrief policy. Foreman consumes
  tracker pages to develop operations, while Analyst reads the same provider without mutation.
- Delegate chooses whether and how to dispatch work and may expose its own optional
  `delegate/hooks/byproducts.md` policy through explicit setup. The pack never fills it.
  Mailbox is transport for a returned artifact, not the dispatch decision.
- Workspace validates the owner-first layout without creating or repairing it. Foreman curates the
  cross-owner operation catalog and writes only its own operations, doctrine, route, and goal
  records; each publisher remains able to follow its own operations directly. Scheduler owns only
  local recurring-run state.
- Records, tracker data, workspace files, hooks, doctrine, and review kinds remain owned by
  the skill that defines them. Coarse owner-local edge types do not compose across owners merely
  because their names match. Pack installation never projects those files into a project.

## Project configuration

This is a human-readable runbook, not a pack lifecycle. Enter it only when the caller supplies a
readable source manifest explicitly, for example: “Read `/path/to/grimoire/PACK.md` and configure
Clankshop for `<project-root>`.” Installation does not cache or execute this section.

### 1. Inspect and propose

Read the target project's instructions. Resolve its agent workspace (default `.spaces`), records
home (default `.records`), and tracker home (default `.trackers`) without writing declarations for
any default. Inspect installed members, all three homes, front-door route blocks, recognized legacy
locations, and Git state. Do not write yet.

Propose one bounded profile that names every selected setup and every destination it may change:

- Core records: Journal.
- Delivery loop: Journal, Backlog's default or selected trackers, Workstream, and optionally Delegate.
- Optional customization: Architect, Contractor, Notepad, Analyst, Debugger, or Inspector only when
  the project wants editable versions of their active surfaces.
- Deferred enhancement: Auditor is optional and time-intensive. Never include it in the initial
  delivery-loop sweep; ask separately when the project is ready to calibrate a rubric.

Obtain approval before writing project policy. Record the pre-sweep Git state and the complete set of
approved destinations. Refuse a destination that already contains unrelated changes.

### 2. Run member-owned setup

Announce a configuration sweep, then invoke only the approved member setup procedures in their
write-only mode. Each member writes only its declared owner surface; Journal's records standup and
Backlog's delimited route are the named exceptions. No member commits during the sweep, recursively
sets up another member, writes a schema, or interprets a sibling namespace.

Setup deploys only actively consumed project surfaces. Project-editable incumbents win byte-for-byte;
package-managed tools may refresh only where their owner already defines refresh semantics. A
recognized legacy file refuses and names that owner's `migrate` command. Report partial safe writes,
correct the refusal, and rerun; never guess through a collision.

### 3. Apply optional project policy

Backlog setup registers its own universal cadence; do not duplicate it inside Workstream hooks.
Workstream's empty hook points remain independent and are available for unrelated host policy.
When Delegate is selected, the project may place this policy in
`<agent-workspace>/delegate/hooks/byproducts.md`:

```markdown
Return each actionable byproduct with a proposed class (`task`, `issue`, or `feedback`), an evidence
path or other concrete evidence, and why it matters. Do not file it directly; the calling workflow
owns routing.
```

There is no direct Delegate-to-Backlog writer. Contractor plans remain typed Workstream queue sources,
and the Architect → Inspector → Contractor flow remains invocation-only rather than deployed glue.

### 4. Validate and optionally commit

Rerun every selected setup in write-only mode and require zero writes. Run each advertised owner
check, then Workspace's package-local `scripts/workspace-check.sh` against the resolved roots. Compare
the complete Git diff, limited to the approved destinations, with the recorded pre-sweep state. Do
not parse heterogeneous setup output to infer the final path set.

If the user requested a commit, make one pathspec-scoped commit over the complete approved diff.
Otherwise leave the reviewed changes uncommitted. Report exact created, preserved, refused, and
project-authored paths. Never create a Clankshop skill face, marker, receipt, installed runbook copy,
or pack-level configuration file.

Install, inspect, or remove the pack with:

```text
./install.sh --pack clankshop
./install.sh --check --pack clankshop
./install.sh --remove --pack clankshop
```
