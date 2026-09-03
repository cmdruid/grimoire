---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Workstream worktree-only runtime and primary-checkout safety — Implementation Plan

The tracer serializes one existing local Workstream landing through a process-scoped lease and
proves immediate contention, crash release, and capability refusal. Later slices remove in-place
execution and parking, make recovery current-worktree-only, move every landing policy into linked
worktrees, quarantine legacy parsing behind `migrate`, and finish with adversarial source guards.
This is a delta over the reviewed implementation already present in the `workstream` worktree; it
does not rewrite the implemented plan that produced that base.

Spec: → `specs/2026-09-03-workstream-worktree-only-runtime-and-primary-checkout-safety.md`

Composes with:

- → `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`
- → `specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md`

Implemented base: → `plans/2026-09-02-workstream-composed-control-surface-and-lean-runtime-implementation-plan.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Delta over reviewed work.** Preserve the current reviewed implementation and its verification.
  Do not replace `skills/workstream/scripts/workstream.sh`, regenerate tests wholesale, or rewrite
  the implemented predecessor plan. Make narrow edits against the live worktree and commit each
  green slice independently.
- **One active topology.** Current Workstream configuration, runbooks, projections, helpers,
  verbs, custody prose, and tests have no topology field or branch. A workstream is always the
  registered linked worktree at `<root>/.streams/<stream>` on `stream/<stream>`. Hook context
  isolation remains unchanged and must not be caught by topology guards.
- **Hard migration boundary.** `.workstreams`, legacy `isolation`, and in-place detection are legal
  only in `skills/workstream/verbs/migrate.md`, the package-only migration helper, its tests, and
  the source guard. Ordinary runtime code never imports, sources, probes, or interprets migration
  code. Historical records remain unchanged.
- **Primary checkout is an endpoint.** Creation, load, save, unit and hook work, sync, gates, and
  shipment preparation use the stream worktree and do not require a clean primary checkout.
  Workstream may mutate the primary checkout only during a leased integration-target transaction
  or an explicit control-surface operation. A target transaction requires the expected branch,
  expected tip, no staged/tracked/untracked dirt, no interrupted Git operation, and verified clean
  postconditions.
- **One repository-wide lease.** Resolve one lock file beneath the absolute Git common directory.
  On Darwin/BSD use `lockf -s -t 0 -k FILE COMMAND`; otherwise use `flock -n FILE COMMAND` when
  available. Both backends re-execute one private transaction entrypoint so the operating system
  holds and releases the lock with the process. Never implement a PID file, stale-owner heuristic,
  wait, sleep, polling loop, owner attribution, tracker row, or third acquisition outcome.
- **Receipts outrank the lock.** Persist `running` before external mutation and reconcile refs plus
  delivery receipts after interruption. Lock acquisition proves only exclusive admission for the
  current transaction. `landing-busy` writes nothing and retains the prepared shipment and `land`
  action. Unsupported primitives refuse before stream admission or mutation.
- **Authority stays ephemeral.** The lease does not grant or persist landing consent. Preserve the
  predecessor contract for bare `ship`, `ship --prepare`, bound explicit approval, invalidation,
  and semantic conflict. A same-session mechanical retry may reuse still-valid authority; a reset
  asks again. No tracker or runbook field stores consent.
- **Formats stay at `@1`.** This hard cut precedes landing of the composed implementation, so remove
  `isolation` from current `CONFIG.md`, runbook identity/policy blocks, fingerprints, and read
  projection without an active-format migration or schema bump. Migration consumes legacy
  `isolation: worktree` but never emits it.
- **Narrow Checkpoint cleanup only.** Remove Checkpoint's obsolete sibling-runtime/in-place
  Workstream adapter while preserving its top-level `WORKSTREAM.md` refusal and all save, resume,
  close, anchor, ownership, and recovery behavior. Do not edit Foreman. No file under
  `skills/workstream/` may mention Checkpoint.
- **Scripts compute facts.** Keep semantic judgment and authority in agent-facing prose. Helpers
  validate coordinates, locks, refs, receipts, and files and emit bounded facts. Add no landing
  daemon, scheduler, retry queue, or generalized repository mutex.
- **Patient zero and budgets.** All creation, landing, recovery, lock, migration, and mutation-red
  tests use throwaway repositories. Never inspect or migrate live `.workstreams` sessions. Current
  router, load, ship, runbook, response-line, and response-width budgets may decrease but may not
  increase.
- **Coexisting work.** At plan time `main...workstream` is 25 commits only on `main` and 10 only on
  `workstream`; upstream Backlog and Inspector work overlaps root docs and repository tests. Before
  Slice 1, preserve the reviewed dirty base and these records in commits, reconcile current `main`
  from observed topology, then rerun Task 0. Resolve overlaps hunk by hunk. Do not use the
  Workstream skill to operate this ordinary Git worktree.

## Task 0 — Re-ground the job against the live worktree

- [x] Read the three composing specs, the implemented predecessor plan, `WORKTREE.md`, `AGENTS.md`,
  `README.md`, `PACK.md`, `skills/skill-builder/docs/DOCTRINE.md`, the Workstream router, every
  current verb/template named by this delta, the runtime/helper function inventory, the test
  runner, the repository hard-cut guard, and Checkpoint's Workstream custody adapter. Re-read each
  slice's files plus direct callers immediately before editing.
- [x] Run the package grounding and predecessor baseline:

  ```sh
  skills/contractor/scripts/ground-check.sh . \
    .records/specs/2026-09-03-workstream-worktree-only-runtime-and-primary-checkout-safety.md
  bash skills/workstream/scripts/tests/run.sh
  bash scripts/tests/workstream-hard-cut-contract-test.sh
  shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh \
    scripts/tests/workstream-hard-cut-contract-test.sh
  git diff --check
  ```

  Expected and observed at plan time: zero unresolved references; all 25 Workstream groups are
  green; the existing hard-cut guard reports 27 passed and 0 failed; ShellCheck and whitespace
  pass. These establish the predecessor baseline, not implementation of this specification.
- [x] Inventory live carriers and remeasure instead of trusting the spec snapshot:

  ```sh
  rg -n 'in-place|--in-place|--isolation|isolation|park|unpark|landing|\.workstreams|read-current' \
    AGENTS.md README.md PACK.md skills/workstream skills/checkpoint \
    skills/debugger/SKILL.md skills/delegate/SKILL.md \
    skills/journal/SKILL.md skills/notepad/SKILL.md \
    scripts/tests/workstream-hard-cut-contract-test.sh
  rg -n '^([a-zA-Z_][a-zA-Z0-9_]*)\(\)' \
    skills/workstream/scripts/workstream.sh \
    skills/workstream/scripts/workstream-git.sh \
    skills/workstream/scripts/worktree-teardown.sh
  wc -c skills/workstream/SKILL.md skills/workstream/verbs/{load,ship}.md \
    skills/workstream/templates/workstream-runbook.md
  git status --short --branch
  git rev-list --left-right --count main...HEAD
  ```

  Grounding result: topology conditionals remain in configuration compilation, admission,
  creation, state/read projection, landing, parking, repair/reconfiguration, migration, teardown,
  five custody consumers, and their fixtures. `cmd_land_advance` already has reusable
  receipt-backed local/remote phases but no lease and only a tracked-dirt check. Push and PR
  fixtures currently require in-place streams; `cmd_pr_verify` leaves the local target stale;
  `cmd_read` has no current-checkout entrypoint; migration shares the runtime helper and converts
  in-place sources. Router/load/ship populations are 8,493/10,505/11,613 bytes.

## Slices

- [ ] **Slice 1: Serialize one receipt-backed local landing — tracer** <requires: Task 0>
  - Build-start gate: before editing any implementation file, preserve the reviewed predecessor
    implementation and this plan/spec pair in scoped commits, inspect the then-current
    `main...HEAD` topology, and reconcile current `main` into this ordinary Git worktree from that
    observed topology. Resolve overlaps hunk by hunk; do not replace either side wholesale. Then
    rerun the complete grounding and predecessor baseline below. Treat Task 0 as the plan-author
    snapshot only: Slice 1 may start only after this unchecked build-start gate is green.

    ```sh
    git status --short --branch
    git rev-list --left-right --count main...HEAD
    skills/contractor/scripts/ground-check.sh . \
      .records/specs/2026-09-03-workstream-worktree-only-runtime-and-primary-checkout-safety.md
    bash skills/workstream/scripts/tests/run.sh
    bash skills/checkpoint/scripts/tests/run.sh
    bash scripts/tests/workstream-hard-cut-contract-test.sh
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh \
      skills/checkpoint/scripts/*.sh skills/checkpoint/scripts/tests/*.sh \
      scripts/tests/workstream-hard-cut-contract-test.sh
    git diff --check
    ```

  - Files: modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/scripts/tests/delivery-contract-test.sh`, and
    `skills/workstream/scripts/tests/run.sh`; create
    `skills/workstream/scripts/tests/landing-lease-test.sh`.
  - Change: split target delivery into an outer command and one private re-executed transaction
    entrypoint. Resolve the lock path from
    `git rev-parse --path-format=absolute --git-common-dir`; reject an unsafe common directory or
    lock path. Use the two lock backends in Global Constraints. Create an invocation-local marker
    outside the repository that the locked child writes before transaction work, so a wrapper exit
    code can be distinguished from a child command that returns the same code. Map only immediate
    contention to `status=landing-busy` and `next_action=land`; missing or broken capability emits
    an ordinary diagnostic before stream admission or receipt mutation.
  - Change: hold the lease around fresh stream admission, candidate/expected-tip/receipt
    revalidation, the existing local target fast-forward, and its postcondition. Keep preparation,
    gates, hooks, building, and agent reasoning outside it. Preserve `running`-before-mutation and
    ref/receipt recovery on retry. Add a test-only after-acquisition hook that coordinates fixture
    processes without changing production timing.
  - Change: run two simultaneous landing attempts against one repository. Prove one owner and one
    immediate busy result with byte-identical tracker/preparation evidence. Terminate an acquired
    fixture process and prove later acquisition without stale cleanup. Exercise success, handled
    failure, unsupported PATH, and each available backend. Assert no owner or consent field enters
    runtime state and no production/test path polls or sleeps for ownership.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh \
      skills/workstream/scripts/tests/landing-lease-test.sh
    ```

    Expected: exactly one concurrent local transaction advances; the loser returns immediately,
    writes nothing, and retains `land`. Normal exit and signal release the lease. Unsupported
    locking refuses before mutation, and interrupted delivery still reconciles from refs/receipts.

- [ ] **Slice 2: Hard-cut runtime topology and parking** <requires: 1>
  - Files: modify `skills/workstream/SKILL.md`,
    `skills/workstream/verbs/create.md`, `skills/workstream/verbs/load.md`,
    `skills/workstream/verbs/save.md`, `skills/workstream/verbs/sync.md`,
    `skills/workstream/verbs/reconfig.md`, `skills/workstream/verbs/status.md`,
    `skills/workstream/verbs/close.md`, `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/scripts/workstream-git.sh`,
    `skills/workstream/scripts/worktree-teardown.sh`,
    `skills/workstream/templates/streams-config.md`, and
    `skills/workstream/templates/workstream-runbook.md`; delete
    `skills/workstream/verbs/park.md`; modify
    `skills/workstream/scripts/tests/runtime-tracer-test.sh`,
    `skills/workstream/scripts/tests/runbook-contract-test.sh`,
    `skills/workstream/scripts/tests/unit-lifecycle-test.sh`,
    `skills/workstream/scripts/tests/hook-runtime-test.sh`,
    `skills/workstream/scripts/tests/isolation-contract-test.sh`,
    `skills/workstream/scripts/tests/operator-note-test.sh`,
    `skills/workstream/scripts/tests/read-envelope-test.sh`,
    `skills/workstream/scripts/tests/reconfig-test.sh`,
    `skills/workstream/scripts/tests/topology-contract-test.sh`,
    `skills/workstream/scripts/tests/git-helpers-test.sh`,
    `skills/workstream/scripts/tests/delivery-contract-test.sh`,
    `skills/workstream/scripts/tests/partial-delivery-test.sh`,
    `skills/workstream/scripts/tests/pr-delivery-test.sh`,
    `skills/workstream/scripts/tests/gitlink-readiness-test.sh`,
    `skills/workstream/scripts/tests/ship-friction-test.sh`, and
    `skills/workstream/scripts/tests/run.sh`.
  - Change: remove park/unpark dispatch and commands, `ALLOW_PARKED`, held/parked state,
    in-place scans, root branch switching, and every `unpark` next action. `runtime-init` always
    creates and registers `<root>/.streams/<stream>` on `stream/<stream>`; admission accepts only
    that exact canonical worktree and never treats the primary checkout as a stream. Teardown
    validates and removes only that exact worktree and branch.
  - Change: reduce defaults to `mode`, `landing`, and `ship-cadence`; accept `local`, `push`, or `pr`
    from explicit creation, project defaults, or bundled defaults for every stream. Remove
    `isolation` from validation, compilation, fingerprints, identity/policy blocks,
    reconfiguration, state/read output, repair, and current-format fixtures. A current config with
    `isolation`, create with `--isolation`/`--in-place`, or removed verb follows the ordinary
    unknown-key/option/command refusal without compatibility prose.
  - Change: convert all delivery fixtures to registered linked worktrees and issue candidate
    commits, gates, gitlink publication, and remote operations with `git -C WORKTREE`. Preserve
    hook `--isolation available|unavailable` and `isolated-preferred|required`: those name context
    execution, not topology.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh
    ```

    Expected: every successful create is a registered worktree with no topology field; all landing
    policies configure successfully; retired flags/verbs are unknown; no primary branch switch or
    parked state remains; hook-context isolation cases stay green.

- [ ] **Slice 3: Make recovery current-worktree-only and remove stale custody adapters** <requires: 2>
  - Files: modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/SKILL.md`, `skills/workstream/verbs/load.md`,
    `skills/workstream/templates/compaction-anchor.md`, `AGENTS.md`,
    `skills/checkpoint/SKILL.md`, `skills/checkpoint/verbs/save.md`,
    `skills/checkpoint/scripts/save-guard.sh`,
    `skills/checkpoint/scripts/tests/save-guard-test.sh`,
    `skills/debugger/SKILL.md`, `skills/delegate/SKILL.md`,
    `skills/journal/SKILL.md`, `skills/notepad/SKILL.md`,
    `skills/workstream/scripts/tests/anchor-test.sh`,
    `skills/workstream/scripts/tests/read-envelope-test.sh`,
    `skills/workstream/scripts/tests/topology-contract-test.sh`, and
    `scripts/tests/workstream-hard-cut-contract-test.sh`; create
    `skills/workstream/scripts/tests/recovery-contract-test.sh` and modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: add `read-current WORKTREE`. Canonicalize the supplied current top level, require its
    top-level runbook/tracker, extract only the stream identity needed for admission, and prove the
    path equals `<root>/.streams/<stream>` plus its Git registry entry. Split named `read STREAM`
    into exact identity resolution followed by one shared projection emitter; successful named and
    current reads are byte-identical.
  - Change: reduce the Workstream recovery anchor to one route: without top-level `WORKSTREAM.md`
    it is inert; with one, invoke the canonical primary helper's `read-current` on this top level.
    The agent never opens the full runbook/tracker, scans `.streams`, or infers custody from a
    branch. Reconcile the bounded projection with Git and continue only one known action. Remove
    every case-insensitive Checkpoint reference from `skills/workstream/`.
  - Change: simplify Debugger, Delegate, Journal, and Notepad custody to the current top-level
    signal. In Checkpoint, keep that same signal as the refusal but delete the sibling
    `.streams/*/WORKSTREAM.md` scan, in-place facts, related router/save prose, Workstream-template
    override, and template-derived fixture. Do not change any other Checkpoint command, file
    contract, token, recovery, ownership, anchor, or lifecycle behavior; do not edit Foreman.
  - Change: add zero/current/foreign recovery fixtures, mismatch refusals, byte-equivalent read
    output, and counted mutation-red cases for sibling scanning/raw projection. Extend the hard-cut
    guard to prove zero `checkpoint` under `skills/workstream/` and zero retired topology in the
    enumerated custody paths. Remeasure existing byte ceilings without raising them.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/checkpoint/scripts/tests/run.sh
    bash scripts/tests/workstream-hard-cut-contract-test.sh
    ```

    Expected: current/named reads match; absent or foreign top-level runbooks never cause a sibling
    scan; all identity/transaction mismatches refuse. Checkpoint still refuses inside an admitted
    worktree stream and otherwise behaves unchanged, with no dependency on Workstream internals.

