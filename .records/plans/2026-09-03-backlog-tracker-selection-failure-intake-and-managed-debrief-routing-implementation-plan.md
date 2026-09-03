---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Backlog tracker selection, failure intake, and managed debrief routing — Implementation Plan

The first slice proves the riskiest new path end to end: an explicit tracker selection survives
every supported durable-write interruption and produces exactly the selected initialized layer
without durable intent residue. Later slices add failure-family intake, replace the discovery pointer with a managed
project debrief route, compose that route with setup only after explicit consent, and close the
repository-wide documentation and boundary contracts. Each slice is independently testable and
committable.

Spec: `.records/specs/2026-09-03-backlog-tracker-selection-failure-intake-and-project-debrief-routing.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** implement the published spec and its published companion ADR exactly.
  Do not use the plan to reopen tracker taxonomy, automatic registration, the five packaged stems,
  `--debrief` consent, or the fixed `.trackers` home.
- **Project-layer compatibility:** keep `schema=tracker@2`, queue and history headers, provider
  commands, ID shapes, custom tracker behavior, and `history.tsv` as the initialization boundary.
  Initialized projects retain their table population and incumbent `.trackers/DEBRIEF.md` prose;
  setup never silently adds `failures`.
- **Selection intent:** `.trackers/.setup-selection` is temporary recovery evidence, not a durable
  configuration file. On a new layer it is the first file beneath `.trackers`; every selected stem
  is validated and normalized before the first write; success removes the intent only after full
  postcondition validation. Its atomic-write temporary is covered by cleanup traps; any unexplained
  residue matching that reserved temporary family is ambiguous, never absent or legacy state. New
  and pre-feature recovery shapes must remain distinguishable.
- **Scripts compute facts; verbs decide:** package scripts validate state, render candidates, and
  emit compact facts. Attended multi-selects, route choices, competing-route judgment, and debrief
  family matching remain agent procedures in `SKILL.md` and `verbs/`; do not move session judgment
  into shell heuristics.
- **Front-door authority:** only explicit `/backlog anchor`, first-time setup consent, or an explicit
  setup `--debrief` may install or refresh the managed route. `--remove` remains available when the
  tracker layer is missing, malformed, or stale. Repair, migration, runtime, queue administration,
  debrief, curate, and setup without route consent neither require nor mutate `AGENTS.md`.
- **Managed ownership:** Backlog owns only the bytes between its exact markers. Preserve all bytes
  outside the block, preserve customized legacy pointer prose, and migrate only the byte-exact old
  canonical pointer. One reserved heading is shared arrangement, not Backlog-owned content.
- **Preview and custody:** every front-door mutation is bound to a displayed candidate and SHA-256
  identities for both its base file and rendered result, revalidates immediately before atomic
  rename, preserves incumbent mode, and reports one exact path. Tracker setup and anchor remain
  separate path-scoped commits; anchor refusal or commit failure cannot roll back successful setup.
- **Package independence:** use `skill-feedback` only as source prior art for managed-block parsing,
  digest, and test shapes. Backlog must copy no runtime dependency or global-home assumption and
  must remain a standalone, harness-agnostic durable-home skill with its existing typed edge.
- **Patient-zero safety:** every consuming-project layer and front-door mutation runs in a throwaway
  Git fixture. Never add a Backlog route or deployed tracker content to Grimoire's real `AGENTS.md`,
  and never let a test write that file.
- **Red proofs:** every new absence, refusal, path, concurrency, ownership, and front-door-neutrality
  guard must first fail against a counted deliberate fixture mutation, then pass after byte-identical
  restoration. A green-only assertion is not evidence that its failing arm executes.
- **Coexisting work:** `main` moved after the design review and other worktrees are active. Before
  walking this plan, the Workstream owner must sync `stream/backlog`, repeat Task 0, and reconcile any
  overlap rather than weakening a contract or overwriting another worktree's changes. Preserve the
  two design records and all unrelated tracked or untracked work.
- **Live Grimoire layer:** do not add `failures.tsv` or rewrite prompt sections in Grimoire's own
  initialized four-queue `.trackers` layer. Fresh throwaway fixtures prove five-default behavior;
  `canonical-provider-parity-test.sh` continues to prove the live incumbent is preserved.

## Task 0 — Re-ground after sync, before editing

- [x] Record `HEAD`, branch, `git status --short`, `git worktree list`, and the target delta after the
  Workstream owner syncs to `main`. Re-read the published spec and ADR, root `AGENTS.md`,
  `skills/skill-builder/docs/DOCTRINE.md`, `README.md`, and every Backlog file named below. Any new
  overlap or changed project invariant is a blocker until reconciled. Run Workstream's cheat-sheet
  validator because its current orientation snapshot predates the latest `main` movement.
- [x] Run Contractor's ground check on the spec. Re-read the exact option parser, write order,
  classifier outputs, prompt ordering, API update behavior, anchor preflight, scoped-commit rules,
  and the assertions in all affected package and repository tests; a resolving path is not proof
  that its current behavior still supports the plan.
- [x] Search capability-wide for setup intent/recovery protocols and managed project route helpers.
  Reuse the current Backlog atomic-write and recovery conventions and the installed
  `skill-feedback` anchor's parsing/digest shapes, but verify that no existing Backlog implementation
  already supplies the required behavior before adding it.
- [x] Re-run the baseline gates and record any incumbent warning or failure. At plan time the Backlog
  suite, provider/anchor/parity contracts, and skill lint were green; lint reported only three
  existing Foreman edge warnings. A changed baseline must be diagnosed before Slice 1.

Verification:

```sh
skills/contractor/scripts/ground-check.sh <root> \
  .records/specs/2026-09-03-backlog-tracker-selection-failure-intake-and-project-debrief-routing.md
