---
doctype: plans
status: published
stage: implemented
schema: contractor/roadmap@1
tags: [roadmap]
---

# Grimoire hard-cut rewrite — Roadmap

This roadmap performs a greenfield rewrite of the alpha domain model inside the existing repository
and crate workspace. It preserves only infrastructure that independently satisfies the published
symlink package-manager contract; existing behavior is evidence, not a compatibility requirement.
The work deliberately sequences foundations before adapters, keeps every source update explicit,
and deletes each superseded abstraction as its replacement reaches a phase gate. Each phase
requires its own reviewed plan before build.

Spec: `.records/specs/2026-08-31-grimoire-symlink-package-manager.md`

## Sequencing
```text
Phase 1 ──> Phase 2 ──> Phase 3 ──> Phase 4 ──┬──> Phase 5 ──┐
                                              └──> Phase 6 ──┴──> Phase 7
```

- Phases 1–4 are a strict foundation chain.
- Phases 5 and 6 both require Phase 4 and are parallel-eligible because they are adapters over the
  same completed core contract; neither may redefine planner or executor behavior.
- Phase 7 requires both adapter phases and is the only close-out phase.
- A phase number expresses a blocking edge, not permission to execute this roadmap directly.

## Cross-cutting foundations
- The published spec is the sole product and format authority. Former design documents may explain
  substrate but cannot preserve an alpha behavior that the spec deletes.
- This is a replacement-in-place, not an incremental compatibility refactor. Existing crate
  boundaries are a useful starting topology, not a product contract. Code is reused only when its
  behavior and boundary already satisfy the new spec without an alpha adapter.
- Each phase removes the obsolete types, fixtures, and production paths in the domain it replaces
  before meeting its gate. Temporary construction scaffolding may exist within a phase, but no
  phase lands with parallel alpha and v1 models or a compatibility translation layer.
- One typed planner/executor owns desired-state resolution, trust blockers, destructiveness,
  preconditions, and filesystem actions. CLI and TUI remain presentation adapters.
- Core code receives resolved paths and injected Git, filesystem, and time boundaries; ambient
  environment access remains confined to the application adapter.
- Remote content is parsed and materialized only as bounded data. Grimoire never executes source
  content, grants trust implicitly, or fetches during update.
- Project and global scopes remain independent while store, trust, project-index, and transaction
  state obey the one documented lock order and crash-recovery contract.
- Every security/absence guard needs a red-proof, every phase keeps the workspace gate green, and
  repository-scanning behavior is also exercised against the root checkout before landing.
- The hard cut has no compatibility reader, migration, force/adopt path, or parallel alpha schema.
  No ADR adds such a branch; a newly discovered product decision returns to the governing spec.

## Phase 1 — Format and inventory foundation   <requires: —>   **SHIPPED 2026-09-01**

> Landed by `stream/app` in five slices. The phase gate is green: canonical inventories and
> receipts, bounded pure-pack parsing, Unicode 17 path handling, capability/review facts, pack
> availability, root dogfood, and the alpha hard cut are complete. Workspace tests and clippy,
> Skill Builder lint/tests, repository integrations, Unicode regeneration, and linked/root layout
> probes passed. The implementation plan remains published at stage `implemented`.
> **Unblocks Phase 2.**

- **Goal:** Make the format library a complete, deterministic authority for skill identity, pure
  packs, discovery, canonical content, capability facts, and source inventory.
- **Scope:** in: bounded `SKILL.md` identity parsing, `grimoire/pack@1`, recursive discovery,
  hostile-path handling, review facts, content and inventory digests, root-pack conversion; out:
  desired-state manifests and locks, source transport, trust, installed links, CLI, TUI.
- **Gate:** Only the new pack grammar and pure-bundle semantics are accepted; deterministic
  discovery and byte-level hash goldens cover valid, malformed, ignored, nested, duplicate, and
  hostile trees; former face/format fixtures and APIs are gone; dependent crates either consume the
  new inventory contract or are reduced to compiling shells for later phases, with no adapter that
  preserves face semantics; the workspace gate is green.
