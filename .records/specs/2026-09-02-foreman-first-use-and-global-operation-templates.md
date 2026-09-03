---
doctype: specs
status: published
schema: architect/spec@1
tags: [foreman, goals, publication, templates, skilldata]
---

# Foreman first-use goals and global operation templates — Spec

Related: → `specs/2026-08-26-foreman-autonomous-workflow-control-plane.md`;
→ `specs/2026-09-02-skilldata-hard-cut-and-workspace-retirement.md`;
→ `adr/2026-09-02-reserve-skilldata-for-project-and-global-skill-owned-data.md`

## Problem

Foreman's durable-goal path assumes that its source operation has already been proven reusable. A
goal may compile only from an active operation whose verification evidence is current, while a new
operation begins as an unverified draft and activation is a separate accepted transition. That is a
sound gate for an established recurring procedure, but it makes a first-ever long-running task pay
the complete publication lifecycle before Foreman may pursue it.

The lifecycle is also circular for an operation whose `Verification` section checks the procedure's
final outputs. Those outputs do not exist until the procedure runs, but the procedure cannot run as
a goal until that same evidence has been recorded and the operation activated. The current sequence
therefore asks the human to accept an operation draft, verification evidence, activation, and the
compiled goal in separate turns even when one successful run is what would produce the missing
evidence.

Two concepts have been conflated:

- **preflight validation** establishes that proposed instructions are structurally valid, bounded,
  source-current, and safe to attempt under ordinary harness permissions;
- **post-run verification** establishes that following those instructions produced the declared
  result and supplies evidence for treating the operation as reusable.

Explicit inspection remains necessary because generated operation prose can turn conversation,
logs, repository text, or tool output into durable project instruction. Removing acceptance would
allow an agent to canonize its own inference. The problem is the number and ordering of gates, not
the existence of the instruction-provenance boundary.

The scripts currently validate custody, shape, digests, and destination state, but human acceptance
is behavioral protocol. A caller can pass different bytes from those it previewed. The write
boundary cannot prove that a human acted, but it can bind an accepted bundle to the exact bytes that
were previewed and refuse drift.

Foreman also makes each first operation begin from one package-only blank scaffold. Users who repeat
the same broad procedure across repositories cannot keep generic authoring templates in a stable
user-owned location: installing them inside the skill risks package replacement and source-tree
mutation, while copying complete operations between projects prematurely treats one project's
commands and assumptions as another project's executable instruction. A reusable template needs to
remain inert global input until Foreman turns it into a project-specific, fully reviewed operation.

## Goal

Add a first-use Foreman lane in which one explicit acceptance covers the exact provisional operation
and immutable goal previews, after which Foreman publishes both and launches pursuit. The operation
remains a normal `foreman/operation@1` draft until a successful run supplies evidence; promotion then
binds that evidence and activates the operation in one accepted atomic rewrite. When authoring an
operation, automatically suggest relevant generic templates from
`~/.agents/skilldata/foreman/templates/operations/`, but require an explicit template selection and
materialize ordinary project operation bytes before any preview, publication, or execution.

Preserve the established lane for proven reusable operations and every existing safety invariant:
immutable goal records, exact source digests, drift pauses, publisher custody, ordinary tool
permissions, non-delegable decision classes, and exactly one external runtime-state owner. Foreman
setup remains optional and is never part of the first-use critical path.

This feature does not:

- infer acceptance or remove the complete-content preview;
- add a provisional lifecycle status or a new goal/operation schema;
- allow multiple new provisional operations in one closure;
- weaken migration, import, debrief, doctrine-promotion, or foreign-publisher acceptance rules;
- make Foreman a runtime, permission, transaction, checkpoint, or workstream owner;
- auto-promote an operation merely because its goal stopped; or
- make preview-digest binding a library-wide acceptance-token system;
- execute, goal-reference, or mutate a global template; or
- add a global template setup, synchronization, migration, registry, or package-distribution system.

## Approach

Keep two explicit lanes:

1. **Proven operation:** `/foreman goal <owner/stem> <objective>` retains the current requirement
   that the complete closure is active, source-current, and currently verified.
2. **First use:** `/foreman start [--as <stem>] <objective>` curates one Foreman-owned operation
   candidate, renders a goal from that exact candidate, previews both artifacts as one bundle, and
   applies them after one explicit acceptance. An explicit `--as` stem wins; otherwise Foreman
   derives a safe stem from the objective and asks only when identity choice or an incumbent
   conflict would change the artifact.

