---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Grimoire Phase 4 transactional core operations — Implementation Plan

Turn the Phase 2–3 pure plans and custody primitives into one headless transaction engine. The
first slice takes one already-trusted, already-materialized direct skill through the real planner,
stale-precondition revalidation, scope journal, temporary symlink, atomic link/state commit, and
cleanup. Later slices widen that exact path across source registration/removal, trust, all desired
state requests, fault recovery, world loading and check, project indexing, and conservative prune.
No slice introduces command grammar or presentation policy; Phases 5 and 6 remain adapters over
the completed core contract.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 4 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Run `git -C /Users/cscott/Repos/grimoire/.workstreams/app status --short --branch`,
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app log stream/app..main --oneline`, and
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app worktree list --porcelain`. Stop for staged
  state, movement on `main`, or a sibling stream that owns transaction, apply, recovery, check,
  project-index, prune, or shared-lock work.
- Run
  `/Users/cscott/Repos/grimoire/.workstreams/app/skills/contractor/scripts/ground-check.sh /Users/cscott/Repos/grimoire/.workstreams/app /Users/cscott/Repos/grimoire/.workstreams/app/.records/specs/2026-08-31-grimoire-symlink-package-manager.md`.
  Confirm that the spec and roadmap remain `published`, then re-read Scope and paths; Manifest;
  Lock; Source identities, fetching, and snapshots; Trust and capability review; Plans,
  confirmation, and frozen mode; Ownership and collisions; Planner/executor API; Transactions and
  recovery; and State, plans, and transactions verification. Re-read the roadmap's Phase 4 scope,
  gate, risks, and strict dependency on Phase 3.
