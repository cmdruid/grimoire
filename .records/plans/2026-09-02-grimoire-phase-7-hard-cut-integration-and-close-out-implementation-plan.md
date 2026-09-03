---
doctype: plans
status: published
schema: contractor/plan@1
tags: [plan]
stage: approved
---

# Grimoire Phase 7 hard-cut integration and close-out — Implementation Plan

Close the rewrite through executable integration evidence, then remove the superseded product
lineage. The tracer first makes this repository install its own `clankshop` pack through the real
CLI from both the stream worktree and root checkout; this exercises the complete inventory,
source-review, trust, planning, transaction, and link-ownership path. Later slices prove
cross-adapter planner identity and cross-home frozen reproduction, make every retained negative
boundary name executable red evidence, and delete only the alpha product documents and residue
that the published contract replaces.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 7 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Verify the `app` handoff, worktree, `stream/app` branch, target movement, dirty/staged state, and
  sibling ownership. Stop for a rebase, staged state, movement on `main`, or another stream that
  owns inventory, adapters, integration tests, or product close-out.
- Re-read Phase 7, the published product contract's discovery, source-security, planner,
  offline/frozen, adapter, and verification sections, repository doctrine, and the live Phase 5/6
  plans and tests. Confirm both adapter plans are published at `stage: implemented` and no Phase 7
  plan or closure already exists.
- Inventory production dependencies with `cargo machete`, enumerate the workspace tests with
  `RUSTC_WRAPPER= cargo test --workspace -- --list`, and search code, fixtures, documentation, and
  tracked paths for the deleted alpha schemas, face model, old configuration, migration reader,
  and installer. Classify historical prose separately from production and keep intentional
  negative evidence such as `crates/grimoire-core/tests/fixtures/lock/alpha.json`.
- Reproduce one real root dogfood attempt before planning implementation. The grounded baseline is
  202 workspace tests, no unused Cargo dependency, no tracked `install.sh`, and a valid
  `clankshop` pack that the CLI cannot install from the built worktree because entries below the
  contractually ignored root `target/` directory are counted until
  `discovery-entry-limit` fires at 100,001.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **The published v1 contract is the only authority.** Do not add compatibility readers,
  migrations, registries, nested/cross-source packs, aliases, force/adopt, Windows behavior, or a
  second planner/executor path. A root-dogfood failure may reopen an earlier mechanism only as far
  as the existing contract requires.
- **Ignored traversal remains bounded and exact.** Inventory owns ignore and skill-boundary
  semantics. Readers may prune a directory only through a typed inventory decision. Each ignored
  or nested-checkout boundary directory consumes one of the 100,000 entries, but its descendants
  consume neither entry nor review-byte budget; an ignore-named directory inside an already
  discovered skill and all of its descendants remain content. Traversal never follows symlinks,
  and an adversarial tree with too many encountered outer or relevant entries still stops at the
  documented limit.
- **Adapters project one core decision.** Planner parity starts from the same immutable
  `WorldState`, typed `Request`, and `PlanningMode`; CLI command mapping and TUI staging may adapt
  input but may not reconstruct actions, blockers, or destructiveness. Frozen reproduction uses
  the committed manifest and lock, an exact trusted immutable snapshot in a fresh home, and an
  injected Git boundary that fails if offline reconcile attempts transport.
- **Negative evidence is executable and lossless.** Each security or absence row names a compiled
  green test, an executed counterfactual that disables the production guard or injects its
  forbidden dependency, and the forbidden observation that makes the unchanged assertion fail.
  A source-code marker or prose description alone is not red evidence. Preserve malicious fixtures
  and alpha-lock rejection evidence when removing obsolete positive behavior. Source content never
  executes; credential paths remain validated, structured runner inputs, and the runner never
  reopens ambient Git configuration or source-selected helper execution.
- **Close only verified work.** The main session is the sole writer. Every slice starts with a
  failing focused test or controlled audit, ends with its targeted tests plus
  `RUSTC_WRAPPER= cargo check --workspace`, and lands as one coherent imperative commit. Do not ship
  or move `main`; mark Phase 7 and the roadmap implemented only after the complete gate is green.