The first-use root is provisional because it has passed preflight validation but not post-run
verification. It is written with `status: draft`, no `verified-against`, and no new schema field. A
provisional workflow may reference existing operations only when every referenced child is already
goal-eligible; the lane never smuggles a second unproven candidate into the closure.

Before create or start drafts bytes, Foreman queries the optional global template catalog from
the objective and intended use. It presents at most three ranked metadata-only suggestions. A
template is read only after the user selects it; silence or rejection uses the bundled operation
scaffold. Selection is part of the ordinary curation exchange, not another publication gate. The
selected template supplies an authoring shape, never trusted instruction: Foreman resolves every
slot against the current project, removes template-only metadata, validates the resulting ordinary
operation, and includes every resulting byte in the existing complete-content preview.

The accepted goal remains a `foreman/goal@1` record. After its ordinary source rows, its Sources
section identifies the provisional root with the exact marker defined below; proven goals omit the
marker. The compiled runbook remains self-contained. Resume accepts that exact source while it is
draft or after it has been promoted, but any instruction or imported-source drift pauses for
attended review.

The apply is one acceptance, not a claim of cross-file atomicity. Foreman preflights the complete
write set, writes or preserves the operation draft first, then publishes or preserves the goal.
Failure after the first write leaves a harmless accepted draft; a rerun converges without a receipt,
manifest, rollback file, or substitute runtime state.

After the goal's compiled verification and stop conditions succeed, goal closure may offer to
promote its provisional root. One preview names the evidence, operation digest, and `active`
transition. One acceptance atomically binds the evidence and changes the operation status. Declining
promotion leaves the draft intact and does not prevent ordinary goal cleanup or archival.

Rejected alternatives:

- **Keep the lifecycle and add only a convenience wrapper.** This reduces command typing but leaves
  the pre-run verification cycle and repeated acceptance stops intact.
- **Remove the operation preview or infer acceptance from goal approval.** This erases the boundary
  that prevents generated evidence from becoming durable project instruction without inspection.
- **Create a `provisional` operation status.** `draft` already expresses accepted but unproven
  instruction; a fourth state would widen every parser, inventory, migration, and lifecycle surface
  without adding information.
- **Publish only an inline goal and create no operation.** This is simpler for one run but discards
  the reusable candidate and makes later promotion reconstruct instructions from execution history.
- **Let Foreman own mutable progress or a multi-file transaction ledger.** Both duplicate existing
  owners and turn a publication simplification into a new runtime or recovery protocol.
- **Treat global templates as active operations.** This would let cross-project prose bypass project
  review, identity, source-currentness, and verification. Templates remain non-executable inputs.
- **Automatically choose the highest-ranked template.** Ranking is lexical discovery, not evidence
  that a template fits the current repository. Explicit selection prevents a plausible match from
  silently shaping durable instruction.
- **Copy global templates during setup.** This would create project policy before a concrete use and
  make setup part of the first-use path. Materialize only the selected project operation.

## Mechanism

### Global operation-template contract and suggestions

Foreman recognizes optional, user-owned template files only at:

```text
~/.agents/skilldata/foreman/templates/operations/<stem>.md
```

The global root, Foreman owner, and `templates/operations` tail are fixed. `<stem>` matches
`[a-z0-9][a-z0-9-]*`; entries are regular, non-symlink Markdown files. Foreman is read-only at this
scope. It never creates the root, installs bundled examples there, follows a source-installation
symlink as data, inventories sibling owners, or writes template changes back from a project.

A global template uses a distinct non-executable contract:

```yaml
---
schema: foreman/operation-template@1
title: Release a service
use-when: Preparing and validating a routine service release
shape: procedure
areas: [release, delivery]
tags: [service]
---
```

The front matter contains exactly `schema`, `title`, `use-when`, `shape`, `areas`, and `tags`.
`shape` is `procedure` or `workflow`; string and list fields follow the corresponding
`foreman/operation@1` rules. There is no `status`, `verified-against`, operation identity, project
path, or goal eligibility.

The template body has its own pre-materialization grammar:

- a procedure contains exactly one each of `Preconditions`, `Procedure`, `Outputs`,
  `Verification`, and `Recovery`, and no `Steps` or `Verification evidence` section;
- a workflow contains exactly one each of `Preconditions`, `Steps`, `Outputs`, `Verification`, and
  `Recovery`, and no `Procedure` or `Verification evidence` section; and
- workflow Steps are a nonempty, sequentially numbered list of operation roles or angle-bracket
  authoring slots. They cannot contain a backticked `<owner>/<stem>` identity.