- [ ] **Slice 4: Enforce the primary endpoint for local, push, and PR** <requires: 3>
  - Files: modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/scripts/workstream-git.sh`,
    `skills/workstream/SKILL.md`, `skills/workstream/verbs/ship.md`,
    `skills/workstream/scripts/tests/landing-lease-test.sh`,
    `skills/workstream/scripts/tests/delivery-contract-test.sh`,
    `skills/workstream/scripts/tests/partial-delivery-test.sh`,
    `skills/workstream/scripts/tests/pr-delivery-test.sh`,
    `skills/workstream/scripts/tests/finalization-test.sh`,
    `skills/workstream/scripts/tests/shipment-prepare-test.sh`,
    `skills/workstream/scripts/tests/gitlink-readiness-test.sh`, and
    `skills/workstream/scripts/tests/git-helpers-test.sh`, and
    `skills/workstream/scripts/tests/run.sh`; create
    `skills/workstream/scripts/tests/primary-checkout-contract-test.sh`.
  - Change: centralize leased primary admission. Revalidate shipment candidate, expected target,
    policy, and receipts under the lease; require the primary checkout on the target branch;
    require `git status --porcelain --untracked-files=all` empty; reject merge, rebase,
    cherry-pick, revert, sequencer, or bisect administration resolved through `git rev-parse
    --git-path`; and recheck the target immediately before non-force fast-forward. Verify ref,
    index, worktree, branch, and complete cleanliness before lease release.
  - Change: local advances once with `merge --ff-only` in the primary checkout. Push performs that
    local advance first, then the guarded non-force remote update from the stream worktree while
    retaining the lease across both destinations. Preserve push-friction, partial-delivery, and
    uncertain receipt classifications. Move changed-gitlink object transfer out of preparation's
    primary checkout and into the leased transaction; preparation may only prove or publish from
    the stream worktree.
  - Change: PR branch publication and create/update remain worktree operations and proceed while
    the primary is dirty. Make `pr-verify <stream>` the remote-observation step: after it proves an
    external merge, persist `phase=postflight`, `outcome=active`, `next_action=postflight`, and an
    `advanced` remote-target delivery receipt containing the observed remote target; do not
    synchronize the primary checkout or mark the shipment landed there. Route postflight through
    `land-advance <stream> --authority confirmed`, which reacquires the repository lease,
    revalidates that observed-target receipt plus the shipment inputs, and fast-forwards the clean
    primary target before recording its local-target delivery and `outcome=landed`. A bare
    authorized `ship`
    may supply that authority in the same session; a still-valid same-session authority survives
    only mechanical contention. After context loss, ask again and pass fresh explicit authority.
    Busy/dirty/wrong-branch/interrupted admission writes no authority, keeps
    `next_action=postflight`, and blocks finalization. `ship-finalize` refuses until the local
    postflight receipt proves synchronization; retry revalidates and converges once.
  - Change: test staged, modified, untracked, interrupted-operation, moved-target, and wrong-branch
    primary states. Each permits safe worktree-local create/load/save/unit/sync/prepare but refuses
    applicable target mutation with unchanged refs, receipts, index, and worktree. Inject a race
    between final admission and mutation and require rejection or `uncertain`, never false success.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    ```

    Expected: safe worktree-local progress ignores primary dirt; all target mutations refuse on any
    admission mismatch; clean local/push leave a coherent primary; PR publication tolerates dirt
    but merged postflight waits for clean leased synchronization and finalizes exactly once.

