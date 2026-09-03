---
doctype: specs
status: published
schema: architect/spec@1
tags: [workstream, lifecycle, safety]
---

# Workstream worktree-only runtime and primary-checkout safety — Spec

This specification refines and composes with
→ `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md` and
→ `specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md`. Those specifications remain
authoritative for the `.streams` control surface, hooks, tracker, shipment preparation, delivery,
and history except where this later specification replaces their stream-topology, recovery,
landing-admission, and migration requirements. The three documents form one implementation target.

## Problem

Workstream currently treats a linked Git worktree and the primary checkout as two supported
execution environments. That choice is exposed as an `isolation` policy and spreads through
configuration, creation, runbook identity, bounded reads, admission, recovery, landing,
reconfiguration, migration, repair, close, cross-skill custody checks, and tests. `park` and
`unpark` add a second state machine so an in-place stream can temporarily surrender the primary
checkout and later reclaim it.

This bifurcation spends agent context and implementation complexity on the less safe behavior.
An in-place stream normalizes doing development work in the checkout shared by coordinators and
every other stream. Uncommitted files, staged entries, branch switches, and interrupted operations
then obstruct creation, synchronization, landing, and unrelated sessions. Parking reduces the
duration of custody but cannot remove the underlying shared-state hazard. It also introduces
extra save, branch, cleanliness, and recovery seams that an ordinary worktree does not need.

The composed implementation makes this cost visible in another way: `push` and `pr` landing are
currently coupled to in-place topology, while worktree streams are restricted to `local`. Removing
in-place execution without redesigning delivery would therefore make the safer topology less
capable. Conversely, retaining a constant `isolation: worktree` field or hidden compatibility mode
would preserve much of the bifurcation after its only active alternative disappeared.

Checkpoint cannot be retired in this change because Foreman still has an active integration with
it, but its current save guard scans sibling Workstream runbooks for the in-place topology this
specification removes. That obsolete custody adapter would become dead behavior and its fixture
would remain coupled to a field no current Workstream emits. Remove only that adapter while leaving
Checkpoint's persistence and recovery behavior intact. Workstream's own package must neither cite
nor depend on Checkpoint; its recovery contract is self-contained.

## Goal

Define a Workstream as one registered Git worktree at `<root>/.streams/<stream>` with its own
branch. The primary checkout is a coordination and integration surface, never a Workstream
execution environment. Active Workstream behavior has no topology mode, parking lifecycle, or
in-place custody branch.

Keep `local`, `push`, and `pr` as configurable landing policies for every workstream. Development,
preparation, and remote branch publication run from the stream worktree. Every Workstream-
controlled primary-checkout synchronization or integration-target update uses a clean, fail-fast,
repository-wide landing lease; an external PR merge is reconciled afterward rather than claimed as
a leased mutation. Recovery admits only the current worktree's top-level `WORKSTREAM.md` and shares
one bounded read path with explicit load.

Legacy topology knowledge exists only behind `/workstream migrate`. Linked legacy streams may move
to the new format; the presence of any in-place legacy stream refuses migration before mutation
with instructions to finish or close it. Checkpoint remains available with only its obsolete
in-place Workstream custody adapter removed; Foreman remains unchanged. No file under
`skills/workstream/` mentions Checkpoint.

## Approach

**Chosen: make the worktree the only runtime topology and make the primary checkout a guarded
integration endpoint.** The public API, current configuration, generated runbook, tracker grammar,
helper output, recovery anchor, and dependent skills describe one topology. Ordinary prose calls
it a _workstream_; it uses _worktree_ only when the Git mechanism matters. It does not repeatedly
qualify the standard as “isolated.” Hook context isolation remains a separate capability and keeps
its existing terminology.

The hard cut is completed before the composed Workstream implementation lands. Therefore the
current `@1` formats may lose the unshipped `isolation` field without an active-format migration or
version bump. The only migration source remains the previously shipped `.workstreams` layout.

Landing policy becomes orthogonal to topology. Bundled and project configuration provide a
default, creation accepts an explicit override, and quiescent reconfiguration may change it.
Target mutation is the narrow exception to primary-checkout non-use: it is serialized, compare-and-
swap guarded, requires a completely clean checkout, and must leave it clean. Other stream work does
not refuse merely because a foreign session has dirtied the primary checkout; it proceeds safely
in the worktree and stops only when integration requires the unavailable endpoint.

