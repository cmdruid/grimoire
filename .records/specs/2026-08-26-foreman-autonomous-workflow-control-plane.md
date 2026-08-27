---
doctype: specs
status: published
schema: architect/spec@1
tags: [foreman, workflow, autonomy, learning]
---

# Foreman project operations and goal runbooks — Spec

Related: `→ specs/2026-08-25-agent-workspace-naming.md`

## Problem

An agent entering an existing project starts with little durable knowledge of how that project is
changed, verified, and operated. Human guidance bridges the gap during short sessions, but that
guidance is repeatedly lost unless the project accumulates explicit procedures, workflows,
front-door pointers, and recovery guidance.

Projects also lack a deliberate learning path. A human may demonstrate a successful manual
operation while explaining decisions and recovering from surprises, but copying the transcript into
live instructions canonizes exploratory steps, secrets, temporary workarounds, and untrusted output.
Reconstructing only the final repository state loses ordering constraints, failure modes, and
rationale.

Brownfield projects often already contain procedures and runbooks in arbitrary files and directory
trees. They may be useful but have no shared schema, stable identity, lifecycle, verification
evidence, or composition model. Requiring users to normalize each one manually before Foreman can
help would defeat the point of bringing Foreman into an established project.

The library has useful pieces but no focused curator over project operations:

- `shopbook` finds or creates one project procedure but does not compose procedures;
- `checkpoint` preserves one root session's runtime state;
- `workstream` preserves and drives one long-lived development stream;
- the harness goal feature can sustain pursuit but needs a strong, project-grounded runbook.

Foreman must not duplicate those runtime owners. Its job is to improve the instructions given to the
agent, not to become a permission system, scheduler, or second orchestration engine.

## Goal

Reintroduce `foreman` as the optional curator and compiler for project operations. It discovers and
curates operations, learns candidates from completed sessions, decomposes and composes reusable
workflows, promotes bounded discovery routes, and compiles an operation plus a concrete objective
into a goal-ready runbook.

Foreman replaces `shopbook`; there is no second skill with overlapping discovery or creation
behavior. This specification establishes `operations` as the current direct-Markdown workspace kind
and supersedes the prior closed-kind list for that slot.

Foreman v1 has four responsibilities:

1. define and discover the shared operation format;
2. create, import, migrate, debrief, verify, and curate operations and doctrine;
3. compose operations into directly followable workflows without duplicating their instructions;
4. compile and launch immutable goal runbooks while leaving mutable runtime state to Checkpoint or
   Workstream.

A project with only Foreman installed must gain value. An operation publisher and its files remain
directly usable without Foreman. Foreman never rewrites another owner's namespace, never becomes a
prerequisite for Workstream, and never expands permissions granted by the user or harness.

## Approach

Foreman is a knowledge tool, not a runtime kernel. Its user-facing surface is:

1. **Inventory** — discover native project entry points and conforming operations; report missing
   metadata, invalid references, duplication, and drift without loading every body.
2. **Create/import** — author a Foreman-owned operation or describe an existing native source by
   reference. Import never silently copies or claims the source.
3. **Migrate** — inspect an explicitly named brownfield file or directory with no schema assumption,
   preview zero or more canonical operation candidates, and ingest only the candidates the user
   accepts. Migration changes canonical custody but never silently deletes or rewrites the source.
4. **Debrief** — inspect the current or explicitly supplied session, build an ephemeral redacted
   event ledger, and curate zero or more operation and doctrine candidates with the user. No
   observation command or pre-session setup is required.
5. **Verify** — follow an operation's declared verification and bind compact evidence to its current
   instruction and source digest.
6. **Compose** — extract reusable procedures from duplicated behavior and assemble workflows from
   operation references.
7. **Project** — maintain only Foreman's bounded, pointer-heavy front-door block. Every other
   publisher owns its own discovery route.
8. **Run** — `/foreman run <operation>` follows one operation in the current attended session using
   ordinary harness tools and permissions.