- [ ] **Slice 5: Quarantine the legacy migration machine** <requires: 4>
  - Files: create `skills/workstream/scripts/workstream-migrate.sh`; modify
    `skills/workstream/scripts/workstream.sh`, `skills/workstream/verbs/migrate.md`,
    `skills/workstream/scripts/tests/migration-test.sh`,
    `skills/workstream/scripts/tests/artifact-contract-test.sh`,
    `skills/workstream/scripts/tests/run.sh`, and
    `scripts/tests/workstream-hard-cut-contract-test.sh`.
  - Change: move every `.workstreams` probe, legacy parser, inventory/manifest stage, hook
    extractor, and conversion action into package-only `workstream-migrate.sh`. The Workstream
    router retains only neutral `migrate` dispatch to its verb; that verb invokes the package
    helper. Installed `.streams/workstream.sh` neither sources nor dispatches legacy code.
  - Change: keep `workstream-migrate.sh ROOT inventory|apply`. Inventory validates the entire
    candidate set before creating `.streams` or a manifest. Accumulate all unsupported in-place
    names and refuse the population with instructions to finish or close them under the legacy
    skill. Mixed population, dirt, interrupted Git, divergence, symlinks, unregistered children,
    nested state, collisions, or ambiguity leave paths, refs, registry, primary, manifest, and
    current runtime bytes unchanged.
  - Change: for linked-only approval, preserve the persistent manifest and resumable
    `git worktree move`. Recheck source set, handoff hash, branch tip, target boundary,
    destination, and registry before mutation; preserve branch, commits, queue pointer, mode,
    landing, cadence, and feature-completion hook. Render field-free current `@1` artifacts,
    validate them through ordinary named `read`, resume after move/artifact interruption, and
    remove the old root only when empty. Never switch the primary or import parking state.
  - Change: set the legacy-literal allowlist to exactly the migration verb, migration helper,
    migration test, and source guard. Red-prove the allowlist and every retired topology predicate
    with counted disposable mutations and exact restoration.
  - Verify:

    ```sh
    bash scripts/tests/workstream-hard-cut-contract-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream-migrate.sh \
      skills/workstream/scripts/tests/migration-test.sh
    ```

    Expected: linked migration remains resumable and emits no isolation field; in-place-only and
    mixed inventory lists all unsupported streams and mutates nothing; ordinary runtime contains
    no legacy parser or literal; every source guard has a proven red arm.

