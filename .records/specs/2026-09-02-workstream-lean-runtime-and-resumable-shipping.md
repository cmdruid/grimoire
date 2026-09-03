---
doctype: specs
status: published
schema: architect/spec@1
tags: [workstream, refinement, shipping]
---

# Workstream lean runtime and resumable shipping — Spec

This specification composes with
→ `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`. The August 31
specification remains the base design; this document replaces only its runtime-reading,
handoff-state, shipping-transaction, gate-selection, and `after-eventful-ship` requirements. Every
base requirement not explicitly replaced here remains authoritative. The two specifications are
implemented and landed as one effective design, without an intermediate base-only runtime. The
existing implementation plan must therefore be replaced before implementation begins.

## Problem

Workstream's safety model is sound, but the agent pays for too much of it repeatedly. At the
current `HEAD`, `SKILL.md`, `flow.md`, the common verbs, and the generated handoff template total
120,486 bytes across the nine files that carry the ordinary loop. A normal `load` is directed
through 48,746 bytes of package prose—`SKILL.md`, `flow.md`, and `verbs/load.md`—before the generated
handoff, whose package scaffold is another 13,894 bytes. A standalone `ship` can require 65,485
bytes of package prose across the router, flow, ship, and sync procedures, plus that handoff. These
populations are the mandatory runtime read edges named by the current router and verbs, not a count
of every Workstream document.

The prose does more than explain policy. It asks the agent to carry a transaction: the pre-rebase
base, own and incoming change sets, gate decision and evidence, target and branch tips, conflict
history, submodule readiness, landing route, postflight state, and the point at which a save is
required. An interruption forces the next agent to reconstruct those facts from long instructions
and Git. Even without interruption, explicit `create` and `load` calls lead to another launch
confirmation, and shipping commonly requires inspect, prepare, confirm, land, run tracked
bookkeeping, land again, and save.

The August 31 design removes Workstream-owned records and introduces guarded helpers, hook
receipts, `.streams/history.tsv`, and compiled configuration. That is necessary but incomplete. It
still places mutable lifecycle state in `WORKSTREAM.md`, preserves a facts-only helper boundary,
and defines `after-eventful-ship` after the target has already moved. Its new TSV history row would
also be classified as build-relevant by Workstream's current extension-only rule, making the full
gate a possible tax on every shipment.

Project-specific knowledge cannot be embedded in the generic skill. A host may know that one TSV
is lifecycle metadata, another is a runtime fixture, a particular dependency cone needs three
focused checks, or a retained integration environment is not repeatable without preflight. Asking
Workstream to infer those semantics either makes it unsafe or turns it into a registry of every
host. Requiring a project adapter or setup step would instead export Workstream's ceremony to the
developer.

## Goal

Make the common Workstream loop agent-efficient without weakening its custody, replay, gate, or
landing boundaries. A stream has one concise agent-facing runbook and one helper-owned mutable TSV
tracker; shipping becomes a zero-setup, resumable transaction whose preparation is branch-local and
whose uncontended successful path needs one gate selection, one landing authorization, one tracked
target advance per destination, and one ignored-state finalization.

## Approach

**Chosen: a thin agent protocol over a guarded per-stream state machine.** `WORKSTREAM.md` becomes a
stable runbook rather than a frequently rewritten database. A new ignored `workstream.tsv` beside
it is the effective helper's exclusive mutable state. Public verbs ask the helper to validate and
advance typed transitions; agents never edit or load the TSV directly. `flow.md` is deleted, verb
read dependencies are removed, and each public verb combines a short judgment contract with helper
facts.

`/workstream ship --prepare` performs every reversible or stream-branch-local action and stops at
`ready-to-land`. Bare `ship` resumes or implicitly performs preparation, obtains landing authority
when the user has not already supplied it, and completes the target mutation and postflight. A
single current-state receipt inside `workstream.tsv` makes every phase resumable and invalidates
evidence when its inputs change.

Gate selection remains zero-setup. The helper supplies exact change facts; the agent selects the
gate command from host instructions already in context and passes its argv to the helper for
execution and evidence capture. A host-provided semantic selector such as `make test-ship` is an
opportunistic accelerator, never a Workstream configuration requirement. Without one, the portable
fallback structurally validates Workstream's own generated history row, uses the documented fast
gate for Markdown-only work, and sends every other or unknown path to the documented full gate.

The post-land `after-eventful-ship` hook is hard-renamed to `ship-friction` and moves inside
preparation. Once shipping friction is known and resolved, the hook runs before the successful
target advance. Its tracked effects join the same branch and invalidate stale gate evidence. No
post-success closure tail reopens a completed shipment; a partially delivered push remains the same
open shipment until every destination contains its current candidate.

Alternatives rejected:

- **Shorten the prose but keep agent-orchestrated state.** This reduces bytes while retaining the
  repeated fact threading and interruption risk that cause the ceremony.
- **Put the tracker fields in `WORKSTREAM.md`.** Markdown is appropriate for context but a poor
  transactional store. It forces the agent to load and rewrite state that deterministic code can
  validate more cheaply.