Alternatives rejected:

- **Keep in-place as a hidden or legacy-only runtime.** Hidden support retains conditional code,
  recovery ambiguity, and the unsafe escape hatch while making it harder for an agent to discover
  why behavior differs.
- **Retain `isolation: worktree` as a constant.** A policy with one legal value is not a policy. It
  spends bytes in every configuration, snapshot, projection, fingerprint, and test while inviting
  a second value to return.
- **Replace parking with `pause`.** An inactive worktree already persists. An agent may save one
  semantic note and later load the stream; another lifecycle state would add ceremony without
  changing custody.
- **Require a clean primary checkout for every stream operation.** That would let unrelated root
  dirt block safe worktree-local creation, building, synchronization, and preparation. Cleanliness
  is required only for operations that mutate or synchronize the integration target.
- **Queue or poll for landing access.** Waiting consumes agent time and introduces another durable
  scheduler. A losing stream can remain prepared and retry later from its existing state.
- **Retire Checkpoint in this change.** Foreman's active dependency would be broken. The package,
  registration, persistence, and recovery behavior remain intact until a later change can retire
  them together; this change removes only the stale in-place Workstream custody adapter.

## Mechanism

### One runtime topology

For an admitted stream named `STREAM`, these identities are invariant:

```text
runtime path       <root>/.streams/STREAM
branch             stream/STREAM
runbook             <root>/.streams/STREAM/WORKSTREAM.md
tracker             <root>/.streams/STREAM/workstream.tsv
Git topology        one registered linked worktree at the runtime path on the branch
```

`<root>` is the canonical primary checkout from Git's worktree registry, not the caller's current
directory. `WORKSTREAM.md` and `workstream.tsv` are top-level files from inside the stream worktree.
The existing shared-local exclusions and nested-runtime guards remain authoritative; ignore files
are still hygiene rather than a safety boundary.

The active helper admits exactly this topology. It validates the canonical paths, registered
worktree, branch, target, instance ID, runbook/tracker binding, and current operation before any
mutation. It never treats the primary checkout as the stream worktree and never searches
`.streams/*` to find a stream for the current session. From the primary checkout, named
coordinator operations resolve one exact runtime path without reading sibling runbook bodies.

No active grammar contains a stream-topology enum. Remove all of these public surfaces:

- `--in-place` and `--isolation` from `create` and helper usage;
- `isolation` from `CONFIG.md`, `WORKSTREAM.md`, policy provenance, fingerprints, `read`, and
  `reconfig`;
- `park` and `unpark` from the router, verb package, helper dispatch, state machine, and tests;
- `unpark` from every `next_action` grammar;
- primary-checkout custody, held-versus-parked classification, and in-place scanners;
- in-place branches from create, load, save, sync, ship, recycle, repair, status, close, and
  cross-skill Workstream detection.

Removed verbs and options receive the ordinary unknown-command or unknown-option refusal. Active
code does not carry tailored deprecation messages or compatibility aliases. The word _park_ may
still appear elsewhere in the library for unrelated concepts; the hard cut targets Workstream
custody behavior, not a repository-wide lexical ban.

### Configuration and lifecycle

The defaults block becomes:

```markdown
<!-- workstream:defaults@1 -->
mode: delegate
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->
```

Its keys remain closed and unique. `landing` accepts `local`, `push`, or `pr` for every stream.
Precedence remains explicit creation choice over project default over bundled default. Creation
accepts:

```text
/workstream create STREAM [SOURCE]
  [--mode delegate|manual]
  [--landing local|push|pr]
  [--ship-cadence milestone|per-track|per-stage]
```

The generated runbook records the effective landing value and its provenance with the other
current policies. The bounded `read` projection reports landing as policy, not as a topology
coordinate. Existing hook configuration, including `isolated-preferred` and `isolated-required`
context execution, is unchanged.

`/workstream reconfig [STREAM] --landing VALUE` remains legal only at a quiescent boundary. No
unit transition, prepared shipment, delivery receipt, unresolved hook, uncertain outcome, or
pending runbook hash may be active. Reconfiguration keeps the existing preview, fingerprint, and
race-recheck contract and does not change paths, branch, target, or instance identity.