9. **Goal** — `/foreman goal <operation> <objective>` previews and publishes an immutable goal
   runbook, then invokes the harness goal feature. `status`, `resume`, and `close` inspect or advance
   that runbook through the current runtime-state owner.

Foreman never grants filesystem, network, credential, version-control, external-write, or
destructive permission. Normal harness permission checks continue to apply. Goal auto-approval
covers only decision classes explicitly delegated in the accepted runbook; destructive actions,
credential selection, policy changes, verification waivers, and permission expansion always return
to the user.

Foreman v1 composes only conforming operation files. Scripts, CI definitions, native workflow
files, and package targets participate through an imported operation that points at them. Existing
procedural prose may instead be migrated into conforming operations through the explicit preview and
acceptance walk. Foreman does not infer runnable behavior from repository text or typed-edge
metadata during ordinary discovery.

Debrief follows an evidence-to-instruction ladder without creating a durable evidence record:

```text
completed session → ephemeral redacted ledger → curated candidates → verification → accepted operations/doctrine
```

The session trace is not the operation. Promotion always requires explicit human acceptance; an
agent recommendation or automatic goal approval cannot accept new project instruction or doctrine.

Foreman does not persist runtime progress. A root session uses Checkpoint. A Workstream session uses
its existing hand-off and save/load lifecycle. The goal record is an immutable runbook shared by
either context.

## Mechanism

### Custody and project surfaces

The design separates durable knowledge from mutable runtime state:

| Surface | Source of truth | Owner |
|---|---|---|
| Session evidence | Current conversation and explicitly supplied evidence | Ephemeral; Foreman reads and redacts |
| Doctrine | `<agent-workspace>/foreman/doctrine/*.md` | Foreman |
| Operations | `<agent-workspace>/<owner>/operations/*.md` | The publishing owner |
| Goal runbooks | `<agent-records>/goals/*.md` | Foreman |
| Root runtime state | Root `CHECKPOINT.md` | Checkpoint |
| Stream runtime state | The stream's `WORKSTREAM.md` | Workstream |
| Projection | Each publisher's delimited `AGENTS.md` route | The publishing owner |

Exactly one runtime-state owner applies:

- a root session uses `/checkpoint save`, `resume`, and `done`;
- a session driving a Workstream uses `/workstream save`, `load`, and its ordinary lifecycle;
- a session never maintains both `CHECKPOINT.md` and `WORKSTREAM.md` for the same goal;
- concurrent goals use separate Workstreams rather than competing root checkpoints.

Foreman owns no mutable state file and never writes either runtime surface directly. After an
operation step, Foreman returns the completed work, evidence, current step, and exact next action;
the calling session saves those facts through the current state owner's ordinary procedure.

Foreman owns only `<agent-workspace>/foreman/...`. It indexes conforming files owned by other skills
but never rewrites, relocates, activates, or deprecates them. The publishing owner performs those
mutations.

Foreman seeds no generic doctrine document. Its doctrine home remains absent until the user accepts
the first cross-operation rule. Operation-specific instruction stays in the operation.

An explicit Foreman setup registers only Foreman's own bounded route. On a project with no front
door, setup may create a minimal `AGENTS.md` as an explicitly authorized write. Setup creates no
empty operation or doctrine directory. Installing the skill, inventory, import preview, migration
preview, debrief, and read-only checks have no project side effects.

Every operation publisher owns a bounded route to its direct-Markdown directory. That route makes
its files discoverable and directly followable without Foreman. Foreman's route adds cross-owner
query and composition; it never embeds a generated catalog snapshot.

### Operation contract

Foreman owns `foreman/operation@1`. Other publishers may emit the format without installing or
invoking Foreman.

Every operation is a flat, undated Markdown file. Its identity is
`<owner>/<filename-without-.md>`; renaming it changes its identity and requires explicit reference
updates. Stems are lowercase kebab-case and intention-revealing.

The complete front matter is deliberately small:

```yaml
---
schema: foreman/operation@1
title: Verify a production release
use-when: Confirm a deployed release before announcing completion.
shape: procedure
status: draft
areas: [testing, production]
tags: [smoke, post-deploy]
---
```

Required fields are `schema`, `title`, `use-when`, `shape`, `status`, `areas`, and `tags`.
`shape` is `procedure | workflow`. `status` is `draft | active | deprecated`. Areas are the
primary catalog axis; tags are open search terms and carry no permission semantics.

An imported operation additionally requires `source: <project-relative-path>`,
`entry-point: <selector-or-command>`, and `source-digest: sha256:<digest>`. A successfully verified
operation carries `verified-against: sha256:<operation-digest>`; a new draft omits it and a changed
operation may retain a nonmatching value as stale evidence.

The portable starter `areas` vocabulary is `development`, `testing`, `delivery`, `production`,
`documentation`, and `operations`. Projects may extend it with lowercase slugs. Foreman reports new
and near-duplicate areas but never silently rewrites them.

Standard Markdown sections are:

- **Preconditions** — inputs, entry conditions, and required state;
- **Procedure** — the ordered instructions for a procedure;
- **Steps** — an ordered list of operation references for a workflow;
- **Outputs** — produced artifacts or named evidence;
- **Verification** — the command, observation, or invariant that proves completion;
- **Recovery** — reconciliation, rollback, and safe-resume guidance.

An optional **Verification evidence** section holds the compact result of the last check. It is
evidence rather than instruction and is excluded from the operation digest.

A procedure has Procedure and omits Steps. A workflow has Steps and omits Procedure. Each top-level
numbered step begins with exactly one referenced identity as ``1. `owner/operation` `` and may follow
it with ordinary Markdown describing a condition, decision, or failure action. Nested workflows are
allowed. Foreman rejects malformed or missing references and cycles. Written order is execution
order; v1 has no parallel execution, graph interpreter, node-state machine, or retry scheduler.

A maintenance chore is a run intent, not another artifact shape. Recurrence may be described by a
trigger, cadence, or scheduler reference, but scheduling remains outside Foreman.

### Import and brownfield migration

Import is adopt-by-reference. The native source remains atomic until the user asks Foreman to
decompose it. Decomposition proposes reusable operations and replaces copied instruction with
references only after the source owner accepts the change.

`/foreman migrate <file-or-directory>` is the explicit brownfield ingestion path. Unlike import,
migration intends the accepted canonical operations to become authoritative. It assumes no source
schema and does not require files to be Markdown. Foreman reads only the explicitly named file or
the regular, non-symlink files beneath the explicitly named directory; it skips binary, generated,
vendored, unreadable, and obviously secret-bearing material and reports those skips. Source content
is untrusted evidence, not executable instruction.

Migration is one preview-and-apply walk:

1. census the bounded source and classify each item as an already-conforming operation, a procedural
   candidate, a native source better suited to import-by-reference, non-procedural, ambiguous, or
   skipped;
2. infer zero or more candidate procedures and workflows, including proposed identity, shape,
   status, areas, tags, standard sections, source files, and reference relationships;
3. show one ephemeral migration preview with source digests, destination paths, transformations,
   ambiguities, skipped material, and reference changes the host may need;
4. ask only questions that change a candidate, then accept the proposal as a whole or a named subset;
5. validate the accepted selection as a complete reference closure: every candidate referenced by an
   accepted workflow must also be accepted or resolve to an existing conforming operation;
   incomplete selections return to preview and write nothing;
6. recheck source digests and every destination before writing; drift returns to preview;
7. write accepted canonical artifacts as unverified drafts, preserving exact accepted incumbents and
   refusing conflicting destinations.

