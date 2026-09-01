---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Grimoire Phase 2 declarative state and planner kernel — Implementation Plan

Build the package-manager kernel as a pure comparison between desired state and an immutable
observation. The first slice plans one direct skill all the way from manifest bytes and a landed
source inventory to deterministic lock and link intents. Later slices widen that tracer through
scope discovery, every manifest/lock shape, pack resolution, project/global context, and the full
Phase 2 request matrix. No slice mutates a scope or introduces source, trust, store, or transaction
custody.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 2 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Re-run `git -C /Users/cscott/Repos/grimoire/.workstreams/app status --short --branch`,
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app log stream/app..main --oneline`, and
  `git -C /Users/cscott/Repos/grimoire/.workstreams/app worktree list --porcelain`. Stop for a
  staged change, movement on `main`, or a sibling stream that now owns core state, resolution, or
  planning.
- Re-run Contractor's ground check, confirm that the governing spec and roadmap remain published,
  then re-read the spec's Scope and paths, Manifest, Lock, `PACK.md`, Plans/confirmation/frozen,
  Ownership and collisions, Planner/executor API, Output and exit classes, and State/plans/
  transactions verification sections. Re-read the roadmap's Phase 2 boundaries and gate.
- Re-read `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/Cargo.toml`,
  `crates/grimoire-pack/src/inventory/mod.rs`, and
  `crates/grimoire-pack/src/inventory/model.rs` against `HEAD`. At plan time core is a two-line
  Phase 2 shell and has zero tests; the landed inventory exposes deterministic `Skill`, `Pack`,
  `SourceInventory`, `SourcePath`, and `Digest` values, including pack availability facts.
- Search all compiled crates and active tests for `Manifest`, `Lockfile`, `WorldState`, `Request`,
  `Plan`, `Action`, `Blocker`, `Preconditions`, `grimoire/manifest@1`,
  `grimoire/lock@1`, agent targets, live-library paths, install logs, and immediate install/remove
  operations. At plan time no v1 state or planner implementation exists. The deleted alpha core in
  Git history is incompatible choreography evidence only; do not restore or translate it.
- Search capability-wide for a comment-preserving TOML editor and deterministic JSON adapters in
  the live dependency graph. Reconfirm the selected `toml_edit` document/edit API and
  `serde_json` formatter behavior before adding them. The plan relies on exact-table editing and a
  private lock DTO over `BTreeMap`; if either API cannot preserve the required contract, amend the
  plan instead of falling back to whole-document TOML serialization or unordered JSON objects.
- Re-measure with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core -- --list`
  and run `RUSTC_WRAPPER= cargo check --workspace` in that same shell. The planning baseline has
  zero core tests and a green workspace check.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published hard cut only.** The new spec and approved roadmap govern. The former alpha library,
  agent-target, lock, install-log, and immediate-operation types are evidence to reject, not APIs
  to preserve. No compatibility parser, migration reader, translation layer, or deprecated type
  alias may land.
- **Pure kernel, immutable input.** `WorldState` owns one observation: parsed manifest and lock
  bytes plus their hashes, resolved paths, source snapshots/inventories supplied by a caller,
  installed-link observations, and optional inherited-global context. Planning never refreshes
  that observation, reads a file, follows a link, invokes Git, consults the process environment,
  or writes state. Scope discovery receives an injected path probe; later phases own production
  filesystem construction and custody.
- **Phase boundary.** Phase 2 owns project/global desired state, deterministic locks, pure
  resolution, logical link intents, blockers, preconditions, destructiveness, and exit-class
  facts. It does not fetch or canonicalize a source, publish a candidate, materialize/repair a
  snapshot, persist trust, acquire shared locks, mutate a link, apply a plan, journal/recover a
  transaction, prune the store, parse CLI arguments, or render CLI/TUI output. Later phases enrich
  observations and actions; they do not replace this planner.
- **One source snapshot is the version unit.** Resolution consumes one supplied
  `SourceSnapshot` per declared alias. A direct skill and every member of a pack resolve from that
  alias's same inventory and revision. There is no per-skill version, nested pack, cross-source
  pack member, hidden catalog, or implicit source lookup.
- **Independent scopes.** Project and global manifests/locks resolve separately. Inherited global
  skills are read-only context for project shadowing facts; a project request never edits, masks,
  removes, or claims a global request or link.