## Slices

- [x] **Slice 1: Install the root `clankshop` pack through the real CLI** <requires: —>
  - Files: modify `crates/grimoire-pack/src/inventory/tree.rs`,
    `crates/grimoire-pack/src/inventory/scan.rs`, inventory test readers and discovery tests,
    `crates/grimoire-core/src/source/local.rs`, `crates/grimoire-core/src/source/git.rs`, and their
    focused tests as required by the traversal contract; create
    `crates/grimoire/tests/root_dogfood.rs`; modify `crates/grimoire/tests/support/mod.rs` only for
    shared process-fixture support.
  - Change: add a typed `Continue`/`SkipSubtree`/`Stop` traversal decision and the minimum
    inventory-owned pass structure needed to count each ignored outer or nested-checkout boundary
    once, then prune its descendants before enumeration or review, while retaining every entry
    beneath a discovered skill, including its `target`, `vendor`, or `fixtures` children. Replace
    recursive Git `ls-tree` enumeration with a directory-at-a-time tree-object walk so
    `SkipSubtree` stops Git before it streams ignored descendants; filesystem and Git readers must
    expose equivalent inventory. Preserve exact limits for relevant hostile trees and excessive
    encountered outer entries. Add a temp-home CLI
    workflow that initializes a project, registers the selected repository as a live source with
    the dedicated trust-all ceremony, installs the root pure `clankshop` pack, proves every member
    link and the absence of a synthetic `clankshop` skill, runs `check`, uninstalls the pack, and
    proves owned links are removed. Select the source from `GRIMOIRE_LIVE_ROOT` or the current
    worktree so the identical test runs against both repository layouts.
  - Verify: begin with the currently failing CLI dogfood tracer and focused failures covering one
    ignored directory with more than 100,000 descendants, 100,001 counted outer entries including
    ignored boundary nodes, an ignore-named directory inside a skill, and a nested checkout. Run
    `RUSTC_WRAPPER= cargo test -p grimoire-pack discovery`,
    `RUSTC_WRAPPER= cargo test -p grimoire-core source`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood`, then rerun the latter with
    `GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire`; run
    `RUSTC_WRAPPER= cargo check --workspace`. Expected: generated and nested-worktree descendants
    are pruned after their boundary entry is counted, skill content is not over-ignored, excessive
    outer and hostile relevant content still stop, and both layouts complete the real
    install/check/uninstall path.

- [x] **Slice 2: Prove one planner across adapters and another home offline** <requires: 1>
  - Files: modify `crates/grimoire/src/command.rs`,
    `crates/grimoire/tests/tui_parity.rs`, `crates/grimoire/tests/support/mod.rs`, and create
    `crates/grimoire/tests/offline_reproduction.rs`; modify only the narrow core test support or
    adapter signatures required to inject an inert Git boundary.
  - Change: route CLI install/uninstall intent through the same core `DesiredState`/`DesiredEdit`
    normalization used by TUI staging, yielding one `Request::ReplaceDesiredState` without changing
    CLI grammar or core semantics. Expose only the narrow pure command-to-planning-input seam needed
    for the parity matrix to feed the identical `WorldState`, `Request`, and mode through direct
    core planning, parsed CLI intent, and TUI staging. Assert exact action and blocker values and
    explicit `Plan::is_destructive()` parity for blocked, additive, and destructive requests;
    retain subprocess rendering and exit-class checks separately. Make production Git construction
    a single injected command dependency: the system entry supplies `SystemGitRunner`, while tests
    can supply the existing trait without a second execution path. Add a two-home remote-source
    fixture with no private-state copying. Machine A produces the original committed manifest and
    lock bytes. A genuinely fresh machine B copies only those two files into a throwaway project,
    uses an injected remote Git fixture to fetch, inspect, grant exact trust, and complete one
    normal install into B's own immutable store, and proves the committed bytes stayed identical.
    Remove B's candidate, Git/review cache, and installed links; copy A's original manifest and lock
    bytes into a second B project path; then reconcile that second project with `install --frozen`
    through a fail-on-use `GitRunner`. Explicitly copy no trust, candidate, cache, project-index, or
    store state from A. Verify zero Git calls, no state rewrite, and links exclusively into B's
    independently verified store.
  - Verify: start with parity assertions that fail because CLI replans from a separately observed
    world and with a missing cross-home frozen workflow. Run
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test tui_parity --test offline_reproduction --test cli_mutations --test tui_workflow`
    and `RUSTC_WRAPPER= cargo check --workspace`. Expected: both frontends observe one core plan,
    and the second home reproduces exact committed state without Git, candidate, cache, source, or
    lock rewriting.

