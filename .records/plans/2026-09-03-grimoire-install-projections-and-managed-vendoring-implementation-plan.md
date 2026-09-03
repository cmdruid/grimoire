---
doctype: plans
status: published
schema: contractor/plan@1
tags: [plan]
stage: approved
---

# Grimoire install projections and managed vendoring — Implementation Plan

Add a managed project-vendor projection without weakening Grimoire's source custody, trust, or
transaction boundaries. The tracer starts from a committed schema-2 fixture in a fresh offline
home, approves one exact vendored skill locally, and restores its relative activation link without
a candidate or store snapshot. Later slices widen that proven path to store-backed creation,
protected update/removal, packs and mode conflicts, the CLI/TUI surfaces, crash recovery, and root
self-hosting.

Spec: `.records/specs/2026-09-03-grimoire-install-projections-and-managed-vendoring.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Run `git status --short --branch`, `git log -8 --oneline --decorate`, and
  `git worktree list --porcelain` from the selected implementation checkout. Stop for unexpected
  staged or untracked production files, movement of the selected base, or another active stream
  owning manifest/lock, trust, planner, transaction, CLI, or TUI work. At plan time root `main` is
  `1027a15`; the published spec and this draft plan are the only expected untracked records. Other
  `.workstreams/` handoffs belong to their own sessions and are not implementation context.
- Run
  `skills/contractor/scripts/ground-check.sh "$PWD" "$PWD/.records/specs/2026-09-03-grimoire-install-projections-and-managed-vendoring.md"`,
  confirm the spec remains `status: published`, and re-read its Problem, Goal, Approach, complete
  Mechanism, and Verification sections. Stop and return any newly opened product decision to the
  spec rather than choosing it in code.
- Re-read `crates/grimoire-core/src/lib.rs`, `crates/grimoire-core/src/model.rs`,
  `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/manifest.rs`,
  `crates/grimoire-core/src/lockfile.rs`, `crates/grimoire-core/src/resolve.rs`,
  `crates/grimoire-core/src/world.rs`, `crates/grimoire-core/src/plan.rs`,
  `crates/grimoire-core/src/trust.rs`, `crates/grimoire-core/src/store.rs`,
  `crates/grimoire-core/src/check.rs`, `crates/grimoire-core/src/projects.rs`,
  `crates/grimoire-core/src/prune.rs`, `crates/grimoire-core/src/apply.rs`,
  `crates/grimoire-core/src/transaction/journal.rs`,
  `crates/grimoire-core/src/source/local.rs`, and `crates/grimoire-core/src/tree.rs`; then re-read
  `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`,
  `crates/grimoire/src/render.rs`, `crates/grimoire/src/tui/model.rs`,
  `crates/grimoire/src/tui/render.rs`, and `crates/grimoire/src/tui/driver.rs` against `HEAD`.
  Confirm their public signatures and the exact tests named below before editing.
- Search production and tests for `ProjectionMode`, `vendor`, `OwnedLinkTarget`, `content_digest`,
  `HeldDirectoryReader`, `PrepareSnapshot`, `ReplaceTrust`, `baseline_updates`, `LinkTransition`,
  and `DirectoryIdentity`. At plan time there is no vendor implementation; the reusable prior art
  is the one `grimoire-pack` inventory/content-digest authority, core's held no-follow filesystem
  reader, typed owned-link targets, pre-mutation snapshot preparation, ordered locks, and the scope
  journal's link captures. Reuse or factor those seams rather than adding another walker, digest,
  lock order, or transaction.
- Re-measure with `RUSTC_WRAPPER= cargo test -p grimoire-core -- --list`,
  `RUSTC_WRAPPER= cargo test -p skill-grimoire -- --list`, and
  `RUSTC_WRAPPER= cargo check --workspace`. The plan-time baseline is 120 core tests, 47 app tests,
  and a green workspace check. Amend this plan rather than coding around a moved schema, API, test
  population, or already implemented capability.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract and hard cuts.** The published projection spec is the authority. Manifest
  and lock move strictly to `grimoire/manifest@2` and `grimoire/lock@2`; v1 project files receive
  only the specified manual hard-cut diagnostic. Trust reads `grimoire/trust@1` losslessly and
  writes strict deterministic `grimoire/trust@2` on its next mutation. Do not invent a project-file
  compatibility reader, automatic manifest/lock migration, eject/adopt/force path, registry, or
  editable-vendor merge.
- **One typed projection model.** Add public `ProjectionMode { Link, Vendor }` with `Debug`, `Clone`,
  `Copy`, `PartialEq`, `Eq`, `Hash`, `PartialOrd`, `Ord`, `Serialize`, and `Deserialize`; omission in
  a schema-2 manifest means `Link`. Introduce `ManifestSkill { source: SourceAlias, mode:
  ProjectionMode }` with `Debug`, `Clone`, `PartialEq`, and `Eq`; add `mode` to `ManifestPack`,
  `LockPack`, and `LockSkill`; and carry it through `DesiredState`, `DesiredEdit`, resolution, tree
  projections, and reports. Preserve comment-aware targeted mutation, deterministic sorting, and
  unknown-field rejection. Adapters pass typed intent and never infer mode from paths, labels, or
  incumbent filesystem state.
- **Observation is incumbent-only.** World loading records activation and vendor paths separately.
  Public fieldless `VendorState { Absent, OwnedUnchanged, Drifted, Foreign }` derives `Debug`,
  `Clone`, `Copy`, `PartialEq`, `Eq`, `Hash`, `PartialOrd`, `Ord`, `Serialize`, and `Deserialize`.
  Public plan-wire `VendorPrecondition { state: VendorState, content: Option<String> }` derives
  `Debug`, `Clone`, `PartialEq`, `Eq`, `Serialize`, and `Deserialize`. Ownership comes from the
  incumbent lock and observed bytes. The planner alone compares incumbent and desired digests to
  choose retain versus replace.
- **One verifier and digest authority.** A dedicated vendor verifier holds the exact vendor root,
  never follows entries, and reuses the `grimoire-pack` scan/content-digest algorithm. It validates
  the root `SKILL.md` name, normalized file modes, allowed entry types, contained symlink targets,
  and existing entry/depth/review-byte limits before accepting a digest. If reuse requires
  factoring the held directory reader or a single-skill scan entry point, move that authority once;
  never duplicate framing bytes, Unicode/path rules, limits, or traversal logic in core.
- **Project paths stay derived.** Add `Paths` helpers for
  `<project>/vendor/grimoire/<source>/<skill>` and transaction-private siblings only in Project
  scope. Extend the existing derived public enum with `OwnedLinkTarget::Vendor { source:
  SourceAlias, skill: SkillName }`; it retains that enum's `Debug`, `Clone`, `PartialEq`, `Eq`,
  `Hash`, `PartialOrd`, `Ord`, `Serialize`, and `Deserialize` floor and derives both the absolute
  validation target and the exact relative `.agents/skills/<skill>` symlink bytes. Global vendor
  paths, absolute vendor activation links, symlinked parent components, path traversal, and an
  incumbent symlink in place of a vendor directory are blockers.
- **Trust remains local and least-authority.** Public `VendorTrustReceipt { commit: String, tree:
  String, inventory: String, skill: SkillName, path: String, content: String }` derives `Debug`,
  `Clone`, `PartialEq`, `Eq`, `Hash`, `PartialOrd`, `Ord`, and `Serialize`; its enclosing trust record
  supplies the canonical identity. It does not satisfy ordinary exact/all source trust. Add
  `TrustChange::GrantVendor` and a typed vendor-trust request that derive receipts only from a
  validated project lock and structurally valid matching trees. A receipt authorizes only
  retain/activation of those exact vendor bytes. `--yes` cannot grant it; identity-wide revocation
  clears vendor receipts while preserving the audit baseline. Vendor-only approval never advances
  a full-source baseline.
- **Offline means no hidden acquisition.** Vendor trust and frozen vendor reconciliation must run
  with Git and transport recorders that fail on any call and with cache, candidate, review export,
  and store absent. Frozen mode changes no manifest, lock, vendor, or trust bytes. Missing or
  changed vendor content blocks; normal create/replace always starts from the exact verified store
  snapshot and existing exact/all source trust.
- **Vendor mutation is one scope transaction.** Add explicit prepare/create/replace/retain/remove
  vendor actions and vendor preconditions. Preparation copies to a transaction-private directory
  before state locks and verifies the result; publication, capture, activation link, manifest, lock,
  trust-baseline update, rollback, and cleanup remain one journaled outcome. Write strict
  `grimoire/transaction@2` journals with derived vendor transitions; recovery retains a bounded,
  read-only `grimoire/transaction@1` decoder for pre-feature state/link journals and never infers a
  vendor transition from v1. Recovery derives every path from validated identities and never
  deletes or restores a late foreign replacement.
- **Copying cannot alias mutable store bytes.** Preserve the reviewed entry set, internal symlink
  target bytes, and normalized `0644`/`0755` modes. An ordinary copy or proven copy-on-write clone
  is legal; mutable hard links, special files, submodules, candidate/review/live/incumbent-vendor
  copy sources, and copying a vendor tree back into the store are not.
- **Existing custody stays intact.** Preserve the store → trust → projects → scope lock order and
  the candidate/cache ranks that precede it. Revalidate manifest, lock, trust, store, link, vendor
  tree, and held-parent identity immediately before mutation. Plans remain pure and serializable;
  apply never refreshes, resolves, fetches, substitutes newer bytes, or treats confirmation as an
  ownership override.
- **Project index and pruning remain conservative.** Every pinned lock snapshot remains indexed and
  prune-reachable even when all selected skills are vendored. A missing store is healthy only for
  current vendored projections; it never makes the lock's snapshot reference disappear. No cache
  compaction or store-eviction policy belongs in this change.
- **Committed surfaces stay explicit.** Grimoire never edits `.gitignore`. Documentation may
  recommend ignoring `.agents/skills/`, but schema-2 manifest/lock files and
  `vendor/grimoire/<source>/<skill>` remain ordinary visible project content.
- **Core owns meaning; adapters own interaction.** Core owns schemas, resolution, trust authority,
  vendor verification/state, planning, checks, actions, and mutation. CLI/TUI own grammar,
  rendering, key handling, and confirmation only. CLI and TUI must produce the same core plan for
  equivalent staged desired state; the TUI never edits TOML or computes inherited pack mode.
- **Red-first, portable gate.** Keep synchronous macOS/Linux support and current dependencies. Do
  not add an async runtime, daemon, database, shell parser, `walkdir`, second transaction library,
  or second inventory implementation. Every slice starts with a failing tracer or matrix, ends with
  its targeted tests and `RUSTC_WRAPPER= cargo check --workspace`, and is independently committable.
  Every security/absence guard gets a controlled failing arm that proves the forbidden outcome is
  observable.

## Slices

- [ ] **Slice 1: Approve and activate one committed vendor tree offline** <requires: —>
  - Files: create `crates/grimoire-core/src/vendor.rs`,
    `crates/grimoire-core/tests/vendor_tracer.rs`, and
    `crates/grimoire/tests/vendor_offline.rs`; modify
    `crates/grimoire-pack/src/inventory/mod.rs`, `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/src/inventory/tree.rs`, `crates/grimoire-core/src/lib.rs`,
    `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/manifest.rs`, `crates/grimoire-core/src/lockfile.rs`,
    `crates/grimoire-core/src/trust.rs`, `crates/grimoire-core/src/resolve.rs`,
    `crates/grimoire-core/src/world.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/apply.rs`, `crates/grimoire-core/src/check.rs`,
    `crates/grimoire-core/src/source/local.rs`, `crates/grimoire-core/tests/manifest.rs`,
    `crates/grimoire-core/tests/lockfile.rs`, `crates/grimoire-core/tests/trust.rs`,
    `crates/grimoire-core/tests/world.rs`, `crates/grimoire-core/tests/planner_source.rs`,
    `crates/grimoire-core/tests/resolution.rs`,
    `crates/grimoire-core/tests/fixtures/lock/alpha.json`,
    `crates/grimoire-core/tests/fixtures/lock/empty.json`,
    `crates/grimoire-core/tests/fixtures/lock/full.json`,
    `crates/grimoire-core/tests/fixtures/planner/base.toml`, and
    `crates/grimoire-core/tests/fixtures/planner/noop-plan.json`; modify
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`,
    `crates/grimoire/src/render.rs`, and `crates/grimoire/tests/cli_grammar.rs`.
  - Change: begin with a failing fresh-home tracer containing only a schema-2 project manifest,
    lock, one structurally valid `vendor/grimoire/<source>/<skill>` tree, and no activation link or
    user-local source state. Complete schema-2 semantics in core before exposing the hard cut:
    parse and serialize direct and pack request modes with link-by-omission, validate pack and
    unanimously resolved skill modes in the lock, expand every direct/pack request root to
    `(skill, mode)`, and emit sorted `materialization-conflict`, `vendor-live-unsupported`, and
    `vendor-global-unsupported` blockers before any action. Add project vendor-path derivation,
    `OwnedLinkTarget::Vendor`, the incumbent-only vendor observation/precondition types, and the
    single verifier that reuses the canonical inventory/content digest. Add strict trust@2 vendor
    receipts plus lossless trust@1 loading, a core request that derives exact receipts from the
    verified locked trees, and project-only `source trust <alias> --vendor` grammar/rendering with
    no `--yes`. Extend frozen planning and the existing link transaction so the matching receipt
    permits only creation or repair of the exact relative activation symlink. Prove no Git, cache,
    candidate, review export, store, manifest/lock/vendor rewrite, source-wide receipt, or baseline
    mutation occurs.
  - Verify: run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test manifest --test lockfile --test resolution --test trust --test vendor_tracer --test world --test planner_source`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_grammar --test vendor_offline`, and
    `RUSTC_WRAPPER= cargo check --workspace`; expected: a fresh offline project can explicitly
    approve and activate one exact vendored skill, while digest laundering, malformed skill
    identity, unsafe entries/links/modes, limit violations, unrelated skills/snapshots, linked mode,
    Global/live scope, and post-revocation activation all fail closed.

