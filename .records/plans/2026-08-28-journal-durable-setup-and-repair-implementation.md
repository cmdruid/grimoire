---
doctype: plans
status: published
schema: contractor/plan@1
tags: [plan]
stage: implemented
---

# Journal durable setup and repair — Implementation Plan

Implement the approved Journal addendum as five end-to-end slices. Preserve the adjacent-provider
and managed-README work already present in the dirty worktree; the first tracer adds the missing
transaction boundary instead of rebuilding that completed path.

Spec: → specs/2026-08-28-journal-records-provider-discoverability-and-durable-setup.md

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Preserve coexisting work.** The worktree already contains uncommitted Journal, README,
  configuration-fixture, and consumer updates. Do not reset or replace them. Re-read their current
  diffs before every slice and amend only the named behavior.
- **Measured baseline.** At plan time, `standup-test.sh` reported 61 passing assertions,
  `records-test.sh` reported 55, and `configure-clankshop-test.sh` passed. Treat a different Task 0
  result as drift to reconcile before editing, not as an expected failure.
- **Behavioral invariants.** Do not change the record discriminator, four-key metadata contract,
  schemas, command grammar, output, crawling, relocation, lifecycle, or writer file-mode fallback.
  Never migrate records or rewrite an incumbent ledger during setup or repair.
- **One reconciler, bounded modes.** `setup` owns the complete fixed tool layer and exact prior-path
  cleanup. `repair` calls the same mechanics with a provider-and-managed-README write set and cannot
  initialize the layer, select configuration, touch the ledger, or clean the prior path.
- **Intent only where needed.** Only a non-clean setup transaction creates
  `<agent-workspace>/journal/setup.intent`. Repair and clean setup create no transaction file. The
  intent is transient, never reported, staged, or committed.
- **Provider publication gate.** The managed README block may be written only after the installed
  provider matches bundled bytes, is executable, and its resolved-root/no-command probe exits 1
  with the current usage surface, including `grep`. The later content-aware `check` may report
  curation without undoing a usable tool layer.
- **Ownership and safety.** Preserve record bytes, ledger bytes, unowned README prose, and all
  writer-owned surfaces. Preflight the complete mode-specific write set, recheck parents before
  writes, refuse symlink or incompatible incumbents, and exercise only throwaway fixtures.
- **Portability.** Keep `standup.sh` POSIX `sh` compatible and the tests runnable on macOS/Bash 3.2.
  Parse intent data without `eval`; safely handle spaces, quotes, and shell metacharacters in
  resolved roots.
- **Hard runtime cut.** Current runtime callers use only `<agent-records>/records.sh`. The prior
  workspace path may remain only in setup's bounded cleanup, negative fixtures, and historical
  records.

## Task 0 — Re-ground before editing

Run this read-only gate against the implementation worktree:

```sh
git status --short
git diff -- skills/journal README.md scripts/tests/configure-clankshop-test.sh
skills/contractor/scripts/ground-check.sh \
  /Users/cscott/Repos/grimoire \
  .records/specs/2026-08-28-journal-records-provider-discoverability-and-durable-setup.md
rg -n 'setup[.]intent|phase=ready|reason=repair-required|--finalize' skills scripts
rg -n 'journal/scripts/records[.]sh|<agent-records>/records[.]sh|journal:records-tool' \
  skills README.md PACK.md scripts .records/specs
bash skills/journal/scripts/tests/run.sh
bash scripts/tests/configure-clankshop-test.sh
```

Expected: the spec resolves; no reusable intent/finalization implementation exists; the adjacent
provider, managed README block, legacy cleanup, and their existing tests are present; both baseline
harnesses are green. If another implementation has appeared, reuse its proven mechanism and update
the exact file lists below before proceeding.

## Slices