- Re-read `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
  `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/plan.rs`,
  `crates/grimoire-core/src/manifest.rs`, `crates/grimoire-core/src/lockfile.rs`,
  `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/locks.rs`,
  `crates/grimoire-core/src/store.rs`, `crates/grimoire-core/src/trust.rs`,
  `crates/grimoire-core/src/source/candidate.rs`,
  `crates/grimoire-core/src/source/workflow.rs`, and `crates/grimoire/src/runtime.rs` against
  `HEAD`. At plan time `Action` covers manifest, lock, trust, materialization, and links but not
  candidate or prune state; `Preconditions` are values produced by tests rather than a production
  loader; `MaterializationIntent` is the only plan-gated bridge into the store; the ordered lock
  coordinator is crate-private and deliberately marked pending Phase 4; and there is no `apply`,
  scope journal, `recover`, `load_world`, `check`, project index, or prune implementation.
- Search compiled crates and active tests for `ApplyOutcome`, `RecoveryOutcome`, `CheckReport`,
  `StalePlan`, `Approval`, `projects.json`, `grimoire/projects@1`, `scope-journal`, `prune`,
  `symlink`, `rename`, `remove_file`, and `remove_dir_all`. Search history only for a specific reuse
  claim. The deleted alpha install/remove choreography and source-path ownership rules are
  incompatibility evidence; do not restore, rename, or wrap them.
- Reconfirm the Phase 3 seams instead of duplicating them: candidate and review parsing rederive
  keys; `CandidateWorkflow` owns fetch publication; `MaterializationIntent::from_action` is the
  only store entry point; store repair has its own journal; trust mutations produce proposed exact
  bytes; and `LockCoordinator` enforces `candidate`, `cache`, `store`, `trust`, `projects`, then
  scope. Phase 4 may widen these APIs deliberately but must not create another hash, inventory,
  trust, source, or lock authority.
- Re-measure with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core -- --list`
  and
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo check --workspace`.
  The planning baseline has 63 core tests and a green workspace check. Amend this plan instead of
  coding around a changed API, test count, or already implemented capability.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published hard cut.** The published spec and approved roadmap remain the product, persistence,
  and sequencing authority. No alpha install log, live-library configuration, agent target,
  immediate install/remove API, compatibility reader, migration, force/adopt path, source catalog,
  registry, or hidden fetch may return.
- **Phase boundary.** Phase 4 owns production world observation, checking, execution of every
  mutating `Request`, scope transactions and recovery, owned links, stale-plan refusal, the project
  index, and conservative store prune. It may add the narrow production nonce/time/fault boundary
  needed to construct the executor once in `skill-grimoire`. It does not parse commands, decide
  TTY confirmation, render plans/findings, implement TUI state, or remove adapter-era residue that
  cannot be deleted until Phases 5–7.
- **One planner, one executor.** Every mutation of desired state, locks, trust, installed links,
  store reachability, or a source-add/remove candidate is represented by a serializable `Action`
  from the pure planner. The published exceptions remain narrow: standalone fetch/inspection and
  source-add preparation mutate only replaceable cache/review evidence, existing-source fetch may
  publish its inert candidate through `CandidateWorkflow`, and successful project observation may
  refresh only `projects.json` through the projects authority. Planned materialization still
  requires its exact action. `apply` accepts only an unblocked plan, never refreshes or replans, and
  rejects an unsupported, malformed, wrong-scope, or internally inconsistent action set before the
  first planned mutation. Frontends can grant or decline destructive approval but cannot inject an
  action, target path, candidate, trust byte sequence, or prune deletion. Additive plans need no
  approval; destructive plans require explicit `Approval::Granted`; decline returns a successful
  cancelled outcome and changes nothing.
- **Stale means inert.** Under the applicable locks, re-observe every serialized precondition:
  manifest/lock presence and byte hash, candidate absence or exact bytes/identity, store
  existence/integrity, trust absence or revision, link kind/raw target, project-index revision,
  journal set, and prune reachability inputs. Any mismatch returns the stable `StalePlan` class
  without mutation. `--yes` is adapter policy and can never weaken this check.
- **Prepared source registration.** Existing-source `fetch_source` remains the inert Phase 3
  workflow. Source add first calls `prepare_source_add` with resolved paths, one immutable world,
  alias, and source value. That workflow derives the exact proposed manifest edit and declaration
  hash, then may populate bare cache and review export, but publishes no declaration, candidate,
  trust, lock, link, or store state. Its opaque `PreparedSource` binds the observed manifest hash,
  exact
  before/after manifest bytes, alias, declaration hash, canonical identity, verified candidate
  bytes, and review location. Only a plan may turn it into `ReplaceCandidate`; source
  removal plans `RemoveCandidate`. Same-scope identity uniqueness is rechecked during planning and
  apply. A combined exact/all trust shortcut carries proposed trust bytes in that same plan; it is
  not an approval flag.
- **Typed link and trust intent.** Hard-cut link actions from arbitrary `PathBuf` targets to
  `OwnedLinkTarget::{Stored { source_key, snapshot_key, skill_path }, Live { identity,
  skill_path }}`; the executor derives the absolute target and refuses mismatches with lock/source
  state. Hard-cut caller-populated exact/all receipts and baselines to `Request::TrustSource {
  alias, mode }`, where the planner derives identity, receipt, and baseline only from the world's
  validated candidate. `RevokeTrust { source_key }` remains identity-wide and derives proposed
  bytes from the parsed trust authority.
- **Materialization precedes state transaction.** Replace the Phase 3 action with typed
  `Action::PrepareSnapshot { operation: SnapshotPreparation::{Materialize, Repair}, ... }` and
  derive `MaterializationIntent` only from that exact action. Verify review objects and
  source/snapshot/review keys; materialize or run the separate store-repair protocol before
  acquiring scope-state locks. Failure may leave
  only an unreferenced verified store entry or recoverable store-repair journal. Update never
  fetches, and frozen restore never consults candidate/cache/baseline state.
- **Ordered custody.** Preserve typed acquisition order: the scope/alias candidate mutex, when a
  planned candidate create/remove needs it, is acquired first; cache remains exclusive to fetch;
  shared-state locks are `store`, `trust`, `projects`, then scope. Ordinary scoped applies take
  shared store and trust leases, project applies take exclusive projects custody before their
  exclusive scope lock, a plan containing trust mutation selects exclusive trust before
  acquisition, and prune takes exclusive
  store and projects locks. No wait for an earlier rank while holding a later one. Lock files live
  only below resolved `Paths::grimoire_home`.
- **Directory-relative ownership.** Core derives every manifest, lock, candidate, trust, project
  index, journal, store, and installed-link path from validated `Paths`, keys, aliases, and skill
  names. It opens scope and link-parent directories without following symlink components, performs
  sibling temporary writes and mutations relative to held directories, and revalidates directory
  identity through commit. The scope lock serializes Grimoire writers. Immediately before each link
  mutation, core re-reads the destination through the held parent and requires the exact raw
  lock-owned symlink from the plan; absent creation uses a no-replace operation. Any external change
  observed at that final ownership decision returns `StalePlan` without moving, replacing, or
  unlinking the foreign entry. A foreign symlink, file, directory, changed owned link, swapped
  parent, or outside canary blocks and remains byte-identical. No general path from a plan or
  journal reaches an open, rename, unlink, or recursive deletion.
- **Journal is the commit authority.** The strict private `grimoire/transaction@1` adapter rejects
  unknown/duplicate fields and records the scope key, transaction identity, plan digest, complete
  before/after manifest/lock/candidate/trust bytes and presence, raw link targets, ordered action
  states, and commit phase. It stores derived identities, never arbitrary absolute mutation paths.
  Create-new and fsync the journal before mutation; fsync each staged regular file and every
  affected parent directory (symlink durability comes from its parent fsync). Durably mark action
  transitions and commit. Ordinary failure rolls back. Recovery validates all
  derived paths and bytes, rolls back an uncommitted journal, rolls forward cleanup once recorded
  state hashes have committed, and is idempotent after every injected fault.
- **Commit ordering.** Stage complete files and replacement links before publication. Publish links
  before manifest/lock state. Source add/remove commits manifest before candidate create/remove. A
  combined source add plus exact/all trust commits manifest, candidate, then atomically staged
  trust bytes, so no crash-visible state trusts an uncommitted registration. Standalone trust is
  one staged, fsynced rename under the exclusive trust lock and needs no scope journal when it has
  no other action. Mark the journal committed before project-index refresh and cleanup.
- **Loader and check are observational authorities.** `load_world` uses injected Git, resolved
  paths, and the explicit runtime boundary but never fetches. It parses exact
  manifest/lock/candidate/trust bytes, reconstructs locked snapshots from immutable store and cached candidates from their
  pinned Git objects or held live roots, validates identity/declaration/inventory/review facts, and
  observes links without following them. Before a link can be considered healthy, re-hash every
  referenced stored skill against its lock content digest without requiring cache/review data.
  `check` reports stable sorted facts for mismatch, trust, store corruption, links, source
  metadata, and pending journals; it never recovers or changes managed scope/store/trust state.
- **Project index is conservative bookkeeping.** The strict deterministic private
  `grimoire/projects@1` adapter records canonical raw project path with UTF-8/base64 projection,
  scope key, exact lock hash, sorted `(source-key, snapshot-key)` references, and injected
  last-observed Unix time. A successful project load/apply refreshes it atomically under
  `projects.lock`. Prune refreshes every readable indexed or explicitly supplied project; missing,
  unreadable, malformed, or concurrently changed projects retain their last-observed references
  and produce findings. Project-index bookkeeping never edits a project manifest/lock/link.
- **Prune proves unreachability.** `Request::Prune` consumes an immutable reachability observation
  in `WorldState` and produces only derived `PruneSnapshot` actions plus blockers/findings. Retain
  snapshots referenced by global lock, every current/readable or last-observed project record,
  current candidate metadata, scope/store-repair journals, or any malformed/uncertain entry.
  Apply holds exclusive store and projects custody through full precondition revalidation and
  removes only a source-key/snapshot-key directory proven unreachable. Confirmation cannot turn an
  uncertain snapshot into a deletion.
- **Check and recovery outcomes are data.** New shared public values (`Approval`, `ApplyOutcome`,
  `RecoveryOutcome`, `RecoveryDisposition`, `CheckReport`, `CheckFinding`, `OwnedLinkTarget`,
  `PreparedSource`, `SourceTrustIntent`, `SnapshotPreparation`, project/reachability observations,
  and runtime traits)
  derive `Debug`, `Clone`, `PartialEq`, and `Eq` where possible. Key/enum values also derive
  `Hash`, `Ord`, and `PartialOrd` when used in sets/maps. Domain values
  do not derive wire schemas merely for convenience; private adapters own exact field names and
  sorting.
- **Injected fault/time boundary.** Core owns transaction decisions and mutations. A narrow runtime
  trait supplies a unique transaction nonce, Unix timestamp, and named fault checkpoints. Its
  test-only crash disposition interrupts apply without running ordinary rollback or cleanup, while
  ordinary errors continue to roll back; the app crate provides the one production implementation
  whose checkpoints always continue. Tests use deterministic time, temporary roots, barriers, and
  crash injection, assert the durable partial journal/state before restart, then recover with a
  fresh runtime. Core still reads no environment, cwd, process arguments, TTY, CLI, or UI state.
- **Red proofs.** Each absence/security guard has a controlled failing arm: stale precondition,
  blocked-plan execution, destructive approval, foreign occupancy, changed owned link,
  directory swap/no-follow, journal path containment, pre/post-commit recovery, candidate commit
  order, trust-last ordering, store digest, frozen-network absence, project uncertainty, prune
  reachability, and lock inversion. A green negative assertion without a fixture that can exercise
  the forbidden outcome is not sufficient.
- **Dependencies and portability.** Keep synchronous macOS/Linux support. Reuse `serde_json`,
  `sha2`, `rustix`, and the existing Phase 3 custody code. Keep `tempfile` test-only. Do not add an
  async runtime, database, daemon, shell parsing, `walkdir`, copy abstraction, presentation crate,
  second transaction library, or another inventory/hash implementation.
- **Tree custody and gate.** Every non-Git command runs with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && ...`; every Git command uses
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app`; the main session is the sole writer.
  Every slice begins red, ends with its targeted test and
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo check --workspace`
  green, and commits coherently. This common workspace check applies after every slice without
  being repeated below. The phase gate includes formatting, workspace tests, clippy, Skill Builder
  lint/tests, repository integrations, pack dogfood/availability, both worktree/root layout probes,
  and production hard-cut searches.