- [ ] **Slice 2: Create and convert vendor projections from the immutable store** <requires: 1>
  - Files: create `crates/grimoire-core/tests/vendor_apply.rs` and
    `crates/grimoire/tests/vendor_plan_render.rs`; modify
    `crates/grimoire-core/src/vendor.rs`, `crates/grimoire-core/src/model.rs`,
    `crates/grimoire-core/src/scope.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/store.rs`, `crates/grimoire-core/src/apply.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`,
    `crates/grimoire-core/tests/apply_matrix.rs`, `crates/grimoire-core/tests/planner.rs`,
    `crates/grimoire-core/tests/transaction_tracer.rs`, and
    `crates/grimoire-core/tests/operation_boundary.rs`; modify `crates/grimoire/src/render.rs`,
    `crates/grimoire/src/command.rs`, and `crates/grimoire/tests/cli_mutations.rs`.
  - Change: add typed `PrepareVendor`, `CreateVendor`, `ReplaceVendor`, `RetainVendor`, and
    `RemoveVendor` actions plus exact before/after vendor preconditions. Each action carries its
    derived project-relative vendor path, incumbent and desired content digests when applicable,
    and lexically sorted added, removed, and changed inventory-entry paths. Human rendering shows
    those facts but never file bytes. Prepare a direct skill only from its verified locked store
    root into a transaction-private sibling; preserve reviewed paths and internal symlink targets,
    normalize directories to `0755` and regular files to `0644`/`0755`, prohibit mutable hard
    links, and rerun the structural verifier and locked digest before publication. Extend the scope
    journal with derived vendor directory transitions and held-parent identities. Implement initial
    vendor creation and both link→vendor and vendor→link conversion ordering: publish the target
    before repointing its activation, remove only unchanged incumbent-owned content, and roll back
    vendor/link/state as one unit. Mark replacement/removal/conversion destructive under existing
    confirmation rules.
  - Verify: run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test vendor_apply --test apply_matrix --test planner --test transaction_tracer --test operation_boundary`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_mutations --test cli_confirmation --test vendor_plan_render`, and
    `RUSTC_WRAPPER= cargo check --workspace`; expected: trusted store bytes create a verified vendor
    projection and exact relative activation atomically, conversions preserve foreign/drifted
    paths, copy faults roll back, inode/canary arms prove no hard-link or path escape exists, and an
    exact plan-render fixture shows both digests and sorted entry changes while a byte canary proves
    source contents never enter output.