- **Let agents edit `workstream.tsv` directly.** Positional and escaping errors would be harder to
  review than Markdown edits. The benefit exists only when typed helper operations are the sole
  writer.
- **Require a configured ship-gate adapter.** That breaks zero-floor use and adds developer setup
  for a capability many projects already express in their front-door instructions.
- **Auto-discover undocumented gate commands.** Guessing Make targets or executable names can run
  an unintended workflow. Existing host instructions or the safe fallback are the authority.
- **Build a full declarative workflow engine.** It would centralize more behavior but recreate the
  generic callback machinery and configuration burden the base specification rejected.
- **Keep post-land tracked hooks with a closure tail.** It permits one logical shipment to mutate
  the target twice and makes successful landing a midpoint rather than a terminal boundary.
- **Make Workstream own project test-state cleanup or general temporary-file retention.** Those are
  host runner and session-artifact policies. Workstream owns only its bounded transaction state.

## Mechanism

### Composition and hard cut

This refinement replaces these base-spec contracts:

- Mutable unit, queue, phase, shipment, evidence, and hook-receipt state moves from
  `WORKSTREAM.md` to `workstream.tsv`.
- The helper may execute authorized deterministic Git and gate phases; it remains unable to choose
  semantic work, resolve conflicts, invent a gate command, retry an uncertain hook, or authorize a
  ref mutation.
- `after-eventful-ship`, its configuration marker, receipt identity, post-land execution, and
  closure tail are removed. `ship-friction` is the sole replacement spelling and runs pre-land.
- `flow.md` and every mandatory cross-read of it are deleted. No verb requires another verb file.
- The current extension-only gate rule becomes the zero-setup selection protocol below.
- Create/load/recycle launch confirmation and mandatory feature-boundary Markdown saves are
  removed. The authorization and save rules below replace them.
- The recovery anchor remains self-contained for custody admission, but its post-admission
  full-handoff read becomes a bounded Workstream-helper projection. Its instruction may invoke the
  effective helper only after the current stream has been admitted.

There is no alias, dual read, legacy hook marker, conversion from a shipped
`after-eventful-ship` receipt, or base-only intermediate format. The base design has not been
implemented, so its proposed all-in-Markdown lifecycle shape is not a migration source. The
existing `.workstreams` hard-cut migration directly produces the composed runbook and tracker.

### Per-stream runtime and ownership

Every stream has exactly two ignored Workstream-owned runtime files:

```text
WORKSTREAM.md       # concise agent-facing runbook
workstream.tsv      # helper-owned current lifecycle state
```

For a linked stream both files are at the linked checkout's top level, whose root-relative address
is `.streams/<stream>/`. For an in-place stream both live directly under
`.streams/<stream>/`. Creation ensures the shared exclusions contain exact `/WORKSTREAM.md` and
`/workstream.tsv` rules before either file is written. The existing topology and nesting guards
admit those exact artifacts and do not infer safety from ignore state.

`WORKSTREAM.md` is agent-facing but not monolithic-at-load. It owns only:

- the stream purpose and durable queue-source pointer;
- immutable stream name, instance ID, root, worktree, branch, target, isolation, and landing
  coordinates needed for custody admission;
- the resolved stable operating policy and compiled hook instruction bodies;
- concise orientation pointers; and
- one bounded operator-note span for semantic reasoning that Git and the tracker cannot express.

It contains no current phase, queue checklist, unit or shipment receipt, gate evidence, commit
list, changed-path inventory, retry count, or mutable next-action field. Exact managed markers split
a bounded runtime brief from compiled hook bodies. `load` and ordinary recovery consume the brief,
purpose, orientation, and operator note through the helper; they do not expose hook bodies. The
helper emits exactly one compiled body only when its event receipt moves to `running`. Compiled
project hook bodies and project-authored purpose/pointers may be any valid size; generated package
scaffolding around them is subject to the read budget below.

`workstream.tsv` is authoritative for every mutable lifecycle fact. Its exact header is:

```text
record\tid\tfield\tvalue
```

Each data row has exactly four tab-separated fields and a unique `(record, id, field)` key. The
first canonical data row is `meta\t-\tschema\tworkstream@1`. Rows are sorted by the helper's
defined record-type order and then bytewise by ID and field. No field may contain a tab, carriage
return, line feed, NUL byte, or other control character. Unknown record types, fields, enum values,
duplicate keys, noncanonical ordering, missing required keys, and unsupported schemas refuse the
complete file.

The closed record families and allowed field sets are:

| Record | ID | Allowed fields |
|---|---|---|
| `meta` | `-` | `schema`, `instance-id`, `runbook-contract-sha256`, `pending-runbook-contract-sha256`, `next-unit`, `next-shipment` |
| `queue` | `-` | `source-kind`, `cursor`, `state` |
| `phase` | `-` | `name`, `next-action` |
| `unit` | positive unit sequence | `slug`, `summary`, `state`, `boundary`, `commit-count` |
| `unit-subject` | `<unit>/<index>` | `subject` |
| `hook` | complete invocation identity | `name`, `fingerprint`, `state`, `inputs-sha256`, `evidence-sha256` |
| `shipment` | positive shipment sequence | `phase`, `outcome`, `branch-tip`, `target-tip`, `inputs-sha256` |
| `shipment-unit` | `<shipment>/<index>` | `unit` |
| `friction` | `<shipment>/<reason>` | `present` |
| `gate` | shipment sequence | `class`, `label`, `inputs-sha256`, `command-sha256`, `outcome`, `evidence-sha256` |
| `gitlink` | `<shipment>/<path-sha256>` | `path`, `object`, `availability`, `published` |
| `delivery` | `<shipment>/local-target` or `<shipment>/remote-target` | `expected-tip`, `candidate-tip`, `observed-tip`, `state` |

`source-kind` uses the base spec's closed queue-source enum; `queue.state` is
`intake|ready|exhausted`. An intake or exhausted cursor is `-`; a ready cursor is nonempty.
`intake` represents a fresh template or unplanned brief whose next unit has not been defined.
`phase.name` is `none|plan|build|ship`; `none` is required in delegate mode and the other values are
manual-mode phases. `next-action` is one of
`define-unit|plan|build|feature-hook|accumulate|sync|unpark|prepare-ship|land|await-merge|postflight|recycle|close|blocked`.
Unit state is `active|complete`. Hook state retains the base
`ready|running|complete|not-applicable` enum. Shipment phase is
`prepare|sync|metadata|gitlinks|gate|friction|ready-to-land|advance|postflight|complete`; its outcome
is `active|blocked|uncertain|awaiting-merge|landed`. Gate class is
`none|docs|full|semantic`, and gate outcome is
`required|running|passed|failed|stale|uncertain`. Gitlink availability is
`ready|transferred|missing`, and `published` is `yes|no|not-required`. Delivery state is
`ready|running|advanced|rejected|uncertain`. Friction reasons
are exactly `rebase-conflict`, `semantic-conflict`, `target-reject`, `remote-reject`,
`repeat-sync`, `gate-recovery`, `gitlink-repair`, and `agent-intervention`; `present` is always
`yes`.

SHA fields are lowercase 64-hex SHA-256 except Git object and ref-tip fields, whose grammar follows
the repository's object format. Counters and indices are positive decimals except `commit-count`,
which is a nonnegative decimal; indices are contiguous from one within their parent. `commit-count`
equals the number of `unit-subject` rows. `boundary` is a Git object ID, and human labels, summaries,
subjects, cursors, and paths are nonempty single-line values of at most 4,096 bytes under the global
control-byte prohibition. Every other non-hash, non-object tracker value has the same byte limit.

The helper validates field presence by state rather than filling unavailable values with sentinels:

- `meta`, `queue`, and `phase` have every listed field except the pending runbook hash, which exists
  only during the reconfiguration transaction below. An intake or exhausted queue may have no
  unit. A ready queue has at least one unit: any number of completed unlanded units plus at most one
  active unit. A quiescent tracker has no shipment-scoped rows.
- Every unit has its five listed fields. An active unit may have zero subjects. A complete unit has
  a positive `commit-count`; its indexed subjects exist and agree exactly with that count.
- A ready or running hook has `name`, `fingerprint`, `state`, and `inputs-sha256`. Complete and
  not-applicable hooks also require `evidence-sha256`; no earlier state may carry it.
- Every shipment has all five listed fields, captured atomically when its immutable batch is
  allocated. Its unit rows are then fixed until finalization. Shipment-scoped child rows require
  that parent.
- A required gate has `class`, `label`, `inputs-sha256`, and `outcome`. A running gate also has its
  command hash. Passed, failed, stale, and uncertain gates have both command and evidence hashes.
  The sole exception is a `none|passed` gate, which has no command or evidence hash because its
  input fingerprint proves that no gate command applies.
- Every gitlink has all listed fields. `published: not-required` is legal only for local delivery;
  push and PR use `yes|no`. A missing object cannot be transferred or published.
- Delivery rows exist only for push shipments and both destinations exist before the first ref
  attempt. Ready and running rows have expected and candidate tips; advanced and rejected rows also
  have an observed tip. An advanced row's observed tip equals its candidate. An uncertain row may
  omit the observed tip only when the ref cannot be read safely. Staleness is derived whenever a
  receipt's expected or candidate tip differs from the current transaction inputs; it is not a
  persisted state.

No unknown or contradictory field combination is accepted. A state that has reached a phase
requires every predecessor's applicable evidence fields.

Arbitrary prose and command output never enter the tracker. The gate command's argv is fingerprinted
but not stored for unattended replay. The helper stores only a bounded label and evidence digest;
invalidated evidence causes the agent to select the gate again from current host instructions. No
field persists landing authorization.

