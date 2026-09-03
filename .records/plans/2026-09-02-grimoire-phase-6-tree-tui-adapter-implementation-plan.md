---
doctype: plans
status: published
schema: contractor/plan@1
tags: [plan]
stage: approved
---

# Grimoire Phase 6 tree TUI adapter — Implementation Plan

Build the basic tree interface as a pure state machine and deterministic Ratatui projection over
the completed core. The first slice carries one project skill from an observed source tree through
a core-owned staged desired-state edit into the exact plan pane. Later slices widen that same path
across packs, Project/Global scope, inherited context, explicit source work, confirmation, the
blocking worker, and the production terminal loop. The app owns navigation and presentation; core
continues to own every package-manager fact, staged edit, plan, and mutation.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and Phase 6 of
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`

## Task 0 — Re-ground before editing

This task is read-only and produces no commit.

- Verify the recorded worktree, branch, target movement, dirty/staged state, and sibling-worktree
  ownership before editing. Stop for a rebase, staged state, movement on `main`, or another stream
  that owns the TUI, core tree/staging, worker, or terminal boundary.
- Confirm the product spec and roadmap remain published, then re-read their TUI, planner,
  transaction, and verification contracts alongside the live core/app signatures. Reconfirm that
  environment resolution, world loading, factual reports, planning, apply, source refresh, the
  worker, and terminal restoration retain their existing ownership; the deleted alpha TUI is not
  a reuse target.
- Re-run `RUSTC_WRAPPER= cargo test -p skill-grimoire -- --list` and
  `RUSTC_WRAPPER= cargo check --workspace`. The planning baseline is 24 app tests, no TUI tests,
  reusable Ratatui/worker/terminal infrastructure, and no core tree projection, staged desired
  state, atomic multi-toggle request, TUI model, renderer, or event driver. Amend the plan if that
  baseline has moved.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Core owns package-manager meaning.** Core projects the complete source/pack/skill tree, derives
  pack state and blockers, validates typed desired edits, and plans one atomic desired-state
  replacement. The app owns navigation and presentation only: it never edits TOML bytes, resolves
  skills, computes tri-state, constructs actions, infers safety from labels, or mutates managed
  paths. Use existing core keys for stable selection unless implementation proves a new identity
  type necessary.
- **Scopes observe immutably and stage independently.** Project and Global load independently;
  Project is the default when present and shows inherited globals read-only with shadowing. Each
  tab holds an immutable world plus disposable in-memory desired state. Toggle replans against that
  world; apply, fetch, update, or staleness reloads it; cancel, tab reload, and quit discard staging.
  Missing scopes render their typed remedy and are never initialized implicitly.
- **Plans and safety ceremonies remain exact.** Staged edits render the complete core plan and one
  transaction applies it; blocked plans cannot apply. Fetch and update are explicit focused-source
  actions and update never fetches. Destructive apply defaults to no, and trust-all has a distinct
  identity/baseline ceremony that alone can submit `SourceTrustIntent::All`.
- **UI mechanics stay pure and bounded.** Typed model transitions and deterministic Ratatui
  rendering perform no I/O. Reuse the single blocking worker for world load, apply, fetch, and
  update; preserve responsiveness, visible errors, joined shutdown, and the existing panic rules.
  Reuse terminal setup/restoration with driver-owned cleanup on every path; resize preserves model
  state, small terminals remain bounded, and non-terminal invocation emits no control bytes.
- **Keep the hard cut and normal gate.** Do not restore alpha state, immediate actions, background
  updates, source-content execution, migration, force/adopt, registries, nested/cross-source packs,
  or another command grammar. Add no async runtime or second framework. Every slice starts red,
  ends with targeted tests plus `RUSTC_WRAPPER= cargo check --workspace`, and commits coherently in
  this worktree. The final gate runs formatting, workspace tests, warnings-denied clippy, Skill
  Builder lint/tests, repository integrations, dogfood/availability, both layout probes, and
  production hard-cut searches.

## Slices

- [ ] **Slice 1: One project skill stages into the exact plan pane** <requires: —>
  - Files: create `crates/grimoire-core/src/tree.rs`,
    `crates/grimoire-core/tests/tui_adapter.rs`, `crates/grimoire/src/tui/mod.rs`,
    `crates/grimoire/src/tui/model.rs`, `crates/grimoire/src/tui/render.rs`, and
    `crates/grimoire/tests/tui_tracer.rs`; modify the core/app module exports plus the manifest and
    planner seams implicated by the tracer.
  - Change: add the minimum core `DesiredState`, typed edit, factual tree projection, and atomic
    desired-state request needed to stage one available loose skill without mutating the observed
    world. Build a pure UI model and deterministic Ratatui view for one project source, its skill,
    and the plan pane. Selection uses existing core source/name keys. The tracer toggles the skill
    and proves that rendered plan bytes equal the direct core plan byte-for-byte.
  - Verify: begin with failing core and TestBackend tracers, then run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test tui_adapter`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test tui_tracer`, and
    `RUSTC_WRAPPER= cargo check --workspace`; expected: one UI intent crosses core-owned staging
    and planning without I/O or an adapter-owned domain decision.

- [ ] **Slice 2: Complete the tree and independent scopes** <requires: 1>
  - Files: create `crates/grimoire/tests/tui_state.rs` and
    `crates/grimoire/tests/tui_render.rs`; modify the core tree/staging projection,
    `crates/grimoire/src/env.rs`, and the TUI model/render modules from Slice 1.
  - Change: widen the same path to all declared sources, packs, required/optional/unavailable
    members, loose skills, and direct/transitive request roots. Core derives `Off`/`Partial`/`Full`,
    exclusions, inert reasons, trust/live status, validation findings, installed/drift/foreign
    status, collisions, blockers, and atomic accumulated edits with shared-root retention. Add
    independent Project/Global tabs, Project-default fallback, read-only inherited globals and
    shadow labels, navigation/scrolling, typed empty-scope remedies, and a bounded small-terminal
    view. Use representative exact-buffer goldens plus semantic assertions for every Phase 6 tree
    state rather than a separate golden for every combination.
  - Verify: begin with failing core state matrices and UI state/render tests, then run
    `RUSTC_WRAPPER= cargo test -p grimoire-core --test tui_adapter --test manifest --test planner --test adapter_context`,
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test tui_state --test tui_render`, and
    `RUSTC_WRAPPER= cargo check --workspace`; expected: tree facts and edits remain core-derived,
    both scopes render deterministically, and inherited/global facts cannot become project edits.