skills/workstream/scripts/workstream-git.sh cheatsheet-check <root>
git -C <root> rev-parse HEAD
git -C <root> branch --show-current
git -C <root> status --short --branch
git -C <root> worktree list --porcelain
git -C <root> log stream/backlog..main --oneline
bash skills/backlog/scripts/tests/run.sh
bash scripts/tests/backlog-provider-contract-test.sh
bash scripts/tests/project-layer-anchor-contract-test.sh
bash scripts/tests/canonical-provider-parity-test.sh
bash skills/skill-builder/scripts/skills-lint.sh .
```

Expected: no unresolved live reference, no unaccounted overlap, all Backlog and repository contracts
pass, and lint reports `fails=0` with only understood pre-existing warnings.

## Slices

- [x] **Slice 1: Initialize exactly one recoverable selected tracker set — tracer** <requires: Task 0>
  - Files:
    - Create `skills/backlog/suggestions/failures.md`.
    - Modify `skills/backlog/scripts/backlog-setup.sh`,
      `skills/backlog/scripts/tracker-layer-status.sh`, and
      `skills/backlog/scripts/tracker-runtime-check.sh`.
    - Modify `skills/backlog/verbs/setup.md`, `skills/backlog/SKILL.md`,
      `skills/backlog/scripts/tests/deploy-test.sh`,
      `skills/backlog/scripts/tests/setup-resume-test.sh`,
      `skills/backlog/scripts/tests/runtime-recovery-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
  - Change:
    - Start with failing fixtures for a fresh `failures`-only selection, several selected stems, the
      all-five default, canonical ordering, and empty, duplicate, unknown, or initialized-layer
      `--trackers` input. Red-prove the exact population assertion by deliberately creating one
      unselected table and showing the fixture fail before restoring it.
    - Extend `backlog-setup.sh` with `--apply [--trackers <comma-separated-stems>]`. Validate a
      nonempty, unique subset of `tasks,issues,failures,feedback,routines`, normalize it to that
      packaged order, and default an omitted list to all five only for fresh initialization. Refuse
      `--trackers` for an initialized layer. Keep `--list` as the deterministic five-row catalog
      consumed by the attended verb.
    - For a newly absent layer, create `.trackers`, then atomically write the two-line validated
      `.setup-selection` before creating `tables/` or any other file. Build only selected tables and
      prompt sections. Validate the exact selection, provider, README, prompt, marker, and history;
      then remove intent as the final setup mutation. A crash leaving only an empty `.trackers`
      directory is restartable as absent setup.
    - Stage the intent through one reserved `.setup-selection.tmp.$$` path. Install `EXIT`, `HUP`,
      `INT`, and `TERM` cleanup before creating that file, validate the completed temporary, expose a
      test hook immediately before rename, and atomically promote it. Inventory the reserved
      temporary family during classification: any survivor is ambiguous and cannot satisfy absent,
      resumable-prefix, or legacy-prefix recognition. Never silently remove a pre-existing survivor.
    - Teach `tracker-layer-status.sh` to validate intent as a regular non-symlink file with exactly
      `schema=backlog/setup-selection@1` and one normalized `trackers=` line. History-absent valid
      intent is a resumable prefix; valid history plus valid intent emits exactly
      `layer_status=selection-cleanup` and `recovery_action=setup`. Runtime, repair, and tracker
      administration direct the caller to `/backlog setup`; setup alone verifies exact population
      and removes the intent. Malformed intent, extra files, or selection/population disagreement is
      ambiguous.
    - Preserve the legacy no-intent prefix path for exactly the former ordered four defaults. A
      conflicting explicit selection refuses. Because new setup writes intent first, a recognized
      no-intent prefix cannot be mistaken for newly interrupted selected setup.
    - Make every setup loop and prompt rank derive from the normalized selection/catalog rather than
      a hard-coded four-stem loop. Do not change arbitrary custom-stem ranking or the tracker@2
      provider schema. Update the setup verb's attended selector and unattended default, but leave
      route consent for Slice 4.
    - Exercise interruption immediately after directory creation, between intent-temporary creation
      and rename, after intent, after every later reported write, after durable history but before
      cleanup, and during cleanup validation. Prove trap cleanup for supported signals, safe refusal
      of unexplained temporary residue, exact resume, conflicting-input refusal, no incumbent-byte
      rewrite, and zero intent or intent-temporary residue after success.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/deploy-test.sh
    bash skills/backlog/scripts/tests/setup-resume-test.sh
    bash skills/backlog/scripts/tests/runtime-recovery-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    shellcheck -S warning skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/backlog/scripts/tracker-runtime-check.sh
    git -C <root> diff --check
    ```

    Expected: fresh setup creates exactly the normalized selection; omitted selection creates all
    five; every interruption resumes or refuses according to durable evidence; initialized four-
    tracker layers remain byte-identical; no successful layer retains `.setup-selection`. Commit
    this setup/recovery tracer independently.

- [ ] **Slice 2: Route and deduplicate unresolved failure families** <requires: Slice 1>
  - Files:
    - Modify `skills/backlog/suggestions/tasks.md`, `skills/backlog/suggestions/issues.md`,
      `skills/backlog/suggestions/feedback.md`, and `skills/backlog/suggestions/routines.md`.
    - Modify `skills/backlog/verbs/debrief.md`, `skills/backlog/verbs/tracker.md`,
      `skills/backlog/SKILL.md`, `skills/backlog/scripts/tests/debrief-contract-test.sh`,
      `skills/backlog/scripts/tests/trackers-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
  - Change:
    - Add red-first routing cases for subjective slowness, unexplained timeout/hang/benchmark,
      confirmed regression, accepted optimization, unresolved flake, expected red-green failure,
      same-session resolved failure, qualitative nitpick, vague preference, and reusable-skill-owned
      feedback. Each case must name its one expected queue or explicit non-capture outcome.
    - Sharpen the packaged suggestions and debrief procedure around knowledge state: chosen outcome
      to `tasks`, established negative condition to `issues`, unresolved operational sighting to
      `failures`, qualitative project-development experience to `feedback`, and repeatable
      trigger/response candidate to `routines`. Preserve the current-objective, in-flight-work,
      owner-boundary, and child/delegate exclusions.
    - Before failure creation, have debrief page the bounded open `failures` population and compare
      component or command, stable signature, and observed behavior. Update one matching family with
      sharper text and the strongest current evidence; otherwise create one row. Do not add a
      fingerprint, occurrence counter, provider command, or history action.
    - Prove through the existing tracker@2 API that repeated matching sightings leave one open row,
      unrelated signatures produce separate rows, and `update` preserves the existing ID while
      replacing text/evidence. Keep family matching as agent judgment rather than a shell classifier.
    - Ensure packaged suggestion changes affect only newly created/added prompt sections. Reconcile
      and repair preserve every incumbent `.trackers/DEBRIEF.md` byte, including an older four-stem
      prompt; `/backlog tracker add failures` installs the new packaged section explicitly.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/trackers-test.sh
    bash skills/backlog/scripts/tests/debrief-contract-test.sh
    bash skills/backlog/scripts/tests/deploy-test.sh
    bash skills/backlog/scripts/tests/repair-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    git -C <root> diff --check
    ```

    Expected: every routing case has one stable disposition; matching flakes update one failure
    family through the unchanged provider API; initialized prompts and tables remain untouched unless
    the user explicitly adds `failures`. Commit failure intake independently.

- [ ] **Slice 3: Manage the standalone project debrief route lifecycle** <requires: Task 0>
  - Files:
    - Create `skills/backlog/templates/agents-route.md`.
    - Modify `skills/backlog/scripts/trackers-anchor.sh`,
      `skills/backlog/verbs/anchor.md`, `skills/backlog/SKILL.md`,
      `skills/backlog/scripts/tests/anchor-test.sh` and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
    - Retain `skills/backlog/templates/agents-pointer.md` as an exact migration input.
  - Change:
    - Begin with failing fixtures for install, refresh, removal, no-op, exact legacy-pointer
      migration, customized-pointer preservation, and removal beside a missing, stale, or malformed
      tracker layer. Red-prove owned-span preservation by corrupting one surrounding-byte assertion
      and showing the test fail before restoring it.
    - Replace the absent-only pointer helper with `preview|apply`, install/update and `--remove`
      modes modeled on the proven `skill-feedback` shapes but rooted at the exact repository top
      level. Preview emits action/status, `path=AGENTS.md`, the complete unified diff,
      `base-sha256=<digest-or-absent>` for the current target, and `candidate-sha256=<digest>` for the
      exact rendered result. Apply requires `--confirmed`, `--base-sha256`, and
      `--candidate-sha256`; it reruns preflight, re-renders, and refuses unless both identities still
      match before one same-directory atomic rename.
    - Validate the package route template and derive `built-against` from the latest path-scoped
      Backlog package commit with a deterministic fallback. Parse the single reserved heading and at
      most one exact owned marker pair outside correctly nested Markdown fences. Reject duplicate,
      orphaned, inverted, indented, or out-of-section markers without a write.
    - Install under the existing reserved section or append that section when absent; refresh only
      the owned span; remove only the owned span while retaining the shared heading and every other
      byte. Preserve CRLF/missing-final-newline surroundings and incumbent file mode. An absent file
      may be created only by confirmed install, never preview or removal.
    - Require a current initialized tracker@2 layer, exact executable provider, and current managed
      README block for install/refresh. Removal validates only Git/root/front-door custody and the
      owned block. Bare anchor with an unhealthy layer may offer removal for an existing valid block
      but cannot offer refresh.
    - Have the verb inspect prose outside the owned block for a competing project-follow-up route.
      Quote the conflict and require an explicit human cutover decision; `--debrief` must refuse for
      that decision rather than silently treating the flag as authorization. The helper reports
      structural facts and candidate bytes but does not decide semantic competition.
    - Recognize only the byte-exact old `## Project trackers` canonical section. A confirmed install
      or `--debrief` migrates it in the same atomic candidate; any modified prose survives unchanged.
      Bare anchor shows the diff, then offers install/cancel or refresh/remove/cancel. The selected
      action confirms the displayed digest; flags skip the choice, not the safety gates.
    - Preserve standalone commit custody: only a reported `AGENTS.md` change is committed, and an
      announced configuration sweep receives the path without a nested commit.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/anchor-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    shellcheck -S warning skills/backlog/scripts/trackers-anchor.sh \
      skills/backlog/scripts/tests/anchor-test.sh
    git -C <root> diff --check
    ```

    Expected: one managed project route installs, refreshes, migrates, and removes through a
    digest-bound atomic lifecycle; malformed or competing state refuses safely; removal works without
    tracker health; no non-anchor operation or real Grimoire front door changes. Commit the standalone
    anchor lifecycle independently.

- [ ] **Slice 4: Compose first-time setup with explicit route consent** <requires: Slices 1, 3>
  - Files:
    - Modify `skills/backlog/verbs/setup.md`, `skills/backlog/verbs/anchor.md`,
      `skills/backlog/SKILL.md`, `skills/backlog/scripts/tests/deploy-test.sh`,
      `skills/backlog/scripts/tests/anchor-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
  - Change:
    - Add red-first contract fixtures for first-time attended setup defaulting route consent to no,
      explicit yes, unattended setup without `--debrief`, fresh and initialized setup with
      `--debrief`, and initialized setup without the flag. Count and red-prove every forbidden
      automatic anchor call before accepting the guard.
    - Make setup classify the layer before interaction. Only first initialization offers the tracker
      multi-select; only a completed first initialization offers the route question. The route
      question displays the standalone anchor candidate and defaults off. `--trackers` bypasses only
      selection; `--debrief` bypasses only route choice and confirmation while retaining preview,
      digest, path, malformed-state, concurrency, and competing-route gates.
    - For initialized setup, preserve ordinary reconciliation with no selector and no route prompt.
      An explicit `--debrief` may install or refresh after reconciliation. A competing behavioral
      route still stops for a human cutover decision; it is never silently overridden.
    - Keep the two mutation transactions and custody boundaries explicit. Finish and commit or return
      the exact `.trackers` paths before anchor begins; then commit or return only `AGENTS.md`.
      Report tracker success plus anchor refusal/failure without rollback or a mixed commit.
    - Update the package contract fixtures so route ownership remains confined to the anchor
      helper/template/verb path. Continue to red-prove that setup without consent, repair, migration,
      runtime, provider calls, and tracker administration stay front-door neutral.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/deploy-test.sh
    bash skills/backlog/scripts/tests/anchor-test.sh
    bash skills/backlog/scripts/tests/skill-doc-test.sh
    git -C <root> diff --check
    ```

    Expected: fresh attended setup offers two independent choices; unattended/default-off setup
    never touches the front door; explicit `--debrief` uses the same anchor path; setup and anchor
    retain separate commits and failure outcomes. Commit setup/anchor composition independently.

- [ ] **Slice 5: Close documentation, parity, and full boundary gates** <requires: Slices 1–4>
  - Files:
    - Modify `README.md`, `scripts/tests/backlog-provider-contract-test.sh`,
      `scripts/tests/project-layer-anchor-contract-test.sh`, and
      `scripts/tests/canonical-provider-parity-test.sh`.
  - Change:
    - Update `README.md` for the retired four-default and discovery-only claims. Describe the
      five packaged defaults, first-time selection, existing-layer preservation, failure/feedback
      boundary, managed route lifecycle, setup default-off choice, and explicit `--debrief` behavior
      without restating another skill's procedure or adding deployed content to root `AGENTS.md`.
    - Change `backlog-provider-contract-test.sh` to permit the owned marker only in Backlog's anchor
      helper/template/verb surface while continuing to forbid every automatic caller and any route
      block in Grimoire's real `AGENTS.md`. Retain and extend its counted mutation proofs.
    - Change `project-layer-anchor-contract-test.sh` so Journal's markerless pointer and Backlog's
      managed route coexist under either invocation order, preserve authored prose, and keep removal
      and exact legacy migration independent. Its copied-package boundary guard must allow Backlog's
      marker template while still failing on an anchor call injected into setup.
    - Change `canonical-provider-parity-test.sh` to assert the live table basename set is exactly
      `feedback,issues,routines,tasks` and that neither `.setup-selection` nor its reserved temporary
      family exists. Red-prove both absence arms in its throwaway copy. Keep provider and
      README-template parity byte-exact; do not materialize `failures.tsv` in Grimoire's initialized
      tracker layer. If implementation requires a tracker@2 provider change, stop and return that
      schema/API gap to the spec instead of widening the plan.
    - Run every absence guard's counted red proof against a copied package or throwaway repository,
      restore the mutated fixture byte-identically, then run the entire package, repository, lint,
      shell, and whitespace gates from the worktree root.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/run.sh
    bash scripts/tests/backlog-provider-contract-test.sh
    bash scripts/tests/project-layer-anchor-contract-test.sh
    bash scripts/tests/canonical-provider-parity-test.sh
    bash skills/skill-builder/scripts/tests/run.sh
    bash skills/skill-builder/scripts/skills-lint.sh .
    shellcheck -S warning skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/backlog/scripts/trackers-anchor.sh \
      skills/backlog/scripts/tests/*.sh
    git -C <root> diff --check
    ```

    Expected: all gates pass; lint has no new warning; the live provider/README match their package
    sources; every front-door test writes only throwaway fixtures; and documentation exposes one
    coherent Backlog contract. Commit the closure sweep independently.

## Coverage check

- Tracker selection, five defaults, intent recovery, legacy prefixes, and initialized preservation
  map to Slice 1.
- Failure taxonomy, performance routing, family deduplication, and incumbent prompt preservation map
  to Slice 2.
- Managed-block lifecycle, legacy pointer migration, removal independence, digest/concurrency safety,
  and competing-route behavior map to Slice 3.
- Setup choices, `--debrief`, default-off behavior, separate custody, and failure isolation map to
  Slice 4.
- Package/repository documentation, patient-zero neutrality, red proofs, and the complete acceptance
  gate map to Slice 5. No published requirement is uncovered.

## Done when

Fresh setup produces exactly the selected subset of the five packaged queues and leaves no intent
residue; existing layers retain their population and prompt prose; debrief routes and deduplicates
failure and feedback examples through the unchanged tracker@2 API; and only explicit, validated
consent changes a throwaway project's `AGENTS.md`. Every slice's targeted gate and the final package,
repository, skill-builder, shellcheck, and whitespace gates pass with no new warning.

_On completion (before landing), run the host's close-the-books sweep._