`runbook-contract-sha256` covers only the immutable identity/custody, managed operating-policy, and
compiled-hook spans, not the project-authored purpose, orientation, or operator note. Reconfig uses
the optional allowed `meta/-/pending-runbook-contract-sha256` row as a two-file commit protocol:
record the validated candidate hash, atomically replace the managed runbook span, then promote the
pending hash and remove the pending row. On interruption, an old-hash runbook rolls the pending row
back, a pending-hash runbook completes the promotion, and any third value refuses. Ordinary load
does not accept a pending transaction. Operator-note saves do not change the contract hash or
tracker.

The tracker holds the current unit, accumulated unlanded units, and current shipment only. After a
shipment finalizes, completed unit, hook, gate, gitlink, and shipment rows are removed atomically;
the next counters and queue cursor remain. Durable landed overview exists only in
`.streams/history.tsv`. The tracker is not an append-only event log and never becomes a second
history surface.

The effective package or installed `workstream.sh` is the sole writer. Every mutation validates the
whole incumbent, checks the expected file fingerprint and relevant Git inputs, writes a fresh file
beside the destination, rechecks the parent and incumbent, and renames atomically. Symlinks and
changed incumbents refuse. Raw agent or human editing is unsupported and never a recovery
instruction.

### Runbook and save discipline

`create` automatically writes both runtime files; setup is neither required nor offered as a
precondition. `reconfig` rewrites only the stable managed policy/hook span of the runbook and the
binding fingerprint in the tracker. `load` asks the helper to validate the runbook, tracker, and Git
custody, then consumes the bounded runbook brief and compact state envelope. It does not read the
complete Markdown file or inactive hook bodies.

`/workstream save` updates the bounded operator-note span only when semantic intent must survive an
imminent reset or custody transfer. It never rewrites lifecycle facts. Feature completion, sync,
hook transitions, gate transitions, and shipment phases update `workstream.tsv` through their typed
helper operations and do not trigger a Markdown save. `park` retains its save-before-custody-transfer
behavior. Successful ship has one authoritative ignored-state commit point. When semantic content
changed, the helper first makes the operator-note update idempotently and verifies its fingerprint;
it then atomically replaces `workstream.tsv` to update the queue/counters and clear the completed
transaction. An interruption before the tracker rename resumes the same finalization and reuses the
already-current note; after the rename the shipment is complete. The non-authoritative note is never
a second completion marker.

Context-pressure warnings still cause a save when the operator note is stale. Involuntary
compaction uses the base recovery anchor to admit only the current stream from the runbook's small
immutable identity marker, then invokes the helper for the bounded runbook brief and mutable state.
It reads neither the complete Markdown file, inactive hook bodies, nor the TSV into model context.
A missing or malformed tracker is possible state loss: targeted repair may
reconstruct only a provably quiescent idle state from matching immutable coordinates, Git, and
history. Active, dirty, unlanded, running-hook, or uncertain-shipment state cannot be reconstructed
and refuses for attended recovery.

### Thin runtime instruction surface

`SKILL.md` contains the scope invariant, zero-floor rule, universal custody/ref-safety rules,
dispatch table, and helper boundary. Each verb file contains its invocation-specific authority,
judgment points, refusal cases, helper calls, and terminal result. No verb instructs the agent to
read another verb. `flow.md` is deleted, and no live package source refers to it as runtime
doctrine. Explanatory rationale may live in non-runtime `docs/`, but runtime correctness cannot
depend on reading it.

The helper exposes typed operations for bounded runbook projection, state inspection, unit
transitions, hook transitions, sync/readiness, gate execution/evidence, shipment preparation,
landing facts, and finalization. It returns facts plus one deterministic `next-action`; it does not
return essays or hidden menus. A common-operation envelope contains at most 12 nonempty lines of at
most 1,024 bytes each. A hook-body response is separately bounded by project content and appears
only for that event. The tracker retains typed receipt facts and digests, while detailed evidence
remains in Git or host-owned logs. An explicit diagnostic command emits bounded receipt facts, not
stored command output.

The source budgets are:

- `skills/workstream/SKILL.md`: at most 10,000 bytes.
- Mandatory package-owned runtime prose for `load`: at most 20,000 bytes total, counting
  `SKILL.md`, `verbs/load.md`, the generated package-owned runbook brief, and every additional
  package file or span that live instructions expose to the agent.
- The equivalent mandatory package-owned read set for standalone `ship`: at most 20,000 bytes.
- Generated runbook scaffolding: at most 4,000 bytes after removing the substituted project-authored
  purpose, pointers, and hook-body spans.

Contract tests enumerate the files in each mandatory read population from the router and verb
edges, print the population and individual byte counts, and fail on either the budget or an
undeclared read edge. The baseline populations are the current files and byte counts recorded in
the Problem section; unrelated package documentation is not counted merely because it exists.

### Authorization and interaction

An explicit human `/workstream create`, `load`, or `recycle` invocation authorizes continuing its
single known next action. The verb reports that action and proceeds; it does not ask the human to
confirm the command they just issued. A blocker, ambiguous queue, or genuine semantic fork still
stops and asks. Manual mode retains phase-boundary stops because its model switch is a human action.

