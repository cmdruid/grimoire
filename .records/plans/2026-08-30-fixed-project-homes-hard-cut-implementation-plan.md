---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Fixed project homes hard cut — Implementation Plan

Decision: → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`

Input exception: the owner explicitly chose an ADR-governed mechanical hard cut instead of a
feature spec. The draft
`specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` is non-governing and
must not supply implementation requirements.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Hard cut:** ordinary code knows only `.records`, `.spaces`, and `.trackers`. Do not add a
  resolver, compatibility flag, declaration probe, fallback, alias, warning ladder, dual read,
  automatic prior-path adoption, or generalized migration framework.
- **Semantic split:** records, workspace support, and trackers remain separate first-class layers.
  Do not collapse one beneath another.
- **Historical custody:** do not rewrite published records or historical `docs/design/` evidence.
  Grimoire's authored `AGENTS.md` never receives a deployed front-door block.
- **Git is recovery:** the narrow records move requires a clean worktree and fully tracked dedicated
  source. It adds no manifest or automatic resume. A failure leaves an ordinary Git diff for human
  inspection, completion, or reversion.
- **Mixed roots:** `/journal migrate` refuses a source containing anything other than recognized
  records, `history.tsv`, `README.md`, `records.sh`, and directories containing only those entries.
  It lists the foreign entries and performs no write.
- **Backlog migration:** runtime and setup use only `.trackers/DEBRIEF.md`. Existing projects receive
  the documented manual command
  `git mv .spaces/backlog/hooks/debrief.md .trackers/DEBRIEF.md`; no code probes the old path.
- **Coexisting work:** `README.md`, `docs/boundary-audit.md`,
  `skills/developer-writing/SKILL.md`, and `skills/developer-writing/tests/behavior.md` contain user
  changes at plan time. Only `README.md` overlaps this job. Preserve those bytes and do not start
  the hard-cut edit until the owner has committed/isolated them or explicitly authorizes an
  in-place merge. The boundary-audit and Developer Writing files are outside scope.
- **Atomic steady state:** Slice 1 is intentionally broad. Provider signatures and every caller
  change together so no committed slice contains mixed dynamic/fixed behavior.
- **Plan gate:** re-read the ADR and every path emitted by Slice 0 against the execution worktree;
  rerun counts instead of trusting this snapshot.

## Slices

- [x] **Slice 0: Re-ground and classify the hard-cut population** <requires: —>
  - Files: read-only inspection of `README.md`, `PACK.md`, `scripts/`, `skills/`, the governing ADR,
    and the non-governing draft spec only to ensure no requirement leaks from it.
  - Change: make no project write. Run the exact candidate command below against the execution
    worktree, save its sorted output outside the repository, and classify every match as
    `replace`, `fixed-local`, `journal-migrate`, `config-rejection`, or `test-fixture`.
    `fixed-local` is limited to an internal identifier whose value is constructed directly from the
    project root and one canonical literal; it is not a selector and is not supplied by a caller or
    declaration. Re-read every live script named below. Search capability-wide for another
    dynamic-root implementation before editing.

    ```sh
    rg -l \
      -e '<agent-(records|workspace|trackers)>' \
      -e 'agent-(records|workspace|trackers):' \
      -e 'records-root:' \
      -e 'records-root-relative' \
      -e 'workspace-relative' \
      -e '--records-root' \
      -e '--workspace-root' \
      -e '--trackers-root' \
      -e '--workspace([[:space:]]|=|\))' \
      -e 'resolve_(records|workspace|trackers)' \
      -e '(records|workspace|trackers)_(root|rel|home)' \
      README.md PACK.md scripts skills | sort
    ```

    Current expected population: 139 files—100 live files (27 shell scripts and 73 prose/template
    files) plus 39 tests. The 27 live scripts are exactly:

    ```text
    skills/analyst/scripts/analyst-deploy.sh
    skills/analyst/scripts/analyst-facts.sh
    skills/architect/scripts/architect-artifacts.sh
    skills/architect/scripts/architect-setup.sh
    skills/auditor/scripts/auditor-seed.sh
    skills/backlog/scripts/backlog-setup.sh
    skills/backlog/scripts/tracker-layer-status.sh
    skills/backlog/scripts/tracker-runtime-check.sh
    skills/contractor/scripts/contractor-setup.sh
    skills/debugger/scripts/bug-mint.sh
    skills/debugger/scripts/debugger-setup.sh
    skills/delegate/scripts/delegate-setup.sh
    skills/foreman/scripts/foreman-door.sh
    skills/foreman/scripts/goal-compile.sh
    skills/foreman/scripts/migration-census.sh
    skills/foreman/scripts/operation-check.sh
    skills/foreman/scripts/operation-write.sh
    skills/foreman/scripts/operations-index.sh
    skills/inspector/scripts/kinds-deploy.sh
    skills/journal/scripts/records.sh
    skills/journal/scripts/standup.sh
    skills/notepad/scripts/note-mint.sh
    skills/notepad/scripts/notepad-setup.sh
    skills/skill-builder/scripts/skills-lint.sh
    skills/workspace/scripts/workspace-check.sh
    skills/workstream/scripts/workstream-git.sh
    skills/workstream/scripts/workstream-setup.sh
    ```

  - Verify: the ADR has `status: published` before Slice 1 begins. The sorted output and
    classifications account for every match; explain any drift from 139 files and 27 live scripts
    before sizing Slice 1. Confirm commit `d788497` contains the previously coexisting README,
    boundary-audit, and Developer Writing changes, then preserve their current `HEAD` bytes; if the
    execution worktree has moved, re-establish that fact from the new baseline rather than trusting
    the recorded commit.

- [x] **Slice 1: Cut every ordinary surface to the three fixed homes** <requires: 0>
  - Files: `README.md`, `PACK.md`, `scripts/tests/backlog-provider-contract-test.sh`,
    `scripts/tests/configure-clankshop-test.sh`; all `replace`, `config-rejection`, and
    `test-fixture` paths emitted by Slice 0; and no path under
    `skills/developer-writing/`. The live executable set is the exact 27-script list in Slice 0.
  - Change:
    - Replace every ordinary symbolic home and declaration resolver with literal `.records`,
      `.spaces`, or `.trackers` construction beneath the project root.
    - Remove `--workspace`, `--records-root`, `--workspace-root`, and `--trackers-root` wherever
      they select a home. Keep arguments that select an operation subject and keep an absolute
      project `--root` on internal helpers where useful.
    - Make installed `.records/records.sh` and `.trackers/trackers.sh` self-locate and require their
      literal canonical parent. Update all callers in the same slice; never execute bundled provider
      bytes against project data.
    - Make Workspace validate only `.spaces/<owner>/<kind>/...`; delete coincidence and arbitrary
      root modes. Keep the owner-first kind grammar.
    - Move Backlog's live routing contract to `.trackers/DEBRIEF.md`. Setup, debrief, tracker
      add/remove, status, README, and tests use only that path. Document that an existing project
      must run `git mv .spaces/backlog/hooks/debrief.md .trackers/DEBRIEF.md` before its first
      post-cut Backlog setup, but add no old-path probe. Add an upgrade fixture that performs that
      explicit move, runs setup, and proves customized debrief bytes remain unchanged.
    - Replace the portable doctrine's front-door-variable guidance with fixed-home guidance. Update
      current skill prose, templates, README/PACK descriptions, agent-council brief, and examples;
      leave historical records untouched.
    - Make the lint/configuration gate reject `agent-records:`, `records-root:`,
      `agent-workspace:`, `agent-trackers:`, and ordinary symbolic-home tokens. Retain those strings
      only in rejection fixtures and the Journal migration surface added by Slice 2.
    - Rewrite override, overlap, coincidence, and configurable-root tests as fixed-home and
      unknown-argument tests. Add canaries at noncanonical paths and prove no ordinary reader or
      writer accesses them. For each absence guard, mutate one real carrier and prove the gate turns
      red before restoring it byte-for-byte.
  - Verify:

    ```sh
    for skill in agent-council analyst architect auditor backlog code-humanizer contractor \
      debugger delegate foreman inspector journal notepad skill-builder workspace workstream; do
      bash "skills/$skill/scripts/tests/run.sh"
    done
    skills/skill-builder/scripts/skills-lint.sh
    scripts/tests/run.sh
    cargo test --workspace
    ```

    Expected: every command exits zero; fresh setup creates only the canonical tree; a second setup
    writes nothing; old selector arguments refuse; canaries under declared/custom roots are never
    read; no ordinary declaration, selector, resolver, or symbolic-home match remains in the Slice 0
    census. A `fixed-local` match may remain only when its canonical literal assignment and lack of
    caller/declaration input are both visible in the same implementation. Commit this steady-state
    cut atomically.

- [x] **Slice 2: Add the thin dedicated-records-root move** <requires: 1>
  - Files: modify `skills/journal/SKILL.md`, `skills/journal/scripts/standup.sh`,
    `skills/journal/scripts/tests/run.sh`, and current Journal setup/contract tests as required;
    create `skills/journal/verbs/migrate.md`,
    `skills/journal/scripts/migrate-records-root.sh`, and
    `skills/journal/scripts/tests/migrate-records-root-test.sh`; update `README.md` only if its
    Journal command summary enumerates migration.
  - Change:
    - Add `/journal migrate [<source-root>]`. An explicit safe repo-relative source wins only when
      any retired `agent-records:`/`records-root:` declarations agree; bare invocation requires one
      distinct declared source. This is the only code that reads retired records values.
    - `preview` requires a clean Git worktree, including no untracked or ignored entries under the
      source; an absent `.records`; a safe, fully tracked, non-symlink source; and no conflicting
      declarations. It classifies files using Journal's existing dated-filename-plus-`doctype`
      discriminator. Only recognized records, `history.tsv`, `README.md`, `records.sh`, and their
      containing directories are allowed. It lists every path and refuses a mixed source before any
      write.
    - After explicit human confirmation, `apply` repeats the entire preflight, runs
      `git mv -- <source> .records`, removes every matching retired records declaration while
      preserving surrounding front-door bytes, and runs the fixed-path Journal standup protocol to
      refresh the provider and managed README block without changing records or ledger bytes. Run
      installed `.records/records.sh check`, then make one exact scoped commit whose pathspec union
      names both rename endpoints (`<source>` and `.records`), every changed front door, and every
      path reported by standup. If standup created its existing setup intent, finalize it only after
      that commit succeeds. Do not invent a migration-specific intent or recovery protocol.
    - Do not add a manifest, digest, selective mover, reference scanner/rewriter, legacy provider,
      old-root alias, fallback, automatic resume, or rollback. A post-write failure reports the Git
      diff and stops; rerun refuses the dirty tree until the human completes or reverts it.
    - Mixed roots and custom workspace/tracker roots remain explicit human migrations. Do not extend
      this verb to them.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/migrate-records-root-test.sh
    bash skills/journal/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    scripts/tests/run.sh
    ```

    Expected: preview is read-only; a dedicated fully tracked source moves wholesale with record and
    ledger bytes unchanged, declarations removed, current canonical tooling installed, and one
    commit containing both halves of the rename; success leaves no setup intent and an empty staged,
    unstaged, and untracked Git status. Dirty, mixed, symlinked, untracked/ignored, conflicting, or
    destination-present cases refuse without writes; no migration manifest or compatibility path
    exists.

## Done when

- The ADR is the only governing design record; the abandoned draft spec supplied no requirements.
- Every ordinary producer, consumer, setup helper, validator, provider, doctrine surface, and test
  uses fixed `.records`, `.spaces`, or `.trackers` paths with no dynamic selector behavior.
- Backlog reads only `.trackers/DEBRIEF.md` and documents—but does not automate—the old prompt move.
- `/journal migrate` performs only the clean dedicated-root Git move and refuses mixed roots.
- The classified census contains retired declarations/tokens only in Journal migration,
  configuration rejection, and deliberate tests; red proofs demonstrate the absence guards work.
- All affected skill harnesses, repository integration tests, lint, shell checks, and Rust workspace
  tests pass, with the preexisting user changes preserved.

_On completion (before landing), run the host's close-the-books sweep._
