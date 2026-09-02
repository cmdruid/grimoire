---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Journal stateless setup and repair hard cut — Implementation Plan

A thin inert tracer first proves Journal's public-state classification and runtime route without
changing any live consumer. One dependent atomic propagation then replaces the private setup
transaction across setup, repair, migration, project guidance, and integrations. The public cut
lands as one unit, so no released package mixes the old lifecycle with the new state model.

Spec: `.records/specs/2026-09-02-journal-stateless-setup-and-repair.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published source of truth:** implement the published spec as a replacement contract. The
  archived provider/setup spec is historical evidence only; do not preserve one of its intent,
  finalization, legacy-probe, prior-provider cleanup, or generated-pointer branches.
- **Hard cut:** setup, bare repair, runtime preflight, and anchor inspect only `.records` and
  read-only Git evidence. They never resolve, inspect, remove, validate, or block on `.spaces`, even
  when an old `setup.intent`, prior provider, symlink, or unsafe workspace parent exists. Such paths
  are inert project residue and are never compatibility fixtures that production code recognizes.
- **State and ownership:** a safe regular `.records/history.tsv` is the initialization boundary.
  When it is absent, a `HEAD` copy routes to `action=git-restore`; a current managed README block or
  archived record routes to `action=human-review`; only the unwitnessed state may create an empty
  ledger. Never truncate or replace an incumbent ledger, mutate records, or overwrite README bytes
  outside Journal's current delimited block.
- **One reconciler, bounded effects:** retain one setup/repair implementation. Setup owns the
  provider, absent ledger, and managed README block in provider → ledger → README order. Bare repair
  requires the ledger and owns only provider and managed-block projections. Every destination is
  preflighted and atomically replaced; a no-op writes nothing.
- **Commit custody:** standalone setup and repair classify every dirty candidate, including paths
  changed during the invocation. `wrote:` records current mutation; `reconciled:` recovers an exact
  earlier package result. A modified incumbent ledger, provider mismatch, or README hunk outside the
  managed block suppresses the entire automatic commit with the exact commit-custody diagnostic.
  An announced write-only sweep already owns its approved bounded diff and does not ask Journal to
  infer custody from `HEAD`. Outside Git, reconciliation still succeeds and reports only current
  `wrote:` paths; it emits no `reconciled:` paths, attempts no automatic commit, and never refuses
  merely because `HEAD` is unavailable.
- **Migration remains generic and explicit:** `/journal migrate <source-root>` requires the human to
  name one safe repo-relative dedicated records root. It retains preview, confirmation, whole-root
  Git move, path safety, content validation, one scoped commit, and ordinary Git recovery. It never
  reads or rewrites `AGENTS.md` or `CLAUDE.md`, infers a source, recognizes a retired declaration,
  identifies a Journal version, or performs cleanup outside the named source.
- **Out of scope:** do not implement `/journal repair --closure` or modify `records.sh` lifecycle
  behavior in this job. That separately specified recovery must not be blocked by bare repair's
  write-set wording, but it receives no placeholder flag, compatibility shim, or speculative test.
- **Patient zero and portability:** all setup, repair, migration, anchor, interruption, unsafe-path,
  and mutation tests use throwaway projects. Never run setup or migration against Grimoire's real
  front door or rewrite its authored `AGENTS.md`. Preserve the existing POSIX/Bash boundaries and
  keep package paths relative to the Journal skill directory.
- **Coexisting work:** at plan time, the spec publication, superseded-spec lifecycle row, and this
  plan are uncommitted record work. The unrelated untracked
  `.records/specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` belongs to
  another session. Re-establish `git status` before implementation and exclude every unrelated path
  from edits, staging, and commits.
- **Gate expectations:** the current Journal harness is green at 523 assertions across seven suites
  on `2cb44ad14c73`. Production Journal scripts pass `shellcheck -S warning`; the library lint passes
  with three known orphan-edge warnings. Treat the plan as a snapshot and re-run Task 0 against the
  execution `HEAD` before editing.

## Task 0 — Re-ground before editing

- [x] Read-only planning pass completed against `2cb44ad14c73` on `main`.
- [x] At execution time, re-read the published spec, `AGENTS.md`,
  `skills/skill-builder/docs/DOCTRINE.md`, Journal's full package, and the affected root integration
  tests. Run Contractor's ground check and record `git status` before touching a file.
- [x] Repeat the live-source census for `setup.intent`, `finalize`, `.spaces/journal`, prior-provider
  cleanup, generated-pointer replacement, migration source inference, `wrote:`, and `reconciled:`.
  Classify each occurrence as production to replace, a deliberate negative fixture, or immutable
  historical evidence. Search capability-wide for prior art; re-read Backlog's state classifier,
  runtime checker, stateless setup custody, and resume tests without copying tracker-specific state.
- [x] Run the current Journal harness before editing. If its baseline differs from 523 passing
  assertions or any named path/signature moved, update the plan or stop on a material contract
  conflict instead of coding around drift.

Verification:

```sh
skills/contractor/scripts/ground-check.sh <root> \
  .records/specs/2026-09-02-journal-stateless-setup-and-repair.md
