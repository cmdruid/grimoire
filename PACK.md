---
schema: grimoire/pack@1
name: clankshop
description: Independent project-development helper and utility skills.
required:
  - journal
optional:
  - analyst
  - architect
  - auditor
  - backlog
  - checkpoint
  - chiropractor
  - contractor
  - debugger
  - delegate
  - foreman
  - inspector
  - mailbox
  - notepad
  - scheduler
  - workstream
---

# clankshop — the skills pack

The frontmatter is a `grimoire/pack@1` pure-bundle manifest. `clankshop` is a distribution
identity, not a skill, and there is no same-named skill directory.

The pack installs independent skills. It does not seed doctrine, publish project
operations or hooks, write a project front door, initialize records or trackers, or
validate a deployed workshop. A skill that owns durable project state exposes
and owns its own setup procedure.

## Members

`journal` is required because it is the records format and tool-layer authority.
All other members are optional and default-installed:

- Work leads: `architect`, `contractor`, and `inspector`; Inspector reviews documents and completed
  implementations, asks in English to fix in this checkout after a material implementation verdict,
  publishes only accepted passing documents, and owns its project kind setup.
- Project knowledge and follow-up: `journal`, `backlog`, `notepad`, `analyst`, and `chiropractor`.
- Development operations: `workstream`, `auditor`, `debugger`, and `foreman`.
- Utilities: `delegate`, `mailbox`, `checkpoint`, and `scheduler`.

Standalone library skills outside this pack include `skill-builder`, which maintains skills
libraries; `agent-council` is a standalone cross-vendor panel, `developer-writing` is a standalone
developer-writing guide, `code-humanizer` keeps durable product source fit for human ownership
at write time while preserving explicit `mark` / `map` / `walk`, `agent-feedback` is a private
global observation queue, and `gcloud-operator` runs IAP/OS Login operator sessions against
Google Cloud. None is part of the project's `clankshop` toolkit.

## Composition seams

- Architect produces the argued specification. Inspector reviews documents, revises supported
  document findings, and may simplify a spec or plan while offering an English close for
  implementation fixes in this checkout without taking ownership. Contractor turns a
  clear request or accepted document into a proportionate implementation sequence when a plan is
  useful and can walk that job; formal records and gates remain conditional.
- Contractor plans and roadmaps are queue sources for Workstream. Workstream owns one registered
  worktree, configurable landing, and the live stream loop; Contractor never ships.
- Journal defines the record contract. Notepad writes notes, Auditor and Debugger write reports,
  and Analyst reads records, reports, the first-class tracker provider, and git history into cited
  briefings.
- A workstream owns one concise `WORKSTREAM.md` runbook and helper-owned `workstream.tsv` state in
  its registered worktree. The root checkout may instead carry one token-bound `CHECKPOINT.md`;
  one session never uses both lifecycles.
- Foreman compiles verified operation closures into immutable goal records. A root pursuit asks
  Checkpoint to own mutable progress; a stream pursuit reads Workstream's admitted projection. The harness goal
  feature may drive either runbook, but Foreman never writes either runtime surface or expands tool
  permission.
- An opt-in stream launch treats one Foreman goal as one Workstream queue unit: the root coordinator
  proves the record closure reachable, seeds the stream, primes its current unit through
  Workstream's generic helper, then loads that same stream. Normal Workstream use performs no
  Foreman checks.
- Backlog's explicit first setup selects from the packaged `tasks`, `issues`, `failures`,
  project-owned `feedback`, and `routines` queues and defaults to all five; initialized layers
  retain their incumbent population and prompt. Unresolved operational sightings route to
  `failures`, while qualitative project experience routes to `feedback`. Backlog owns the
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
  main session remains the sole writer of its stream worktree and active unit. Delegate and Mailbox
  are optional: if either needed capability is absent, the unit runs inline. Delegate may expose
  its own optional `delegate/hooks/byproducts.md` policy through explicit setup; the pack never
  fills it.
