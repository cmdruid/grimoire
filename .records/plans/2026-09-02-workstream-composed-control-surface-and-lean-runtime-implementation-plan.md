---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Workstream composed control surface and lean runtime — Implementation Plan

The tracer takes one zero-setup stream through a complete local shipment using the new runbook,
tracker, gate, ref, history, and finalization contracts without exposing the runtime through the
public router. Later slices widen hooks, delivery, control operations, and migration before one
atomic public cut. No committed state exposes the August 31 base runtime without the September 2
refinements.

Specs:

- → `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`
- → `specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md`

Decisions:

- → `adr/2026-08-31-give-workstream-a-dedicated-streams-control-home.md`
- → `adr/2026-08-31-add-explicit-project-layer-discovery-anchors.md`
- → `adr/2026-09-02-reserve-skilldata-for-project-and-global-skill-owned-data.md`

Supersedes: → `plans/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history-implementation-plan.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Composed contract.** Implement both published Workstream specs as one effective design. The
  September 2 spec replaces the base spec's mutable-handoff, runtime-reading, shipment,
  gate-selection, authorization, save-cadence, and `after-eventful-ship` clauses. Do not implement
  or commit an intermediate all-Markdown lifecycle.
- **Later Backlog decision wins.** The published project-layer discovery ADR supersedes the base
  spec's proposed versioned `backlog-route@1` front-door block. Preserve the current explicit,
  marker-free `/backlog anchor`; do not restore route registration, debrief cadence, or managed
  Backlog markers. Only the serialized-custodial-continuation rule for an explicitly invoked
  debrief remains new Backlog work here.
- **Hard cut.** Ordinary Workstream code reads and writes only `.streams` for its control and
  runtime surfaces. `.workstreams` exists only in attended migration/rejection code and fixtures.
  Add no alias, symlink, fallback, or mixed-root mode. Existing project customization bytes under
  retired Workstream support homes are not migrated or deleted.
- **Fixed control ownership.** The only tracked files below `.streams` are `.gitignore`,
  `CONFIG.md`, `README.md`, `history.tsv`, and `workstream.sh`. Immediate child directories are
  ignored stream runtimes. Ignore rules are hygiene; canonical coordinates, Git worktree-registry
  agreement, exact tracked-path allowlists, and nested-runtime guards are the safety boundary.
- **Zero setup.** `create` uses package defaults and the package helper when the tracked control
  surface is absent. Setup is never a prerequisite. Once the initialized control ledger exists,
  stale, missing, malformed, or unsafe managed state refuses and points to naked `repair`.
- **Two runtime artifacts.** Each stream owns ignored `WORKSTREAM.md` plus helper-owned
  `workstream.tsv`. The runbook contains stable purpose, custody, policy, compiled hooks,
  orientation, and one bounded operator note. The strict EAV tracker contains every mutable fact.
  Agents never read or edit the raw TSV; the effective helper is its sole writer.
- **Bounded agent protocol.** `SKILL.md` is at most 10,000 bytes. Mandatory package-owned prose for
  `load` and standalone `ship` is at most 20,000 bytes each. Generated runbook scaffolding is at
  most 4,000 bytes excluding substituted project prose and hook bodies. Common helper responses
  are at most 12 nonempty lines and 1,024 bytes per line. No verb requires another verb or
  `flow.md`; delete `flow.md` at activation.
- **Receipts, not transcripts.** The tracker stores typed state, identities, input fingerprints,
  outcomes, and SHA-256 evidence digests—not prose, commands, output, consent, or retry logs. Every
  mutation validates the complete incumbent, checks its fingerprint and relevant Git inputs,
  rechecks the destination, and atomically renames a sibling temporary file. Unsafe or
  contradictory state refuses.
- **Hook boundary.** Version 1 recognizes only `feature-completion` and `ship-friction`.
  `parallel-preferred` resolves to serialized isolation; there is no parallel dispatcher or
  prepare/apply protocol. A recovered `running` receipt is uncertain and never auto-replays.
  Isolated execution inherits full context, pauses the parent, cannot invoke Workstream lifecycle
  verbs, and returns only the specified four-line closure envelope.
- **Patient zero.** Setup, anchor, migration, creation, and lifecycle tests use throwaway repos.
  Update grimoire's authored recovery prose and inventory guards, but never install a consuming
  project anchor or real `.streams` control surface here.
- **Historical custody.** Do not rewrite published records, `docs/design/`, or `docs/BACKLOG.md` to
  remove retired literals. Migration leaves old project customization and record bytes untouched.
  Add no generic scratch cleanup.
- **Shared-tree custody.** Recheck worktrees and dirty files before each slice. Never read or move
  `/Users/cscott/Repos/grimoire/.workstreams/app/WORKSTREAM.md`; it belongs to another session.
  Preserve unrelated edits and records. The current skilldata cut overlaps root docs, Workstream,
  Backlog, Skill Builder, and repository tests, so rebase it before editing the same hunks.
- **Known baseline drift.** At plan time Workstream's setup suite stops because the in-progress
  `.agents/skilldata` symlink fixture omitted the intermediate `.agents` directory. The first four
  Backlog suites passed; its long setup-resume suite was interrupted after roughly 150 seconds.
  Establish a clean serial baseline in Task 0 and do not attribute these conditions to this plan.
- **Atomic activation.** Slices 1–5 build behind package-only helper/test entrypoints. Slice 6 makes
  the independent Backlog custody adjustment. Slice 7 switches every live Workstream reader,
  writer, route, doctrine exception, inventory rule, and test together. The incumbent public
  `workstream-git.sh` behavior remains unchanged through Slice 6. Slice 8 adds proof only.

## Task 0 — Re-ground the job against HEAD

- [x] Read both specs, all three decisions, this plan, `AGENTS.md`, `README.md`, `PACK.md`,
  `skills/skill-builder/docs/DOCTRINE.md`, `skills/workstream/SKILL.md`,
  `skills/workstream/scripts/tests/run.sh`, `skills/backlog/SKILL.md`,
  `skills/backlog/scripts/tests/run.sh`, `crates/grimoire-pack/src/inventory/scan.rs`,
  `crates/grimoire-pack/tests/support/inventory.rs`, and
  `crates/grimoire-pack/tests/live_root_layout.rs`. Inventory every package and integration path;
  use the literal census below to classify every queued path and symbol. Immediately before each
  slice, read every incumbent file that slice modifies or deletes plus its direct callers and
  tests; do not preload unrelated package bodies. Run:

  ```sh
  skills/contractor/scripts/ground-check.sh . .records/specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md
  skills/contractor/scripts/ground-check.sh . .records/specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md
  rg --files skills/workstream skills/backlog scripts/tests | sort
  git status --short
  git worktree list --porcelain
  ```

  Expected: both checks report zero unresolved references; overlapping and foreign work is
  identified. If the skilldata implementation remains uncommitted, preserve it hunk-by-hunk or
  stop for coordination—never replace its files wholesale.
- [x] Recompute the live carrier and read-budget populations; do not reuse the spec snapshot:

  ```sh
  rg -n '\.workstreams|\.streams|\.spaces/workstream|\.agents/skilldata/workstream|\.records/streams|after-eventful-ship|feature-completion|WORKSTREAM\.md|workstream\.tsv|workstream-setup|flow\.md' \
    README.md PACK.md AGENTS.md scripts skills crates/grimoire-pack \
    --glob '!**/.workstreams/**'
  wc -c skills/workstream/SKILL.md skills/workstream/flow.md \
    skills/workstream/verbs/create.md skills/workstream/verbs/load.md \
    skills/workstream/verbs/save.md skills/workstream/verbs/sync.md \
    skills/workstream/verbs/ship.md skills/workstream/verbs/recycle.md \
    skills/workstream/templates/workstream-handoff.md
  ```

  Classify every retired literal as live behavior, bounded migration/rejection, fixture, or
  historical evidence. Trace mandatory read edges from the live router and verbs before recording
  byte populations.
- [x] Establish the baseline serially without writing the project. Record the current Workstream
  fixture result; do not repair it in Task 0 or change production semantics merely to turn it
  green. Run no second Backlog or repository suite while Backlog setup-resume is active.

  ```sh
  bash skills/workstream/scripts/tests/run.sh
  bash skills/backlog/scripts/tests/run.sh
  bash skills/skill-builder/scripts/tests/run.sh
  skills/skill-builder/scripts/skills-lint.sh
  bash scripts/tests/run.sh
  cargo test --workspace
  GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire \
    cargo test -p grimoire-pack --test live_root_layout
  git diff --check
  ```

  Record exits and assertion counts. If overlapping skilldata work still leaves Workstream red,
  stop before Slice 1 and coordinate its owner to land or repair that work; proceed with one narrowly
  bounded known failure only after explicit human approval. Every implementation slice must be
  independently green and committable—"no worse" is not its gate.

## Slices

- [x] **Slice 1: Ship one zero-setup local unit through the new state machine — tracer** <requires: Task 0>
  - Files: create `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/templates/streams-config.md`,
    `skills/workstream/templates/workstream-runbook.md`,
    `skills/workstream/scripts/tests/runtime-tracer-test.sh`,
    `skills/workstream/scripts/tests/state-contract-test.sh`, and
    `skills/workstream/scripts/tests/read-envelope-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: add one package/installed byte-identical helper. Both package and installed invocation
    require an explicit canonical root; the only authoritative installed helper is
    `<root>/.streams/workstream.sh`. Validate the supplied root, that exact installed path, and
    their Git topology before state access so a linked checkout's tracked `.streams` twin or a
    wrong root cannot acquire control. Implement `runtime-init`, `state`, `unit-begin`, `unit-complete`,
    `ship-prepare`, `gate-run`, `land-advance`, and `ship-finalize` behind package-only calls. Pin
    the exact EAV schema, record order, state-aware fields, value grammars, counters, fingerprints,
    sibling-temp replacement, and validation-before-mutation boundary. Implement disabled hooks,
    local landing, and direct docs/full gates in the tracer; unsupported modes refuse.
  - Change: the tracer creates a temporary repo without control files, creates one linked runtime
    from package defaults, completes one committed unit, prepares with
    `gate-run --class docs --label tracer -- true`, and stops ready without moving the target. It
    then supplies explicit ephemeral authority, advances the local target once, and finalizes.
    Assert one committed history row, one tracker finalization, no raw TSV/hook body in output, and
    idempotent recovery at every phase. Generate each instance ID from 128 bits of secure entropy
    and encode it as exactly 32 lowercase hexadecimal characters; entropy failure occurs before any
    branch, path, or worktree mutation and has no fallback. Preserve that ID through every
    non-create operation. A reused closed name receives a fresh ID, starts unit/shipment counters at
    one only when no same-name history exists, and otherwise seeds both above the greatest existing
    same-name unit sequence. The fresh ID keeps a discarded unlanded instance distinct even when
    its sequence never reached history and is later reused. Strict tables cover every record family
    even when the tracer does not populate it.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/runtime-tracer-test.sh
    bash skills/workstream/scripts/tests/state-contract-test.sh
    bash skills/workstream/scripts/tests/read-envelope-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh skills/workstream/scripts/tests/runtime-tracer-test.sh skills/workstream/scripts/tests/state-contract-test.sh skills/workstream/scripts/tests/read-envelope-test.sh
    ```

    Expected: prepare never mutates the target; missing authority refuses; authorized advance
    occurs once; retries reuse shipment/batch; malformed, reordered, duplicated, oversized,
    symlinked, or concurrently changed state refuses. Linked-checkout tracked twins and wrong-root
    invocation refuse. Creation/recreation tests prove fresh IDs, first-instance counters, and
    history-aware sequence seeding; an injected entropy failure proves that no ref, branch, path,
    worktree, or runtime byte changed. Mutation-red proofs break schema, incumbent, and ref guards
    and restore fixtures byte-identically.

- [x] **Slice 2: Complete the runbook, unit loop, hooks, and isolated closure** <requires: 1>
  - Files: modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/templates/streams-config.md`, and
    `skills/workstream/templates/workstream-runbook.md`; create
    `skills/workstream/scripts/tests/runbook-contract-test.sh`,
    `skills/workstream/scripts/tests/unit-lifecycle-test.sh`,
    `skills/workstream/scripts/tests/hook-runtime-test.sh`,
    `skills/workstream/scripts/tests/isolation-contract-test.sh`, and
    `skills/workstream/scripts/tests/operator-note-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: implement bounded `read`, `diagnose`, operator-note save, phase/queue/unit transitions,
    runbook/tracker binding, and interrupted two-file hash recovery. `read` emits admitted identity,
    purpose/orientation/note projection, compact state, and one `next-action`; never raw rows or
    inactive hooks. Save changes only the note span.
  - Change: compile exactly `feature-completion` and `ship-friction` from versioned blocks while
    preserving provenance and opaque bodies. The helper validates identity and policy, transitions
    a receipt from `ready` to `running` before emitting the exact hook identity, opaque body, and
    fallback policy, then validates the supplied four-line closure/effects envelope and completes
    or reconciles the receipt. It does not create a conversational fork, inherit context, execute a
    hook, or discard a transcript. Resolve inline, isolated-preferred, isolated-required, and
    parallel-preferred mechanically per spec; parallel-preferred chooses serialized isolation.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/runbook-contract-test.sh
    bash skills/workstream/scripts/tests/unit-lifecycle-test.sh
    bash skills/workstream/scripts/tests/hook-runtime-test.sh
    bash skills/workstream/scripts/tests/isolation-contract-test.sh
    bash skills/workstream/scripts/tests/operator-note-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: intake, manual/delegate phases, accumulate, recycle, and close return exact actions;
    load output is bounded; running blocks and never auto-replays; missing isolation follows policy;
    a failed child cannot fall back; started identities ignore future config. The isolation contract
    test simulates only the machine boundary—ready/running handoff, emitted invocation envelope, and
    accepted closure—and does not claim to prove inherited conversation context or transcript
    isolation. Red proofs cover every marker, hash, transition, scope, and closure guard.

- [x] **Slice 3: Add semantic gates, gitlinks, and pre-land friction to preparation** <requires: 2>
  - Files: modify `skills/workstream/scripts/workstream.sh`; create
    `skills/workstream/scripts/tests/shipment-prepare-test.sh`,
    `skills/workstream/scripts/tests/gate-contract-test.sh`,
    `skills/workstream/scripts/tests/gitlink-readiness-test.sh`, and
    `skills/workstream/scripts/tests/ship-friction-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: complete `prepare -> sync -> metadata -> gitlinks -> gate -> friction ->
    ready-to-land`. Capture immutable batch/pre-rebase facts once and resume at the first invalid
    phase. Push/PR preparation fetches remote target objects without updating refs. Reconcile unit
    subjects/counts, append strict-union history, commit shipment metadata once, and validate
    changed gitlinks plus local transfer or remote publication.
  - Change: enforce the two legal gate forms. Direct gates receive exact argv/cwd only. Selector
    gates clear inherited prefix variables, create private mode-0600 NUL manifests and a nonexistent
    receipt path, validate the exact three-row receipt and exit agreement, digest complete output,
    and emit only its tail. Bind evidence to all specified inputs and implement the closed fallback,
    exempting only this shipment's history rows.
  - Change: derive the exact friction reasons; run `ship-friction` after green gate and before
    readiness. Commit/validate effects and return to gate if the candidate changes. Bind provisional
    not-applicable evidence to all reasons; running/complete never replays.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/shipment-prepare-test.sh
    bash skills/workstream/scripts/tests/gate-contract-test.sh
    bash skills/workstream/scripts/tests/gitlink-readiness-test.sh
    bash skills/workstream/scripts/tests/ship-friction-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: every interruption resumes under one identity; clean prepare executes one gate;
    changed inputs invalidate affected evidence; malformed manifests/receipts/environment/output,
    missing objects, and unpublished remote gitlinks block. Friction effects remain pre-land.