## Slices

- [x] **Slice 1: One trusted stored skill crosses the transaction boundary** <requires: —>
  - Files: create `crates/grimoire-core/src/apply.rs`,
    `crates/grimoire-core/src/transaction/mod.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`, and
    `crates/grimoire-core/tests/transaction_tracer.rs`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/tests/tracer.rs`, `crates/grimoire-core/tests/planner.rs`,
    `crates/grimoire-core/tests/planner_source.rs`, `crates/grimoire-core/tests/resolution.rs`,
    `crates/grimoire-core/tests/boundary.rs`,
    `crates/grimoire-core/tests/fixtures/planner/noop-plan.json`,
    `crates/grimoire/src/runtime.rs`, and `crates/grimoire/src/lib.rs`.
  - Change: add public `Approval`, `ApplyOutcome`, and `TransactionRuntime` contracts, with the
    required trait floor, plus `SystemRuntime` in the app crate for nonce/time and no-op fault
    checkpoints. The runtime checkpoint contract distinguishes `Continue` from a test-only crash
    interruption; crash interruption returns control to the harness without invoking the ordinary
    rollback/cleanup path, while production can construct only `Continue`. Extend `CoreError` with
    stable stale-plan, blocked-plan, approval, transaction, and recovery classes. Add derived
    transaction directory/journal/temp/link paths to `Paths` and remove the Phase 4 dead-code
    allowances from lock/store modules only as each path becomes live.

    Hard-cut the link actions in `plan.rs` to the typed `OwnedLinkTarget` contract and update the
    Phase 2–3 planner fixtures in this slice; no executor accepts a serialized absolute target.
    Build the thinnest real executor around an existing `Request::Reconcile` plan for one direct
    skill whose exact snapshot is already trusted and valid in the immutable store. Preflight the
    whole plan; derive and acquire shared store/trust then exclusive projects/scope locks; recover
    or refuse an incumbent journal; re-read manifest, lock, trust, store-skill digest, link, and
    directory observations; and return `StalePlan` before mutation on any mismatch. Serialize and
    create-new/fsync the strict journal with complete before/after bytes and ordered action state.
    Stage the replacement lock and replacement-link data and fsync the regular file. Through the
    held link-parent directory, revalidate its identity and immediately re-read the destination:
    create uses a no-replace operation, while retain requires the exact raw lock-owned target
    observed by the plan. Publish the created link, then the lock, mark committed, fsync parents,
    and remove
    journal/temporaries. Re-derive the absolute link target from the action's validated
    source/snapshot/path tuple and require it to equal the lock-derived target; disagreement is an
    invalid plan. `Approval::Declined` returns
    `ApplyOutcome::Cancelled`, and a destructive plan without `Granted` is inert. Slice 1 supports
    exactly retain/create link and
    lock replacement actions; any other action set is rejected during preflight before the journal.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test transaction_tracer`.
    The tracer plans then applies one direct skill, observes the exact immutable-store symlink and
    lock bytes, re-applies as a no-op, and proves stale manifest/lock/link/store/trust and a foreign
    destination are all inert. A barrier creates or swaps the destination after plan/preflight
    observation but before final ownership revalidation and proves the foreign entry remains
    byte-identical. Its red arms bypass one precondition, final ownership revalidation, or
    target-derivation comparison in the fixture and reach the outside/wrong-target canary.