- [ ] **Slice 3: Complete protected vendor lifecycle and transaction recovery** <requires: 2>
  - Files: create `crates/grimoire-core/tests/vendor_lifecycle.rs`; modify
    `crates/grimoire-core/src/vendor.rs`, `crates/grimoire-core/src/plan.rs`,
    `crates/grimoire-core/src/trust.rs`, `crates/grimoire-core/src/world.rs`,
    `crates/grimoire-core/src/check.rs`, `crates/grimoire-core/src/projects.rs`,
    `crates/grimoire-core/src/prune.rs`, `crates/grimoire-core/src/apply.rs`,
    `crates/grimoire-core/src/transaction/journal.rs`,
    `crates/grimoire-core/tests/transaction_recovery.rs`,
    `crates/grimoire-core/tests/transaction_concurrency.rs`, `crates/grimoire-core/tests/check.rs`,
    `crates/grimoire-core/tests/project_index.rs`, `crates/grimoire-core/tests/prune.rs`,
    `crates/grimoire-core/tests/planner_source.rs`, and
    `crates/grimoire-core/tests/update_all.rs`.
  - Change: implement retain, source update, replacement, uninstall, and idempotent missing-owned
    behavior from the incumbent lock. Compare desired versus incumbent digests only in planning;
    block structurally invalid or digest-drifted trees as `vendor-drift` and unowned occupancy as
    `foreign-vendor-path`, with no `--yes` bypass. Under all-snapshots trust, advance the full-source
    baseline in the same transaction when newly resolved vendor bytes publish even if activation
    remains at the stable relative path; leave it unchanged for vendor-only approval. Extend fault
    injection and recovery across every vendor capture/publication/link/state/commit/cleanup prefix,
    preserve late foreign replacements, and cover vendor update versus check, prune, another
    project, and same-project mutation under the existing lock order. Keep all locked snapshot
    references in the project index and prune reachability calculation.
  - Verify: run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test vendor_lifecycle --test transaction_recovery --test transaction_concurrency --test check --test project_index --test prune --test planner_source --test update_all`
    and `RUSTC_WRAPPER= cargo check --workspace`; expected: update/remove are protected by incumbent
    ownership and byte identity, baseline transitions are exact, every crash converges to the whole
    before or after state, races cannot redirect mutation, and vendored locks remain conservative
    store references.

- [ ] **Slice 4: Expose projection modes through CLI/TUI staging and reports** <requires: 1, 2, 3>
  - Files: modify `crates/grimoire-core/src/model.rs`, `crates/grimoire-core/src/tree.rs`,
    `crates/grimoire-core/src/plan.rs`, `crates/grimoire-core/src/check.rs`,
    `crates/grimoire-core/src/source/info.rs`, `crates/grimoire-core/src/source/query.rs`,
    `crates/grimoire-core/tests/planner.rs`, `crates/grimoire-core/tests/tui_adapter.rs`, and
    `crates/grimoire-core/tests/check.rs`; modify
    `crates/grimoire/src/args.rs`, `crates/grimoire/src/command.rs`,
    `crates/grimoire/src/render.rs`, `crates/grimoire/src/tui/model.rs`,
    `crates/grimoire/src/tui/render.rs`, and `crates/grimoire/src/tui/driver.rs`; modify
    `crates/grimoire/tests/cli_grammar.rs`, `crates/grimoire/tests/cli_mutations.rs`,
    `crates/grimoire/tests/cli_reports.rs`, `crates/grimoire/tests/tui_state.rs`,
    `crates/grimoire/tests/tui_render.rs`, `crates/grimoire/tests/tui_runtime.rs`,
    `crates/grimoire/tests/tui_parity.rs`, and `crates/grimoire/tests/tui_workflow.rs`.
  - Change: expose Slice 1's complete core mode semantics through the adapters. Make
    `install --link`/`--vendor` mutually exclusive, default new requests to link, and preserve an
    existing request's mode when neither flag is passed. Project TUI rows show linked/vendored
    status, `v` toggles only a selected mutable root, pack members remain inherited/read-only, and
    Global disables the operation. Carry mode through desired-state staging so direct core, CLI,
    and TUI inputs render the same plan, destructiveness, blockers, and stable exit classes.
    `trust list` and `source info` distinguish full-source from vendor-only approval. `list` reports
    each resolved mode, activation status, and store snapshot or project-relative vendor path;
    `check` distinguishes missing or wrong activation, `vendor-untrusted`, missing vendor content,
    vendor drift, foreign vendor paths, missing required linked snapshots, and an optional absent
    vendor store without treating that optional absence as failure.
  - Verify: run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test planner --test tui_adapter --test check --test source_info`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_grammar --test cli_mutations --test cli_reports --test tui_state --test tui_render --test tui_runtime --test tui_parity --test tui_workflow`,
    and `RUSTC_WRAPPER= cargo check --workspace`; expected: omitted CLI mode is stable, adapters
    neither infer nor override Slice 1's projection policy, trust authority is labeled accurately,
    every published activation/vendor/store state has a distinct deterministic report, and CLI/TUI
    staging produces the same core plan.

- [ ] **Slice 5: Prove reproduction, self-hosting, and the repository gate** <requires: 1, 2, 3, 4>
  - Files: modify `crates/grimoire/tests/hard_cut.rs`,
    `crates/grimoire/tests/offline_reproduction.rs`, `crates/grimoire/tests/root_dogfood.rs`,
    `crates/grimoire/tests/boundary.rs`, `crates/grimoire/tests/cli_workflows.rs`, and
    `crates/grimoire/tests/source_runtime.rs`; create
    `crates/grimoire/tests/mixed_projection.rs`; modify `crates/grimoire-pack/tests/red_proofs.rs`,
    `crates/grimoire-pack/tests/live_root_layout.rs`, and `README.md`.
  - Change: update the production hard-cut proof to schema 2 and trust dual-read/v2-write behavior.
    Run a committed-state clone with empty user-local state and failing transport through offline
    vendor approval, frozen activation, and check without changing committed bytes. Exercise mixed
    linked/vendored skills and prove every `.agents/skills` entry is a symlink, store targets are
    absolute managed snapshots, and vendor targets are project-relative. Build root self-hosting in
    a disposable clone that is both pinned source and consuming project; keep any live-root
    discovery probe read-only and prove `vendor/` plus activation links never become duplicate
    source skills. Cover all structural, trust, ownership, transaction, concurrency, CLI/TUI, and
    no-network guards with controlled failing arms, update user-facing documentation, and perform an
    attended terminal pass for mode labels, `v` staging, confirmation, cancellation, and reload.
  - Verify: run `RUSTC_WRAPPER= cargo fmt --all -- --check`,
    `RUSTC_WRAPPER= cargo test --workspace`,
    `RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`,
    `skills/skill-builder/scripts/skills-lint.sh`, `skills/skill-builder/scripts/tests/run.sh`, and
    `scripts/tests/run.sh`; then rerun
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood --test offline_reproduction --test mixed_projection`
    with `GRIMOIRE_LIVE_ROOT` set to the selected checkout. Expected: every published verification
    row is executable and green, the disposable self-host cannot rediscover projected content, the
    actual checkout remains unchanged, and the repository has no waiver or obsolete v1 production
    contract.

## Done when

- Project manifests and locks use strict schema 2; request-root projection modes resolve
  deterministically across direct skills and packs, while Global and live vendoring fail closed.
- Linked skills still activate from the immutable store; managed vendor trees are copied only from
  verified locked store bytes, activate through relative symlinks, and are replaced or removed only
  with incumbent-lock ownership plus an unchanged-content proof.
- A fresh offline clone can structurally verify and explicitly approve exact vendored skills, then
  restore activation without candidate/cache/store access; that approval cannot escape its exact
  identity/snapshot/skill/path/content tuple or bypass revocation.
- Vendor publication, activation, state files, trust baselines, rollback, and recovery form one
  transaction. Fault, race, foreign-path, drift, symlink, mode, hard-link, traversal, and limit
  red-proofs demonstrate the intended safety mechanisms.
- CLI and TUI expose the same core-derived modes, plans, blockers, confirmation rules, reports, and
  stable outcomes. Mixed projection, offline reproduction, disposable root self-hosting, formatting,
  workspace tests, warnings-denied clippy, skills-library gates, and repository integrations all
  pass without waiver.

_On completion (before landing), run the host's close-the-books sweep._