- [ ] **Slice 6: Align public guidance and run the composed gate** <requires: 5>
  - Files: modify `README.md`, `PACK.md`, `skills/workstream/SKILL.md`,
    `skills/workstream/verbs/create.md`, `skills/workstream/verbs/load.md`,
    `skills/workstream/verbs/save.md`, `skills/workstream/verbs/sync.md`,
    `skills/workstream/verbs/ship.md`, `skills/workstream/verbs/recycle.md`,
    `skills/workstream/verbs/close.md`, `skills/workstream/verbs/status.md`,
    `skills/workstream/verbs/setup.md`, `skills/workstream/verbs/repair.md`,
    `skills/workstream/verbs/anchor.md`, `skills/workstream/verbs/reconfig.md`,
    `skills/workstream/verbs/migrate.md`,
    `skills/workstream/templates/streams-readme-block.md`,
    `skills/workstream/templates/coordinator.md`,
    `skills/workstream/templates/debug.md`, and
    `skills/workstream/templates/design.md`; modify assertions as required in
    `scripts/tests/clankshop-contract-test.sh`,
    `scripts/tests/configure-clankshop-test.sh`,
    `scripts/tests/project-layer-anchor-contract-test.sh`, and
    `scripts/tests/run.sh`.
  - Change: census all active prose after the mechanical cuts. Describe one worktree-owned loop,
    configurable landing, optional semantic note, bounded current-worktree recovery, and guarded
    primary endpoint. Remove topology qualifiers and parking. Do not add any Checkpoint mention to
    Workstream; retain Checkpoint's own independent package and leave Foreman untouched. Explain
    legacy behavior only in `migrate.md`.
  - Change: remeasure router/load/ship/runbook/response envelopes and simplify rather than consume
    freed budget. Run the source guard over generated control files as well as source. Confirm
    control surface, hooks, tracker, history, shipment, gates, partial delivery, reconfiguration,
    repair, close, nesting, and cross-skill contracts still compose.
  - Verify serially:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/checkpoint/scripts/tests/run.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    cargo test --workspace
    GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire \
      cargo test -p grimoire-pack --test live_root_layout
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh \
      skills/checkpoint/scripts/*.sh skills/checkpoint/scripts/tests/*.sh
    git diff --check
    ```

    Expected: deterministic suites pass against throwaway repositories; mandatory read budgets do
    not increase; only the migration allowlist contains legacy topology; `skills/workstream/` has
    no Checkpoint reference; live-root tests never inspect or move developer streams. Preserve and
    report any established host-specific Cargo exception rather than weakening its assertion.

## Done when

- Every current workstream is one registered linked worktree; current formats, configuration,
  projections, verbs, and helpers contain no topology mode, parking state, or `unpark` action.
- Local, push, and PR prepare and publish from the stream worktree. Every Workstream-controlled
  primary target synchronization uses one non-blocking process-scoped lease with complete clean
  admission and postconditions; external PR merges reconcile afterward.
- Contention is immediate and non-durable, unsupported locking refuses before mutation, signal
  release is proven, and recovery determines outcome only from refs and receipts. Landing authority
  never enters durable state.
- Recovery activates only on the current worktree's top-level runbook; named/current reads share
  one bounded projection and no agent scans siblings or reads raw runtime files.
- Legacy support exists only in the migration verb/helper/tests/guard. Linked migration remains
  resumable; any in-place or mixed population refuses before manifest/repository mutation.
- Checkpoint retains its independent lifecycle and top-level Workstream refusal without its stale
  in-place adapter. Foreman is unchanged, and Workstream contains no Checkpoint reference.
- Workstream, Checkpoint, Backlog, Skill Builder, repository integration, Cargo, live-root,
  ShellCheck, hard-cut, read-budget, mutation-red, and whitespace gates pass. Contractor does not
  land the implementation.

_On completion (before landing), run the host's close-the-books sweep._
