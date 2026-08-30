---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Backlog `trackers.sh`, durable setup, and tracker-root README — Implementation Plan

Hard-cut Backlog's public provider to adjacent `trackers.sh`, make the tracker root explain its
current `tracker@1` tool contract, and make setup deterministic and resumable with a narrow repair
entrypoint. Slice 1 crosses the public seam end to end in an initialized fixture: install the renamed
provider, render and execute the managed README contract, repair it, and prove Backlog plus both
generic consumers use only the canonical path. Slice 2 replaces repeat-initialization with the
receipt-ledger boundary and honest Git custody. Slice 3 wires exact runtime recovery and closes the
library-wide contract. Project front-door registration and agent-event dispatch remain outside this
job.

Spec: → `specs/2026-08-28-backlog-tracker-provider-discoverability.md` (published addendum).
Base contract: → `specs/2026-08-27-backlog-routines-and-universal-debrief.md` (published
`tracker@1` design).

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **One canonical provider:** rename the bundled and installed provider from `tracker-api.sh` to
  `trackers.sh`. Preserve commands, arguments, schemas, receipts, paging, validation, and successful
  machine-readable output byte-for-byte. Canonical paths, examples, comments, and path-bearing
  diagnostics change only by substituting the new filename. Add no alias, wrapper, fallback, probe,
  cleanup, or migration branch for the prior filename; an incumbent pre-cut file remains untouched
  project residue.
- **One authoritative README seam:** package one exact `backlog:trackers-tool` block. It identifies
  itself as Backlog's current package-owned contract, names adjacent `trackers.sh` as canonical,
  explains the public files and Git/provider ownership split, documents representative runnable
  forms of all seven commands, and carries the repair rule. It permits direct TSV inspection but
  forbids hand mutation; tells agents to stop and run `/backlog repair` rather than hand-repairing or
  running bundled bytes when the provider is missing, non-executable, or wrong-schema; and states the
  stable-consumer-key, required-resolution, optional evidence/result, and provider-reported-path
  contracts. Examples run from the tracker root through adjacent `./trackers.sh`. Preserve every byte
  outside the block. Duplicate, nested, reversed, or unmatched markers refuse before any write.
- **One shared reconciler, bounded entrypoints:** setup and repair call the same provider-and-README
  primitive. Initialized setup may additionally reconcile prompt sections for incumbent queues.
  Repair requires an existing valid ledger and valid queue schemas and may touch only `trackers.sh`,
  its executable bit, and the managed README block; it never initializes or mutates roots,
  declarations, queues, receipts, prompts, or front-door state.
- **One read-only classifier contract:** invoke
  `tracker-layer-status.sh setup|repair|runtime --root <root> --workspace <W> --records-root <R>
  --trackers-root <T>` with roots already resolved and validated by the caller; it never scans the
  front door. Every successful classification emits exactly one `layer_status=` value from
  `absent|resumable-prefix|initialized|ledger-loss|ambiguous`, one `provider_status=` from
  `absent|current|drifted|non-executable|invalid`, one `readme_status=` from
  `absent|current|drifted|malformed`, and one `recovery_action=` from
  `none|setup|repair|git-restore|human-review`. Setup, repair, runtime prose, and tests consume this
  vocabulary rather than inventing mode-local aliases; callers render the spec's exact user-facing
  diagnostics.
- **Receipt ledger is the initialization boundary:** first setup accepts no queue selection and
  always initializes `tasks`, `issues`, `feedback`, and `routines`. Before `receipts.tsv`, admit only
  an absent layer or an exact deterministic prefix containing the canonical provider, header-only
  built-in queues, their prompt sections, and an earlier custom-root declaration. Publish the ledger
  only after every pre-ledger extent validates. Afterward, preserve the incumbent queue population
  and never recreate a removed queue.
- **Witness-bounded recovery:** a missing ledger present in `HEAD` reports
  `reason=ledger-recovery-required action=git-restore`; a managed README without a ledger and without
  that Git evidence reports `reason=ledger-recovery-required action=human-review`; an otherwise exact
  unwitnessed prefix resumes and may recreate an empty ledger. Runtime without any post-ledger
  witness reports `reason=setup-required action=/backlog setup`. Tests must keep these branches
  distinct.
- **Honest commit custody:** the current invocation emits `wrote=`. A resumed setup emits
  `reconciled=` only for a finite setup-owned postcondition that is current on disk and differs from
  `HEAD`. Their unique union is standalone setup's commit path set. A path with an indistinguishable
  project edit refuses automatic custody. Clean committed reruns emit neither vocabulary; repair
  commits only its unique `wrote=` paths.