- [x] **Slice 1: Carry one initialized setup safely through interruption and commit** <requires: Task 0>
  - Files:
    - modify `skills/journal/scripts/standup.sh`
    - modify `skills/journal/verbs/setup.md`
    - modify `skills/journal/scripts/tests/standup-test.sh`
    - modify `skills/journal/scripts/tests/records-test.sh`
    - create `skills/journal/scripts/tests/setup-transaction-test.sh`
    - modify `skills/journal/scripts/tests/run.sh`
    - modify `scripts/tests/configure-clankshop-test.sh`
  - Change:
    - Give the package-private helper an explicit transactional surface:
      `standup.sh setup|finalize <root> --records-root <rel> --workspace-root <rel>`. Implement both
      modes in this slice. Setup derives only the exact prior provider
      `<agent-workspace>/journal/scripts/records.sh` internally from the workspace root; no caller
      accepts or passes `--legacy-tool`. Do not introduce the `repair` mode until Slice 3.
    - Apply the transaction to every non-clean setup while using an initialized fixture whose
      provider is missing as the tracer acceptance case. Preflight the complete setup write set,
      safely create the workspace owner directory, and atomically write `setup.intent` before any
      tool-layer change. Store exactly one schema, phase, absolute project/records/workspace roots,
      absolute prior-provider path, empty-or-path pending entry, and repeated repo-relative
      completed-path entries. Reject
      duplicate, missing, unsupported, symlinked, or declaration-conflicting fields without `eval`.
    - Atomically checkpoint one pending path before each durable destination commit, then replace the
      intent after the postcondition holds to promote that path to completed and clear pending.
      Resume `phase=applying` by validating already-complete results, finishing or promoting the
      pending step, executing only missing steps, and emitting the union of every completed
      `wrote: <repo-relative-path>` entry. After the structural provider gate and final
      content check run, atomically advance to `phase=ready` without deleting the intent.
    - Make `finalize` accept only a matching, revalidated ready intent and remove only that intent.
      In standalone prose, derive the commit pathspec from the recorded union, omitting a path only
      when it is absent and `git ls-files --error-unmatch -- <path>` proves it was never tracked.
      Commit eligible paths through `scoped-commit.sh`, then finalize. A ready rerun with no pending
      Git change revalidates and finalizes without attempting an empty commit. Sweep mode hands the
      union to the caller's recorded diff custody before finalizing.
    - Add a test-only phase stop hook to a copied fixture helper. Prove interruption after intent,
      after provider installation, after ready, after the scoped commit, and before finalization.
      Every rerun must report the same complete union, make at most one commit, and leave neither an
      intent nor an outstanding setup change when complete.
    - Update every current private-helper caller to the explicit setup/finalize protocol in the same
      slice. Package tests may finalize after capturing write-only output; the consuming-project
      sweep must retain that output in its approved diff custody before finalization. Do not leave a
      compatibility parser for the old helper CLI.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/setup-transaction-test.sh
    bash skills/journal/scripts/tests/run.sh
    bash scripts/tests/configure-clankshop-test.sh
    ```

    Expected: the new transaction suite reports zero failures; the existing Journal suites remain
    green; the interrupted initialized fixture finishes with one current provider and one scoped
    commit.

- [x] **Slice 2: Widen durable setup across the full fixed layer and provider upgrade** <requires: 1>
  - Files:
    - modify `skills/journal/scripts/standup.sh`
    - modify `skills/journal/scripts/tests/standup-test.sh`
    - modify `skills/journal/scripts/tests/setup-transaction-test.sh`
  - Change:
    - Put fresh setup, initialized reconciliation, ledger creation, managed-block reconciliation,
      executable restoration, and exact prior-provider cleanup behind the setup transaction from
      Slice 1. A clean layer validates without creating an intent or reporting a write.
    - Preserve the current install-before-advertise-before-remove ordering. Remove only the exact
      resolved `<agent-workspace>/journal/scripts/records.sh` regular file, remove it last, retain a
      coincident newly installed provider, and never remove parent directories. Replace the prior
      generated three-line README pointer only when all three rendered lines match exactly.
    - Validate all existing intent fields and mode destinations before mutation. Cover malformed,
      unsupported, symlinked, stale-root, and argument-conflicting intents; unsafe records,
      workspace, provider, ledger, README, and legacy parents; and immediate parent exchange after
      preflight.
    - Expand failure injection to every fresh and initialized durable write. Prove that record bytes,
      every incumbent ledger byte, unowned README prose, and coincident-root content remain exact;
      malformed records produce a curation advisory without rolling back the tool.
    - Exercise both legacy Git states: a tracked provider deletion remains in the commit pathspec;
      an untracked removed provider remains in the reported union but is omitted only after the
      exact `ls-files` proof. Add mutation red proofs for every new intent/refusal guard by copying
      the helper, applying a counted one-guard mutation, requiring the negative fixture to fail, and
      restoring byte-identical source.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/standup-test.sh
    bash skills/journal/scripts/tests/setup-transaction-test.sh
    shellcheck skills/journal/scripts/standup.sh
    ```

    Expected: all setup matrices and guard mutations pass, clean setup reports no writes and creates
    no intent, and ShellCheck reports no new defect.