- Foreman curates the cross-owner operation catalog and writes only its own operations, doctrine,
  route, and goal records; each publisher remains able to follow its own operations directly.
  Scheduler owns only local recurring-run state.
- Records, tracker data, skilldata files, hooks, doctrine, and review kinds remain owned by
  the skill that defines them. Coarse owner-local edge types do not compose across owners merely
  because their names match. Pack installation never projects those files into a project.

## Project configuration

This is a human-readable runbook, not a pack lifecycle. Enter it only when the caller supplies a
readable source manifest explicitly, for example: “Read `/path/to/grimoire/PACK.md` and configure
Clankshop for `<project-root>`.” Installation does not cache or execute this section.

### 1. Inspect and propose

Read the target project's instructions, inspect the fixed `.agents/skilldata`, `.records`, and
`.trackers` homes plus `.streams` when present, and inspect installed members plus Git state. Do not
write yet.

Propose one bounded profile that names every selected setup and every destination it may change:

- Core records: Journal.
- Delivery loop: Journal, Backlog's default or selected trackers, Workstream, and optionally
  Delegate. Workstream needs no setup for ordinary use; propose its optional control surface only
  when the project wants committed defaults or hooks.
- Optional customization: Architect, Contractor, Notepad, Analyst, Debugger, or Inspector only when
  the project wants editable versions of their active surfaces.
- Deferred enhancement: Auditor is optional and time-intensive. Never include it in the initial
  delivery-loop sweep; ask separately when the project is ready to calibrate a rubric.

Obtain approval for the profile and every destination before writing project policy. Record the
pre-sweep Git state and refuse an approved destination that already contains unrelated changes.

### 2. Run member-owned setup

Announce a configuration sweep, then invoke only the approved members' public setup procedures in
write-only mode. Each member writes only its declared owner surface; no member sets up a sibling.
Workstream is excluded from this aggregate sweep: its optional setup owns one atomic control-surface
commit and must be requested and run separately. Project-authored surfaces are absent-only and
incumbents remain byte-for-byte. Follow each member's own preflight, migration, and collision
response; report any partial safe writes, correct the refusal, and rerun.

### 3. Apply optional project policy

Backlog's tracker transaction configures only `.trackers`. A first-time attended setup may
separately offer its managed project debrief route, defaulting off; `--debrief` is explicit consent
to the same standalone anchor lifecycle. Include `AGENTS.md` among approved destinations before
accepting that choice. Unattended setup without the flag and initialized reconciliation do not offer
or author the route. Workstream's two hook points live in its own optional `.streams/CONFIG.md`
and remain independently owned and unchanged by this profile.
When Delegate is selected, the project may place this policy in
`.agents/skilldata/delegate/hooks/byproducts.md`:

```markdown
Return each actionable project-owned byproduct with a proposed class (`task`, `issue`, or `feedback`),
an evidence path or other concrete evidence, and why it matters. If an observation's remedy belongs
in a reusable installed skill, return it separately with the affected skill tag for the caller's
home feedback channel. Do not file either directly; the calling workflow owns routing.
```

There is no direct Delegate-to-Backlog writer. Contractor plans remain typed Workstream queue sources,
and the Architect → Inspector → Contractor flow remains invocation-only rather than deployed glue.

### 4. Validate and optionally commit

Rerun every selected setup in write-only mode and require zero writes. Invoke each advertised public
owner check. Compare the complete Git diff over
all approved destinations with the recorded pre-sweep state; setup output is not the final path set.

If the user requested a commit, make one pathspec-scoped commit over the complete approved diff.
Otherwise leave the reviewed changes uncommitted. Report exact created, preserved, refused, and
project-authored paths. Never create a Clankshop-specific skill, marker, receipt, installed runbook copy,
or pack-level configuration file.

Inspect and manage this bundle through Grimoire. The canonical product and format contract is
`.records/specs/2026-08-31-grimoire-symlink-package-manager.md`.