- **No data transformation:** preserve valid queue and receipt bytes, IDs, timestamps, receipt
  history, project README prose, incumbent prompt bodies, and unrelated front-door bytes. Tracker
  administration remains the only way to change queue population after initialization. Never run
  bundled provider bytes against project data.
- **Consumer independence:** Backlog, Analyst, Foreman, and integration fixtures resolve
  `<agent-trackers>` and invoke adjacent `trackers.sh`. Analyst and Foreman keep their existing schema
  checks, bounds, stable consumer keys, and graceful degradation; they never invoke a Backlog
  recovery verb or bundled provider.
- **Out-of-scope seams stay inert:** do not revise, replace, or reinterpret project front-door
  registration, event triggers, callback composition, or lifecycle dispatch. Existing tests for
  those surfaces remain green as regression coverage, not as requirements owned by this plan. Never
  install a Backlog route into grimoire's real `AGENTS.md`.
- **Dirty-tree discipline:** preserve all unrelated changes. Re-read overlapping files immediately
  before editing—especially `README.md`, `skills/skill-builder/docs/DOCTRINE.md`,
  `scripts/tests/configure-clankshop-test.sh`, `scripts/tests/run.sh`, and Backlog setup/docs/tests—and
  change only provider, tracker-root documentation, setup-state, recovery, and caller seams.
- **Shell and proof discipline:** remain Bash 3.2/BSD-macOS compatible; use package-relative paths;
  preflight complete write sets; refuse symlinks and incompatible entries; recheck immediately before
  writes; replace atomically; and red-prove every new guard with counted mutations followed by exact
  fixture restoration.

## Slices

- [x] **Task 0: Re-ground the provider, setup states, and every live caller** <requires: —>
  - Files: read-only inspection of `AGENTS.md`; the governing spec and base contract; this plan;
    `README.md`; `PACK.md`; `skills/skill-builder/docs/DOCTRINE.md`; all files under
    `skills/backlog/`; `skills/analyst/SKILL.md`, `skills/analyst/scripts/analyst-facts.sh`, and its
    tests; `skills/foreman/SKILL.md`, `skills/foreman/verbs/tune.md`, and its tests; and
    `scripts/tests/`.
  - Change: make no writes. Record `git status --short`; search live source for `tracker-api.sh`,
    `tracker-api`, `trackers.sh`, `<agent-trackers>`, `tracker@1`, `backlog:trackers-tool`,
    `/backlog repair`, `wrote=`, `reconciled=`, and the three recovery actions. Classify hits as
    provider ownership, runtime consumer, setup/commit custody, negative hard-cut fixture, current
    documentation, or historical record. Confirm `skills/backlog/scripts/trackers.sh`,
    `skills/backlog/verbs/repair.md`, and the new status helpers do not exist and no provider redesign
    has begun. Confirm front-door and callback files are outside the edit set.
  - Verify:

    ```sh
    skills/contractor/scripts/ground-check.sh "$PWD" \
      "$PWD/.records/specs/2026-08-28-backlog-tracker-provider-discoverability.md"
    bash skills/backlog/scripts/tests/run.sh
    bash skills/analyst/scripts/tests/facts-test.sh
    bash skills/foreman/scripts/tests/tracker-tune-test.sh
    bash scripts/tests/configure-clankshop-test.sh
    ```

    Ground check reports only the planned `skills/backlog/scripts/trackers.sh` destination
    unresolved; every test command exits 0 before Slice 1.