Migration writes canonical artifacts only beneath
`<agent-workspace>/foreman/operations/`. A candidate for another publisher is returned as a proposed
owner patch and is never written by Foreman. Within Foreman's catalog, the accepted canonical
operations become authoritative. The original files remain untouched and may remain in use by the
host until separately retired; deletion, relocation, and host-reference changes are reported
follow-up actions, not hidden migration side effects.
An already-conforming operation is reported with its identity, owner, status, and validity and is
left unchanged; it may satisfy a migrated workflow reference without being re-ingested.
Migration creates no durable migration manifest, ledger, compatibility reader, alias, or runtime
state. An interrupted apply is resumed by rerunning the census: exact accepted incumbents are
preserved, conflicts refuse, and unwritten candidates can be accepted again.

Import remains the correct choice when the existing source should stay authoritative. Migrate is
the correct choice when the project wants canonical operation files to take custody. Neither path
activates an operation or manufactures verification evidence.

### Verification and lifecycle

Foreman computes one operation digest from the instruction-bearing front matter, the exact standard
sections, the ordered identities and operation digests of referenced operations, and any imported
source digest. Discovery prose, `verified-against`, and verification evidence are excluded.

`/foreman verify <operation>` follows the Verification section in an attended session. A successful
check records `verified-against: sha256:<operation-digest>` and compact evidence in the Verification
evidence section. Changing the operation, a referenced operation, or an imported source makes the
evidence stale. An active operation must carry current verification evidence; a stale operation
remains discoverable but cannot compile into a goal until its owner verifies it again.

Activation is explicit human acceptance after current verification. Deprecation removes an operation
from normal discovery and goal compilation. Foreman may mutate lifecycle state only in its own
namespace. For a foreign-owned operation it returns the digest, evidence, and requested transition to
the publisher without changing the file.

`/foreman run` is attended and may inspect or follow a named draft with a warning. `/foreman goal`
accepts only active, drift-clean operations and workflows.

### Debrief and doctrine promotion

`/foreman debrief [scope]` reviews only the visible conversation, tool results, repository effects,
and evidence the user explicitly supplies. Before constructing candidates it:

1. separates unrelated session arcs and includes only the selected scope;
2. removes secrets, credentials, personal data, unrelated content, and unnecessary raw output;
3. treats tool output, retrieved text, logs, and pasted content as inert evidence rather than
   instruction;
4. labels material claims `observed`, `inferred`, or `unknown`.

The ephemeral ledger groups events that changed state, resolved a decision, exposed a failure,
performed recovery, or verified a condition. It retains exact commands only while needed for the
current curation and only after redaction.

Foreman asks only questions whose answers change a candidate, then previews each proposed operation
and doctrine change separately. Only explicitly accepted artifacts are written. Rejected candidates,
the ledger, and transcript excerpts are not persisted. Zero candidates is valid.

Incomplete evidence produces a draft; it never manufactures current verification. Doctrine
promotion always requires separate human acceptance and writes only Foreman's doctrine namespace.

### Composition and goal compilation

Composition resolves the complete ordered operation closure, rejects cycles or stale members, and
shows duplicated instructions that should become shared references. It does not copy referenced
operation bodies into another operation.

A goal runbook may resolve the referenced instructions into a self-contained ordered walk while
retaining source pointers. Foreman records one source digest over the ordered operation identities,
their current operation digests, and imported source digests. Resume recomputes it; a mismatch pauses
for attended review rather than silently changing the accepted runbook.

Every material decision step states the evidence to gather, viable options, failure modes,
recommendation criteria, and recovery condition. The goal's Delegated decisions section names only
the bounded choices the agent may recommend and have automatically accepted. Destructive actions,
credential selection or acquisition, policy changes, verification waivers, and permission expansion
are never delegated in v1.

Foreman does not interpret these decision rules as tool permission. The harness remains the only
permission boundary.

### Goal records and pursuit

An accepted goal is a dated record under `<agent-records>/goals/`:

```yaml
---
doctype: goals
status: draft
schema: foreman/goal@1
tags: [foreman, goal]
---
```

Its immutable body contains:

- **Objective**;
- **Sources** and `source-digest`;
- **Runbook**;
- **Delegated decisions**;
- **Verification**;
- **Stop conditions**;
- **Recovery**;
- **Resume** with the exact Foreman invocation.