- [x] **Slice 3: Add narrow repair through the shared reconciler** <requires: 2>
  - Files:
    - modify `skills/journal/scripts/standup.sh`
    - create `skills/journal/verbs/repair.md`
    - modify `skills/journal/verbs/setup.md`
    - modify `skills/journal/SKILL.md`
    - create `skills/journal/scripts/tests/repair-test.sh`
    - modify `skills/journal/scripts/tests/run.sh`
  - Change:
    - Add `standup.sh repair <root> --records-root <rel> --workspace-root <rel>` as a complete mode
      by calling the same provider renderer, byte installer, executable restoration, usage probe,
      README marker parser, block renderer, and immediate parent checks used by setup, with a hard
      write-set parameter that contains only `<agent-records>/records.sh` and
      `<agent-records>/README.md`. Repair uses the workspace root only to locate and reject an
      active setup intent; it never derives, validates, or inspects the prior provider path.
    - Require an existing safe records root, a regular `history.tsv`, no setup intent, and zero or
      one well-formed managed block. Repair must not create the root or ledger, inspect or remove the
      prior provider, replace the old generated pointer, create a writer surface, or alter record,
      ledger, and unowned README bytes. A clean repair is a no-op and creates no intent.
    - Route `/journal repair` in the frontmatter description and dispatch table. Its procedure
      resolves the same roots, runs repair mode, commits only unique `wrote:` paths when standalone,
      and remains write-only inside a declared sweep. Missing ledger or active setup intent names
      `/journal setup`; content-aware `check` findings name curation without undoing repair.
    - Test missing, non-executable, and byte-stale providers; absent and stale managed blocks; clean
      repair; custom roots and shell metacharacters; malformed markers; unsafe destinations; missing
      ledger; active intent; and a canary prior provider. Add counted mutation red proofs for every
      repair entry guard and assert only the two allowed paths can change.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/repair-test.sh
    bash skills/journal/scripts/tests/run.sh
    ```

    Expected: repair restores only provider and managed-block bytes, every refusal is pre-mutation,
    and the complete Journal harness is green.

- [x] **Slice 4: Publish discoverable guidance and ordered recovery diagnostics** <requires: 3>
  - Files:
    - modify `skills/journal/SKILL.md`
    - modify `skills/journal/verbs/search.md`
    - modify `skills/journal/verbs/done.md`
    - modify `skills/journal/verbs/curate.md`
    - modify `skills/journal/scripts/standup.sh`
    - modify `skills/journal/scripts/tests/standup-test.sh`
    - modify `skills/journal/scripts/tests/repair-test.sh`
    - create `skills/journal/scripts/tests/contract-test.sh`
    - modify `skills/journal/scripts/tests/run.sh`
    - modify `README.md`
  - Change:
    - Make Journal's shared runtime preflight authoritative and ordered: active intent emits
      `reason=setup-required action=/journal setup`; absent/non-regular ledger emits the same;
      initialized missing, non-executable, byte-stale, or usage-stale provider emits
      `reason=repair-required action=/journal repair`. Search, done, and curate must neither invoke
      the prior path nor run the bundled provider against project records.
    - Complete the managed README block with the discriminator, four required keys,
      records-root-relative identity, live crawl, ledger role, safely quoted invocation prefix,
      read-only discovery, lifecycle commands, owner-schema rule, and the warning to run
      `/journal repair` rather than hand-repair or use bundled bytes. Keep specialized curation and
      commit custody out of the block.
    - Execute representative rendered `list`, `grep`, `show`, `history`, `check`, `new`, `touch`,
      `done`, and `relocate` forms against throwaway records. Independently corrupt provider bytes,
      mode, bare-probe exit status, and the `grep` usage line; prove setup and repair leave the
      managed block absent or unchanged until provider validation passes.
    - Add a contract suite for dispatch, exact recovery diagnostics, no bundled runtime invocation,
      and README ownership. Its absence proofs must use recognizable canaries and counted mutations,
      not a clean grep alone. Update the library inventory to advertise setup and repair without
      reproducing their procedures.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/contract-test.sh
    bash skills/journal/scripts/tests/run.sh
    ```

    Expected: every rendered command works, recovery cases select exactly one action, the README
    marker remains unique, and all Journal suites pass.