`/workstream ship --prepare` authorizes every reversible or branch-local preparation phase but
never a target or remote ref mutation, push, or PR creation/update. An explicit bare
`/workstream ship` authorizes preparation and landing. When the autonomous loop reaches a cadence
landing point without an explicit ship invocation, it prepares first and asks once with the compact
readiness envelope.

Landing authority binds the stream instance, shipment identity, unit batch, integration target,
and landing mode. It survives mechanical target-contention retries when those values remain fixed
and every changed input is revalidated. A changed batch, target, landing mode, semantic conflict,
unresolved hook effect, or genuine scope decision invalidates it and requires a new decision. A
session reset loses ephemeral landing authority; a recovered `ready-to-land` transaction asks
again rather than persisting consent in the tracker.

### Resumable shipment preparation

The current shipment uses these ordered phases:

```text
prepare -> sync -> metadata -> gitlinks -> gate -> friction -> ready-to-land
        -> advance -> postflight -> complete
```

Each phase has a closed outcome and input fingerprint in `workstream.tsv`. On interruption,
`ship --prepare` or bare `ship` validates completed inputs, reuses still-valid phases, and resumes at
the first absent, failed, uncertain, or stale phase. It never repeats a running hook or assumes a
possibly successful external mutation failed.

`ship --prepare` performs:

1. **Prepare.** Validate custody, clean/committed unit boundaries, tracker/runbook binding, migration
   state, and any incumbent shipment. Allocate one shipment identity and immutable ordered batch
   only when none exists; retries reuse both.
2. **Sync.** Capture the pre-rebase base and branch/target tips, synchronize the branch, and update
   the transaction facts. The helper performs deterministic Git plumbing; the agent resolves
   conflicts. A conflict or repeated sync records a friction reason. For push or PR delivery,
   preparation fetches the remote target object without updating the local integration-target ref
   and rebases against that recorded object; only the confirmed advance phase may update a target
   or remote ref.
3. **Metadata.** Reconcile unit subjects/counts, append the base specification's one history row per
   unit through the effective helper, and commit all shipment metadata on the stream branch.
4. **Gitlinks.** For every changed mode-`160000` path, verify the recorded object exists in the
   stream submodule and that the landing destination can obtain it. Local landing may perform a
   standard local object transfer before target advance. Push or PR landing refuses an unpublished
   submodule object. No successful land relies on postflight object repair.
5. **Gate.** Produce exact own, incoming, final-land, and transaction-generated path populations.
   Select and execute the gate through the zero-setup protocol below, recording fingerprints and a
   bounded evidence digest.
6. **Friction.** If the closed friction predicate is true, run the compiled `ship-friction` hook
   exactly once after recovery has produced a green preparation. Commit and validate any tracked
   effects on the stream branch. A changed final-land fingerprint invalidates gate evidence and
   returns to the gate phase before readiness.
7. **Ready.** Recompute custody, branch tip, target tip, batch, gate, hook, and gitlink facts. Record
   `ready-to-land` and emit the compact readiness envelope. `--prepare` stops here with no ref or
   remote mutation.

A clean path selects and runs its gate once. Eventful recovery or tracked friction-hook effects may
rerun the same selector because the candidate landing changed; that is evidence invalidation, not a
second user gate choice. A failed command never becomes reusable green evidence.

### Zero-setup gate selection

Workstream adds no gate key or block to `.streams/CONFIG.md`, installs no adapter, scans for no
conventional target, and asks no setup question. Preparation provides the agent with a bounded
changed-path manifest and the existing host instructions already provide the verification policy.
The only legal execution forms are
`gate-run --class <docs|full> --label <label> -- <argv...>` and
`gate-run --class semantic --selector --label <label> -- <argv...>`. The helper rejects every other
class/selector combination. It executes the exact argv in the canonical worktree without `eval`,
streams complete stdout and stderr through an incremental SHA-256 digest, retains and emits only the
trailing output that fits the common-operation envelope, and binds the result to the command,
branch, target, change populations, and relevant test-state identifier. Only the outcome and digest
facts persist. A `none` classification records its receipt without executing `gate-run`.

A host may document a semantic selector such as `make test-ship`. Only `--selector` mode receives
Workstream's environment and external-receipt contract; direct documentation and full gates run
with the canonical working directory and exact supplied argv, and the helper authors their internal
receipts from captured status and output. Before invoking a selector, the helper clears inherited
variables with the same prefix and sets:

```text
WORKSTREAM_GATE_SCHEMA=workstream-gate@1
WORKSTREAM_GATE_ROOT
WORKSTREAM_GATE_WORKTREE
WORKSTREAM_GATE_BRANCH
WORKSTREAM_GATE_TARGET
WORKSTREAM_GATE_BASE
WORKSTREAM_GATE_LANDING
WORKSTREAM_GATE_OWN_MANIFEST
WORKSTREAM_GATE_INCOMING_MANIFEST
WORKSTREAM_GATE_FINAL_MANIFEST
WORKSTREAM_GATE_GENERATED_MANIFEST
WORKSTREAM_GATE_RECEIPT
```