- [x] **Slice 2: Execute the complete request, candidate, trust, and link action matrix** <requires: 1>
  - Files: create `crates/grimoire-core/tests/apply_matrix.rs` and source/apply fixtures under
    `crates/grimoire-core/tests/fixtures/transaction/`; modify
    `crates/grimoire-core/src/apply.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/manifest.rs`,
    `crates/grimoire-core/src/locks.rs`, `crates/grimoire-core/src/store.rs`,
    `crates/grimoire-core/src/trust.rs`, `crates/grimoire-core/src/source/candidate.rs`,
    `crates/grimoire-core/src/source/workflow.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`,
    `crates/grimoire-core/src/transaction/mod.rs`,
    `crates/grimoire-core/tests/planner.rs`,
    `crates/grimoire-core/tests/planner_source.rs`,
    `crates/grimoire-core/tests/trust.rs`, and
    `crates/grimoire-core/tests/source_boundary.rs`.
  - Change: introduce opaque `PreparedSource` and typed `SourceTrustIntent::{Untrusted, Exact,
    All}`. Add `prepare_source_add(paths, world, alias, source, runner)`: it produces the deterministic
    manifest edit first, derives the declaration hash from those exact proposed bytes, and then
    lets Git/local inspection update only cache and review export before returning the bound value
    without candidate publication. Retain `fetch_source` as prepare plus declaration-revalidated
    candidate publication for an already registered alias. Hard-cut `Request::AddSource` to require
    the prepared value and trust intent. The pure planner recomputes the manifest edit/declaration
    hash and requires byte equality with the prepared binding before emitting any action.
    Simultaneously replace `Request::TrustExact` and
    `Request::TrustAll` with candidate-selecting `Request::TrustSource { alias, mode }`; the planner,
    not the caller, derives canonical identity, exact receipt when applicable, and the explicit
    approval baseline. Live exact trust remains invalid and live all-trust writes no exact receipt.
    Validation findings do not block source registration, candidate publication, or explicit
    trust; they continue to block any action that creates or repoints a link.
    The planner verifies alias/declaration/canonical identity/review bindings and same-scope
    identity uniqueness, then emits `ReplaceManifest`, `ReplaceCandidate`, and optional
    `ReplaceTrust` in normative order. `Request::RemoveSource` emits manifest then candidate removal
    and remains blocked while a request root names the alias. Candidate actions serialize only
    exact bytes plus scope/alias/source identity; paths remain derived. Candidate absence/exact hash
    and identity become explicit preconditions.

    Widen executor preflight, staging, journal entries, rollback data, and application to every
    existing action: create/replace manifest and lock; create/retain/repoint/remove owned links;
    replace trust with mode `0600`; replace/remove candidate; and plan-gated snapshot preparation.
    Hard-cut `MaterializeSnapshot` to `PrepareSnapshot` with explicit `Materialize` versus `Repair`;
    a trusted materializable corrupt snapshot may repair online, while frozen or unavailable
    corruption remains blocked. Execute materialization/repair before the state transaction,
    reverify the resulting snapshot under the shared store lease, then apply links/state.
    Initialization uses
    create-new manifest and lock and refuses any incumbent bytes. Standalone trust-only plans take
    exclusive trust custody and one staged/fsynced atomic rename without a scope journal. Scoped
    candidate create/remove takes the pair mutex first and holds it through commit. Ensure all
    desired-state requests—initialize, reconcile, skill/pack install and uninstall, exclusion
    replacement, cached source update, source add/remove, exact/all trust, baseline advance, and
    revoke—reach no mutation except through this action interpreter.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test apply_matrix --test candidate --test planner --test planner_source --test trust`.
    Matrices cover project/global initialization, loose skill and pack install, shared-member
    retention, exclusions, uninstall, multi-skill cached update without Git, live links, source
    add/remove with absent/existing candidate, exact/all trust shortcuts, baseline movement, revoke
    without uninstall, every link occupancy state, and additive/destructive approval. Preparation
    tests prove cache/review may change while manifest/candidate/trust/store/links do not; disabling
    the plan-gated candidate or materialization constructor exposes its mutation canary.

- [x] **Slice 3: Crash-safe rollback, roll-forward, and candidate/trust ordering** <requires: 2>
  - Files: create `crates/grimoire-core/tests/transaction_recovery.rs` and transaction goldens under
    `crates/grimoire-core/tests/fixtures/transaction/`; modify
    `crates/grimoire-core/src/apply.rs`, `crates/grimoire-core/src/transaction/mod.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`,
    `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/error.rs`, and
    `crates/grimoire-core/src/lib.rs`.
  - Change: complete the canonical journal adapter and expose `recover(paths, runtime)` returning
    `RecoveryOutcome` with sorted `RecoveryDisposition` facts. The journal rederives every managed
    location from scope/key/name values and cross-checks plan digest, before/after hashes, action
    order, and durable phase. It rejects unknown/duplicate fields, malformed raw-target fallback,
    absolute/traversing temporary names, scope mismatch, wrong state mode, and any store-repair
    journal. Journal creation, every action transition, committed marker, staged state/link writes,
    renames/unlinks, directory fsync, project-index handoff, and cleanup each receive named fault
    checkpoints.

    On an ordinary error before commit, restore exact before state and owned link targets and leave
    foreign/unproven paths untouched; return the original error only after rollback succeeds, else
    a recovery-required error with the durable journal retained. On restart, a journal whose
    complete recorded state-file set has not reached its after hashes rolls back exact before
    state, including any manifest/candidate/trust prefix. Only a journal whose complete state-file
    set—including candidate and trust when applicable—has reached its after hashes may finish the
    durable commit marker, project-index handoff, and cleanup; recovery never publishes remaining
    candidate or trust bytes as post-commit cleanup. Recovery is idempotent after every prefix.
    Enforce manifest-before-candidate for source add/remove and
    manifest→candidate→trust for combined registration/trust. A crash may expose a registered
    source without candidate or trust, never candidate for an absent registration after completed
    recovery and never trust for a registration that did not commit. Removal rollback restores the
    exact candidate bytes. Do not interpret or recover Phase 3 store-repair journals here.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test transaction_recovery`.
    A fault matrix uses the crash disposition before and after every
    journal/write/fsync/rename/unlink/mark/cleanup seam for create, repoint, remove, source add,
    source remove, combined trust, and standalone trust; it asserts the retained journal and exact
    partial state before restarting with a fresh runtime. Two repeated recoveries yield either the
    exact before state or complete after state with no mixed links/files. Tampered journal paths
    cannot touch an outside canary. Controlled wrong commit ordering demonstrates the forbidden
    trust/candidate intermediate.

