---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Backlog routines and universal debriefing — Implementation Plan

Build the first-class tracker layer as a tested provider before widening Backlog's human workflow
and adding consumers. The first implementation slice proves the new TSV API from item creation
through paging, observation, and consumption; later slices deploy it, hard-cut the legacy engine,
wire generic consumers, and remove the old Workstream-specific coupling.

Spec: `.records/specs/2026-08-27-backlog-routines-and-universal-debrief.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published baton:** implement only the published spec above. It has no open questions. If an
  implementation detail would add durable state, compatibility behavior, locking, transactions,
  migrations, or consumer registration, stop and return that design change to the spec.
- **Hard cut:** `.trackers` (or the declared `agent-trackers:` override) is the only live tracker
  layer. Do not probe, import, alias, migrate, or preserve operational entrypoints for
  `.records/trackers` or `<agent-workspace>/backlog/trackers`.
- **Simple durability:** queue TSVs hold current rows, `receipts.tsv` holds only observation and
  consumption receipts, and Git owns history, recovery, merges, and rollback. Do not add revisions,
  tombstones, leases, snapshots, a merge driver, or an internal transaction/versioning layer.
- **Three independent roots:** resolve `agent-records`, `agent-workspace`, and `agent-trackers`
  independently. `<agent-trackers>` defaults to `.trackers`, must be repo-relative and not `.`, and
  must be pairwise non-overlapping with the other roots in both containment directions. Backlog owns
  tracker-root validation; Workspace continues to validate only the workspace root.
- **Stable public contract:** the installed `<agent-trackers>/tracker-api.sh` and its `describe`
  output define `tracker@1`. Consumer skills may resolve and call that API, but must not name
  Backlog verbs, Backlog's workspace namespace, or a consumer-specific setup adapter.
- **Patient-zero:** every setup, route, API, debrief, consumer, and hard-cut proof runs against a
  throwaway project fixture. Never register Backlog or create `.trackers` in this repository's root.
- **Safe writes:** inventory and validate the complete destination set before setup writes; reject
  symlinked components, incompatible entries, unsafe root declarations, and root collisions.
  Preserve incumbent project data and prompt bodies byte-for-byte; only the package-managed API may
  refresh. Preserve and report earlier safe writes if an injected later failure interrupts setup.
- **Line-safe TSV:** all string inputs are single-line and tab-free. Reject invalid strings rather
  than inventing escaping. Reads are side-effect free; only `observe` and `consume` write receipts.
- **Consumer semantics:** observations are advisory per stable consumer key; consumption is global,
  requires a resolution, implies observation, preserves the queue row, and is idempotent. A batch
  may report missing/already-consumed IDs while processing the remaining valid IDs.
- **Coexisting work:** the current worktree already has unrelated edits in `PACK.md`, `README.md`,
  Foreman, Workspace, `skills/skill-builder/docs/DOCTRINE.md`, and
  `skills/skill-builder/scripts/skills-lint.sh`. Re-read and preserve those changes at each slice;
  never overwrite or normalize them as part of this job.
- **Shell portability:** retain the repository's Bash/BSD-macOS conventions, executable bits, stable
  machine-readable facts, `set -euo pipefail` where the owning script uses it, and throwaway-fixture
  test style. Run `bash -n`/the library lint through the advertised gate rather than relying on a
  clean grep alone.

## Slices

- [x] **Task 0: Re-ground every seam against the implementation checkout** <requires: —>
  - Files: read-only inspection of the published spec; `AGENTS.md`; `README.md`; `PACK.md`;
    `skills/backlog/`; `skills/foreman/`; `skills/analyst/`; `skills/workspace/`;
    `skills/workstream/`; `skills/skill-builder/docs/DOCTRINE.md`;
    `skills/skill-builder/scripts/skills-lint.sh`; `scripts/tests/`.
  - Change: make no writes. Run Contractor's ground check, record `git status --short`, and repeat
    capability-wide searches for the legacy tracker homes, legacy Backlog commands, the workspace
    `trackers` kind, Backlog-specific Workstream hooks, and all consumers of the coarse `tracker`
    edge. Re-read every matching live file; historical design records are evidence, not rewrite
    targets. Confirm there is no existing first-class tracker API before sizing new code. Because
    this is shell and prose rather than a compiled API, use the package tests plus `bash -n` and
    `skills-lint.sh` for the executable verdict instead of treating grep as proof.
  - Verify: `skills/contractor/scripts/ground-check.sh "$PWD" "$PWD/.records/specs/2026-08-27-backlog-routines-and-universal-debrief.md"`
    reports `unresolved_count=0`; the recorded search inventory accounts for every live hit before
    Slice 1 begins.

- [x] **Slice 1: Prove `tracker@1` from creation through a consumed receipt** <requires: 0>
  - Files: create `skills/backlog/scripts/tracker-api.sh` and
    `skills/backlog/scripts/tests/tracker-api-test.sh`; modify
    `skills/backlog/scripts/tests/run.sh`.
  - Change: implement the fixed provider CLI exactly as published: `describe`, `catalog`, `create`,
    `page`, `update`, `observe`, and `consume`. The staged provider self-locates from its canonical
    position inside `<agent-trackers>` and refuses a symlinked invocation path; callers invoke it
    directly without passing unrelated root arguments, and the provider does not scan the front
    door. `describe` publishes the exact
    `tracker@1` queue/receipt headers, output facts, cursor rule, and command capability so consumers
    do not need Backlog instructions. Queue rows contain an ID that remains stable for the item's
    live lifetime, UTC creation time, text, and optional evidence; allocate `<stem>-N` above IDs
    present in both that queue and retained receipts so live rows and receipt-derived status cannot
    collide after remove/re-add. Deleted, unreceipted tracker history remains Git's concern rather
    than requiring another allocator ledger. Receipt rows contain `receipt-N`, UTC time, consumer,
    source tracker, item ID, `observed|consumed`, required consumption resolution, and optional
    result. Derive open/consumed status from valid consumption receipts rather than rewriting queue
    rows. Use deterministic file order plus the last returned item ID as the non-snapshot traversal
    cursor. Implement the published receipt restrictions, open-only updates, per-consumer
    `--unobserved`, idempotent receipt writes, consume-implies-observed behavior, and partial batch
    reporting without locks or transaction files.
  - Verify: `bash skills/backlog/scripts/tests/tracker-api-test.sh` exits 0 after red-first fixtures
    prove schema validation, create/update, multi-page traversal, cursor continuation, side-effect-free
    reads, observation surviving updates, required resolutions, shared results, dismissals, idempotent
    repeats, receipt paging restrictions, reserved-receipt refusal, invalid-line refusal, and partial
    missing/already-consumed reporting. `bash skills/backlog/scripts/tests/run.sh` ends
    `backlog tests: ALL GREEN`.

- [x] **Slice 2: Deploy the first-class layer and universal Backlog route** <requires: 1>
  - Files: modify `skills/backlog/scripts/backlog-setup.sh`,
    `skills/backlog/scripts/register-route.sh`, `skills/backlog/scripts/tests/deploy-test.sh`, and
    `skills/backlog/verbs/setup.md`; create `skills/backlog/suggestions/routines.md`.
  - Change: refactor setup to stage the package API at `<agent-trackers>/tracker-api.sh`, create the
    absent-only layer `README.md` and `receipts.tsv`, and initialize bare setup with `tasks`,
    `issues`, `feedback`, and `routines`. An explicit builtin/custom selection replaces that default.
    Accept `--trackers-root` only on first setup: write an absent line-start declaration, require an
    incumbent declaration to match, and refuse relocation once tracker state exists. Pass the
    resolved records/workspace roots into setup validation without writing their defaults. Keep the
    Backlog-owned editable prompt at `<agent-workspace>/backlog/hooks/debrief.md`; preserve incumbent
    H2 bodies, add a strict four-criterion routines section, append custom stubs, and remove only the
    selected stem's section. Make the root `AGENTS.md` block state the universal custodial-session
    cadence and point to the tracker layer without embedding the full procedure. Remove the route
    when the final configurable queue is removed while retaining the layer and `receipts.tsv`.
    Define package-private `tracker-add <stem>` and `tracker-remove <stem>` modes on
    `backlog-setup.sh` as the sole configurable-queue lifecycle writer outside initial setup. Both
    receive the already-resolved roots, run the same full preflight/recheck regime, update only the
    named queue and prompt section, refuse `receipts`, and reconcile the route block; they are not
    added to the public `tracker@1` API.
    Inventory before writes, recheck each destination, refresh only `tracker-api.sh`, and report all
    earlier safe writes after an injected later failure.
  - Verify: `bash skills/backlog/scripts/tests/deploy-test.sh` exits 0 after fixtures prove implicit
    `.trackers`, all four defaults, explicit replacement selection, safe first override, declaration
    mismatch/late-relocation refusal, `.`/traversal/overlap refusal in both directions, symlink and
    incompatible-entry refusal, incumbent README/data/prompt preservation, managed API refresh,
    partial-write recovery, package-private add/remove safety and prompt reconciliation,
    final-queue route removal, and no deployed state in grimoire.

- [x] **Slice 3: Move Backlog's human workflow onto the provider and delete the legacy lifecycle** <requires: 2>
  - Files: modify `skills/backlog/SKILL.md`, `skills/backlog/verbs/tracker.md`,
    `skills/backlog/verbs/file.md`, `skills/backlog/verbs/debrief.md`,
    `skills/backlog/verbs/curate.md`, `skills/backlog/scripts/tests/skill-doc-test.sh`, and
    `skills/backlog/scripts/tests/run.sh`; create `skills/backlog/verbs/query.md` and
    `skills/backlog/scripts/tests/debrief-contract-test.sh`; delete
    `skills/backlog/verbs/migrate.md`, `skills/backlog/scripts/trackers.sh`, and
    `skills/backlog/scripts/tests/trackers-test.sh`.
  - Change: make `file`, `query`, debrief, and curation thin users of the installed API. `query`
    wraps only `catalog` and `page`. `tracker add|remove|list` resolves the three roots, uses
    `catalog` for reads, and invokes only `backlog-setup.sh tracker-add|tracker-remove` for literal
    queue-file lifecycle. Those package-private modes refuse the reserved `receipts` stem, keep the
    prompt H2 population aligned, allow removal despite open rows, and leave unrelated receipts
    untouched. Debrief reads the project prompt itself, scopes only the work since the context's last
    successful debrief, treats zero rows as success, routes each leftover by disposition, lists open
    routines before filing, and updates a matching routine rather than duplicating it. Encode the
    trigger/response/cost/boundary test and require inferred recurrence to say so in evidence. Curate
    exposes only update/consume; remove complete/drop/reorder, migration/import, high-water comments,
    old `status` columns, and every operational reference to owner-local tracker storage. Retain the
    existing scoped-commit custody rules, using only paths reported by the new writers.
  - Verify: `bash skills/backlog/scripts/tests/run.sh` ends `backlog tests: ALL GREEN`. Its
    mutation-red-proof shell fixtures verify the debrief instruction contract, prompt preservation,
    literal add/list/remove wiring, provider calls, and unknown refusal for migrate/import/complete/
    drop/reorder; they do not claim to execute agent judgment. Then walk table-driven root- and
    Workstream-shaped debrief scenarios against the verb contract and record the expected
    create/update/no-op calls for bounded once-only scope, zero results, routine deduplication,
    inferred evidence, custom routing, and delegate-to-caller custody.

- [x] **Slice 4: Add Foreman's generic batch-draining consumer** <requires: 1, 2>
  - Files: modify `skills/foreman/SKILL.md`, `skills/foreman/scripts/tests/run.sh`, and
    `skills/foreman/scripts/tests/skill-doc-test.sh`; create `skills/foreman/verbs/tune.md` and
    `skills/foreman/scripts/tests/tracker-tune-test.sh`.
  - Change: add `consumes: tracker` and dispatch `/foreman tune <tracker>` as runtime curation, not
    setup. Resolve `<agent-trackers>`, require an executable API whose `describe` reports
    `tracker@1`, request one bounded open page for stable key `foreman/tune`, and reason over the
    batch as a whole. Cluster related rows, compare incumbent operations, and propose procedures,
    workflows, doctrine, or dismissals through Foreman's existing acceptance rules. After acceptance,
    consume only resolved rows with a resolution and optional shared operation/workflow reference;
    observe insufficient rows without closing them. Missing provider state must leave Foreman usable
    with tracker data supplied directly by the caller. Do not add `/foreman setup` integration,
    Backlog verb instructions, adapters, cursors, or a process graph inside the routines queue.
  - Verify: `bash skills/foreman/scripts/tests/tracker-tune-test.sh` exits 0 with a real staged API
    fixture proving paging under `foreman/tune`, stable observations across sessions, deferred-row
    receipt behavior, many-to-one result references, accepted consumption calls, absent-provider
    degradation, and mutation-red-proof assertions over the verb's required instruction contract;
    it does not claim to execute Foreman's judgment. Then walk one attended fixture batch through
    `tune.md` and inspect its clustering, incumbent-operation comparison, proposals, and exact
    observe/consume disposition before running `bash skills/foreman/scripts/tests/run.sh`, which
    must end `foreman tests: ALL GREEN`.

- [x] **Slice 5: Move Analyst to `tracker@1` and prove the legacy homes are dark** <requires: 1, 2, 3>
  - Files: modify `skills/analyst/SKILL.md`, `skills/analyst/scripts/analyst-facts.sh`,
    `skills/analyst/scripts/tests/facts-test.sh`, and `skills/analyst/scripts/tests/skill-doc-test.sh`;
    create `skills/backlog/scripts/tests/hard-cut-test.sh`; modify
    `skills/backlog/scripts/tests/run.sh`.
  - Change: resolve `<agent-trackers>` independently in Analyst and use `describe`, `catalog`, and
    side-effect-free `page` calls for status/briefing facts. Preserve Analyst's read-only, facts-not-
    verdicts behavior and graceful absence when no provider exists. Build one red-proof consuming
    fixture containing uniquely recognizable legacy rows in both `.records/trackers` and
    `<agent-workspace>/backlog/trackers`, plus different live rows in `<agent-trackers>`; prove setup,
    catalog, provider paging, and Analyst can surface only the live layer. Assert the
    removed writer and retired verbs are absent or unknown and no compatibility probe remains in
    executable Backlog/Analyst code.
  - Verify: `bash skills/analyst/scripts/tests/run.sh` ends `analyst tests: ALL GREEN` and
    `bash skills/backlog/scripts/tests/hard-cut-test.sh` exits 0 only when both planted legacy
    canaries remain invisible and unchanged.

- [x] **Slice 6: Make the third root portable doctrine and retire the workspace kind** <requires: 2>
  - Files: modify `README.md`, `skills/skill-builder/docs/DOCTRINE.md`,
    `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh`, `skills/workspace/SKILL.md`,
    `skills/workspace/scripts/workspace-check.sh`,
    `skills/workspace/scripts/tests/workspace-check-test.sh`,
    `skills/foreman/scripts/operations-index.sh`, and
    `skills/foreman/scripts/tests/operations-index-test.sh`.
  - Change: document three independent roots and the `agent-trackers:` declaration/default/resolver
    rules; remove `trackers` from the closed owner-local workspace-kind vocabulary and the kind-first
    lint pattern. Make Workspace reject `<agent-workspace>/<owner>/trackers` as an unknown kind while
    remaining completely unaware of and non-authoritative over the first-class tracker root. Remove
    the now-retired reserved owner treatment from Foreman's operation index. Add red-proof lint and
    workspace fixtures so a planted owner-local tracker kind fails while a sibling first-class
    `.trackers` tree is outside Workspace's scope. Preserve the unrelated in-progress `drafts`-kind
    changes in all overlapping files.
  - Verify: `bash skills/workspace/scripts/tests/run.sh`,
    `bash skills/skill-builder/scripts/tests/run.sh`, and
    `bash skills/foreman/scripts/tests/operations-index-test.sh` all exit 0; running
    `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`.

- [x] **Slice 7: Remove Workstream-specific Backlog glue and close the pack seam** <requires: 3, 4, 5, 6>
  - Files: modify `PACK.md`, `scripts/tests/configure-clankshop-test.sh`,
    `skills/workstream/SKILL.md`, `skills/workstream/flow.md`,
    `skills/workstream/verbs/save.md`, `skills/workstream/verbs/close.md`,
    `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/templates/coordinator.md`,
    `skills/workstream/templates/design.md`, `skills/workstream/templates/debug.md`, and
    `skills/workstream/scripts/tests/hooks-test.sh`.
  - Change: make the pack describe Backlog's four defaults, universal debrief cadence, first-class
    tracker provider, and tracker-to-Foreman/Analyst typed seam. Delete the configuration step that
    writes Backlog bodies into Workstream hooks; retain Workstream's generic empty hook points and
    prove them with neutral fixture content. Remove Workstream prose that treats tracker routing,
    tracker commits, occurrence counters, debrief cursors, or tracker candidate buffers as hand-off
    state. Replace the coordinator template's retired instruction to move Backlog rows to `done`
    with provider-neutral guidance that resolves rows through their current consumer workflow.
    Keep Workstream's own execution debrief records and feature/ship/reset events distinct;
    at a healthy boundary, the universally loaded Backlog cadence runs before Workstream saves, but
    Workstream does not invoke or buffer it. Update the consuming-project pack fixture to expect
    `.trackers/{README.md,tracker-api.sh,receipts.tsv,tasks.tsv,issues.tsv,feedback.tsv,routines.tsv}`,
    the Backlog-owned prompt and route block, empty/independent Workstream hooks, rerun idempotence,
    and no pack-created tracker state during installation alone.
  - Verify: `bash skills/workstream/scripts/tests/run.sh` ends `workstream tests: ALL GREEN` and
    `bash scripts/tests/run.sh` ends `repository integration tests: ALL GREEN`; a live-source search
    finds no deployed Workstream-to-Backlog hook body or hand-off tracker buffer outside historical
    design records.

## Done when

The published spec's setup, provider, debrief, routine, consumer, hard-cut, storage-boundary, and
pack/Workstream requirements map to Slices 1–7 with no uncovered requirement. All package suites
named above pass against throwaway fixtures; the attended debrief and Foreman batch walkthroughs
match their agent-facing contracts; `bash skills/skill-builder/scripts/skills-lint.sh .`
reports `fails=0`; `bash scripts/tests/run.sh` reports all repository integration tests green; and
`git diff --check` is clean. A final `rg` confirms that live code and current doctrine contain no
legacy tracker home, retired Backlog command, owner-local `trackers` kind, or Backlog-specific
Workstream glue except deliberate red-proof fixture canaries. Review the complete diff against the
published spec and preserve every pre-existing unrelated worktree change before handing the job to
Inspector.

_On completion (before landing), run the host's close-the-books sweep._