- **Comment-preserving manifest authority.** Parse only `grimoire/manifest@1`; reject unknown keys,
  invalid slugs, wrong table/value shapes, invalid `url`/`path`/`ref`/`live` combinations, missing
  aliases, and invalid pack exclusions. Mutations edit only the addressed key through
  `toml_edit`; untouched comments, whitespace, ordering, and scalar spelling stay byte-identical.
  Relative paths remain portable manifest strings. Core receives the manifest directory and never
  resolves `HOME`, cwd, or command arguments.
- **Deterministic lock authority.** Parse only `grimoire/lock@1`; every other schema, including the
  alpha lock, is a hard-cut typed error that tells the adapter to instruct deletion and a
  non-frozen install. Serialize UTF-8 JSON with two-space indentation, lexical object keys and
  member/request-root arrays, exact variant fields, and one trailing newline. Never serialize
  derived canonical, cache, store, review, or materialization paths, candidate state, trust,
  timestamps, or ambient machine facts. A user-authored `declared` source value is preserved
  exactly and is the sole permitted absolute source path.
- **Resolution before choreography.** Resolve complete desired state first, then compare it with
  the observed lock and links. Shared request roots retain one skill; excluded optional members
  are absent; enabled-but-missing optional members are unavailable facts; missing required
  members, source/name collisions, malformed inventories, and foreign link occupancy are stable
  blockers. Equal content from different source/revision owners does not permit adoption.
- **Plans are domain values.** Every `Action` carries explicit scope and before/after state. Plans
  list manifest and lock edits plus logical link create/repoint/retain/remove intents; presentation
  does not infer missing effects. `Plan::is_destructive` is derived from action variants exactly:
  link removal/repoint, source revision advance, desired-state removal, trust revocation, or prune
  are destructive. Phase 2 tests only the action kinds it owns; later variants must extend that one
  derivation rather than add adapter policy.
- **Preconditions and failures are typed.** Preconditions pin the observed manifest/lock bytes and
  every compared link target or absence. The enum is designed for Phase 3's candidate identity,
  snapshot existence, and trust revision without representing those future observations now.
  Blockers have stable codes and factual detail. Exit classes use the spec's precedence
  `5 > 4 > 3 > 2 > 1`; human messages remain adapter-owned and do not drive classification.
- **Public type floor and schema adapters.** Shared public values derive `Debug`, `Clone`,
  `PartialEq`, and `Eq`; identifiers, hashes, scopes, request roots, and enum keys also derive
  `Hash`, `Ord`, and `PartialOrd` where map/set use requires them. Manifest and lock domain values
  do not derive `serde` merely to save code: private adapters own their wire names, unknown-field
  rejection, and variant shapes. `Plan` and its nested public facts receive one deliberate,
  deterministic serialization contract because the product contract requires the plan itself to
  be serializable; no adapter may invent a second plan shape.
- **Determinism and red proofs.** Use `BTreeMap`/`BTreeSet` for semantic ordering and sort every
  externally visible list explicitly. Each absence/safety guard has a controlled red proof: disable
  the named rule in a test-only path and show the fixture would accept an alpha lock, ambient read,
  hidden replan, foreign owner, or cross-source resolution without it.
- **Dependencies and portability.** Add only the narrow data dependencies required here:
  `toml_edit` for manifest edits, `serde`/`serde_json` for the private lock adapter, `sha2` for
  observation hashes, `thiserror` for typed errors, and `tempfile` for tests. Keep async, UI,
  command parsing, Git/network, filesystem-walking, and platform-specific link crates out of
  `grimoire-core`.
- **Tree custody.** Every command runs with
  `cd /Users/cscott/Repos/grimoire/.workstreams/app && ...` in the same tool call; every Git command
  uses `git -C /Users/cscott/Repos/grimoire/.workstreams/app`. The main session is the only writer.
  Root-checkout probes are read-only and preserve unrelated root files.
- **Gate.** Every slice runs red-first targeted tests and
  `RUSTC_WRAPPER= cargo check --workspace`. The phase gate additionally runs formatting, all
  workspace tests, clippy with warnings denied, the Skill Builder lint/tests, repository
  integrations, and both worktree/root inventory layout probes.

## Slices