- [x] **Slice 1: Cut the public provider, README, repair, and callers end to end** <requires: 0>
  - Files: rename `skills/backlog/scripts/tracker-api.sh` to
    `skills/backlog/scripts/trackers.sh` and
    `skills/backlog/scripts/tests/tracker-api-test.sh` to
    `skills/backlog/scripts/tests/trackers-test.sh`; create
    `skills/backlog/templates/trackers-readme-block.md`,
    `skills/backlog/scripts/tracker-readme-status.sh`,
    `skills/backlog/scripts/tracker-layer-status.sh`,
    `skills/backlog/scripts/tests/readme-test.sh`,
    `skills/backlog/scripts/tests/repair-test.sh`, and `skills/backlog/verbs/repair.md`; modify
    `skills/backlog/scripts/backlog-setup.sh`,
    `skills/backlog/scripts/tests/deploy-test.sh`,
    `skills/backlog/scripts/tests/hard-cut-test.sh`,
    `skills/backlog/scripts/tests/skill-doc-test.sh`,
    `skills/backlog/scripts/tests/run.sh`, `skills/backlog/SKILL.md`, and
    `skills/backlog/verbs/setup.md`; modify `skills/analyst/scripts/analyst-facts.sh` and
    `skills/analyst/scripts/tests/facts-test.sh`; modify `skills/foreman/verbs/tune.md` and
    `skills/foreman/scripts/tests/tracker-tune-test.sh`; modify only the Backlog assertions in
    `scripts/tests/configure-clankshop-test.sh`.
  - Change: rename the package and staged executable while preserving its behavior and applying only
    the declared filename substitutions. Implement `tracker-readme-status.sh <template> <README>` as
    a read-only absent/current/drifted/malformed classifier. Add the shared provider-and-README
    primitive and its initialized-layer `repair` entrypoint; install or refresh the block only after
    the provider is executable, the ledger and queues validate, `describe` emits exactly one
    `schema=tracker@1`, and `catalog` succeeds. Dispatch and document `/backlog repair` in the same
    slice so the README never advertises an unavailable recovery command. Repoint every live
    Backlog, Analyst, Foreman, and consuming-project caller atomically. Keep neighboring prompt,
    front-door, callback, Journal, and other package assertions byte-preserving and behaviorally
    unchanged.
  - Verify: red-first fixtures prove a fresh and initialized layer installs executable
    `trackers.sh`, leaves planted pre-cut bytes unchanged, appends or refreshes exactly one README
    block, preserves surrounding prose and all data, and makes a current rerun byte-stable. Execute
    the rendered forms of `describe`, `catalog`, bounded `page`, `create`, `update`, `observe`, and
    `consume` and verify row/receipt effects. Static assertions require every README ownership,
    safety, recovery, and mutation-semantic statement named in Global Constraints. Marker mutations
    and invalid-schema/catalog fixtures must fail before a README write. Repair fixtures prove
    missing, non-executable, wrong-schema, and drifted providers converge while uninitialized,
    malformed, unsafe, and write-set-canary cases refuse or remain unchanged. The pre-cut provider
    test must fail before the cut and pass only when all live callers use `trackers.sh`. Before the
    Slice 1 commit, the normalized prior provider blob must compare byte-identically with the renamed
    file:

    ```sh
    git show HEAD:skills/backlog/scripts/tracker-api.sh \
      | sed 's/tracker-api\.sh/trackers.sh/g' \
      | cmp - skills/backlog/scripts/trackers.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/analyst/scripts/tests/facts-test.sh
    bash skills/foreman/scripts/tests/tracker-tune-test.sh
    bash scripts/tests/configure-clankshop-test.sh
    shellcheck -S warning \
      skills/backlog/scripts/trackers.sh \
      skills/backlog/scripts/tracker-readme-status.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/backlog/scripts/backlog-setup.sh
    ```

    Every command exits 0, and the Backlog runner names `trackers-test.sh`, `readme-test.sh`, and
    `repair-test.sh`.

- [x] **Slice 2: Make setup deterministic, resumable, and honest about custody** <requires: 1>
  - Files: create `skills/backlog/scripts/tests/setup-resume-test.sh`; modify
    `skills/backlog/scripts/tracker-layer-status.sh`,
    `skills/backlog/scripts/backlog-setup.sh`, `skills/backlog/SKILL.md`,
    `skills/backlog/verbs/setup.md`, `skills/backlog/verbs/tracker.md`,
    `skills/backlog/scripts/tests/deploy-test.sh`,
    `skills/backlog/scripts/tests/hard-cut-test.sh`,
    `skills/backlog/scripts/tests/skill-doc-test.sh`, and
    `skills/backlog/scripts/tests/run.sh`.
  - Change: add the classifier's read-only `setup` mode for absent, exact pre-ledger prefix,
    initialized, Git-recoverable ledger loss, README-only damage, and ambiguous state. Remove all
    setup queue-selection forms. For a custom first root, write the validated declaration first;
    install or validate provider, four header-only queues, and prompt sections before atomically
    publishing `receipts.tsv`; render the README only after provider discovery succeeds. On an
    initialized layer, preserve the ledger and incumbent queue population, add prompt sections only
    for existing queues, and reconcile provider/README through the shared primitive. Keep
    `tracker add|remove` as the only population-changing operations. Compare setup-owned extents with
    `HEAD` to emit exact `reconciled=` paths, combine them with current `wrote=` paths for standalone
    commit custody, and refuse a path containing indistinguishable project edits.
  - Verify: enumerate every valid subset of pre-ledger package extents and inject failure before and
    after every durable write. Every exact prefix converges; custom/nonempty queues, malformed
    extents, unsafe paths, and other ambiguous states refuse before mutation. A missing ledger in
    `HEAD` reports `action=git-restore`; README-only damage reports `action=human-review`; loss before
    either witness resumes only when the remainder is an exact fixed prefix. Initialized fixtures
    preserve default-with-removal, custom, and zero-queue populations. Git-custody fixtures prove
    current `wrote=`, prior exact `reconciled=`, unique scoped path union, mixed-edit refusal, and no
    output after the aggregate commit. Counted mutations red-prove the prefix classifier, both
    ledger-loss branches, publication boundary, initialized-queue preservation, and custody guard.
    Existing front-door regression suites remain green without modifying their production files or
    fixtures beyond setup-call syntax made obsolete by the removal of queue selection.

    ```sh
    bash skills/backlog/scripts/tests/setup-resume-test.sh
    bash skills/backlog/scripts/tests/run.sh
    bash scripts/tests/configure-clankshop-test.sh
    shellcheck -S warning \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tests/setup-resume-test.sh
    ```

    Every command exits 0.