- [x] **Slice 4: Production world loading, read-only check, and offline frozen restore** <requires: 3>
  - Files: create `crates/grimoire-core/src/world.rs`, `crates/grimoire-core/src/check.rs`,
    `crates/grimoire-core/tests/world.rs`, `crates/grimoire-core/tests/check.rs`, and loader fixtures
    under `crates/grimoire-core/tests/fixtures/world/`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/store.rs`,
    `crates/grimoire-core/src/source/git.rs`, `crates/grimoire-core/src/source/local.rs`,
    `crates/grimoire-core/src/source/review.rs`, `crates/grimoire-core/src/scope.rs`, and
    `crates/grimoire/src/runtime.rs`.
  - Change: implement `load_world(paths, git, runtime)` as the one production observation path.
    Read manifest/lock/trust/candidate bytes with explicit absent/present hashes; reject malformed
    state rather than fabricating defaults except the explicit uninitialized scope. For each locked
    Git snapshot derive source/snapshot keys only from lock commit/tree/inventory, inventory the
    immutable store without following links, and verify every referenced skill content digest,
    normalized mode, link boundary, and exact lock target. For live lock sources, hold/revalidate
    the original root and observe current bytes. For candidates, cross-check outer scope/alias,
    declaration hash and canonical identity, load/reverify review export, and reconstruct inventory
    without network access from the fixed bare cache/private commit or held live root. A missing
    candidate/cache is an observation/blocker, never an implicit fetch. Observe installed links via
    no-follow metadata and raw symlink targets; never open foreign destinations.

    Add sorted `CheckReport`/`CheckFinding` domain values and `check(world)` covering manifest-lock
    resolution mismatch, invalid candidate/source metadata, missing/corrupt stores, untrusted active
    sources, missing/exact/drifted/foreign links, shadowing context, unavailable optional members,
    and pending/recoverable scope or store-repair journals. Check never invokes recovery or writes
    scope/store/trust/candidate/link bytes. Connect frozen reconcile to loaded lock-derived states:
    no candidate/cache/baseline lookup, no Git command, no live source, exact stored snapshot only,
    and link repair only after stored skill verification.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test world --test check --test planner_source --test resolution`.
    Fixtures cover initialized/absent project and global scopes, malformed state, candidate/cache
    absence, pinned and live observations, invalid UTF-8 link targets, every ownership/drift state,
    corrupt referenced skill, pending journals, trust states, and deterministic finding order. An
    offline frozen fixture removes cache/review/candidate data, leaves several store snapshots and
    a different trust baseline, performs zero Git calls, and repairs only the lock-derived link.
    Red arms follow a foreign link or skip stored-skill verification and read the canary/call the
    wrong target.