- [x] **Slice 4: Complete delivery, partial recovery, PR, and finalization** <requires: 3>
  - Files: modify `skills/workstream/scripts/workstream.sh`; create
    `skills/workstream/scripts/tests/delivery-contract-test.sh`,
    `skills/workstream/scripts/tests/partial-delivery-test.sh`,
    `skills/workstream/scripts/tests/pr-delivery-test.sh`, and
    `skills/workstream/scripts/tests/finalization-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`.
  - Change: implement guarded local/push/PR advance and postflight without force. Persist destination
    running before mutation and observed outcomes afterward; derive the five push classifiers.
    Preserve transaction identity across mechanical contention and lose authority on reset,
    semantic resolution, or changed bound inputs.
  - Change: admit two-parent reconciliation only from verified partial delivery with exact divergent
    tips and neither ancestral. Require old candidate first/divergent tip second, invalidate gate and
    destinations for the new candidate, and reuse the shipment. Semantic conflicts invalidate
    authority. Prove the clean path has no merge. PR records awaiting-merge after one authorized
    push/create-or-update and finalizes only after verified merge.
  - Change: finalize by idempotently applying an optional note, then atomically clearing completed
    transaction rows while retaining counters/cursor. Postflight may verify refs, align submodules,
    and call host stop commands, but creates no tracked commit/event.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/delivery-contract-test.sh
    bash skills/workstream/scripts/tests/partial-delivery-test.sh
    bash skills/workstream/scripts/tests/pr-delivery-test.sh
    bash skills/workstream/scripts/tests/finalization-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: destinations recover independently; uncertain never claims success; reconciliation
    preserves both tips; late rejection activates only provisional friction; finalization
    interruption converges without duplicate history, note, queue advance, or hook. The incumbent
    public `workstream-git.sh` and its tests remain byte-unchanged in this slice.