- [x] **Slice 1: One direct skill produces one complete pure plan** <requires: —>
  - Files: modify `crates/grimoire-core/Cargo.toml`, `Cargo.lock`, and
    `crates/grimoire-core/src/lib.rs`; create `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/manifest.rs`,
    `crates/grimoire-core/src/lockfile.rs`, `crates/grimoire-core/src/resolve.rs`,
    `crates/grimoire-core/src/plan.rs`, and `crates/grimoire-core/tests/tracer.rs`.
  - Change: add the narrow dependencies above and establish the final module boundaries without
    exposing a compatibility facade. Define validated source/skill/pack aliases, `Scope`,
    `SourceSpec`, `SnapshotId`, `SnapshotKind`, `RequestRoot`, `SourceSnapshot`,
    `InstalledLink`, and their trait floor. Implement the thinnest strict manifest reader for one
    `url` source and one direct `[skills]` request, plus the thinnest strict empty-lock reader and
    canonical lock writer. Consume a caller-supplied landed `SourceInventory` and Git snapshot
    identity to resolve that skill. Define immutable `WorldState`; `Request::Reconcile`;
    `Plan { actions, blockers, preconditions, facts }`; typed manifest/lock/link before-and-after
    `Action` values; typed blocker/precondition values; and `ExitClass`/destructiveness derivation.
    The tracer starts from exact manifest and empty-lock bytes plus a synthetic inventory, plans
    one lock replacement and one logical owned-link creation, pins the complete resulting lock
    bytes and action/precondition values, and repeats with the new lock/link observation to prove a
    deterministic no-op. No method applies those actions. Keep the parsers private behind domain
    constructors so later slices widen one authority rather than add parallel fast paths.
  - Verify: first make
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test tracer`
    fail because the shell has no planner, then make it pass with byte-exact manifest/lock and
    value-exact plan goldens. Run `RUSTC_WRAPPER= cargo check --workspace` in the same shell.
    Expected: one request traverses the complete pure kernel, a second identical observation is a
    no-op, and no executor or ambient filesystem access exists.

- [ ] **Slice 2: Scope discovery and the complete comment-preserving manifest** <requires: 1>
  - Files: create `crates/grimoire-core/src/scope.rs`,
    `crates/grimoire-core/tests/scope.rs`, and
    `crates/grimoire-core/tests/manifest.rs`; modify
    `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/error.rs`,
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/manifest.rs`,
    and `crates/grimoire-core/src/plan.rs`.
  - Change: define resolved `Paths` and `ScopePaths::{Project, Global}` without reading the
    process environment. Implement nearest-parent project discovery over an injected read-only
    `PathProbe`, including nested projects, filesystem-root termination, exact explicit-project
    validation, and no-project facts; a global scope is constructed only from a caller-resolved
    user home. Complete the manifest grammar: required schema, strict slug maps, source declarations
    with exactly one of `url`/`path`, optional declared `ref`, path-only `live`, direct skill
    requests, pack requests, sorted unique exclusions, unknown-key rejection, and alias-reference
    validation. Preserve an absent `ref` as absent; Phase 2 never guesses `HEAD` or a remote default
    branch. Retain the declared path exactly and expose a pure lexical resolution against the
    caller-supplied manifest directory for local source observations; perform no filesystem
    canonicalization.

    Parse into an immutable `toml_edit::Document` that retains original spans and keep the original
    bytes beside the typed value. Add one `ManifestMutation` authority for add/remove source,
    install/uninstall direct skill, install/uninstall pack, and pack-exclusion replacement. It uses
    the addressed key/value/table spans to replace or insert only the minimum byte range, renders
    only the new fragment, then reparses the complete proposed bytes and verifies that the intended
    semantic delta is the only one. A missing or ambiguous span is a typed refusal, never permission
    to serialize the whole document. This span-based patch path, rather than `DocumentMut::to_string`
    over the whole document, preserves dotted-key order, scattered table placement, comments,
    whitespace, untouched scalar spelling, and every other unaddressed byte. It returns exact
    proposed bytes plus semantic before/after values, never silently initializes an absent scope,
    and never applies the bytes. Widen `Request` and planning just enough to express those
    desired-state edits; duplicate/no-op requests remain typed no-ops or input errors as specified,
    never hidden rewrites.
  - Verify: red-first, run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test scope && RUSTC_WRAPPER= cargo test -p grimoire-core --test manifest && RUSTC_WRAPPER= cargo check --workspace`.
    Goldens cover nearest/nested/explicit/global paths; every wrong schema/key/type/source-field
    combination; alias references; live/ref conflicts; absent refs; relative and absolute declared
    paths; and each targeted edit inside deliberately irregular comments, dotted keys, scattered
    tables, whitespace, table order, and scalar spelling. Expected: only the addressed byte range
    changes, every untouched byte remains identical, proposed bytes reparse to the intended typed
    value, and the workspace remains green.

- [ ] **Slice 3: The hard-cut deterministic lock authority** <requires: 1>
  - Files: create `crates/grimoire-core/tests/lockfile.rs` and lock fixtures under
    `crates/grimoire-core/tests/fixtures/lock/`; modify
    `crates/grimoire-core/src/error.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/lockfile.rs`, `crates/grimoire-core/src/resolve.rs`,
    and `crates/grimoire-core/src/plan.rs`.
  - Change: complete private `serde` DTOs for `grimoire/lock@1` while keeping domain values
    serialization-independent. Model Git sources with portable declaration, ref, full commit, and
    full tree; live sources with only their permitted portable declaration/kind fields. Model pack
    locks with source, required, optional, enabled, and unavailable sets; skill locks with source,
    source-relative path, canonical content digest, and every sorted `skill:`/`pack:` request root.
    Preserve each lock source's `declared` string exactly, including a user-authored absolute local
    path. Reject unknown, missing, duplicate, variant-inapplicable, malformed digest/object-id, and
    noncanonical request-root data, plus any derived canonical, cache, store, review, or
    materialization path field; a declared value is the only location where an absolute source path
    may survive. Treat every non-v1 schema as
    `LockSchemaUnsupported`, never as empty state or a migration candidate. Serialize through a
    two-space formatter from `BTreeMap`-backed values, append exactly one newline, and prove parse →
    write canonicalization and write → parse semantic identity. Compare canonical semantic values
    when planning so formatting-only incumbent differences do not create false desired-state
    changes, while byte hashes still remain apply preconditions.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test lockfile`.
    Goldens cover empty, Git, live, multi-source, excluded/enabled/unavailable optionals, shared
    request roots, lexical ordering, no trailing/multiple newline, malformed objects, an absolute
    declared local path with no derived-path leakage, and representative alpha lock schemas. A
    controlled red proof routes one alpha schema
    through the disabled guard and demonstrates why the strict test must fail. Run
    `RUSTC_WRAPPER= cargo check --workspace` in the same shell.