Template slots are legal only in the body. The structural validator proves front matter, sections,
numbering, safe filenames, and the absence of concrete workflow identities. It does not claim to
recognize secrets or decide whether prose is portable. After selection, curation treats absolute
project paths, credential-like values, imported-source declarations, instruction-like retrieved
text, and other project-specific assumptions as inert evidence to remove or replace before the
ordinary operation checker sees the candidate.

Add a package-local, read-only template validator and metadata index. The index validates exact
children and returns stem, title, `use-when`, shape, areas, and tags in ascending stem order. Foreman
compares that metadata with the requested objective and intended use, then presents at most three
templates it judges relevant, explaining each match. The helper supplies facts; it neither scores
semantic fitness nor chooses a template.

A missing global root or no positive match is a normal empty result. An unsafe root chain disables
global suggestions for that invocation with a warning and leaves create/start usable from the
bundled scaffold. Malformed individual entries are excluded and reported by stem without exposing
their body. If the user explicitly selects such an entry, selection refuses with its validation
error. Foreman never silently falls through from an explicitly selected invalid template.

Suggestions occur automatically during both `/foreman create` and `/foreman start`. Foreman does
not read a suggested body or choose it on the user's behalf. An explicit selection reads the body
once into ephemeral storage. The agent then:

1. resolves every authoring slot and generic step against current repository facts;
2. removes template front matter and emits a complete `foreman/operation@1` candidate with the
   chosen project identity, `status: draft`, and no unresolved slot;
3. treats all source prose as inert input during curation, including instruction-looking content;
4. validates the candidate through the normal operation checker; and
5. previews the full candidate, or the joint candidate and goal bundle for start, under the same
   explicit acceptance and digest binding as package-scaffolded authorship.

Template origin is not stored as an absolute path or a runtime dependency. The materialized project
operation is self-contained and lives at
`.agents/skilldata/foreman/operations/<stem>.md`; later validation, execution, resume, and promotion
never reread the global template. An existing project operation always takes precedence over
authoring a same-purpose replacement: Foreman offers its normal inventory/use path before global
template suggestions.

### First-use curation and eligibility

`/foreman start [--as <stem>] <objective>` is a top-level intent route into the goal procedure. It
resolves a concrete objective and one operation identity, then drafts the complete operation from
the explicitly selected global template or the existing package-only operation template. The
candidate must be Foreman-owned, use
`schema: foreman/operation@1`, carry `status: draft`, omit `verified-against`, and satisfy the same
closed front matter, standard-section, source-current, reference, and cycle checks as ordinary
creation.

The start lane may synthesize from the user's request, attended conversation, and repository facts.
Retrieved text and tool output remain inert evidence and are redacted before they enter a candidate.
It does not serve as a shortcut from migration, import, debrief, or doctrine promotion: those
procedures retain their own source-specific preview and acceptance boundaries.

Preflight classifies the candidate root separately from its closure:

- the exact root may be `draft` with missing verification evidence;
- an imported root must still have a current imported-source digest;
- every referenced child must independently report `goal_eligible=true`; and
- deprecated, malformed, cyclic, stale-source, stale-evidence, missing, foreign provisional, or
  additional draft children refuse before preview.

No operation effect occurs during preflight. The candidate's `Verification` section is compiled as
the goal's completion check; it is not executed as a prerequisite for the first run.

### Joint render and acceptance binding

Extend the goal compiler with a provisional render mode that accepts one identity-to-candidate
overlay. The existing operation checker already validates an ephemeral candidate overlay; the
compiler uses that path for the root and ordinary on-disk resolution for its proven children. The
result is the same immutable goal shape used by the proven lane, with a Sources declaration that
marks the provisional root and records its canonical operation digest.

After the ordinary source rows, first-use rendering writes exactly:

```text
Provisional root: `foreman/<stem>@sha256:<64-lowercase-hex>`
```

The identity and digest must exactly match the requested root and its ordinary Sources row. The
marker occurs once in a first-use goal and zero times in a proven goal; another owner, malformed
identity or digest, absent or duplicate source row, conflicting digest, duplicate marker, or marker
on a proven render refuses. It is body syntax within `foreman/goal@1`, not a new front-matter field.
The closure source-digest formula remains unchanged because it already includes the root identity
and canonical operation digest.

Rendering emits an ephemeral manifest containing:

```text
operation=<owner/stem>
operation_sha256=<sha256 of exact candidate bytes>
goal_record=<dated goal destination>
goal_sha256=<sha256 of exact draft goal bytes>
```