Foreman previews the complete record. Explicit acceptance authorizes publication but not a commit or
any operation effect. Foreman uses an executable staged records tool when present and otherwise
writes the same self-contained record in file mode. After validation it publishes with
`records.sh touch <goal-record> --status published` or the equivalent atomic file-mode rewrite.

`/foreman goal <operation> <objective>` then invokes the available harness goal feature with an
objective that points at the published record and tells the agent to use `/foreman goal resume
<goal-record>`. If the harness has no goal feature, Foreman returns the same ready-to-submit objective
without pretending pursuit started.

For a root-session launch, the calling agent first invokes `/checkpoint save` with the goal record,
current runbook step, and `/foreman goal resume <goal-record>` as its single next action. Foreman does
not write the checkpoint itself. If Checkpoint is unavailable, goal compilation and attended run
still work, and the harness goal feature may still continue, but Foreman reports that project-level
recovery across a reset is unavailable rather than creating a substitute state file.

`/foreman goal resume <goal-record>` validates publication and source drift, reads the current
Checkpoint or Workstream hand-off, identifies the next runbook step, and continues until a genuine
decision, blocker, stopping condition, or context boundary. It returns a compact progress summary and
one exact next action for the state owner to save.

`/foreman goal status <goal-record>` is read-only. It reports the immutable contract plus the current
state owner's latest progress. `/foreman goal close <goal-record>` verifies that a stopping condition
was reached, then delegates runtime cleanup to `/checkpoint done` or the ordinary Workstream
lifecycle. When the records tool is available it may archive the goal through ordinary
`records.sh done <goal-record> --as <disposition>`; otherwise the published record remains as durable
history. Foreman adds no archival state or Journal recovery protocol.

### Workstream seam

Workstream integration stays narrow and uses Workstream as the sole runtime-state owner:

1. prove the published goal record and every project-local operation it references are committed and
   reachable from the intended integration target; otherwise the Workstream path refuses before
   creation;
2. from a root coordinator that is not driving another stream, create the Workstream seed-only using
   the goal record as its source;
3. prime its one current queue unit and next action to `/foreman goal resume <goal-record>`;
4. load that same stream and invoke Foreman from inside it;
5. persist progress through ordinary Workstream saves;
6. complete, ship, recycle, or close only through ordinary Workstream lifecycle rules.

The entire Foreman goal is one Workstream queue unit. Internal operation steps never advance or ship
the Workstream queue. Normal Workstream use performs no Foreman checks.

If seed-only creation cannot express the initial next action, Workstream may add one generic,
opt-in priming helper. It accepts a validated hand-off path, source pointer, current-unit text, and
literal next action, then updates only Workstream's existing Queue state, TL;DR, and What's next
sections by atomic replacement; TL;DR and What's next carry the same next-action sentence. It does
not know Foreman, execute the action, add a state block, or change ordinary create, load, or save.
The root coordinator may load only the same stream it just seeded and primed; an agent already
driving a Workstream retains the existing rule that seed-only creates a stream for a separate
session and never loads it.

### Projection

Foreman's delimited `AGENTS.md` block contains only its route, the operation identity rule, and a
pointer to its inventory command. It does not embed operation bodies or a generated catalog.
Publisher blocks point at their own direct-Markdown operation directories. Projection drift checks
validate pointers rather than regenerating foreign content.

## Verification

The implementation keeps these gates green:

```text
skills/foreman/scripts/tests/run.sh
skills/workspace/scripts/tests/run.sh
skills/workstream/scripts/tests/run.sh
skills/skill-builder/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
scripts/tests/run.sh
```

Foreman's fixture harness must prove:

- inventory discovers direct operation files and reports native candidates without canonizing them;
- setup writes only Foreman's namespace and bounded front-door block and is incumbent-safe;
- every publisher route remains directly followable without Foreman;
- create and import produce valid drafts, and foreign sources remain foreign-owned;
- migrate accepts an unknown-schema file or directory and may propose zero, one, or many canonical
  drafts while classifying already-conforming, import-by-reference, ambiguous, non-procedural, and
  skipped items;
