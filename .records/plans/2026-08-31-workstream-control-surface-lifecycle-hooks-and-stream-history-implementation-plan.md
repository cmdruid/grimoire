---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Workstream control surface, lifecycle hooks, and stream history — Implementation Plan

Spec: → `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`

Decision: → `adr/2026-08-31-give-workstream-a-dedicated-streams-control-home.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published design is authoritative.** Implement the published spec and companion ADR. Do not
  revive the superseded Callback registry or use the unpublished
  `specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` as an input.
- **Hard cut.** Ordinary Workstream code reads and writes only `.streams`. Retired
  `.workstreams`, `.spaces/workstream`, and `.records/streams` spellings may remain only in the
  bounded migration/rejection surfaces and historical evidence. Add no alias, symlink, fallback,
  dual read, or automatic adoption path.
- **One fixed owner surface.** Only `.streams/.gitignore`, `.streams/CONFIG.md`,
  `.streams/README.md`, `.streams/history.tsv`, and `.streams/workstream.sh` may be tracked below
  `.streams`; immediate child directories are ignored runtime streams. Ignore rules are hygiene.
  Canonical coordinates, Git worktree-registry agreement, tracked-path allowlists, and exact
  targets remain the safety boundary.
- **Zero floor with a guarded initialization boundary.** `create` must work with package defaults
  and the package helper when `.streams` has no tracked control files. Once the managed README or
  installed helper establishes initialization, ordinary mutation must refuse stale, missing,
  malformed, or symlinked installed state and direct the caller to repair.
- **Scripts report facts; the agent owns lifecycle judgment.** The package and installed
  `workstream.sh` bytes validate, classify, fingerprint, mint identities, and perform narrow atomic
  state transitions. They do not choose whether to run a hook, retry uncertain effects, advance a
  queue, or ship.
- **Receipts are replay guards.** A 128-bit random immutable instance ID distinguishes stream
  incarnations. Unit and shipment sequences remain monotonic state; receipt identity includes the
  instance ID and compiled hook fingerprint. A recovered `running` receipt is uncertain and never
  replays automatically.
- **No concurrent writers in version 1.** `parallel-preferred` is accepted and fingerprinted but
  resolves to serial isolation. Do not add capability discovery, a prepare/apply artifact, or a
  parallel hook dispatcher. A serialized custodial continuation may file through the explicit
  debrief procedure; an ordinary child or delegate still returns byproducts.
- **Post-ship effects must finish delivery.** A tracked `after-eventful-ship` effect completes only
  after the non-recursive closure tail delivers it under `local`, `push`, or `pr`. The tail writes
  no history, advances no queue, and emits no hook event.
- **Backlog remains independent.** Workstream never detects, installs, configures, or writes
  Backlog. Backlog retains its explicit provider-backed debrief procedure and lean route. A
  consuming project's opaque `CONFIG.md` hook body is the only composition seam.
- **Patient-zero boundary.** Tests install anchors and `.streams` control surfaces only in
  throwaway repositories. Update grimoire's authored `AGENTS.md` recovery doctrine to the new live
  spelling, but never install a managed route block or consuming-project layout into it.
- **Historical custody.** Do not rewrite published `.records` files or `docs/design` evidence just
  to remove retired spellings. The migration explicitly leaves project `.spaces/workstream` and
  `.records/streams` bytes untouched.
- **Coexisting work.** The linked worktree at
  `/Users/cscott/Repos/grimoire/.workstreams/app` belongs to another session. Never read its
  `WORKSTREAM.md`, migrate it, move it, or use it as a fixture. At plan time the only unrelated root
  change is the untracked
  `.records/specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md`; preserve
  it. Recheck status and worktrees before every slice because this is a shared repository.
- **Test isolation.** Backlog's setup-resume suite is long-running and mutation-heavy. Do not run a
  second Backlog suite or repository integration suite concurrently with it. Every new absence or
  guard assertion must be red-proved against a temporary package or fixture copy, count the
  intended mutation, restore byte-identically, and return green.
- **Atomic activation.** Slices 1–3 build and test new Workstream machinery behind package
  boundaries. Slice 4 cuts Backlog behavior, documentation, and repository contracts together.
  Slice 5 is intentionally broad: every live Workstream reader, writer, caller, recovery anchor,
  doctrine exception, inventory, guard, and test switches together so no committed steady state
  mixes old runtime paths with the new control contract. Slice 6 hardens the completed cut; it does
  not carry a contract migration required to make Slice 5 green.

## Task 0 — Re-ground the job against HEAD

- Files: read-only inspection of the published spec and ADR; `AGENTS.md`, `README.md`, `PACK.md`;
  `skills/skill-builder/docs/DOCTRINE.md`; the complete `skills/workstream/` and
  `skills/backlog/` packages; `scripts/tests/`; and
  `crates/grimoire-core/tests/live_repo.rs`.
- Change: make no project write. Re-run the candidate census below, re-read every returned live
  carrier, and search capability-wide for an existing `.streams` control helper, migration engine,
  hook-receipt implementation, or append-only union helper before adding one. Classify retired-path
  matches as `replace`, `migration/rejection`, or `historical`; only the last two may remain after
  Slice 6.

  ```sh
  rg -n \
    -e '\.workstreams' \
    -e '\.spaces/workstream' \
    -e '\.records/streams' \
    -e 'debrief-anchor' \
    -e 'callback-action' \
    AGENTS.md README.md PACK.md skills scripts crates/grimoire-core/tests/live_repo.rs
  ```

- Capture `git status --short` and `git worktree list --porcelain`. If the active legacy app
  worktree is still present, record only its registry path and branch; do not open its handoff.
  Preserve every incumbent diff before editing an overlapping path.
- Run the baseline sequentially:

  ```sh
  skills/contractor/scripts/ground-check.sh <root> \
    <root>/.records/specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md
  bash skills/workstream/scripts/tests/run.sh
  bash skills/backlog/scripts/tests/run.sh
  skills/skill-builder/scripts/skills-lint.sh
  bash scripts/tests/run.sh
  cargo test --workspace
  ```

  Expected plan-time facts: the ground check reports `checked=1` and no unresolved references;
  Workstream reports 125 passing assertions and `ALL GREEN`; Backlog reports every suite green,
  including 414 setup-resume cases; lint reports `fails=0` with only the three existing orphan-edge
  warnings; repository integration reports `ALL GREEN`. Cargo was not measured during planning and
  must establish its own green baseline before Slice 1. Any drift or new failure is investigated
  before sizing or editing; do not normalize it into this job.

## Slices

- [ ] **Slice 1: Prove the control helper through one complete unit — tracer** <requires: Task 0>
  - Files: create `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/templates/streams-config.md`,
    `skills/workstream/templates/streams-readme-block.md`,
    `skills/workstream/templates/streams-gitignore`,
    `skills/workstream/scripts/tests/control-helper-test.sh`,
    `skills/workstream/scripts/tests/config-contract-test.sh`, and
    `skills/workstream/scripts/tests/lifecycle-ledger-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: add one shell entrypoint whose package and installed bytes are identical. It accepts an
    explicit root in package mode and self-locates from canonical `.streams/workstream.sh` in
    installed mode. Implement guarded parent/file classification, exact managed versions,
    configuration parsing and compilation, 128-bit secure instance-ID minting, receipt
    transitions, history validation/first append/idempotence/strict union, and compact fact output.
    Keep setup, anchor mutation, migration, and live Workstream verbs undispatched in this slice.
    The tracer fixture begins with a zero-setup repository, compiles one configured
    `feature-completion` hook into a fixture handoff, mints an instance ID, advances its receipt
    `ready → running → complete`, appends one validated history row with the package helper, and
    proves a retry does not duplicate the key. The focused tables cover every defaults enum,
    precedence/provenance branch, hook grammar/version/fingerprint, malformed byte, invalid policy
    combination, receipt transition, shipment identity, zero-setup header, and strict-union case.
    Use fresh temporary files in the destination directory, recheck parents and incumbents before
    rename, and refuse symlinks or a changed fingerprint.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/control-helper-test.sh
    bash skills/workstream/scripts/tests/config-contract-test.sh
    bash skills/workstream/scripts/tests/lifecycle-ledger-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh \
      skills/workstream/scripts/tests/control-helper-test.sh \
      skills/workstream/scripts/tests/config-contract-test.sh \
      skills/workstream/scripts/tests/lifecycle-ledger-test.sh
    ```

    Expected: every fixture passes; the installed and package invocation paths produce identical
    facts; entropy failure precedes every repository mutation; a deliberately weakened schema,
    fingerprint, transition, and union guard turns its test red before byte-identical restoration.

- [ ] **Slice 2: Complete setup, repair, anchor, and reconfiguration behind the helper** <requires: 1>
  - Files: modify `skills/workstream/scripts/workstream.sh`, the three control templates created in
    Slice 1; create
    `skills/workstream/verbs/repair.md`, `skills/workstream/verbs/anchor.md`,
    `skills/workstream/verbs/reconfig.md`,
    `skills/workstream/scripts/tests/control-surface-test.sh`,
    `skills/workstream/scripts/tests/anchor-test.sh`, and
    `skills/workstream/scripts/tests/reconfig-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`. Do not yet change the public router or old runtime
    verbs.
  - Change: implement helper subcommands for `setup`, naked `repair`, targeted stream repair facts,
    anchor status/install/refresh/remove, and reconfig preview/apply. Setup owns exactly the five
    tracked control files, preserves project `CONFIG.md` and README prose, reports partial safe
    progress, and makes one exact pathspec commit only in standalone mode. Repair refreshes only
    package-managed control bytes and refuses a missing initialized ledger as possible data loss.
    Anchor mutation uses the helper's embedded managed extent, owns one bounded versioned block,
    preserves surrounding bytes, reclassifies before atomic rename, and has no dependency on project
    helper or config. Do not modify the live package `templates/compaction-anchor.md` in this slice:
    the still-public old `create` reads it directly. Anchor tests exercise only the helper's embedded
    candidate bytes in throwaway front doors; Slice 5 changes the package template and router
    together. Reconfig stores scalar provenance, preserves explicit overrides by default,
    implements explicit mutable replacements and repeatable `--inherit`, previews exact old/new
    extents, rejects topology changes and active receipts, and writes only the managed handoff spans.
    Targeted repair emits mechanical facts and exact candidates but never invents intent or enters
    another stream.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/control-surface-test.sh
    bash skills/workstream/scripts/tests/anchor-test.sh
    bash skills/workstream/scripts/tests/reconfig-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: fresh, partial, current, drifted, malformed, symlinked, parent-race, and
    commit-custody fixtures match the published classifiers; setup reruns write nothing; naked
    repair never changes runtime state; anchor tests mutate only throwaway `AGENTS.md` fixtures;
    explicit overrides survive a naked reconfig and change only through a named option or
    `--inherit`. Mutation copies prove each ownership and race guard can fail.

- [ ] **Slice 3: Make legacy stream migration resumable and topology-safe** <requires: 2>
  - Files: modify `skills/workstream/scripts/workstream.sh`; create
    `skills/workstream/scripts/tests/migration-test.sh` and
    `skills/workstream/scripts/tests/topology-contract-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`. Keep the existing public `verbs/migrate.md` untouched
    until Slice 5 atomically changes the router.
  - Change: add the attended `.workstreams` inventory, preview, apply, and resume operations. The
    helper classifies direct legacy children from Git registry plus handoff coordinates, rejects
    collisions, unknown entries, nested runtime, divergent/missing handoffs, active lifecycle
    mutation, and mixed roots, and records the finite operation in ignored
    `.streams/.migration.tsv`. Linked streams move only through `git worktree move`; in-place state
    uses a guarded rename. Rewrite only canonical absolute runtime/handoff coordinates, mint the
    instance ID, mark retained scalar choices `explicit`, preserve compiled hook bodies without
    reading `.spaces`, seed sequences above history, and mark current receipts not applicable.
    Recheck source, destination, registry, and handoff fingerprints around every move. Remove the
    manifest and old root only after complete validation. Never inspect, translate, move, or delete
    `.spaces/workstream` or `.records/streams`.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/migration-test.sh
    bash skills/workstream/scripts/tests/topology-contract-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: linked and in-place fixtures migrate, interruption after each durable move resumes,
    exact coordinates and Git registry agree, unknown bytes remain at the old root and block
    completion, `.spaces` and `.records/streams` fixture checksums never change, and ordinary helper
    mutations refuse while either root carries an incomplete inventory. Run only against temporary
    repositories; the live `.workstreams/app` is not a test target.

- [ ] **Slice 4: Cut Backlog from universal cadence to a lean explicit route** <requires: 1>
  - Files: modify `README.md`, `PACK.md`, `skills/backlog/SKILL.md`,
    `skills/backlog/verbs/setup.md`,
    `skills/backlog/verbs/repair.md`, `skills/backlog/verbs/tracker.md`,
    `skills/backlog/verbs/debrief.md`, `skills/backlog/scripts/backlog-setup.sh`,
    `skills/backlog/scripts/register-route.sh`, `skills/backlog/scripts/route-status.sh`,
    `skills/backlog/scripts/tests/deploy-test.sh`,
    `skills/backlog/scripts/tests/repair-test.sh`,
    `skills/backlog/scripts/tests/setup-resume-test.sh`,
    `skills/backlog/scripts/tests/route-test.sh`,
    `skills/backlog/scripts/tests/debrief-contract-test.sh`,
    `skills/backlog/scripts/tests/hard-cut-test.sh`,
    `skills/backlog/scripts/tests/skill-doc-test.sh`, and
    `skills/backlog/scripts/tests/run.sh`; delete
    `skills/backlog/templates/debrief-anchor.md` and
    `skills/backlog/scripts/tests/debrief-anchor-contract-test.sh`; create
    `skills/backlog/templates/backlog-route.md` and
    `skills/backlog/scripts/tests/route-contract-test.sh`; modify
    `scripts/tests/configure-clankshop-test.sh`, `scripts/tests/clankshop-contract-test.sh`, and
    `scripts/tests/run.sh`; replace
    `scripts/tests/backlog-anchor-contract-test.sh` with
    `scripts/tests/backlog-route-contract-test.sh`.
  - Change: replace `debrief-anchor@1` with the exact `backlog-route@1` discoverability block. Setup,
    repair, and tracker administration reconcile that route through the existing bounded ownership
    machinery, replacing a recognized old package extent without carrying its cadence instructions.
    Delete package-only detector/cadence prose and any callback-action expectation while preserving
    the `produces: tracker` edge and explicit `/backlog debrief`. Amend debrief custody so ordinary
    children/delegates still return byproducts, while a serialized custodial continuation supplied
    with the current completed-unit identity, commit evidence, and prior successful receipt may run
    the provider writes and one scoped commit. Add no durable cursor and no Workstream dependency.
    In the same slice, rewrite the README inventory and PACK seam map so they describe explicit
    Backlog debriefing and the lean discoverability route, with no universal cadence or instruction
    to duplicate that cadence in Workstream hooks.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/run.sh
    bash scripts/tests/backlog-route-contract-test.sh
    bash scripts/tests/configure-clankshop-test.sh
    bash scripts/tests/clankshop-contract-test.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    ```

    Expected: all Backlog tests pass sequentially; fresh and incumbent routes converge to one lean
    block; malformed/duplicate/reserved content refuses; the old recognized extent is replaced;
    explicit debrief still permits zero rows and at most one commit; ordinary child filing remains
    prohibited. Red-proof the live-source absence guards for the deleted template, universal cadence
    text, callback declarations, and old marker. The public inventory and pack seam map agree with
    the installed route, and the complete repository integration suite remains green at this cut.