- [x] **Slice 5: Prove consuming-project and cross-writer integration** <requires: 1, 2, 3, 4>
  - Files:
    - modify `scripts/tests/configure-clankshop-test.sh`
  - Change:
    - Update the delivery-loop fixture to call setup with the resolved workspace root, retain the
      complete reported union in its approved diff custody, and finalize the setup intent without a
      nested commit. Assert the adjacent provider and README instructions are usable, no intent
      remains, no writer directory is created, and the second complete sweep is diff-free.
    - Add initialized repair coverage to the consuming project. In one committed fixture, seed
      deliberately stale provider bytes and a stale but well-formed managed README block, run repair
      in write-only mode, and prove the aggregate diff contains exactly the provider and README paths
      while queue, record, ledger, hook, route, and unowned README bytes remain unchanged. Separately
      remove a committed adjacent provider and prove repair restores it, without treating that
      byte-identical restoration as aggregate-diff evidence.
    - Run the live-source census. The prior workspace-provider path may occur only in setup cleanup,
      negative fixtures, and unchanged historical records. Current guidance and runtime invocations
      must use the adjacent provider; generic writers must retain their staged-tool-or-file-mode
      behavior and must not acquire a Journal setup floor.
    - Run every affected owner and repository gate. Preserve and report unrelated dirty work rather
      than sweeping it into a slice.
  - Verify:

    ```sh
    bash scripts/tests/configure-clankshop-test.sh
    bash skills/architect/scripts/tests/run.sh
    bash skills/contractor/scripts/tests/run.sh
    bash skills/debugger/scripts/tests/run.sh
    bash skills/foreman/scripts/tests/run.sh
    bash skills/inspector/scripts/tests/run.sh
    bash skills/notepad/scripts/tests/run.sh
    bash skills/workstream/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh /Users/cscott/Repos/grimoire
    bash scripts/tests/run.sh
    git diff --check
    rg -n 'journal/scripts/records[.]sh' skills README.md PACK.md scripts .records/specs
    ```

    Expected: every harness exits 0; Skill-builder reports `fails=0`; the source census contains
    only the three allowed historical/cleanup fixture classes; and the final diff is limited to the
    approved implementation paths plus explicitly reported pre-existing work.

## Spec coverage

| Requirement | Slices |
|---|---|
| Adjacent provider, exact bounded prior-path cleanup, and no runtime compatibility path | 2, 5 |
| Durable first and initialized setup, complete path custody, and clean no-op rerun | 1, 2 |
| Narrow provider-and-README repair on initialized layers | 3, 5 |
| Managed README ownership, runnable basics, and provider publication gate | 3, 4 |
| Ordered setup-required versus repair-required diagnostics | 3, 4 |
| Safety guards, interruption recovery, mutation red proofs, and byte preservation | 1, 2, 3, 4 |
| Unchanged record behavior and generic writer independence | 4, 5 |

Coverage gaps: none.

## Done when

- `<agent-records>/records.sh` is the only runtime provider and the adjacent managed README block is
  independently useful.
- Every non-clean setup is resumable through a validated applying/ready intent, retains its complete
  path union through commit custody, and finalizes cleanly; clean setup performs no writes.
- `/journal repair` restores only the provider and managed README block on an initialized layer and
  sends missing prerequisites to setup.
- Setup and repair preserve records, incumbent ledger bytes, project prose, configuration, and
  writer-owned surfaces; bounded prior-provider cleanup remains setup-only and install-first.
- Runtime diagnostics select setup for absent/incomplete initialization and repair for provider
  drift, with no compatibility fallback or bundled runtime invocation.
- Journal, consumer, writer, doctrine, lint, and repository integration gates are green, and all
  material refusal/absence guards have demonstrated red proofs.

_On completion (before landing), run the host's close-the-books sweep._