Root and worktree are canonical absolute paths; branch, target, base, and landing are the validated
transaction values. Each manifest variable names a mode-`0600` regular file in a helper-owned
private temporary directory. The file contains bytewise-sorted, root-relative Git paths separated
by NUL bytes, with no leading `./`, duplicate, or absolute entry. `WORKSTREAM_GATE_RECEIPT` names a
nonexistent path in that directory. The selector must create the receipt without replacing its
parent or using a symlink.

The semantic receipt is at most 4,096 bytes and has the exact `key\tvalue` header followed in
canonical order by unique `schema`, `outcome`, and `test-state` rows. Schema is
`workstream-gate@1`, outcome is `passed|failed`, and the bounded test-state value is nonempty
single-line text under the tracker's control-byte prohibition. Class and label come only from the
validated `gate-run` invocation and are not echoed by the selector. Exit zero must agree with
`passed`; an observed nonzero exit must agree with `failed`. A signal, an unverifiable launch
result, or a missing, malformed, oversized, symlinked, or exit-disagreeing semantic receipt records
`uncertain` and blocks. The helper fingerprints the validated receipt plus the complete streamed
output digest; the selector never supplies its own authoritative digest.

A selector may plan focused checks, expand submodule changes, choose clean or preserved test-state
modes, and deduplicate commands. Those semantics and state transitions remain host-owned.
Workstream validates and fingerprints the receipt but does not interpret project path taxonomies.

When no selector exists, the agent uses the host's documented fast and full gates under this closed
fallback:

- Rows that the current shipment itself appended to `.streams/history.tsv` are structurally
  validated by `workstream.sh` and removed from the build-relevant population. An incumbent or
  independently edited ledger is not exempt.
- If every remaining own changed path ends in `.md`, run the documented fast documentation gate.
- If any remaining own path is non-Markdown or unknown, run the documented full gate.
- Incoming-only changes reuse the target's evidence unless the own/incoming interaction or a host
  selector requires a rerun. If the target moves after a green receipt, classify the exact incoming
  delta and invalidate only the affected evidence.
- If a required host gate cannot be identified or executed, preparation blocks; it does not invent
  a command or silently land.

Journal, Backlog, and arbitrary TSV files receive no generic exemption. A host selector may safely
classify `.records/history.tsv`, `.trackers/tables/*.tsv`, providers, schemas, fixtures, and shared
build surfaces because it owns their semantics. Unknown host paths remain full-gate by default.

### Ship friction hook

The composed configuration recognizes exactly `feature-completion` and `ship-friction`. All base
isolation, fingerprint, `ready|running|complete|not-applicable` receipt, uncertain-recovery, and
non-recursion rules continue, but their mutable state lives in `workstream.tsv`.

The closed `ship-friction` predicate is true when the current shipment required any of:

- rebase conflict or semantic conflict resolution;
- a rejected local or remote target-ref update;
- more than one synchronization attempt;
- a failed gate followed by remediation and a successful rerun;
- gitlink object transfer, publication repair, or availability intervention; or
- an explicit shipping-friction fact recorded through the helper after agent intervention.

The hook identity is
`<stream>/<instance-id>/shipment/<shipment-sequence>/ship-friction`. A clean shipment records it
`not-applicable`. An applicable hook runs inside preparation after known friction is resolved and
before `ready-to-land`. `not-applicable` is provisional until shipment completion: its evidence
binds the complete friction set, and a later ref rejection invalidates that evidence, clears it,
and transitions the same invocation identity to `ready`. The hook then runs before retry. This is
not replay because the prior receipt executed no hook body. A completed or running hook is never
replayed automatically, even if later friction adds another reason.

Tracked hook effects must be committed and clean before readiness and are included in the same
landing. They invalidate any gate receipt whose final-land fingerprint changed. The base spec's
post-land closure tail is deleted. A problem discovered only after a successful target advance is
captured through the host's normal follow-up lane or the stream's next unit; it cannot reopen the
completed shipment merely to land bookkeeping.

### Landing and postflight

Bare `ship` implicitly prepares when necessary. At `ready-to-land`, it either consumes authority
from the explicit invocation or asks once in the autonomous path. It rechecks the receipt inputs
immediately before mutation and performs the configured local, push, or PR action using the base
specification's fail-safe ref rules.

A rejected ref mutation records friction and returns the same identity to preparation. With the
same batch, target, and landing mode, standing authority permits mechanical revalidation and retry;
a semantic conflict or changed contract invalidates it. The helper never forces a ref and never
persists human consent across a session boundary.

For local landing, the successful transaction advances the target once. Push mode is one logical
shipment with two ordered, independently guarded destinations: local target first, remote target
second. Before each attempt the helper records that destination `running`; afterward it reads the
ref and records `advanced`, `rejected`, or `uncertain`. It never claims completion until both
destinations contain the current candidate tip.