- [ ] **Slice 4: Run actions through distinct ceremonies and one runtime** <requires: 1, 2>
  - Files: create `crates/grimoire/src/tui/driver.rs` and
    `crates/grimoire/tests/tui_runtime.rs`; modify the TUI model/render modules,
    `crates/grimoire/src/main.rs`, `crates/grimoire/src/command.rs`,
    `crates/grimoire/src/runtime.rs`, `crates/grimoire/src/ui.rs`, and
    `crates/grimoire/src/worker.rs` only where the existing seams require extension.
  - Change: add blocked/additive/destructive apply, cancellation, stale-result reload, staged quit
    discard, and a separate trust-all identity/baseline ceremony. Add explicit focused-source fetch
    and cached update actions; no transition schedules background source work and update has no
    fetch capability. Reuse one worker for blocking load/apply/fetch/update jobs while staging and
    planning remain pure and synchronous. Route bare invocation through an injected event/terminal
    driver, reject non-terminals before raw mode, handle keys/outcomes/resize, and restore the
    terminal exactly once on normal, error, worker-panic, and UI-panic paths. Shutdown joins the
    worker.
  - Verify: start with failing reducer, job-recorder, and scripted-driver tests covering each
    ceremony, explicit source action, busy/error outcome, scope default, resize, shutdown, and
    restoration boundary. Run
    `RUSTC_WRAPPER= cargo test -p skill-grimoire --test tui_runtime --test tui_state --test tui_render --test panic_hook --test worker`
    and `RUSTC_WRAPPER= cargo check --workspace`; expected: only accepted typed effects cross the
    runtime, trust cannot use ordinary apply approval, source work is explicit, and terminal/worker
    custody closes cleanly.

- [ ] **Slice 7: Prove workflows and close the Phase 6 gate** <requires: 1, 2, 4>
  - Files: create `crates/grimoire/tests/tui_parity.rs` and
    `crates/grimoire/tests/tui_workflow.rs`; modify `README.md`, this plan, the focused app boundary
    test, and only production/test files implicated by final gate failures.
  - Change: prove identical direct-core, CLI, and TUI inputs produce identical actions, blockers,
    exit class, and destructiveness. Exercise a temp-home workflow across both scopes through tree
    browsing, loose-skill/pack/optional staging, cancel/apply, inherited shadowing, explicit fetch,
    dedicated trust-all, cached update without fetch, drift, and offline reload. Keep boundary
    proofs focused on app-owned mutation, background fetch, update-time fetch, inherited edits, and
    generic trust approval, with one controlled failing arm for each retained absence guard; the
    repository-wide exhaustive negative-guard and dependency audit remains Phase 7 work. Run Code
    Humanizer over durable TUI code and maintained tests, update README status, and record an
    attended Project/Global terminal pass in this plan. Publish at `stage: implemented` only after
    every gate and terminal scenario is green.
  - Verify: run the focused TUI/core suites, then the attended terminal pass covering navigation,
    staging, plan review, cancellation, apply, resize, error recovery, and shell restoration. Run
    `RUSTC_WRAPPER= cargo fmt --all -- --check`, `RUSTC_WRAPPER= cargo test --workspace`,
    `RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings`, Skill Builder lint/tests,
    repository integrations, pack dogfood/availability, and both worktree/root layout probes.
    Expected: the Phase 6 roadmap gate is green and the binary exposes the canonical CLI plus the
    staged Project/Global tree TUI without taking over Phase 7's final hard-cut audit.

## Done when

- Bare `grimoire` opens a responsive Project/Global tree TUI, defaults correctly when no project
  exists, preserves scope independence, and restores the terminal after normal, error, and panic
  paths.
- Every source, pack, skill, required/optional/unavailable member, request root, inherited/shadowed
  entry, collision, trust/live state, blocker, and drift condition is a direct deterministic core
  projection; pack tri-state and staged edits are never inferred by rendered text or app logic.
- Loose skill, pack, and optional-member edits accumulate only in memory, produce one exact core
  plan, apply through one transaction, and discard safely on cancel/quit/reload. Dedicated
  trust-all and destructive confirmations cannot be bypassed or confused.
- Fetch and update are explicit focused-source worker jobs; update cannot fetch, nothing updates in
  the background, and all mutation remains behind core refresh/plan/apply authorities.
- TestBackend, reducer, worker, driver, parity, temp-home, and attended terminal checks cover every
  Phase 6 state named by the spec; focused controlled-red arms prove each retained adapter absence
  guard. All targeted, workspace, clippy, skills/repository integration, dogfood, hard-cut, and
  root/worktree layout gates are green.

_On completion (before landing), run the host's close-the-books sweep._