An idle workstream needs no persisted paused state. Ending a session leaves its worktree, branch,
runbook, and tracker in place. `/workstream load STREAM` later resumes it. `/workstream save [NOTE]`
remains an optional semantic operation: it changes only the bounded operator note when intent not
captured by Git or `workstream.tsv` must survive a reset. It is not required before ending a
session, does not snapshot mechanical state, and does not enroll a separate root-session lifecycle.

### Self-contained recovery

The Workstream recovery anchor is self-contained and explains only the current-worktree layout. It
activates after context compaction or a continuation summary and examines only the current Git top
level:

- Without a top-level `WORKSTREAM.md`, it is inert. It does not scan `.streams`, inspect foreign
  sessions, or infer custody from the current branch.
- With a top-level `WORKSTREAM.md`, it invokes the Workstream current-checkout read path. The agent
  does not read the raw runbook or tracker.
- The helper validates that the current top level is the recorded, registered worktree and that
  immutable coordinates, branch, target, instance ID, runbook contract, tracker binding, and
  pending transaction agree.
- It emits the same bounded purpose, policy, operator note, queue, unit, shipment, hook, and
  `next_action` projection used by explicit load.
- The agent reconciles that projection with Git. Committed state and current files outrank saved
  semantic intent; the compaction summary supplies only later intent that does not contradict
  durable state. A known action continues without another user round trip; ambiguity or uncertain
  state stops.

The helper exposes one `read-current` operation taking the current worktree path. `read STREAM` and
`read-current WORKTREE` share the same admission and projection functions after identity
resolution. The anchor carries only the activation condition and call route; recovery judgment
lives in the on-demand Workstream path. No rotating token, singleton root file, automatic refresh,
or copy of another recovery discipline is added.

### Primary-checkout boundary

The primary checkout is a coordinator and integration surface. During ordinary stream execution,
Workstream may inspect it and may update shared Git administration needed to create or register a
worktree, but it does not edit project files there, stage its index, commit from it, switch it onto
a stream branch, or run build work there. Explicit control-surface maintenance remains governed by
`setup`, `repair`, `anchor`, and `reconfig`; it is not stream development.

`create`, `load`, `save`, unit work, hook work, `sync`, gate execution, and shipment preparation do
not require the primary checkout to be clean when their own inputs and mutation targets are safe.
They operate in the stream worktree and may bring work to `ready-to-land` while the primary
checkout is unavailable.

Before an operation advances or synchronizes the integration target through the primary checkout,
the helper must:

1. acquire the repository-wide landing lease without waiting;
2. revalidate the prepared candidate, expected target tip, configured landing policy, and delivery
   receipts;
3. require the primary checkout to be on the expected integration target when its working tree
   must be advanced;
4. require `git status --porcelain --untracked-files=all` to be empty, covering staged, tracked,
   and untracked dirt plus interrupted Git operations;
5. perform only the expected non-force target operation; and
6. verify the resulting ref, index, working tree, and cleanliness before releasing the lease.

Disjoint dirt is still dirt and blocks the transaction. A failed precondition changes no target
or delivery receipt and returns the prepared stream to the same resumable action. A target
compare-and-swap rejection records the existing shipment-friction fact. If an uncooperative
external process races after admission and the final state cannot be proved, the shipment becomes
`uncertain`; Workstream does not claim success or attempt an automatic rollback.

### Landing lease

The landing lease is one non-blocking, process-scoped advisory lock in the repository's shared Git
administrative area. It serializes Workstream target transactions across every linked worktree but
does not claim to lock arbitrary external Git processes. A supported host primitive must release
ownership when the process exits, including signal termination.

Acquisition has two outcomes:

- `acquired`: proceed with the bounded transaction and release ownership on every handled exit;
- `landing-busy`: report contention without requiring owner attribution, mutate nothing, perform no
  polling or sleep, preserve preparation evidence, and return `land` as the resumable action.

If the host has no supported non-blocking lock primitive, the helper refuses before target
admission or mutation with an ordinary capability diagnostic. Missing capability is not a landing
state, tracker record, or third acquisition outcome.

After an interrupted owner exits, a later owner may acquire the released lock but must still
reconcile target refs and delivery receipts before deciding whether the earlier transaction took
effect. Workstream never infers transaction outcome from lock ownership or stale metadata. The
lease is held only across target admission, mutation, and postcondition—not during building,
testing, hook execution, or ordinary agent reasoning.

### Worktree-native landing policies

All preparation, gate, hook, candidate commit, Gitlink publication, and remote branch commands use
the stream worktree. The landing policies retain the composed shipment and delivery receipts:

- **`local`.** Under the landing lease, compare the local target with the recorded expected tip and
  fast-forward the primary checkout exactly once to the candidate. Never update a checked-out
  branch behind its working tree, force a ref, or use the primary index to create a commit.
- **`push`.** Treat local target and remote target as the existing two ordered destinations. Under
  the landing lease, advance and verify the clean primary checkout first, then perform the guarded
  non-force remote update from the stream worktree. Rejections and interruptions retain the
  existing clean, push-friction, partial-delivery, and uncertain recovery classifications. The
  lease prevents another Workstream landing from interleaving with this local/remote transaction.
- **`pr`.** Push the stream branch and create or update the authorized pull request from the stream
  worktree; opening or updating the PR does not require a clean primary checkout because it does
  not advance the integration target. After external merge is verified, postflight acquires the
  landing lease and synchronizes the clean primary checkout to the merged target. If primary
  checkout admission fails, the merged shipment remains durably pending postflight and is not
  falsely finalized.

The lease does not broaden landing authority. Bare `ship`, `ship --prepare`, autonomous approval,
changed-contract invalidation, semantic conflict, and session-bound consent retain the composed
specifications' existing rules. A `landing-busy` result neither persists nor renews consent. The
current invocation's ephemeral authority survives a mechanical retry only while the same session
and bound inputs remain valid; a reset asks again, and no authority field is written to the tracker.

### Migration quarantine

The active runtime recognizes no legacy topology. All instructions for legacy conversion live in
`skills/workstream/verbs/migrate.md`. Legacy parsing and mechanics live in a migration-only helper
and migration tests; they are not sourced or interpreted by ordinary runtime commands. The router
contains only the neutral `migrate` dispatch entry.

`migrate inventory` examines the previously shipped `.workstreams` root. It performs no move and
publishes no manifest if any candidate is in-place, dirty, rebasing, divergent, symlinked,
colliding, unregistered, or otherwise uncertain. An in-place candidate receives one actionable
diagnostic: finish or close that stream with the legacy skill before retrying migration. A mixed
population refuses as one inventory; eligible linked streams are not moved around an unsupported
in-place stream.

When every candidate is a quiescent registered linked worktree, inventory and attended
`migrate apply` retain the composed migration transaction: persistent manifest, exact rechecks,
`git worktree move`, branch and committed-work preservation, runbook/tracker installation, stage
resumption, registry validation, and removal of the old root only when empty. Translation consumes
the legacy `isolation: worktree` value but emits no current `isolation` field. No operation imports
an in-place handoff, parks a branch, or switches the primary checkout to complete migration.

No other verb, template, current helper path, active configuration example, dependent-skill
custody rule, or recovery text may mention `.workstreams`, in-place Workstreams, parking custody,
or retired topology flags. Historical records remain unchanged. A source guard owns the exact
allowlist for migration files and its own test fixture so compatibility cannot leak back into the
active skill.

### Active consumers and non-goals

Current `debugger`, `delegate`, `journal`, and `notepad` custody rules simplify to the same
top-level `WORKSTREAM.md` admission signal when they operate inside a stream. They remove branch-
matched in-place scans and never inspect a sibling runtime from the primary checkout. Checkpoint's
save guard retains that top-level signal but removes its `.streams/*/WORKSTREAM.md` scan, in-place
facts, related prose, and template-derived in-place fixture. Its save, resume, close, and recovery
contracts otherwise remain unchanged. Library guidance and the package seam map describe
Workstream as worktree-owned without altering Foreman's runtime choices.

This change intentionally does not:

- delete, deprecate, migrate, install, or otherwise redesign the `checkpoint` skill beyond removing
  its obsolete in-place Workstream custody adapter;
- alter Foreman's goal ownership, recovery, or Workstream bridge;
- rename hook context isolation or change hook execution and fallback behavior;
- change the `.streams` control-home decision, zero-setup creation, hooks, `workstream.tsv`,
  shipment identities, gate semantics, history rows, or partial-delivery reconciliation except as
  required by the single topology and landing lease;
- add a pause state, landing daemon, retry queue, polling loop, force update, automatic lock theft,
  or general repository mutex; or
- rewrite historical specs, plans, ADRs, reviews, or migration evidence.

## Verification