- [x] **Slice 3: Wire runtime recovery and publish the repository contract** <requires: 2>
  - Files: create `skills/backlog/scripts/tests/runtime-recovery-test.sh` and
    `scripts/tests/backlog-provider-contract-test.sh`; modify
    `skills/backlog/scripts/tracker-layer-status.sh`, `skills/backlog/SKILL.md`,
    `skills/backlog/verbs/setup.md`, `skills/backlog/verbs/repair.md`,
    `skills/backlog/verbs/tracker.md`, `skills/backlog/verbs/file.md`,
    `skills/backlog/verbs/query.md`, `skills/backlog/verbs/debrief.md`,
    `skills/backlog/verbs/curate.md`,
    `skills/backlog/scripts/tests/repair-test.sh`,
    `skills/backlog/scripts/tests/debrief-contract-test.sh`,
    `skills/backlog/scripts/tests/skill-doc-test.sh`, and
    `skills/backlog/scripts/tests/run.sh`; modify `README.md`,
    `skills/skill-builder/docs/DOCTRINE.md`,
    `scripts/tests/configure-clankshop-test.sh`, and `scripts/tests/run.sh`.
  - Change: add the classifier's `runtime` mode and make every Backlog provider-using verb consume it
    before invoking installed `trackers.sh`. Emit the exact repair, Git-restore, human-review, or
    setup diagnostic for its state and never resume setup from a runtime verb. Keep Analyst and
    Foreman independent. Name `<agent-trackers>/trackers.sh` in current library documentation and
    portable doctrine. Add a repository contract guard for the hard cut, one shared repair
    implementation, generic-consumer independence, and patient-zero protection; exclude historical
    records and named negative fixtures only, and red-prove every absence assertion against a copied
    source population.
  - Verify: runtime fixtures red-prove all four diagnostics through tracker, file, query, debrief,
    and curate entrypaths and prove bundled bytes are never run against project data. Repair covers
    default-with-removal, custom, and zero-queue initialized populations and remains provider/README
    only after injected failures. The consuming-project fixture proves fixed first initialization,
    executable adjacent provider, one authoritative README block, runnable discovery, stable
    initialized rerun, and absence of the pre-cut provider on a fresh project while preserving
    neighboring assertions.

    ```sh
    bash skills/backlog/scripts/tests/runtime-recovery-test.sh
    bash skills/backlog/scripts/tests/repair-test.sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/analyst/scripts/tests/facts-test.sh
    bash skills/foreman/scripts/tests/tracker-tune-test.sh
    bash scripts/tests/backlog-provider-contract-test.sh
    bash scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    shellcheck -S warning \
      skills/backlog/scripts/trackers.sh \
      skills/backlog/scripts/tracker-readme-status.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tests/setup-resume-test.sh \
      skills/backlog/scripts/tests/runtime-recovery-test.sh \
      skills/backlog/scripts/tests/repair-test.sh
    git diff --check
    ```

    Every command exits 0, and a final live-source search confirms no tracker layer or Backlog route
    was installed in grimoire's real project surfaces.

## Done when

Fresh setup creates the fixed four queues, publishes the ledger only after its pre-ledger
postconditions validate, and exposes executable adjacent `trackers.sh` plus one authoritative README
block. Exact interrupted prefixes resume; initialized setup preserves removed, custom, and empty
queue populations; narrow repair changes only provider/README; runtime distinguishes repair,
Git-backed ledger recovery, README-only human review, and first setup; and standalone commits own
exactly their reported paths. The prior provider is untouched residue and absent from all live
contracts and callers. Backlog, Analyst, Foreman, consuming-project, skill-lint, repository,
ShellCheck, mutation-red-proof, and diff gates pass while every unrelated worktree change and all
out-of-scope front-door/event behavior remain intact.

_On completion (before landing), run the host's close-the-books sweep._