The bundle preview digest is the SHA-256 of those exact newline-terminated manifest bytes. Foreman
shows the two destinations, both complete artifacts, and the bundle digest. One explicit acceptance
authorizes creation or preservation of those exact artifacts and submission of the published goal
to the available harness goal feature. It does not authorize a commit, destructive action,
credential use, policy change, verification waiver, permission expansion, or any tool action that
the harness would otherwise gate.

The script boundary accepts `--expected-preview-digest` and recomputes the manifest after every
input and destination is resolved. A mismatch refuses before mutation. This is a preview/write drift
guard, not proof that a human performed the acceptance.

The rendered `goal_record` path is an input to apply, not a hint to recompute from the wall clock.
Publication must create or preserve that exact path. When the adjacent records tool is executable,
Foreman uses its ordinary `new`/`touch` path and requires the returned path to equal the rendered
destination; file mode uses the same destination directly. A destination conflict discovered before
publication refuses the complete apply before the operation write.

### Convergent apply

Use one stable package entrypoint for the variable first-use publication command. Before its first
write it:

1. revalidates the candidate, provisional-root rules, proven child closure, imported sources, exact
   goal body, and expected bundle digest;
2. resolves the operation and goal destinations and rechecks every existing parent;
3. requires each destination to be absent or the exact expected projection; and
4. refuses all conflicts, symlinks, incompatible entries, destination changes, and source drift.

Apply writes the operation first through the existing incumbent-preserving Foreman writer, then
publishes the goal through the existing opportunistic records path. An exact operation incumbent is
preserved. An exact already-published goal projection is also a successful preservation, including
the normalized `published` status and any representation written by the adjacent records tool. A
non-identical incumbent refuses.

If a race or injected fault occurs between writes, the accepted draft operation may remain and the
goal is absent. Rerunning the same accepted bundle preserves that draft and finishes publication.
If publication completed before the caller lost the result, rerun recognizes the exact published
goal and returns success without duplicating history. No compensating deletion is attempted.

The harness goal is invoked only after publication is confirmed. If no goal feature exists, Foreman
returns the same ready-to-submit objective used by the proven lane without claiming pursuit began.

### Resume and runtime state

The goal record, not current operation lifecycle status, determines whether a root was accepted as
provisional. Resume parses and validates the exact Sources marker. Without it, every source remains
subject to ordinary goal eligibility. With it, only the marked Foreman-owned root may be `draft` or
`active`; its canonical instruction digest must match the marker and ordinary source row, and its
imported sources must remain current. Every other source remains subject to ordinary goal
eligibility. A malformed marker, status outside `draft|active`, digest mismatch, source change, or
ineligible child pauses before action.

Checkpoint and Workstream remain optional, mutually exclusive runtime-state owners. Start does not
require an empty initial checkpoint before the first operation step. A root session that explicitly
enrolls Checkpoint saves after the first human-visible work unit, before a healthy reset, or on a
context-pressure warning; a stream continues through its existing save/load lifecycle. Foreman
returns completed work, evidence, current step, and one exact next action at each boundary as it does
today. The optional Workstream launch path is otherwise unchanged.

### Post-run promotion

When a provisional goal reaches its objective, compiled Verification checks, and stop conditions,
Foreman may offer promotion only for the exact Foreman-owned provisional root recorded by the goal.
It rechecks that the operation is still a draft, its canonical digest matches, imported sources are
current, referenced children remain goal-eligible, and the runtime evidence demonstrates the
operation's own Verification section.

Foreman renders one compact evidence fragment and previews:

- the operation identity and canonical digest;
- the exact evidence that will replace its Verification evidence section; and
- the status transition from `draft` to `active`.

After one explicit acceptance, a new bounded writer mode rechecks the destination byte digest and
all eligibility facts, inserts `verified-against: <canonical-digest>`, replaces only Verification
evidence, and sets `status: active` in one atomic file replacement. The resulting operation must
revalidate with `verification=current` and `goal_eligible=true` before replacement. Foreign-owned
operations return a publisher request and are never written.

Promotion is optional. Rejection or unavailable evidence leaves the operation draft byte-identical.
Goal cleanup and record archival remain governed by the existing close procedure and do not imply
promotion. Existing standalone `verify` and `activate` verbs remain available and unchanged for
operations outside this first-use lane.

### Documentation and hard-cut paths