- **Hard-cut population.** A contract test enumerates active Workstream instructions, verbs,
  templates, runtime helpers, generated control files, the root `AGENTS.md` Workstream anchor, and
  current custody prose and helpers in `checkpoint`, `debugger`, `delegate`, `journal`, and
  `notepad`. It prints the included paths before asserting zero Workstream-topology occurrences of
  `in-place`, `--in-place`, `--isolation`, an `isolation` config/runbook row, `park`/`unpark`
  commands, and `unpark` actions. A separate assertion requires zero case-insensitive `checkpoint`
  references anywhere under `skills/workstream/`.
  The only literal legacy population is the exact migration verb, migration-only helper,
  migration tests, and the source guard itself. Hook-isolation terms and unrelated uses of _park_
  are explicitly outside this population. Mutation-red fixtures inject each retired topology
  construct into an enumerated temporary active source and require the guard to fail.
- **Configuration and creation.** Fresh zero-setup and initialized fixtures prove all three landing
  defaults and explicit overrides create registered worktrees with no isolation field. Removed
  flags and verbs fail as unknown; malformed current config containing `isolation` fails rather
  than degrading. Reconfiguration changes landing only at the defined quiescent boundary and
  preserves immutable identity.
- **Topology and lifecycle.** Tests prove every successful create has the canonical path, branch,
  Git worktree registration, top-level runbook, bound tracker, and nesting exclusions. No runtime
  command changes the primary checkout's branch or develops files there. Save changes only the
  bounded operator note; ending and loading an idle stream require no park state.
- **Recovery.** Compaction fixtures with zero, one, and foreign top-level runbooks prove the anchor
  is inert outside the current stream, never scans `.streams`, and never reads a raw runbook or
  tracker into agent context. `read-current WORKTREE` and named `read STREAM` emit byte-equivalent
  projections after identity resolution. Coordinate, instance, branch, tracker, transaction, and
  Git mismatches refuse before continuation. Existing router, per-operation, scaffold, and
  envelope byte budgets must not increase. Instrumented mutation-red fixtures introduce a sibling
  scan and raw runbook/tracker projection into temporary recovery sources; each prohibited access
  must make the contract fail.
- **Primary-checkout admission.** Separate fixtures stage a file, modify a tracked file, add an
  untracked file, start an interrupted Git operation, move the target, and switch the primary
  branch. Each still permits safe worktree-local operations and shipment preparation, but every
  applicable target advance or synchronization refuses without mutation. A clean transaction
  leaves the target, index, working tree, and status consistent. Race injection between admission
  and mutation produces rejection or `uncertain`, never an unsupported success claim.
- **Landing lease.** Two simultaneous Workstream landing attempts against one repository yield
  exactly one owner and one immediate `landing-busy` result. The loser retains the same prepared
  shipment, evidence, and next action. A same-session mechanical retry reuses still-valid ephemeral
  authority; a reset retries only after renewed authority, and the tracker never stores consent.
  Success, handled failure, and signal fixtures prove process-scoped release, while recovery still
  derives transaction outcome from refs and receipts. A host with no supported primitive receives
  an ordinary pre-mutation capability refusal with no new tracker state or landing classifier. No
  test waits or polls for ownership.
- **Landing policies.** Local, push, push-rejection, partial-delivery, PR-open, PR-merge, and
  postflight-recovery fixtures run from registered stream worktrees. They prove the existing
  expected-tip, non-force, receipt, hook, gate, history, and one-finalization rules while enforcing
  the clean primary-checkout boundary. PR publication proceeds with a dirty primary checkout, but
  merged-target synchronization and finalization wait for clean leased admission.
- **Migration.** Linked-only fixtures preserve branches, commits, queue state, hook snapshots, and
  resumable manifest stages while emitting the field-free current format. In-place-only and mixed
  inventories report every unsupported stream and leave the manifest, paths, branches, registry,
  primary checkout, and current runtime bytes unchanged. Mutation proofs change the inventory,
  branch tip, handoff, target, or destination between inventory and apply and require refusal.
- **Integration gates.** The complete Workstream, Checkpoint, hard-cut, Backlog hook, Skill Builder,
  repository integration, ShellCheck, whitespace, live-root, read-budget, and mutation-red suites
  pass. Checkpoint tests prove top-level Workstream refusal without scanning sibling runtime files
  or deriving fixtures from Workstream templates. The tests run only against throwaway repositories
  and never migrate or inspect live sessions under the developer's primary checkout.