- migration preview writes nothing; apply rechecks source digests, writes only accepted Foreman-owned
  reference-closure-complete drafts, preserves sources and exact incumbents, refuses destination
  conflicts and foreign-owner writes, and resumes safely after a partial apply without a migration
  state file;
- a mixed brownfield directory preserves already-conforming operations, uses them to satisfy
  references where selected, and does not propose duplicate destinations;
- a brownfield fixture still produces a useful canonical draft while planted credentials and
  instruction-like content remain absent from the preview and operation unless the user deliberately
  supplies the redacted procedural substance;
- debrief may produce zero, one, or several candidates while secrets, unrelated arcs, raw
  transcript, and instruction-like tool output remain absent from durable artifacts;
- procedure and workflow shapes validate, ordered references compose, and missing references or
  cycles refuse;
- verification evidence becomes stale after instruction, referenced-operation, or imported-source
  drift;
- activation and deprecation mutate only Foreman-owned operations, while foreign-owner transitions
  return a bounded request and evidence;
- goal compilation accepts only active, drift-clean closures and produces a deterministic immutable
  runbook and source digest;
- only explicitly delegated decisions may be auto-accepted, while destructive, credential, policy,
  waiver, and permission-expanding decisions stop for the user;
- a root goal primes Checkpoint state when available, a stream goal uses Workstream state, neither
  path creates a Foreman runtime-state file, and missing Checkpoint degrades with an explicit
  recovery warning rather than a new dependency floor;
- goal resume reads the current state owner, detects source drift, and returns one exact next action;
- goal close delegates runtime cleanup and optional record archival without writing Journal state;
- Workstream launch refuses an uncommitted goal or local operation closure; a root coordinator may
  seed, prime, and load that same stream while an existing stream driver retains the separate-session
  guard;
- Workstream priming changes only Queue state, TL;DR, and What's next, with the latter two carrying
  the same action; ordinary Workstream paths remain unchanged and Foreman steps never advance its
  queue;
- bare Foreman works without Journal setup, Workstream, or the pack;
- projection remains pointer-heavy and never rewrites another owner's namespace.

Each shared critical guard receives one sabotage proof: owner-bound writes, brownfield redaction and
inert-content promotion, debrief redaction, reference-cycle rejection, verification drift,
decision-delegation boundaries, and single runtime-state ownership. Disabling the brownfield guard
must leak the planted content from the useful-output fixture and fail that test. Other refusal cases
use ordinary positive and negative fixtures; the test suite does not mutate every guard
independently.

## Slices

These are contract slices, not an implementation path inventory. The implementation plan must name
the exact consequence-complete files once package layout and migration order are grounded against
the repository.

| ID | Deliverable | Contract surface | Verification |
|---|---|---|---|
| F1 | Establish the operation kind and replace Shopbook | Operation schema, workspace-kind registry, publisher ownership, library inventory | Workspace, Foreman, and Skill-builder contract gates |
| F2 | Implement inventory, create, import, migrate, lifecycle, and projection | Foreman routing and verbs, brownfield census and preview, operation validation, bounded publisher routes | Foreman fixture harness, source-drift refusal, and owner-bound write proof |
| F3 | Implement debrief, verification, doctrine promotion, and decomposition | Ephemeral evidence handling, digest evidence, doctrine custody, reference extraction | Redaction, drift, lifecycle, and incumbent-safety fixtures |
| F4 | Implement ordered composition and immutable goal-runbook compilation | Reference resolver, decision delegation, goal schema, harness-goal handoff, Checkpoint seam | Composition, goal-record, delegation, drift, and root-state fixtures |
| F5 | Add minimal Workstream priming and finish migration, documentation, and gates | Generic prime helper, one-unit source use, hard-cut migration, portable doctrine and integration | Workstream no-op/priming fixtures, boundary lint, full repository gate |