- **Risks:** The current core and dogfood repository depend directly on face-era types, fallback
  discovery, and an incompatible content hash. Mechanical API preservation can hide the obsolete
  model behind renamed types instead of replacing it.

## Phase 2 — Declarative state and planner kernel   <requires: 1>
- **Goal:** Establish project/global desired state, deterministic locked resolution, and one pure
  domain planner before any new filesystem executor is introduced.
- **Scope:** in: scope discovery, comment-preserving manifest edits, hard-cut JSON locks, pack
  resolution and request roots, optional-member states, immutable `WorldState`, typed requests,
  plans, blockers, preconditions, and exit-class facts; out: Git/network access, candidate and
  snapshot custody, trust persistence, link mutation, recovery, CLI/TUI rendering.
- **Gate:** Manifest and lock goldens are deterministic and machine-portable; the alpha lock is a
  hard error with no reader; project/global and pack-resolution matrices cover every requested,
  excluded, unavailable, shared, collision, and shadowing state; pure planner tests prove complete
  actions, blockers, and destructiveness without ambient reads or filesystem writes; the former
  agent-target, live-library, install-log, and immediate-operation domain types are absent rather
  than wrapped.
- **Risks:** Letting current install choreography shape the planner would encode live-library and
  agent-target assumptions that the new contract explicitly removes.

## Phase 3 — Source custody and trust   <requires: 2>
- **Goal:** Make untrusted local and remote sources inspectable and make trusted pinned content
  immutable without activating either.
- **Scope:** in: source identity and URL policy, local Git/live and remote Git backends, bare cache,
  scope/alias candidates, safe review exports, immutable store materialization and repair,
  `source-info@1`, diffs, exact/all-snapshots trust, identity-wide revocation, the ordered
  shared-state locks needed by source/store/trust/candidate operations, and the separate
  store-repair journal and recovery; out: desired-link reconciliation, the scope operation journal,
  project indexing and pruning, final CLI/TUI adapters.
- **Gate:** Local bare-remote and malicious-tree suites prove fetch is inert, candidate custody is
  published only after declaration revalidation under the required lock order, review output is
  lossless, snapshots are immutable and integrity-checked, and quarantine-swap fault injection
  proves corrupt replacement restores or completes idempotently; no source content executes, exact
  trust changes with snapshot identity, trust-all never updates downstream state, and live sources
  remain explicitly non-reproducible.
- **Risks:** Git transport helpers, hostile path bytes, filters, symlinks, submodules, and corrupt
  store replacement are supply-chain boundaries; a convenient checkout path can silently bypass
  the trust model.

## Phase 4 — Transactional core operations   <requires: 3>
- **Goal:** Complete the headless package manager by applying domain plans through owned symlinks
  and crash-safe shared state.
- **Scope:** in: application of every mutating `Request`, including source registration/removal,
  candidate publication, trust changes, reconcile/install/uninstall/update, and prune; check and
  frozen restore, ownership and collision enforcement, the scope operation journal and recovery,
  integration of the Phase 3 shared-state lock substrate, project index, stale-plan rejection, and
  injected production boundaries; out: command parsing and rendering, TUI interaction design,
  legacy cleanup that depends on completed adapters.
- **Gate:** End-to-end core fixtures cover project/global installs, packs and loose skills,
  multi-skill source updates, offline frozen restore, drift, untrusted removal, and prune; fault
  injection proves rollback/roll-forward and idempotent recovery at every scope-journal seam,
  including candidate removal and combined source-add/trust ordering; concurrent scope, fetch,
  trust, and prune tests preserve lock order and reachability; no foreign path is mutated; the
  former install/remove/check choreography and source-path ownership rules are gone.