- [x] **Slice 3: Make the final boundary and negative-guard audit executable** <requires: 1, 2>
  - Files: modify `crates/grimoire-core/tests/source_boundary.rs`,
    `crates/grimoire-core/tests/operation_boundary.rs`, `crates/grimoire/tests/boundary.rs`, and
    `crates/grimoire/tests/source_runtime.rs`; create
    `crates/grimoire-pack/tests/red_proofs.rs` and `crates/grimoire/tests/hard_cut.rs`.
  - Change: reconcile the pack, source, operation, CLI, and TUI matrices against every negative
    security and absence guard in the published verification contract. Give every retained row a
    production guard, unique compiled green test, executed disabled-policy or breaking-fixture arm,
    and forbidden observation. Run the unchanged invariant assertion against the disabled arm and
    prove that it fails, for example with a caught assertion or isolated expected-failure process,
    rather than accepting marker presence as evidence; add a narrow test seam where necessary but
    compile no bypass into the production runtime. Cover source identity and ref grammar, exact
    HEAD/ref selection and races, sanitized runner inputs and resource limits, held-local custody,
    candidate/cache concurrency and leases, review export and source-info goldens, trust and store
    integrity, operation/transaction ownership, and adapter absence guards. Add controlled breaking
    fixtures for the production hard-cut scanner covering the alpha lock
    parser, face behavior, former target/configuration model, migration path, ambient core access,
    adapter-owned mutation, background/update-time fetch, inherited edits, and generic trust
    approval. Exercise `SystemGitRunner`'s validated SSH-agent and app-owned askpass inputs with a
    recorder, preserving its cleared environment and proving arbitrary ambient Git configuration
    and helpers remain absent. Keep the intentional alpha-lock fixture solely as rejection proof.
  - Verify: begin by making the source matrix execute and observe failure from one disabled guard,
    then require that shape for every row, and feed one forbidden sample to each hard-cut scanner.
    Run `RUSTC_WRAPPER= cargo test -p grimoire-pack --test red_proofs`,
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test source_identity --test source_backends --test source_tracer --test source_concurrency --test review_export --test source_info --test trust --test planner_source --test operation_boundary --test transaction_recovery --test transaction_concurrency --test source_boundary`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test boundary --test hard_cut --test source_runtime`, then run
    `RUSTC_WRAPPER= cargo check --workspace`. Expected: every negative row is backed by a live
    breaking arm and all forbidden observations stay unreachable in production.