git status --short
skills/journal/scripts/tests/run.sh
```

Expected: `unresolved_count=0`; all current Journal suites pass; every coexisting worktree path is
named and excluded; and the census accounts for every live dependency on the retired lifecycle.

## Slices

- [x] **Slice 1: Prove public-state classification and runtime routing — tracer** <requires: Task 0>
  - Files:
    - Create `skills/journal/scripts/records-layer-status.sh`,
      `skills/journal/scripts/records-runtime-check.sh`,
      `skills/journal/scripts/tests/layer-status-test.sh`, and
      `skills/journal/scripts/tests/runtime-recovery-test.sh`.
    - Modify `skills/journal/scripts/tests/run.sh` only to execute the two new suites. Do not route a
      live Journal verb through the helpers in this slice.
  - Change:
    - Write the end-to-end tracer first: construct an initialized disposable `.records` layer with
      the canonical staged provider, safe ledger, and exact managed-block README; add arbitrary,
      symlinked, and unsafe `.spaces/journal` residue; run the runtime checker; invoke the returned
      provider path with `list`; and prove the result and diagnostics are independent of workspace
      state. Mutate the workspace-independence guard once, require the fixture to fail, restore the
      helper byte-identically, and require green.
    - Implement `records-layer-status.sh setup|repair|runtime --root <absolute-root>` as the shared
      read-only fact source. Validate the root and only the canonical `.records` parent and selected
      destinations; classify provider and README state; detect whether Git `HEAD` tracks the exact
      ledger path; and emit compact stable facts for layer, ledger, provider, README, and recovery
      state. It must never open `.spaces`, infer a version, or mutate the project.
    - For the archived-record witness, reproduce the provider's exact two-conjunct record
      discriminator without executing either provider copy: a dated record-shaped Markdown basename
      plus a `doctype` declared inside the first closed front-matter block. Count
      `status: archived` only when it occurs in that same block. Do not follow symlinks. Prove that a
      body-only status string, undated Markdown, missing doctype, malformed or unterminated front
      matter, and symlinked file cannot witness ledger loss.
    - Implement `records-runtime-check.sh --root <absolute-root>` as the deterministic runtime gate
      over those facts. A missing or unsafe ledger emits exactly
      `reason=setup-required action=/journal setup`; an initialized layer with a missing, unsafe,
      non-executable, byte-stale, or usage-incomplete provider emits exactly
      `reason=repair-required action=/journal repair`; success prints only the absolute staged
      provider path. Exercise the provider's exit status, usage heading, and complete command roster
      without performing a record mutation.
    - Cover every state-classifier branch in Git and non-Git fixtures: safe initialized layer,
      tracked missing ledger, managed-block witness, archived-record witness, unwitnessed absence,
      provider drift, malformed marker, and unsafe canonical paths. Red-prove the ledger witness
      ordering and exact runtime diagnostics.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/layer-status-test.sh
    bash skills/journal/scripts/tests/runtime-recovery-test.sh
    bash skills/journal/scripts/tests/run.sh
    shellcheck -S warning skills/journal/scripts/*.sh
    git diff --check
    ```

    Expected: every command exits zero; the two new helpers are independently usable but no live
    Journal consumer calls them yet; the tracer reaches the staged provider using only public state;
    all ledger and provider classifications are deterministic; the planted workspace dependency and
    ledger-guard mutations have demonstrated red. Commit this inert tracer independently.