- **Risks:** The existing symlink calls look reusable but lack the new immutable-store,
  stale-plan, ownership, locking, and recovery contracts. The commit point spans links and several
  state files, so partial success or lock inversion can create failures that ordinary happy-path
  tests will not expose.

## Phase 5 — Complete CLI adapter   <requires: 4>
- **Goal:** Deliver the full npm-like command surface as a thin adapter over the completed core.
- **Scope:** in: canonical grammar, scope resolution, command-specific flags, human and stable
  `source info --json` output, plans, TTY/non-TTY confirmation, exit classes, help/version; out:
  TUI state and rendering, core-side replanning, hidden migration or force flags.
- **Gate:** Every grammar production and invalid flag combination has integration coverage; CLI
  plans and outcomes are direct renderings of core values; temp-home workflows cover init through
  source review, trust, install, explicit update, check, uninstall, frozen restore, and prune with
  the specified exit and confirmation behavior; the former TUI-only argument model is absent.
- **Risks:** Adapter shortcuts around planning, trust, or confirmation would create a second
  mutation API even if the underlying core remains correct.

## Phase 6 — Tree TUI adapter   <requires: 4>
- **Goal:** Deliver project/global skill management through the staged tree interface without
  duplicating package-manager decisions.
- **Scope:** in: Project and Global tabs, inherited global context, source/pack/skill tree,
  tri-state packs, optional toggles, inline blockers and drift, plan pane, explicit fetch/update,
  dedicated trust-all ceremony, reuse of generic worker and terminal-custody infrastructure where
  it still fits; out: new domain semantics, alpha app state transitions, background updates,
  source-content execution, CLI-only presentation.
- **Gate:** State-machine and render tests cover all tree states, staged edits, cancellation,
  blocked apply, shared request roots, missing members, trust/live labels, collisions, shadowing,
  resize and terminal restoration; TUI intents and views are direct projections of core
  `Request`, `Plan`, and source-information values without local package-manager decisions; a human
  terminal pass completes both scopes.
- **Risks:** The existing TUI is organized around a live library and immediate pack actions, so
  retaining its state transitions can bypass staged desired state even when the screen looks new.
  Generic worker and terminal code is reusable; the old application state and rendering contract
  are not.

## Phase 7 — Hard-cut integration and close-out   <requires: 5, 6>

> Completed on `stream/app` with all Phase 2–7 work still accumulated and unshipped. The complete
> workspace, lint, integration, clippy, adapter, source-security, transaction, controlled-red,
> offline-reproduction, dependency, and root/worktree dogfood gates passed without waiver. The
> implementation plan is published at stage `implemented`; landing still requires the user's
> explicit ship decision.

- **Goal:** Make the new product the only Grimoire contract present in code, fixtures,
  documentation, and dogfood workflows.
- **Scope:** in: adapter integration, root-repository dogfood, final dependency and boundary audit,
  deletion of residual alpha documentation, fixtures, dead scaffolding, and `install.sh`; out:
  domain replacements that belonged in earlier phase gates, migration tooling, registries,
  nested/cross-source packs, aliases, force/adopt, Windows support.
- **Gate:** The complete workspace, lint, integration, clippy, CLI/TUI end-to-end, malicious-source,
  transaction fault-injection, root-checkout discovery, and dogfood gates are green; controlled red
  proofs cover every negative guard; planner parity feeds the same request and world inputs through
  both adapters and observes identical actions, blockers, and destructiveness; searches find no
  production alpha schema, face behavior, migration reader, old configuration path, or shell
  installer; another machine reproduces a project offline from its committed manifest and lock.
- **Risks:** A residual audit can reveal an earlier phase that preserved an alpha seam and must be
  reopened; deletion can remove the only test for an invariant along with obsolete code; a
  worktree-only dogfood run can falsely pass if repository discovery ignores root-only content.

_When a phase meets its gate, run the host's close-the-books sweep before advancing._