- [ ] **Slice 5: Atomically activate `.streams` and the lifecycle loop** <requires: 2, 3, 4>
  - Files: modify `AGENTS.md`, `README.md`, `PACK.md`,
    `skills/skill-builder/docs/DOCTRINE.md`,
    `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh`,
    `skills/workstream/SKILL.md`, `skills/workstream/flow.md`,
    `skills/workstream/verbs/create.md`, `skills/workstream/verbs/load.md`,
    `skills/workstream/verbs/save.md`, `skills/workstream/verbs/sync.md`,
    `skills/workstream/verbs/park.md`, `skills/workstream/verbs/ship.md`,
    `skills/workstream/verbs/recycle.md`, `skills/workstream/verbs/close.md`,
    `skills/workstream/verbs/status.md`, `skills/workstream/verbs/setup.md`, and
    `skills/workstream/verbs/migrate.md`; expose the Slice 2
    `skills/workstream/verbs/repair.md`, `skills/workstream/verbs/anchor.md`, and
    `skills/workstream/verbs/reconfig.md`; modify
    `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/scripts/workstream-git.sh`,
    `skills/workstream/scripts/workstream-prime.sh`,
    `skills/workstream/scripts/worktree-exclude.sh`,
    `skills/workstream/scripts/worktree-teardown.sh`,
    `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/templates/compaction-anchor.md`,
    `skills/workstream/templates/coordinator.md`,
    `skills/workstream/templates/debug.md`, and
    `skills/workstream/templates/design.md`; delete
    `skills/workstream/scripts/hooks.sh`,
    `skills/workstream/scripts/workstream-setup.sh`,
    `skills/workstream/templates/manifest.md`,
    `skills/workstream/templates/debrief.md`, and
    `skills/workstream/scripts/tests/hooks-test.sh`; modify every remaining file under
    `skills/workstream/scripts/tests/`, including `run.sh`, `lib.sh`,
    `artifact-contract-test.sh`, `git-helpers-test.sh`, `seam-contract-test.sh`,
    `setup-test.sh`, and `workstream-prime-test.sh`, plus the Slice 1–3 tests; modify
    `scripts/tests/configure-clankshop-test.sh`, `scripts/tests/clankshop-contract-test.sh`,
    `scripts/tests/run.sh`, and `crates/grimoire-core/tests/live_repo.rs`.
  - Change: switch the public router, handoff coordinates, all primitives, flow, helper calls, and
    package contracts together. `create` ensures both shared exclusions, rejects incomplete legacy
    state, resolves explicit/project/bundled scalar provenance, mints the immutable instance ID,
    compiles exactly two hooks, initializes sequences/receipts, and admits linked or in-place
    topology without requiring setup. `load`, `save`, `sync`, `park`, `status`, `close`, and
    `recycle` validate canonical `.streams` custody and never expose another session's handoff body.
    Legitimate tracked control files inside linked checkouts are allowed; an immediate nested
    runtime directory, runtime handoff, or Git marker is corruption independently of ignore state.
  - Change: integrate the lifecycle. Feature completion records semantic commit subjects/count,
    transitions its unit-scoped receipt, and runs inline or a serialized full-context custodial
    continuation according to policy. `parallel-preferred` always resolves serially. Ship allocates
    one shipment identity per nonempty batch, appends one history row per unit before landing, and
    reuses both receipt and row keys across retries. Eventful ship runs the shipment-scoped hook;
    tracked effects require a clean committed state and the non-recursive local/push/PR closure
    tail before completion. Recovery never replays `running` automatically. Reconfig affects only
    identities not started. All unresolved receipts block the next lifecycle seam.
  - Change: remove Workstream record/template ownership. Plans and roadmaps remain external queue
    sources; inline/ad hoc state stays concise in the handoff; `.streams/history.tsv` is the sole
    Workstream activity ledger. Remove the `produces: plan, report` edge and project-template list.
    Replace the old record migration command with the tested `.workstreams` migration and report
    anchor refresh without editing the front door.
  - Change: switch every directly coupled public contract and repository guard in the same cut.
    Update grimoire's authored compaction recovery text to `.streams` without installing a managed
    anchor. Rewrite the Workstream portions of README/PACK for the fixed control surface,
    project-authored configuration, and lifecycle loop. Teach portable doctrine and lint that
    `.streams` is Workstream's ADR-governed narrow fixed-home exception—not a generic fourth home—
    while preserving `.spaces/<skill>/hooks/<seam>.md` for ordinary hook publishers; make a
    temporary non-Workstream use fail. Update configured-project and pack contracts so no live
    caller invokes the deleted setup or hooks scripts, and update the live-repository enumeration
    guard from `.workstreams` to `.streams` while retaining the `repos` exclusion.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/backlog/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    cargo test --workspace
    GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire \
      cargo test -p grimoire-core --test live_repo
    git diff --check
    ```

    Expected: package tests cover zero-setup and initialized paths; linked and in-place lifecycle;
    config snapshots and provenance; unit/shipment receipts; multi-unit history; rebase and land
    retries; local/push/PR closure tails; same-name recreation; explicit uncertain recovery;
    reconfig; setup/repair/anchor; migration; and nesting guards with every `.gitignore` fixture
    removed. Every newly added guard has a counted mutation-red proof. Run an attended acceptance
    fixture under each supported harness: a full-context isolated `/backlog debrief` sees the
    completed unit, commits through the provider, and returns only the four-line closure envelope to
    the parent. Record the harness result in the implementation handoff; a missing isolation
    capability must follow the configured inline-or-stop policy exactly. The same committed state
    has no caller of a deleted Workstream script, no stale `.workstreams` recovery instruction, a
    lint policy that recognizes only the bounded Workstream exception, and green repository and
    live-root gates.

- [ ] **Slice 6: Adversarially harden the hard cut and close repository gates** <requires: 5>
  - Files: modify `skills/backlog/scripts/tests/route-contract-test.sh`,
    `skills/workstream/scripts/tests/artifact-contract-test.sh`,
    `skills/workstream/scripts/tests/seam-contract-test.sh`,
    `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh`,
    `scripts/tests/backlog-route-contract-test.sh`,
    `scripts/tests/clankshop-contract-test.sh`, and `scripts/tests/run.sh`. Leave `docs/design/`,
    `docs/BACKLOG.md`, and published records unchanged as historical evidence. This slice may
    strengthen tests for the already-green cut; it must not defer a behavior, caller, doctrine,
    inventory, or allowlist change required by Slice 5.
  - Change: add one final hard-cut census over live sources. It must reject a Callback package or
    dispatcher, ordinary `.workstreams` reads, `.spaces/workstream` or `.records/streams` access,
    old Workstream manifest/debrief templates, `debrief-anchor@1`, and stale anchor content. Permit
    retired spellings only in the migration/rejection implementation and its fixtures. Red-prove
    each alternative against a temporary source copy with a counted replacement and byte-identical
    restore.
  - Verify sequentially:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    cargo test --workspace
    GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire \
      cargo test -p grimoire-core --test live_repo
    git diff --check
    ```

    Expected: every command exits zero; lint retains no new warning; the already-cut live root enumerates
    without descending into `.streams/<stream>`; configured-project fixtures commit only declared
    `.streams` control files, tracker state, and bounded routes; rerun writes nothing; the final
    census contains only reviewed migration/rejection and historical matches. Inspect the complete
    diff and confirm the live `.workstreams/app` worktree and unrelated record remain untouched.

## Done when

- Every published requirement maps to a completed slice: fixed control layout and topology (1, 2,
  5); setup/repair/anchor/reconfig (2, 5); resumable migration (3, 5); Backlog independence (4);
  lifecycle identities, isolation, closure tails, and history (1, 5); and doctrine/hard-cut absence
  proofs (5, 6).
- An ordinary main-checkout session loads no callback dispatcher or lifecycle catalog. A stream
  session receives one guarded snapshot through its own `WORKSTREAM.md` and can recover after
  compaction without reading another session's handoff.
- Zero-setup create, initialized repair, explicit anchor ownership, preserved override provenance,
  serialized hook execution, non-recursive post-ship delivery, one-row-per-landed-unit history, and
  same-name stream recreation all pass deterministic fixtures.
- Live code has no ordinary `.workstreams`, `.spaces/workstream`, `.records/streams`, Callback, old
  debrief-anchor, or Workstream record-template behavior. Historical evidence and the bounded
  migration/rejection surfaces remain intact.
- Workstream, Backlog, Skill Builder, repository integration, Cargo, live-root, ShellCheck, and
  whitespace gates pass sequentially. The implementation changes remain on their working branch;
  Contractor does not land them to trunk.

_On completion (before landing), run the host's close-the-books sweep._