- [x] **Slice 4: Delete the superseded alpha product lineage and residue** <requires: 3>
  - Files: delete `docs/design/2026-08-07-grimoire-repurpose-design.md`,
    `docs/design/2026-08-08-pack-format-design.md`,
    `docs/design/2026-08-08-pack-format-impl-plan.md`,
    `docs/design/reviews/2026-08-08-pack-format-codex-review.md`,
    `docs/design/reviews/2026-08-08-pack-format-codex-review-2.md`,
    `docs/design/2026-08-15-tui-v0.1-roadmap.md`,
    `docs/design/2026-08-15-tui-phase1-implementation.md`,
    `docs/design/2026-08-18-cli-verbs-spec.md`,
    `docs/design/2026-08-18-tui-phase2-implementation.md`, and
    `docs/design/2026-08-18-tui-phase3-implementation.md`; modify
    `docs/design/2026-08-08-repo-restructure-design.md`, `README.md`,
    `crates/grimoire/Cargo.toml`, and only paths implicated by the residual/dependency audit.
  - Change: remove the directly superseded faced-pack, local-library, immediate-operation, and
    TUI-only product documents; preserve unrelated skills-library history and the still-useful
    workspace-topology record while replacing its dangling parent pointer with an explicit
    historical note. Update README product/layout guidance to the published contract, remove the
    obsolete qntx reading-reference claim, and describe `skill-grimoire` as the CLI/TUI adapter.
    Confirm `install.sh`, positive alpha fixtures, compatibility scaffolding, and dead dependencies
    are absent; remove only dependencies or code proven unused by `cargo machete`, compiler/tests,
    and reachability inspection. Run Developer Writing on the changed reader-facing prose and Code
    Humanizer on durable Rust or maintained tests changed by this phase.
  - Verify: start with the residual search showing the listed documents, README pointer, and stale
    crate description. Run `cargo machete`, the hard-cut boundary tests, a tracked-file search for
    `install.sh`, and scoped production searches for alpha schema, face behavior, old configuration
    and target models, migration, force/adopt, and former CLI grammar; explicitly allow only named
    negative fixtures/tests. Run `RUSTC_WRAPPER= cargo test --workspace` and
    `RUSTC_WRAPPER= cargo check --workspace`. Expected: only the published v1 product is presented
    or compiled, every retained alpha token is test data or historical non-product context, and no
    required invariant test was deleted with its former implementation.

- [ ] **Slice 5: Close the complete hard-cut integration gate** <requires: 1, 2, 3, 4>
  - Files: modify this plan,
    `.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`, and `README.md`; modify only
    production, test, or record files implicated by a final-gate failure.
  - Change: run every narrow and repository-wide Phase 7 gate against the stream worktree and root
    checkout, correct in-scope failures at their root, and record the new product as implemented
    but unshipped. Check every plan slice and set this plan to `status: published` and
    `stage: implemented`; set the roadmap to `stage: implemented` without claiming it shipped or
    moved `main`. Make README status and verified commands agree with the gate. Run the host
    close-the-books sweep and commit any legitimate project-owned closure artifact.
  - Verify: run `RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `RUSTC_WRAPPER= cargo test --workspace`,
    `RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/run.sh`, and `scripts/tests/run.sh`. Run
    `RUSTC_WRAPPER= cargo test -p grimoire-pack --test clankshop --test pack_availability --test live_root_layout`
    and the root-layout variant with `GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire`; run the CLI
    root-dogfood test against both layouts, all CLI/TUI workflows and parity, malicious-source and
    source-boundary suites, transaction fault/concurrency suites, hard-cut controlled-red tests,
    offline reproduction, and `cargo machete`. Expected: every Phase 7 gate is green without waiver,
    the worktree is clean after its closure commit, and `main` remains unchanged.

## Done when

- The real CLI installs, checks, and uninstalls the root `clankshop` pure pack from both the stream
  worktree and root checkout without inventorying ignored build or nested-worktree content.
- CLI and TUI feed the same typed input and immutable world to one planner and observe identical
  actions, blockers, and destructiveness; a fresh home reproduces committed project state in frozen
  mode with transport disabled and without machine paths in the lock.
- Every negative security/absence guard has named compiled and controlled-red evidence. Production
  code, positive fixtures, tracked files, README, and active product documentation expose no alpha
  schema, face behavior, old configuration/target path, migration reader, shell installer, or dead
  compatibility dependency.
- All targeted, workspace, lint, clippy, adapter workflow, malicious-source, transaction,
  dogfood, root/worktree discovery, hard-cut, dependency, and repository integration gates pass.
  The plan and roadmap are published at `stage: implemented`, close-the-books is complete, all
  Phase 2–7 commits remain accumulated on `stream/app`, and final shipping still awaits the user's
  explicit decision.

_On completion (before landing), run the host's close-the-books sweep._