The helper derives and emits one push classifier, in this precedence order:

- `uncertain` — an attempted destination cannot be verified;
- `partial-delivery` — a destination advanced during this shipment while all destinations do not
  yet contain the current candidate;
- `complete` — both destinations contain the current candidate;
- `push-friction` — a rejection exists but no destination has advanced;
- `clean` — no push-specific friction has occurred.

The classifier is derived transaction state, not a third hook, event, or configuration key.
`remote-reject` and `target-reject` remain the causal friction records that activate
`ship-friction`. A partial delivery retains the shipment identity, immutable unit batch, history
rows, queue position, hook receipt, and ephemeral landing authority. If recovery or the friction
hook changes the candidate, an already-advanced receipt becomes stale by input mismatch and cannot
be reused; the gate is revalidated and a typed retry replaces the receipt before that destination
may advance again. This exceptional continuation is not a second shipment or bookkeeping tail. The
one-advance goal applies to local landing and to each destination of an uncontended clean push, not
to a contended partial-delivery recovery.

When partial delivery leaves the local and remote destination tips divergent, neither non-force
ref can advance to a linearized candidate while preserving both original tips. The sole recovery
exception is a two-parent reconciliation commit on the stream branch: the current candidate is its
first parent and the divergent destination tip is its second. The helper admits this exception only
when the active shipment is classified `partial-delivery`, both exact tips still match their
receipts, and neither is an ancestor of the other. The agent resolves any conflict; semantic
resolution invalidates landing authority, while a conflict-free mechanical reconciliation retains
it. The new candidate invalidates and reruns the gate. Hook applicability is reevaluated under the
same identity: a provisional `not-applicable` receipt may become ready, but a completed or running
hook is not replayed. Both destination receipts are then stale by input mismatch and resume through
typed replacement and the ordinary guarded advances. No merge preparation or merge commit occurs
on a clean landing path.

PR mode records `awaiting-merge` after the one authorized push/create or update; finalization occurs
only after merge is verified, without another tracked branch mutation.

Postflight may verify refs, align local submodule checkouts, stop resources through host-owned
commands, release custody, finalize `workstream.tsv`, and update the ignored operator note. It may
not create tracked commits, append another history row, advance a queue twice, or emit a lifecycle
hook. Any newly discovered tracked work becomes follow-up or a later shipment.

### Migration and lifecycle operations

The base `.workstreams` migration writes the composed format directly. It preserves stable purpose,
coordinates, pointers, queue source, effective scalar choices, and compiled hook bodies in the new
runbook. It translates recoverable mutable queue/unit state into `workstream.tsv`, gives legacy
hook bodies the base specification's explicit inline/serial provenance, maps no old
`after-eventful-ship` state, and marks any current composed hook receipts not applicable as already
required for unknown historical execution. Ambiguous active state refuses rather than inventing a
tracker.

`repair <stream>` validates both files and their binding. It may restore package-managed runbook
markers or reconstruct a missing tracker only under the quiescent proof described above. `reconfig`
updates stable policy and future hook fingerprints without changing active identities. `status`
and `load` obtain mutable facts only through the helper and disclose no sibling runbook body or raw
tracker. `close` removes both runtime files only after the existing canonical-path, registry,
custody, and completion guards pass.

### Explicit non-goals

- No general Callback package, event registry, parallel hook dispatcher, or user-configurable event
  names.
- No mandatory Workstream setup, gate adapter, new tracked control file, or front-door block.
- No Workstream-owned project path taxonomy beyond its own generated history row.
- No generic `/private/tmp` cleanup, `.scratch` retention service, test-container reset policy, or
  quarantine manager.
- No automatic conflict resolution, semantic gate choice, hook replay, or force update.
- No detailed Workstream event log. `workstream.tsv` is current state; `.streams/history.tsv` is the
  compact landed overview.

## Verification

- **Read-surface contract.** A test enumerates the current mandatory read populations for `load`
  and standalone `ship`, prints every included path and byte count, and enforces the 10,000-byte
  router, 20,000-byte per-operation, 4,000-byte generated-scaffold, and 12-line envelope limits.
  Mutation proofs add a read edge, inflate each controlled population past its limit, and require
  the test to fail. A live-source guard rejects `flow.md`, `Also read` dependencies, and runtime
  instructions to read another verb.
- **Tracker grammar and authority.** Table tests cover every record family and enum, canonical
  ordering, unique keys, indexed collections, state-dependent field presence, zero-commit active
  units, simultaneous active and completed units, exact delivery IDs, the reconfiguration-only
  pending hash, value-size limits, gitlink cross-field consistency, control-byte rejection,
  unsupported versions, runbook binding, symlink/parent/incumbent races, atomic writes, and every
  legal and illegal state transition. A temporary direct edit makes the next helper mutation fail.
  Source guards reject prose that tells an agent to edit the TSV manually.