- [x] **Slice 2: Propagate the stateless setup and repair hard cut atomically** <requires: Slice 1>
  - Files:
    - Rename `skills/journal/scripts/tests/setup-transaction-test.sh` to
      `skills/journal/scripts/tests/setup-resume-test.sh` and replace its transaction fixtures.
    - Modify `skills/journal/scripts/standup.sh`,
      `skills/journal/scripts/records-anchor.sh`,
      `skills/journal/scripts/migrate-records-root.sh`, and
      `skills/journal/scripts/tests/run.sh`.
    - Modify `skills/journal/scripts/tests/standup-test.sh`,
      `skills/journal/scripts/tests/setup-resume-test.sh`,
      `skills/journal/scripts/tests/repair-test.sh`,
      `skills/journal/scripts/tests/contract-test.sh`,
      `skills/journal/scripts/tests/records-test.sh`,
      `skills/journal/scripts/tests/migrate-records-root-test.sh`, and
      `skills/journal/scripts/tests/anchor-test.sh`.
    - Modify `skills/journal/SKILL.md`, `skills/journal/verbs/setup.md`,
      `skills/journal/verbs/repair.md`, `skills/journal/verbs/migrate.md`,
      `skills/journal/verbs/anchor.md`, `skills/journal/verbs/search.md`,
      `skills/journal/verbs/done.md`, and `skills/journal/verbs/curate.md`.
    - Modify `scripts/tests/configure-clankshop-test.sh`,
      `scripts/tests/project-layer-anchor-contract-test.sh`, and
      `scripts/tests/canonical-provider-parity-test.sh`. Review `README.md`, `PACK.md`, and
      `skills/journal/templates/records-readme-block.md`; edit them only if their current prose or
      fixture wiring contradicts the published contract.
    - Do not modify `skills/journal/scripts/records.sh`, historical record bodies, the real
      `AGENTS.md`, or any other skill package.
  - Change:
    - Rewrite `standup.sh` around the Slice 1 classifier and delete the entire intent
      implementation: schema, workspace resolution, load/write/phase/pending/completed functions,
      `finalize` mode, prior-provider resolution/removal, and prior generated-pointer replacement.
      Preserve complete preflight, immediate parent rechecks, temporary sibling files, atomic
      destination replacement, provider validation, managed-block byte preservation, failure hooks,
      and current-write reporting. Setup rejects the two witnessed ledger-loss states before writing;
      otherwise it reconciles provider → absent empty ledger → managed README. Repair admits only
      initialized state and never includes ledger or records in its write set. Both emit
      `records check failed — tool layer is current; action=/journal curate` for every content-check
      failure and never classify it as migration work.
    - Replace the absent-README renderer with an atomic install whose bytes are exactly
      `skills/journal/templates/records-readme-block.md` and whose mode is `0644`. On an incumbent
      safe README, replace or append only the current delimited block and preserve every other byte.
      Prove that a fresh README differs from `HEAD` only by the owned block and therefore passes the
      same custody classifier as an incumbent managed-block refresh; do not retain the generated
      heading, dated standup line, or any other new prose outside the markers.
    - Expose the helper grammar exactly as
      `standup.sh setup|repair <root> [--write-only]`. The optional flag is an internal invocation
      context for an already announced caller-owned sweep, not a Journal verb. It changes no
      reconciliation or safety guard, skips standalone Git commit-custody inference, and reports only
      current writes for the outer sweep's approved diff.
    - Normal Git-backed standalone setup and repair compare every bounded candidate with `HEAD`,
      including current writes. Admit the provider only when its whole diff is the bundled executable
      result, admit a ledger only when it is a new safe empty file absent from `HEAD`, and admit README
      only when all changed bytes are inside the managed block. Emit `reconciled:` for an admitted
      dirty candidate not written now. Any ambiguous candidate returns
      `reason=commit-custody-required detail=<path>`, leaves completed writes inspectable, and
      suppresses the entire automatic commit. Update standalone verb custody to commit the unique
      admitted `wrote:` plus `reconciled:` union; clean committed reruns emit neither vocabulary.
      Outside Git, run the same reconciliation and safety gates, emit `wrote:` only for paths changed
      during that invocation, emit no `reconciled:`, make no scoped-commit attempt, and do not refuse
      because `HEAD` is unavailable.
    - Replace the transaction suite with a state-derived interruption matrix. Stop after provider,
      ledger, and README destination commits; assert every published file is complete; rerun without
      private state; and require convergence plus recovered `reconciled:` custody. Cover fresh,
      initialized, non-Git, write-only sweep, clean rerun, provider drift, executable-bit repair,
      managed-block drift, current and prior-attempt custody, and parent-swap races. In the non-Git
      fixture assert current `wrote:` paths, no `reconciled:` output, no commit attempt, and a usable
      final layer. Prove a dirty incumbent ledger, mismatched provider, prior unowned README hunk, and
      unowned hunk preserved beneath a current managed-block refresh each suppress the whole
      Git-backed standalone commit.
    - Add the setup integration for the ledger-loss matrix proven in Slice 1: tracked missing ledger
      → `git-restore`; current or drifted managed block without recoverable Git ledger →
      `human-review`; archived record without a recoverable ledger → `human-review`; no witness →
      empty-ledger initialization. Red-prove each guard and the README-after-ledger ordering. Repair
      and runtime continue to route every missing ledger to setup, which owns the finer recovery
      decision.
    - Route search, done, and curate through the Slice 1 runtime helper before any adjacent provider
      call. Make anchor reuse the public-layer facts and additionally require the current managed
      README block. Remove workspace resolution from those verbs and make anchor ignore every
      workspace state.
    - Make all Journal prose and consumers state-derived in the same change. Remove `finalize` from
      usage and calls; route setup/repair custody through the new output; and retain only the current
      canonical provider and managed README ownership seams. A live source guard must reject operative
      `setup.intent`, transaction phase, automatic prior-path, or workspace-provider references while
      allowing immutable records and deliberately named negative fixtures. Break each guard once,
      count the planted occurrence, require red, restore, and require byte identity.
    - Hard-cut migration to the required interface
      `migrate-records-root.sh preview|apply --root <absolute-root> --source <repo-relative>
      [--confirmed]`. Delete all front-door declaration discovery, agreement checks, mutation,
      changed-front tracking, optional-source behavior, intent finalization, and prior-version prose.
      Preserve literal path validation, clean attached Git worktree, dedicated tracked source
      inventory, unsafe/mixed/ignored/collision refusals, preview facts, confirmation, repeated
      preflight, whole-root `git mv`, post-move validation, scoped commit, and ordinary Git-diff
      recovery. Invoke `standup.sh setup <root> --write-only` after the confirmed move; migration
      already owns the exact source and destination population. Parse only current setup writes, make
      one commit over the whole move and refresh, and require clean status.
    - Replace old upgrade/intent tests with generic brownfield and inert-residue tests. Setup,
      repair, runtime, and anchor must behave identically when `.spaces/journal` is absent, contains
      an old-looking regular file, is symlinked, or has an unsafe parent. Migration without
      `--source` refuses; retired declarations cannot select a source and remain byte-identical even
      during an explicit migration. No test may require production code to identify those fixtures
      as a former Journal version.
    - Update root integration fixtures atomically with the package. Remove every finalize call;
      copy the new classifier/runtime dependencies into isolated provider-parity fixtures; collect
      Journal output according to standalone versus announced-sweep custody; preserve exact
      provider/README repair boundaries; keep setup and repair front-door neutral; and retain the
      adjacent-provider and offline-project lifecycle proofs.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/run.sh
    shellcheck -S warning skills/journal/scripts/*.sh
    skills/skill-builder/scripts/skills-lint.sh
    scripts/tests/run.sh
    bash -n skills/journal/scripts/*.sh skills/journal/scripts/tests/*.sh \
      scripts/tests/configure-clankshop-test.sh \
      scripts/tests/project-layer-anchor-contract-test.sh \
      scripts/tests/canonical-provider-parity-test.sh
    git diff --check
    ```

    Expected: every command exits zero; the package exposes no `finalize` mode or operative setup
    intent; setup/repair/runtime/anchor never inspect workspace state; all missing-ledger and custody
    diagnostics match exactly; every interruption converges; fresh README creation satisfies the
    managed-block-only custody rule; non-Git setup and repair reconcile without a commit attempt;
    bare repair changes only provider and managed README; migration requires one explicit source and
    performs one confirmed whole-root commit without touching front doors; the live-source and
    mutation guards have demonstrated red; and no unrelated worktree path enters the diff. Commit
    this public hard cut atomically because scripts, public prose, migration, and contract fixtures
    cannot safely land with mixed lifecycle models.

## Done when

- Fresh and initialized disposable projects converge to the current adjacent provider, safe ledger,
  and managed README without creating, reading, deleting, or requiring any private setup artifact.
  Interruptions after each destination leave only complete files and rerun from public state alone.
- Missing-ledger recovery distinguishes a Git-restorable ledger, witnessed ambiguous loss, and safe
  initialization without truncating incumbent data. Runtime operations route through the staged
  provider only after the exact setup/repair preflight.
- Standalone setup and repair automatically commit only a fully proven bounded diff. Earlier exact
  results are recovered through `reconciled:`; any coexisting project-owned change suppresses the
  whole automatic commit and remains inspectable. Announced sweeps retain their own approved diff.
- Bare repair remains provider/README-only, and the neutral curation diagnostic is used for every
  content-check failure. No closure-repair flag or ledger mutation is introduced by this plan.
- `/journal migrate <source-root>` retains explicit preview, confirmation, safety, Git recovery, and
  one whole-root commit, but has no source inference, retired-declaration handling, front-door edit,
  version recognition, setup intent, or finalization path.
- Current Journal code, guidance, templates, root integrations, and tests contain no operative
  `setup.intent`, `finalize`, prior-provider cleanup, prior generated-pointer replacement, or legacy
  setup/repair branch. Immutable historical records and deliberate negative fixtures are the only
  allowed references.
- Journal's complete harness, production-script ShellCheck, Skill-builder lint, repository
  integration suite, syntax checks, and whitespace gate pass. The real `AGENTS.md`, unrelated skill
  packages, historical record bodies, and all pre-existing unrelated worktree changes remain
  untouched.

_On completion (before landing), run the host's close-the-books sweep._