- [x] **Slice 5: Durable project index and cross-scope transaction concurrency** <requires: 4>
  - Files: create `crates/grimoire-core/src/projects.rs`,
    `crates/grimoire-core/tests/project_index.rs`, and
    `crates/grimoire-core/tests/transaction_concurrency.rs`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/apply.rs`, `crates/grimoire-core/src/world.rs`,
    `crates/grimoire-core/src/transaction/mod.rs`, `crates/grimoire-core/src/locks.rs`,
    `crates/grimoire-core/src/scope.rs`, and `crates/grimoire/src/runtime.rs`.
  - Change: implement strict deterministic `grimoire/projects@1` parsing/writing. Each record is
    keyed by scope key and carries exactly one canonical path projection (UTF-8 or base64 raw Unix
    bytes), exact lock hash, sorted unique `{source_key, snapshot_key}` references, and injected
    integer last-observed time; parsing rederives the scope key and validates every key/reference.
    Missing index means an empty authority; malformed existing bytes fail closed. Under exclusive
    projects custody, atomically refresh the project record after any successful project load and
    after a committed project apply, preserving unrelated records byte-semantically. If refresh
    fails after state commit, retain the committed scope journal so recovery can finish it. Global
    load/apply never writes a project record.

    Complete lock-mode selection and concurrent execution: ordinary non-trust project/global
    applies share store/trust, distinct project scopes serialize only themselves, project apply
    takes projects before scope, candidate actions take their pair mutex first, trust writes take
    exclusive trust, store materialization releases its exclusive preparation lease before the
    state-lock set, and recovery reacquires the same ranks from journal contents. Add barrier-based
    tests for independent projects, project/global, apply/fetch, apply/trust, candidate removal/fetch,
    and recovery/apply; forbidden inversions fail before waiting.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test project_index --test transaction_concurrency`.
    Goldens cover UTF-8/raw paths, sorting, key cross-checks, malformed state, atomic refresh, and
    refresh-after-crash. Concurrency tests prove allowed operations overlap, conflicting operations
    serialize, and no paused later-rank holder waits for an earlier lock. Disabling projects custody
    loses an indexed reference in the red arm.