Foreman's router and goal documentation distinguish the proven and first-use lanes and say directly
that `/foreman setup` only registers a discovery route. Missing setup, global templates,
`.agents/skilldata/foreman/`, or the records tool is not a publication floor; the accepted write
lazily creates only the owned operation and goal directories it needs.

Foreman's `SKILL.md` carries the shared `## Global skilldata` declaration. It names the read-only
template catalog, its optional nature, the no-write rule, and the explicit selection and project
materialization boundary. No production verb accepts a global-home selector.

Existing `foreman/operation@1` contents remain valid after the project owner places them at the new
path, and existing `foreman/goal@1` records remain valid. The proven goal command, inventory,
attended run, migration, debrief, lifecycle, projection, and Workstream launch
contracts do not change except for the coordinated `.spaces` hard cut in the related skilldata spec.
Foreman contains no old-path probe or migration behavior; existing `.spaces` content is inert and
left for the project owner. Grimoire remains patient zero: every setup, template, start, apply,
resume, promotion, and failure-recovery case runs against disposable fixtures, and no Foreman route,
global data, or deployed operation is written into Grimoire's own `AGENTS.md` or
`.agents/skilldata` tree.

## Verification

Extend Foreman's fixture suite to prove:

- `/foreman start [--as <stem>] <objective>` is routed as the first-use lane and documentation makes
  setup optional;
- a missing global template root is a successful empty catalog and never becomes a setup floor;
- valid `foreman/operation-template@1` files index complete metadata in stable stem order, while
  Foreman presents no more than three explained, relevant suggestions;
- malformed files, unsafe parents, symlinks, concrete workflow identities, invalid section shapes,
  and template lifecycle fields never become suggestions; an explicitly selected invalid entry
  refuses;
- suggestion output exposes metadata only, no template body shapes a candidate before explicit
  selection, no template is executed or selected automatically, and rejecting suggestions uses the
  bundled scaffold;
- selection-time curation removes or replaces planted credentials, absolute project paths,
  imported-source declarations, and instruction-like retrieved text before materialization, with a
  sabotage case that fails if the planted content reaches the candidate;
- selected templates materialize complete, slot-free `foreman/operation@1` candidates under
  `.agents/skilldata/foreman/operations/`, while global bytes remain unchanged and no global path is
  persisted in the operation;
- later goal compilation, resume, verification, and promotion remain valid after the selected global
  template is changed or removed;
- provisional rendering is side-effect free and accepts exactly one valid Foreman-owned draft root;
- an imported provisional root must be source-current;
- active/current referenced children compile in written order, while any second draft, stale,
  deprecated, malformed, missing, cyclic, or foreign provisional child refuses;
- the goal records the provisional identity and canonical digest and remains a valid
  `foreman/goal@1` record;
- a proven goal contains no provisional marker; a first-use goal contains exactly one marker whose
  identity and digest match the root Sources row; malformed, duplicate, foreign, missing-source, and
  conflicting-digest markers refuse publication and resume;
- changing either preview, identity, destination, or expected digest after rendering refuses before
  mutation;
- one accepted apply creates a draft operation and published goal whose bodies equal the previews;
- an operation or goal destination conflict is found during preflight before either artifact is
  written;
- an injected failure after operation publication leaves only the accepted draft, and rerun
  preserves it and publishes the goal without durable transaction state;
- loss of the result after goal publication converges by preserving the exact published goal and
  does not append duplicate lifecycle history;
- resume accepts the unchanged provisional root, accepts its later digest-stable promotion, and
  pauses on instruction, child, or imported-source drift;
- initial root launch creates no checkpoint as a publication side effect, while later state-owner
  boundaries still return an exact save action;
- post-run promotion refuses incomplete verification, stale digests, source drift, ineligible
  children, and foreign ownership;
- successful promotion performs one atomic replacement whose evidence is digest-bound and whose
  result is active, current, and goal-eligible;
- disabling the expected-preview-digest guard makes a planted preview mutation land and therefore
  fails its red-proof test;
- disabling the promotion recheck or atomic combined rewrite makes the promotion sabotage fixture
  fail; and
- the existing proven-operation goal, standalone verify/activate, migration/debrief acceptance,
  runtime custody, and Workstream launch tests remain green.

Run `skills/foreman/scripts/tests/run.sh`, the affected Checkpoint and Workstream suites, the pack
installation tests, and `skills/skill-builder/scripts/skills-lint.sh .`. All project-write scenarios
use disposable fixtures. The final gate reports no new lint failure and leaves Grimoire's real
`AGENTS.md`, `.agents/skilldata`, and the real user-global Foreman skilldata untouched.