- [x] **Slice 5: Add control operations and resumable root migration** <requires: 2, 4>
  - Files: modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/templates/streams-config.md`, and
    `skills/workstream/templates/workstream-runbook.md`; create
    `skills/workstream/templates/streams-readme-block.md`,
    `skills/workstream/templates/streams-gitignore`,
    `skills/workstream/verbs/repair.md`, `skills/workstream/verbs/anchor.md`,
    `skills/workstream/verbs/reconfig.md`,
    `skills/workstream/scripts/tests/control-surface-test.sh`,
    `skills/workstream/scripts/tests/anchor-test.sh`,
    `skills/workstream/scripts/tests/reconfig-test.sh`,
    `skills/workstream/scripts/tests/migration-test.sh`, and
    `skills/workstream/scripts/tests/topology-contract-test.sh`; modify
    `skills/workstream/scripts/tests/run.sh`. Keep the public router and old verbs unchanged.
  - Change: implement setup and naked repair over exactly five tracked files. Preserve project
    config/README prose, refresh only managed bytes, report partial progress, make one exact commit
    only under standalone custody, and refuse missing initialized ledger state. `repair <stream>`
    emits guarded candidates and reconstructs only provably quiescent idle state.
  - Change: implement anchor status/install/refresh/remove from embedded recovery bytes, independent
    of installed state. Own one bounded versioned extent and reclassify before replacement.
    Implement reconfig preview/apply, explicit scalar options, repeatable `--inherit`, provenance,
    future-only hook adoption, quiescent topology checks, and pending-hash recovery.
  - Change: implement attended `.workstreams` inventory/preview/apply/resume. Classify with Git
    registry and canonical coordinates; reject collisions, unknown children, nested/mixed roots,
    divergent/missing handoffs, and active uncertainty. Use `git worktree move` for linked streams
    and guarded rename for in-place state. Persist `.streams/.migration.tsv`; rewrite only runtime
    coordinates into the composed files, mint IDs, preserve authored purpose/pointers/hooks, seed
    counters above history, and mark receipts not applicable. Remove old root only when empty and
    validated. Leave customization/records untouched and report anchor refresh without editing it.
  - Verify:

    ```sh
    bash skills/workstream/scripts/tests/control-surface-test.sh
    bash skills/workstream/scripts/tests/anchor-test.sh
    bash skills/workstream/scripts/tests/reconfig-test.sh
    bash skills/workstream/scripts/tests/migration-test.sh
    bash skills/workstream/scripts/tests/topology-contract-test.sh
    bash skills/workstream/scripts/tests/run.sh
    shellcheck skills/workstream/scripts/workstream.sh
    ```

    Expected: zero-setup and initialized modes remain distinct; control reruns converge; anchor and
    reconfig races refuse/recover; each durable move resumes. No fixture relies on ignore rules,
    touches the live `.workstreams/app`, or migrates customization/records.

- [x] **Slice 6: Preserve the lean Backlog anchor and add custodial debrief execution** <requires: Task 0>
  - Files: modify `skills/backlog/verbs/debrief.md`,
    `skills/backlog/scripts/tests/debrief-contract-test.sh`,
    `skills/backlog/scripts/tests/skill-doc-test.sh`,
    `scripts/tests/backlog-provider-contract-test.sh`, and
    `scripts/tests/project-layer-anchor-contract-test.sh` only where current assertions need the
    new custody distinction.
  - Change: keep debrief explicit/provider-backed. Ordinary children still return byproducts.
    Permit only a serialized custodial continuation supplied with completed-unit identity, commit
    evidence, and the prior successful receipt to perform bounded provider writes and at most one
    scoped commit. Add no cursor, Workstream import, callback, cadence, managed route, or marker.
    Preserve marker-free `/backlog anchor` and its project-owned tracker pointer exactly.
  - Verify serially:

    ```sh
    bash skills/backlog/scripts/tests/debrief-contract-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    bash skills/backlog/scripts/tests/run.sh
    bash scripts/tests/backlog-provider-contract-test.sh
    bash scripts/tests/project-layer-anchor-contract-test.sh
    ```

    Expected: ordinary child filing refuses; qualified continuation completes zero or more provider
    rows without a cursor; anchor stays optional/marker-free. Absence guards reject old route,
    debrief-anchor, callback, and cadence behavior.

- [x] **Slice 7: Atomically activate the composed `.streams` runtime** <requires: 3, 4, 5, 6>
  - Files: modify `AGENTS.md`, `README.md`, `PACK.md`,
    `skills/skill-builder/docs/DOCTRINE.md`,
    `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/lint-skilldata-path-test.sh`, and
    `skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`; modify
    `skills/workstream/SKILL.md`, `skills/workstream/verbs/create.md`,
    `skills/workstream/verbs/load.md`, `skills/workstream/verbs/save.md`,
    `skills/workstream/verbs/sync.md`, `skills/workstream/verbs/park.md`,
    `skills/workstream/verbs/ship.md`, `skills/workstream/verbs/recycle.md`,
    `skills/workstream/verbs/close.md`, `skills/workstream/verbs/status.md`,
    `skills/workstream/verbs/setup.md`, `skills/workstream/verbs/migrate.md`, and the Slice 5
    `skills/workstream/verbs/repair.md`, `skills/workstream/verbs/anchor.md`, and
    `skills/workstream/verbs/reconfig.md`; modify `skills/workstream/scripts/workstream.sh`,
    `skills/workstream/scripts/workstream-git.sh`,
    `skills/workstream/scripts/workstream-prime.sh`,
    `skills/workstream/scripts/worktree-exclude.sh`,
    `skills/workstream/scripts/worktree-teardown.sh`,
    `skills/workstream/templates/streams-config.md`,
    `skills/workstream/templates/streams-readme-block.md`,
    `skills/workstream/templates/streams-gitignore`,
    `skills/workstream/templates/workstream-runbook.md`,
    `skills/workstream/templates/compaction-anchor.md`,
    `skills/workstream/templates/coordinator.md`, `skills/workstream/templates/debug.md`, and
    `skills/workstream/templates/design.md`; modify
    `skills/workstream/scripts/tests/lib.sh`, `skills/workstream/scripts/tests/run.sh`,
    `skills/workstream/scripts/tests/artifact-contract-test.sh`,
    `skills/workstream/scripts/tests/seam-contract-test.sh`,
    `skills/workstream/scripts/tests/git-helpers-test.sh`,
    `skills/workstream/scripts/tests/workstream-prime-test.sh`,
    `skills/workstream/scripts/tests/runtime-tracer-test.sh`,
    `skills/workstream/scripts/tests/state-contract-test.sh`,
    `skills/workstream/scripts/tests/read-envelope-test.sh`,
    `skills/workstream/scripts/tests/runbook-contract-test.sh`,
    `skills/workstream/scripts/tests/unit-lifecycle-test.sh`,
    `skills/workstream/scripts/tests/hook-runtime-test.sh`,
    `skills/workstream/scripts/tests/isolation-contract-test.sh`,
    `skills/workstream/scripts/tests/operator-note-test.sh`,
    `skills/workstream/scripts/tests/shipment-prepare-test.sh`,
    `skills/workstream/scripts/tests/gate-contract-test.sh`,
    `skills/workstream/scripts/tests/gitlink-readiness-test.sh`,
    `skills/workstream/scripts/tests/ship-friction-test.sh`,
    `skills/workstream/scripts/tests/delivery-contract-test.sh`,
    `skills/workstream/scripts/tests/partial-delivery-test.sh`,
    `skills/workstream/scripts/tests/pr-delivery-test.sh`,
    `skills/workstream/scripts/tests/finalization-test.sh`,
    `skills/workstream/scripts/tests/control-surface-test.sh`,
    `skills/workstream/scripts/tests/anchor-test.sh`,
    `skills/workstream/scripts/tests/reconfig-test.sh`,
    `skills/workstream/scripts/tests/migration-test.sh`, and
    `skills/workstream/scripts/tests/topology-contract-test.sh`. Delete
    `skills/workstream/flow.md`, `skills/workstream/scripts/hooks.sh`,
    `skills/workstream/scripts/workstream-setup.sh`,
    `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/templates/manifest.md`, `skills/workstream/templates/debrief.md`,
    `skills/workstream/scripts/tests/hooks-test.sh`, and
    `skills/workstream/scripts/tests/setup-test.sh`. Modify
    `scripts/tests/configure-clankshop-test.sh`,
    `scripts/tests/clankshop-contract-test.sh`, `scripts/tests/run.sh`,
    `crates/grimoire-pack/src/inventory/scan.rs`,
    `crates/grimoire-pack/tests/support/inventory.rs`, and
    `crates/grimoire-pack/tests/live_root_layout.rs`; create
    `scripts/tests/workstream-hard-cut-contract-test.sh`.
  - Change: replace the router with bounded scope, zero-floor, custody/ref rules, helper boundary,
    and dispatch. Make every verb self-contained and wire all lifecycle/control operations to the
    tested helper. Explicit create/load/recycle proceeds without redundant confirmation; manual
    model switches, blockers, and semantic forks still stop.
  - Change: public verb instructions own contextual hook execution. When isolation is selected,
    use only an already-exposed native same-harness full-context fork: pause the parent after the
    helper records `running`, pass the emitted single hook body, suppress the child transcript, and
    return only the closure envelope for helper validation. Do not use `/delegate`, `codex exec`, a
    shell subprocess, a generic worker, capability discovery, or a parallel dispatcher. If that
    native primitive is unavailable, take the configured inline-or-stop fallback; a child failure
    never falls back inline.
  - Change: before mutation, create ensures the shared exclusions contain exactly the required
    `/.streams/*/`, `/WORKSTREAM.md`, and `/workstream.tsv` coverage, then writes both runtime
    files. Load/recovery uses only admitted helper projections; save is note-only; ship exposes
    prepare plus resumable readiness/authority;
    status does not read foreign bodies; close validates exact registered targets and performs no
    generic cleanup. Remove Workstream record/template production and retain only plan/roadmap
    consumption plus history.
  - Change: update authored recovery prose to `.streams` without installing an anchor; rewrite
    README/PACK; teach Doctrine/lint the narrow fixed-home exception; switch inventory exclusions
    and live-root test to `.streams` while retaining `repos`; remove configured-project callers of
    deleted scripts. Enforce byte budgets with a test that enumerates every mandatory read edge,
    prints file/span counts and totals, rejects undeclared edges, and red-proves each ceiling.
  - Verify serially:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    cargo test --workspace
    GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire cargo test -p grimoire-pack --test live_root_layout
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh
    git diff --check
    ```

    Expected: the public package uses the composed machinery; every read budget passes; no caller
    reaches a deleted file; all topologies, control states, delivery modes, migration, reconfig,
    isolation, and nesting fixtures pass without touching this repo's front door/foreign worktree.

- [x] **Slice 8: Adversarially prove the hard cut and full-context acceptance path** <requires: 7>
  - Files: modify `skills/workstream/scripts/tests/state-contract-test.sh`,
    `skills/workstream/scripts/tests/read-envelope-test.sh`,
    `skills/workstream/scripts/tests/runbook-contract-test.sh`,
    `skills/workstream/scripts/tests/isolation-contract-test.sh`,
    `skills/workstream/scripts/tests/migration-test.sh`,
    `skills/workstream/scripts/tests/artifact-contract-test.sh`,
    `skills/workstream/scripts/tests/seam-contract-test.sh`,
    `skills/skill-builder/scripts/tests/lint-skilldata-path-test.sh`,
    `skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`,
    `scripts/tests/workstream-hard-cut-contract-test.sh`,
    `scripts/tests/backlog-provider-contract-test.sh`, and `scripts/tests/run.sh`.
  - Change: add a final live-source census rejecting Callback machinery, ordinary `.workstreams`,
    retired Workstream support readers, `.records/streams`, `flow.md`, old templates,
    `after-eventful-ship`, unbounded helper output, raw tracker-reading instructions, and generic
    cleanup. Permit strings only in reviewed migration/rejection tests and history, consistent with
    skilldata lint. Every guard receives a counted disposable mutation and exact restoration.
  - Change: deterministic isolation tests prove only the helper's mechanical invocation and closure
    seam. Separately, under each supported harness, run an attended fixture whose native isolated
    full-context feature hook can use facts available only in the current conversation, invokes
    `/backlog debrief`, makes provider writes/one scoped commit, pauses the parent while running,
    suppresses child output from the parent transcript, and returns only four closure lines. Record
    capability/outcome in the implementation handoff; unavailable isolation follows inline-or-stop
    policy and is never reported as a pass.
  - Verify serially:

    ```sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash scripts/tests/run.sh
    cargo test --workspace
    GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/grimoire cargo test -p grimoire-pack --test live_root_layout
    shellcheck skills/workstream/scripts/*.sh skills/workstream/scripts/tests/*.sh
    git diff --check
    ```

    Expected: deterministic gates pass; the harness result is recorded; no production match escapes
    its bounded exception; the foreign worktree and unrelated dirty files remain unchanged.

## Done when

- Every composed requirement maps to a completed slice: tracker/runbook/read budgets (1, 2, 7);
  hooks/isolation (2, 8); preparation/gates/gitlinks/friction (3); delivery/finalization (4);
  setup/repair/anchor/reconfig/migration (5); Backlog custody without anchor regression (6); public
  hard cut/doctrine/inventory (7, 8).
- Ordinary root sessions load no callback/workflow engine. Stream sessions receive bounded helper
  projections; recovery never reads a foreign handoff, inactive hook, or raw tracker.
- Zero-setup creation, initialized recovery, nesting guards, unit history, single finalization,
  resumable local/push/PR shipping, partial delivery, semantic gates, pre-land friction, and
  same-name recreation pass deterministic fixtures.
- Live Workstream behavior has no ordinary `.workstreams`, retired support reader,
  `.records/streams`, `flow.md`, old templates, `after-eventful-ship`, Callback dispatcher, or
  generic cleanup. Historical and bounded migration/rejection evidence remains.
- Workstream, Backlog, Skill Builder, repository, Cargo, live-root, ShellCheck, read-budget,
  mutation-red, and whitespace gates pass serially. Contractor does not land the implementation.

_On completion (before landing), run the host's close-the-books sweep._

## Implementation outcome

The deterministic Workstream, Backlog, Skill Builder, repository-integration, ShellCheck,
hard-cut, read-budget, and live-root gates passed. The Cargo workspace passed with the known
macOS invalid-UTF-8 filesystem assertion excluded; the unchanged assertion receives
`Uncategorized` instead of its expected `PermissionDenied` on this host.

The mechanical isolated-hook invocation and four-line closure seam passed. An attended native
full-context fork was not launched from this plain-worktree build session, so transcript isolation
and conversational-context inheritance remain harness acceptance evidence rather than a local
deterministic test result.