- [ ] **Slice 6: Conservative reachability planning and destructive prune** <requires: 5>
  - Files: create `crates/grimoire-core/src/prune.rs`,
    `crates/grimoire-core/tests/prune.rs`, and prune fixtures under
    `crates/grimoire-core/tests/fixtures/prune/`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/apply.rs`,
    `crates/grimoire-core/src/projects.rs`, `crates/grimoire-core/src/world.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`,
    `crates/grimoire-core/src/locks.rs`, and `crates/grimoire-core/src/scope.rs`.
  - Change: add `Request::Prune`, immutable reachability observations on `WorldState`, derived
    `Action::PruneSnapshot { source_key, snapshot_key }`, and serialized preconditions for the
    exact store generation, global lock, project-index bytes, every refreshed project lock, current
    candidate set, and active scope/store-repair journal references. Build the observation by
    enumerating only canonical two-key store directories and all candidate/journal namespaces with
    strict limits and no symlink following. Refresh every readable indexed or explicitly supplied
    project under projects custody before pure planning. Missing, unreadable, malformed, or changed
    projects retain last-observed references and emit findings; malformed store/candidate/journal
    entries and any reference whose identity cannot be proven are retained.

    Pure planning marks only fully proven unreachable snapshots for deletion and makes every prune
    action destructive. Apply requires `Approval::Granted`, takes exclusive store then projects
    custody, revalidates the complete reachability generation, rederives and contains each store
    directory, refuses symlinks/special entries, and removes only the planned snapshot through
    bounded, directory-relative, no-follow traversal. It never
    prunes source cache, review cache, trust, candidates, project records, active transaction
    content, or an entire source directory by broad recursion. Candidate publication/apply retains
    its shared store lease so prune cannot pass revalidation before a new reference commits.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test prune --test transaction_concurrency --test source_concurrency`.
    Fixtures retain global, readable-project, missing-project last-observed, explicit-project,
    candidate, scope-journal, store-repair, malformed, and concurrently introduced references;
    only one isolated canonical snapshot is planned and removed after approval. Stale index,
    candidate, journal, or store generation aborts without deletion. An outside canary survives
    hostile names and symlinks. Red arms omit each reachability source or shared/exclusive store
    lease and demonstrate the otherwise-deleted referenced snapshot.

