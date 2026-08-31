---
name: clankshop
version: 4.1.0
description: "Independent agent skills with a faceless composition runbook"
required: journal
optional: analyst, auditor, backlog, architect, chiropractor, contractor, inspector, debugger, delegate, checkpoint, foreman, mailbox, notepad, scheduler, workspace, workstream
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
- Project knowledge and follow-up: `journal`, `backlog`, `notepad`, `analyst`, and `chiropractor`.
- Development operations: `workstream`, `auditor`, `debugger`, and `foreman`.
- Utilities: `delegate`, `mailbox`, `checkpoint`, `scheduler`, and `workspace`.

Four skills are intentionally outside the pack: `skill-builder` maintains skills libraries,
`agent-council` is a standalone cross-vendor panel, `developer-writing` is a standalone
developer-writing guide, and `code-humanizer` keeps durable product source fit for human ownership
at write time while preserving explicit `mark` / `map` / `walk`. None is part of the project's
`clankshop` toolkit.

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
  first-class `.trackers` layer, its `tracker@2` provider, queue tables, lifecycle history, and
  editable debrief-routing prompt. The pack itself installs no tracker, script, route, or debrief
  policy. Foreman consumes
  tracker pages to develop operations, while Analyst reads the same provider without mutation.
- Chiropractor audits and confirmation-gates documentation-spine topology: task routes from
  `AGENTS.md`, compatibility with `CLAUDE.md`, and links to authoritative procedures or runnable
  entry points. It owns no setup and never repairs scripts or workflows; prose authoring, artifact
  review, code quality, and operation curation remain with their respective skills.
- Workstream may submit a bounded queue unit to Delegate, which chooses whether and how to dispatch
  it and resumes Workstream from the returned result. When file-work needs out-of-band transport,
  Delegate may use Mailbox; Mailbox transports the artifact but never chooses the route. Workstream's
  main session remains the sole writer of its held target. Delegate and Mailbox are optional: if
  either needed capability is absent, the unit runs inline. Delegate may expose its own optional
  `delegate/hooks/byproducts.md` policy through explicit setup; the pack never fills it.
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

Read the target project's instructions, inspect the fixed `.spaces`, `.records`, and `.trackers`
homes, and inspect installed members plus Git state. Do not write yet.

Propose one bounded profile that names every selected setup and every destination it may change:

- Core records: Journal.
- Delivery loop: Journal, Backlog's default or selected trackers, Workstream, and optionally Delegate.
- Optional customization: Architect, Contractor, Notepad, Analyst, Debugger, or Inspector only when
  the project wants editable versions of their active surfaces.
- Deferred enhancement: Auditor is optional and time-intensive. Never include it in the initial
  delivery-loop sweep; ask separately when the project is ready to calibrate a rubric.

Obtain approval for the profile and every destination before writing project policy. Record the
pre-sweep Git state and refuse an approved destination that already contains unrelated changes.

### 2. Run member-owned setup

Announce a configuration sweep, then invoke only the approved members' public setup procedures in
write-only mode. Each member writes only its declared owner surface; no member commits or sets up a
sibling. Project-authored surfaces are absent-only and incumbents remain byte-for-byte. Follow each
member's own preflight, migration, and collision response; report any partial safe writes, correct the
refusal, and rerun.

### 3. Apply optional project policy

Backlog setup configures only `.trackers`; it does not author a project front door or Workstream
hooks. Workstream's hook points remain independently owned and unchanged by this profile.
When Delegate is selected, the project may place this policy in
`.spaces/delegate/hooks/byproducts.md`:

```markdown
Return each actionable byproduct with a proposed class (`task`, `issue`, or `feedback`), an evidence
path or other concrete evidence, and why it matters. Do not file it directly; the calling workflow
owns routing.
```

There is no direct Delegate-to-Backlog writer. Contractor plans remain typed Workstream queue sources,
and the Architect → Inspector → Contractor flow remains invocation-only rather than deployed glue.

### 4. Validate and optionally commit

Rerun every selected setup in write-only mode and require zero writes. Invoke each advertised public
owner check, then `/workspace check` against the resolved roots. Compare the complete Git diff over
all approved destinations with the recorded pre-sweep state; setup output is not the final path set.

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