- [ ] **Slice 4: Same-snapshot pack resolution and independent scopes** <requires: 2, 3>
  - Files: create `crates/grimoire-core/tests/resolution.rs` and resolution fixtures under
    `crates/grimoire-core/tests/fixtures/resolution/`; modify
    `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/resolve.rs`,
    `crates/grimoire-core/src/lockfile.rs`, and `crates/grimoire-core/src/plan.rs`.
  - Change: widen resolution from the direct-skill tracer to every desired root. Resolve a pack
    only against its named alias's one supplied inventory; required members are always enabled,
    optional members default enabled, exclusions disable only declared optional members, and an
    enabled missing optional becomes a sorted unavailable fact without a skill lock. A missing
    required member, malformed source inventory, unknown skill/pack, invalid exclusion,
    duplicate skill owner across source aliases/revisions, or direct/pack roots that resolve one
    installed name to different owners emits stable blockers. Merge same-owner roots into one
    sorted skill lock and retain it until the final root disappears. Emit a lock source only when
    its alias contributes at least one requested skill or pack. A source-only manifest declaration
    remains manifest-only; adding the first contributing root adds the source lock, and removing the
    final root removes the source from the lock without removing its manifest declaration. Produce
    complete resolution facts for excluded, enabled, unavailable, shared, collision,
    source-contribution, and source-invalid states.
    Resolve project and global worlds independently, then accept an immutable global resolution as
    read-only context for a project plan; same-name entries become explicit shadowing facts and
    never a project action against global state. Add frozen comparison of declarations, direct
    roots, exclusions, and locked resolution; live sources, missing exact snapshots, trust, and
    store integrity remain later observations and blockers, not guesses in this phase.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test resolution`.
    Table-driven matrices exhaust loose skills, required/optional pack members,
    enabled/excluded/unavailable states, source-only declarations, first-root contribution, shared
    direct and multi-pack roots, final-root lock removal with manifest retention, missing required
    members, cross-source attempts, equal-content owner collisions, independent scopes, inherited
    globals, and project shadowing. Red proofs disable same-snapshot and
    owner-equality guards once and show the forbidden cross-source/adoption outcomes. Run
    `RUSTC_WRAPPER= cargo check --workspace` in the same shell.

- [ ] **Slice 5: Complete Phase 2 planner matrices and hard-cut gate** <requires: 2, 3, 4>
  - Files: create `crates/grimoire-core/tests/planner.rs`,
    `crates/grimoire-core/tests/boundary.rs`, and planner fixtures under
    `crates/grimoire-core/tests/fixtures/planner/`; modify
    `crates/grimoire-core/src/error.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/lib.rs`,
    `crates/grimoire-core/Cargo.toml`, `Cargo.lock`, and `README.md`.
  - Change: complete planning for the Phase 2 request set: initialize an absent scope; reconcile
    an existing manifest; add/remove a source declaration when no roots violate ownership; install
    or uninstall a direct skill; install or uninstall a pack; replace optional exclusions; and
    resolve a caller-supplied proposed source snapshot for an explicit source update without
    fetching or claiming custody of candidate state.
    Every plan enumerates exact proposed manifest/lock bytes, logical link
    create/repoint/retain/remove intents, unavailable and shadowing facts, stable blockers, and all
    observed-byte/link preconditions. Derive destructive state from actions and choose the exit
    class from all findings with the spec's precedence. Cover absent/exact/owned-old/drift/foreign
    link observations: absent may create; a symlink already at the newly resolved target retains;
    repoint or removal is allowed only when the current symlink target exactly equals the target
    derived from the incumbent lock; an altered formerly owned link is drift and remains untouched;
    and every other symlink, regular file, or directory is foreign occupancy and blocks.
    A blocked or stale world is still a factual serializable plan value but has no apply path in
    this phase. Add `PlanningMode::{Normal, Frozen}` so frozen comparison is explicit input rather
    than an adapter-side branch. Pin the serialized plan shape and ordering as the one
    adapter-consumable value, while keeping it outside the stable `source-info@1` promise. Add
    boundary tests proving `grimoire-core` has no environment, CLI/UI, async,
    Git/network, filesystem-walk, link-mutation, transaction, recovery, or alpha-domain dependency;
    planning the same `WorldState` twice is byte/value identical and performs no I/O. Export only
    the reviewed v1 domain API from `lib.rs`. Update the README status to say Phase 1 inventory and
    Phase 2 planner foundations are complete and source custody/trust is next; do not claim an
    install command exists.
  - Verify: run
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-core --test planner --test boundary`.
    Expected: request matrices pin complete actions/blockers/preconditions/destructiveness/exit
    values, owned-old targets alone may repoint/remove, drift and foreign occupancy never mutate,
    stale inputs never trigger replanning, and adapter parity is possible by consuming the same
    plan value. Prove the hard cut with
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && ! rg -n '(AgentTarget|AgentEnv|LiveLibrary|LibraryConfig|InstallLog|PackShape|ImmediateInstall|ImmediateRemove)' crates/grimoire-core/src crates/grimoire/src`;
    expected: no production compatibility hit. Then run these exact gates:
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test --workspace`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/skills-lint.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && skills/skill-builder/scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && scripts/tests/run.sh`,
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && RUSTC_WRAPPER= cargo test -p grimoire-pack --test clankshop --test pack_availability`, and
    `cd /Users/cscott/Repos/grimoire/.workstreams/app && GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire RUSTC_WRAPPER= cargo test -p grimoire-pack --test live_root_layout`.
    Expected: every gate is green. The documented unrelated archived-record ledger failure is
    outside this stream and is not a reason to weaken or rewrite any Phase 2 gate.

## Done when

- `grimoire-core` parses and minimally edits only `grimoire/manifest@1`, discovers project/global
  scopes through resolved/injected boundaries, and serializes only deterministic
  `grimoire/lock@1` bytes; alpha locks fail hard with no reader or migration.
- Direct skills and same-snapshot packs resolve every required, optional, excluded, unavailable,
  shared-root, collision, independent-scope, and shadowing state into deterministic lock/domain
  values.
- One immutable `WorldState` and typed Phase 2 `Request` produce a complete pure `Plan` with exact
  logical actions, stable blockers, preconditions, destructiveness, exit-class facts, and no
  ambient read, hidden replan, or mutation.
- Link ownership observations distinguish absent, exact, owned-changed, and foreign occupancy; the
  planner never invents ownership or crosses the project/global boundary.
- No Git/network, candidate/store/trust persistence, executor, transaction/recovery, CLI/TUI,
  async, alpha-domain, or compatibility surface has entered Phase 2.
- Formatting, full workspace tests, clippy, skill lint/tests, repository integrations, and both
  worktree/root layout probes are green. The Phase 2 execution manifest can be closed and the plan
  marked implemented only after those gates pass.

_On completion (before landing), run the host's close-the-books sweep._