- [ ] **Slice 7: Complete operation security matrices and the Phase 4 hard-cut gate** <requires: 6>
  - Files: create `crates/grimoire-core/tests/operation_boundary.rs`; modify
    `crates/grimoire-core/tests/boundary.rs`, `crates/grimoire-core/tests/tracer.rs`,
    `crates/grimoire-core/tests/planner.rs`, `crates/grimoire-core/tests/planner_source.rs`,
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/Cargo.toml`,
    `crates/grimoire/src/lib.rs`, `crates/grimoire/src/runtime.rs`,
    `crates/grimoire/Cargo.toml`, `Cargo.lock`, and `README.md`; update only Phase 4 fixtures and
    existing tests required by intentional `Request`, `WorldState`, `Action`, and precondition hard
    cuts.
  - Change: sweep every Phase 4 roadmap/spec requirement against implemented mechanisms and tests.
    Add one executable matrix mapping each transaction/ownership/recovery/index/prune guard to its
    exact test, controlled disabled mechanism, and forbidden observation; add missing red arms, not
    labels for green negative assertions. Pin deterministic plan/action/precondition, transaction
    journal, project-index, check-report, apply/recovery outcome, candidate create/remove, and prune
    byte goldens. Tighten public trait-floor and boundary tests so planning remains pure; all
    scope/store/trust/candidate/link/project mutations are reachable only through named source,
    store, transaction, apply, recovery, or prune modules; production nonce/time/fault runtime
    construction exists only in `skill-grimoire`; and no environment, command grammar, TTY, UI,
    shell, alpha type, force/adopt path, hidden fetch/update, or second inventory/hash authority
    enters core.

    Update README status to state that inventory, declarative planning, source custody/trust, and
    transactional core operations are complete and the CLI/TUI adapters are next; do not claim an
    installation command or user-facing workflow yet. Remove every Phase 4 `allow(dead_code)` and
    temporary unsupported-action branch. Run Code Humanizer's write-time standard over the durable
    executor and maintained tests without broad unrelated cleanup.
  - Verify: first run the targeted Phase 4 suite:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test transaction_tracer --test apply_matrix --test transaction_recovery --test world --test check --test project_index --test transaction_concurrency --test prune --test operation_boundary`.
    Then prove the hard cut with
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && ! rg -n '(LiveLibrary|LibraryConfig|InstallLog|AgentTarget|ImmediateInstall|ImmediateRemove|\\bforce\\b|\\badopt\\b|git2|reqwest|tokio)' crates/grimoire-core/src crates/grimoire/src`;
    expected: no forbidden production hit. Run these exact gates:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test --workspace`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/skills-lint.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack --test clankshop --test pack_availability`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire/.workstreams/app RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`, and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`.
    Expected: every gate is green; the known unrelated archived-record ledger failure remains out
    of scope and is not permission to weaken a Phase 4 gate.

## Done when

- Every mutating request becomes one complete serializable plan, and every planned mutation of
  manifest, lock, source-add/remove candidate, trust, links, or store reachability occurs only
  through the action interpreter under the required approval and locks. Standalone source custody
  remains limited to cache/review/current-candidate evidence, and project-load bookkeeping can
  refresh only the project index through its authority under `projects.lock`.
- Apply never replans; it rejects blocked/malformed/wrong-scope plans and stale manifest, lock,
  candidate, store, trust, link, index, journal, or reachability observations before mutation.
- One direct skill, packs and shared members, project/global reconciliation, cached multi-skill
  update, source add/remove, trust/revoke, untrusted removal, and offline frozen link repair all
  work through the same headless transaction engine without source execution or update-time fetch.
- The strict scope journal rolls back before commit, rolls forward after commit, restores exact
  candidate/link/state bytes, preserves manifest→candidate→trust ordering, and recovers
  idempotently after every injected fault without interpreting store-repair journals.
- World loading and check reverify locked skills, candidates, trust, links, and pending journals
  without ambient reads or network access; check reports deterministic findings and does not
  recover or mutate managed state.
- The project index preserves readable and uncertain project references, and prune deletes only a
  canonical snapshot proven unreachable after destructive approval and full locked revalidation;
  concurrent apply/fetch/trust/prune operations preserve lock order and reachability.
- No CLI/TUI policy, alpha compatibility, force/adopt path, hidden fetch, broad filesystem target,
  or second inventory/hash authority has entered core; targeted fault/security matrices,
  formatting, workspace tests, clippy, skills/repository integrations, dogfood, and both layout
  probes are green.

_On completion (before landing), run the host's close-the-books sweep._