- **Runbook separation.** Fixtures prove generated `WORKSTREAM.md` contains no mutable lifecycle,
  queue-position, evidence, receipt, or next-action field; project-authored purpose, pointers,
  operator note, and hook bodies survive save and reconfig. Feature completion and sync change only
  the tracker. Save changes only the bounded operator-note span.
- **Zero-floor lifecycle.** Fresh repositories with no `.streams` control files can create, load,
  prepare, land, recycle, repair, and close through the package helper. No scenario prompts for
  setup or creates a gate configuration. Intake template and brief streams, quiescent trackers,
  delegate and manual phases, behind-target sync, and parked in-place unpark each emit their exact
  next action. Initialized repositories retain the base helper-integrity boundary.
- **Preparation transaction.** Interruption is injected after every phase and atomic write. Repeated
  `ship --prepare` resumes the same identity and batch, reuses valid evidence, and stops at
  `ready-to-land`. Mutation proofs change the branch, target, batch, runbook, tracker, gate command,
  gate receipt, hook effects, and gitlink object after green preparation; each invalidates exactly
  its dependent phases. No prepare fixture changes a target/remote ref, pushes, or creates/updates a
  PR.
- **Gate behavior.** Fixtures cover a documented semantic selector, selector absence, selector-only
  environment exposure, every valid and invalid class/selector combination, mode-`0600` NUL
  manifests, direct and selector argv execution without `eval`, the three-row semantic receipt,
  every exit/receipt agreement, signal, malformed or symlinked receipt, input binding,
  unchanged-evidence reuse, target-delta reclassification, Markdown-only fast gate, unknown-path
  full gate, and the exact self-generated history-row exception. A large-output gate proves
  full-stream hashing while the agent-visible tail stays within the 12-by-1,024-byte envelope. An
  independently edited history row and arbitrary `.records`, `.trackers`, fixture, and TSV paths
  select the full fallback. A mock host selector proves it can classify those paths without
  Workstream learning their taxonomy.
- **Gitlinks.** Linked repositories prove local object availability/transfer, published and
  unpublished pins, local/push/PR policy, missing objects, changed pins after preparation, and no
  post-land repair requirement.
- **Friction hook.** Scenarios cover every predicate input, clean not-applicable state, pre-land
  timing, `not-applicable` invalidation and transition to ready after a late ref rejection, one
  identity across retries, tracked/no-op/external effects, gate invalidation after tracked effects,
  completed-hook suppression after later friction, uncertain running recovery, and no recursive
  event. Live-source guards reject `after-eventful-ship` outside historical/base-spec references and
  reject closure-tail behavior.
- **Authorization and ceremony.** Transcript fixtures count prompts. Explicit create/load/recycle
  produce no redundant confirmation; explicit bare ship produces none; autonomous landing produces
  exactly one; `--prepare` never asks to land; a mechanical contention retry does not ask again;
  changed batch/target/mode, semantic conflict, session reset, blocker, and genuine fork do. Manual
  mode retains only its required phase-switch prompts.
- **Landing and finalization.** Clean local shipment proves one selected gate, one successful target
  advance, one history row per unit, one ignored-state finalization, no tracked postflight write,
  and no mandatory Markdown save at feature completion. Push fixtures interrupt before and after
  every destination attempt and cover `clean`, `push-friction`, `partial-delivery`, `uncertain`, and
  `complete`, including a remote rejection after local advance and a friction-hook commit that
  makes its receipt stale by input mismatch. Divergent partial-delivery fixtures prove exact-tip and
  ancestry guards, typed replacement of stale receipts, conflict-free and conflicted two-parent
  reconciliation, semantic-authority invalidation, gate and hook treatment, same-shipment
  continuation, and a clean-path mutation proof that rejects any merge machinery. PR fixtures prove
  awaiting-merge state without premature completion. Ref rejection resumes preparation under the
  same shipment identity. Finalization interruption before and after the tracker commit point proves
  the operator note is idempotent and completion is never split across two authorities.
- **Recovery and migration.** Compaction recovery reads the bounded runbook brief plus a compact
  helper envelope, never the full runbook, inactive hook bodies, raw TSV, or deleted flow prose.
  Legacy linked and in-place migrations produce the two-file format directly. Quiescent tracker
  reconstruction succeeds from exact facts; active, ambiguous, dirty, unlanded, running, or
  uncertain recovery refuses. The live sibling stream named by the repository's current
  instructions is never opened or used as a fixture.
- **Scope guards.** Tests prove Workstream creates no required adapter/configuration, general event
  log, scratch cleanup surface, host state-reset logic, Callback runtime, or project-specific path
  map. Every absence guard is mutation-red-proved against a temporary source copy.

The refinement is complete when ordinary load and ship operations stay within their measured read
budgets; `WORKSTREAM.md` is a concise runbook; only the helper mutates `workstream.tsv`; preparation
is safely resumable and target-free; host semantics remain optional and zero-setup; eventful tracked
bookkeeping is included before the logical shipment completes; and the common successful shipment
is one authorization, one selected gate, one tracked target advance per destination, and one
ignored-state finalization.
