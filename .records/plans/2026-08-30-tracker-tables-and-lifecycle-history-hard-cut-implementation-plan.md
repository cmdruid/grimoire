---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Tracker tables and lifecycle history hard cut — Implementation Plan

Decision: → `adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md`

Input exception: the owner explicitly chose an ADR-governed mechanical hard cut instead of a
feature spec. The abandoned, untracked fixed-homes draft is non-governing and must not supply
implementation requirements.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Hard cut:** ordinary setup and runtime know only `tracker@2`, `.trackers/tables/*.tsv`, and
  `.trackers/history.tsv`. Do not add an alias, dual read, fallback, automatic adoption, version
  bridge, compatibility mode, or permanent migration command.
- **One atomic steady state:** provider paths, schema validation, setup/recovery, direct consumers,
  deployed project files, prose, and tests change in one implementation commit. No committed slice
  may mix tracker@1 and tracker@2 behavior.
- **Preserved semantics:** queue rows retain the four-column schema and stay in their tables.
  Observation remains consumer-scoped and idempotent; consumption remains global and terminal,
  implies observation by its consumer, and requires a resolution. Removing a tracker preserves its
  history, and recreating its stem allocates above item IDs retained there.
- **Minimal public delta:** lifecycle mutations identify each newly appended history row as
  `event=event-N`; all mutation paths remain relative to `.trackers`. Configurable tracker stems
  use only the ordinary stem grammar, without a ledger-name reservation. Receipt terminology
  remains only where it accurately identifies the retired brownfield input or rejection evidence;
  no current system behavior assigns that name special meaning.
- **Empty population:** keep `.trackers/tables/.gitkeep` as the structural marker so an initialized
  zero-queue layer survives Git and fresh clones. Catalog ignores it, tracker removal preserves it,
  and setup owns it as part of the fixed layout.
- **Initialization and recovery:** a valid `history.tsv` is the initialization boundary. Preserve
  the existing resumable-prefix, lost-ledger, repair, README-custody, symlink, parent-swap, and
  concurrent-edit protections, translated to `tables/` and `history.tsv`. Any old root-level queue
  TSV or `receipts.tsv` causes a write-free refusal.
- **Manual brownfield conversion:** document one explicit clean-worktree, reviewed Git conversion.
  It enumerates and moves every root queue to `tables/`, renames `receipts.tsv` to `history.tsv`,
  rewrites only each first-column `receipt-N` token to `event-N`, preserves row order and every
  non-ID byte, then runs current setup to reconcile the provider and managed guide. No ordinary
  code probes or performs that conversion.
- **Historical custody:** do not rewrite published plans, specs, ADRs, or `docs/design/` evidence.
  Grimoire's authored `AGENTS.md` and `.trackers/DEBRIEF.md` stay unchanged. The abandoned untracked
  fixed-homes spec remains untracked and outside this job.
- **Coexisting work:** at review time,
  `.records/adr/2026-08-31-give-workstream-a-dedicated-streams-control-home.md` and
  `.records/specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md` are
  unrelated drafts from another session. Do not inspect, edit, stage, commit, or derive tracker
  requirements from them. Re-establish the unrelated status population at execution and preserve
  any successor or additional entries the same way.
- **Patient zero and parity:** exercise setup, recovery, and conversion against throwaway fixtures.
  The repository's deployed `.trackers` layer is an explicit consuming-project conversion and must
  remain byte-for-byte aligned with Backlog's package provider and managed README output.
- **Plan gate:** re-read the ADR and every path emitted by Slice 0 against the execution worktree;
  rerun the census instead of trusting this snapshot.

## Slices

- [ ] **Slice 0: Re-ground and classify the tracker@2 cut** <requires: —>
  - Files: read-only inspection of the governing ADR; `.trackers/`; `README.md`; `PACK.md`;
    `scripts/tests/`; `skills/backlog/`; `skills/analyst/`; `skills/foreman/`;
    `skills/journal/scripts/tests/`; `skills/workspace/scripts/tests/`; and
    `skills/skill-builder/docs/DOCTRINE.md` plus its tests.
  - Change: make no project write. Confirm the ADR is published, record the execution HEAD and Git
    status, and save a sorted candidate list outside the repository. Classify every match as a
    hard-cut change, legacy conversion or rejection evidence, historical evidence, a semantically
    current use of receipt terminology, or an unrelated match:

    ```sh
    rg -il \
      -e 'tracker@1' \
      -e 'receipt' \
      -e '\.trackers/[a-z][a-z0-9-]*\.tsv' \
      -e '\$TRACKERS/[^/" ]+\.tsv' \
      -e '\$LAYER/[^/" ]+\.tsv' \
      README.md PACK.md scripts skills .trackers | sort
    ```

    Re-read the three provider/setup/recovery scripts, every direct caller of `describe`,
    `catalog`, `page`, `observe`, or `consume`, and every repository parity guard before editing.
    Confirm the deployed conversion population: the four queue tables plus `receipts.tsv`; inspect
    whether history rows require ID rewriting rather than trusting the current header-only snapshot.
  - Verify: all matches are accounted for; no unclassified live caller or second tracker provider
    exists; `.trackers/trackers.sh` still matches `skills/backlog/scripts/trackers.sh`; and every
    unrelated status entry is named and excluded from this job. Explain any population change
    before Slice 1.

- [ ] **Slice 1: Cut the complete tracker layer to tables and lifecycle history** <requires: 0>
  - Files:
    - Modify provider/setup/recovery:
      `skills/backlog/scripts/trackers.sh`, `skills/backlog/scripts/backlog-setup.sh`, and
      `skills/backlog/scripts/tracker-layer-status.sh`.
    - Modify Backlog's live contract:
      `skills/backlog/SKILL.md`, `skills/backlog/templates/trackers-readme-block.md`,
      `skills/backlog/verbs/setup.md`, `skills/backlog/verbs/repair.md`,
      `skills/backlog/verbs/tracker.md`, and `skills/backlog/verbs/query.md`.
    - Modify direct consumers:
      `skills/analyst/SKILL.md`, `skills/analyst/scripts/analyst-facts.sh`,
      `skills/analyst/scripts/tests/facts-test.sh`,
      `skills/analyst/scripts/tests/skill-doc-test.sh`, `skills/foreman/SKILL.md`,
      `skills/foreman/verbs/tune.md`, and `skills/foreman/scripts/tests/tracker-tune-test.sh`.
    - Modify doctrine and root descriptions: `README.md`, `PACK.md`, and
      `skills/skill-builder/docs/DOCTRINE.md`.
    - Modify Backlog fixtures:
      `skills/backlog/scripts/tests/trackers-test.sh`,
      `skills/backlog/scripts/tests/deploy-test.sh`,
      `skills/backlog/scripts/tests/readme-test.sh`,
      `skills/backlog/scripts/tests/repair-test.sh`,
      `skills/backlog/scripts/tests/setup-resume-test.sh`,
      `skills/backlog/scripts/tests/runtime-recovery-test.sh`,
      `skills/backlog/scripts/tests/hard-cut-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
    - Modify integration and boundedness fixtures:
      `scripts/tests/backlog-provider-contract-test.sh`,
      `scripts/tests/canonical-provider-parity-test.sh`,
      `scripts/tests/configure-clankshop-test.sh`,
      `skills/journal/scripts/tests/repair-test.sh`,
      `skills/workspace/scripts/tests/workspace-check-test.sh`, and
      `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh`.
    - Move the deployed files `.trackers/feedback.tsv`, `.trackers/issues.tsv`,
      `.trackers/routines.tsv`, and `.trackers/tasks.tsv` to the same basenames under
      `.trackers/tables/`; move `.trackers/receipts.tsv` to `.trackers/history.tsv`; create
      `.trackers/tables/.gitkeep`; and reconcile `.trackers/trackers.sh` and
      `.trackers/README.md`. Preserve `.trackers/DEBRIEF.md` unchanged.
    - Review without expected edits: `skills/backlog/scripts/tracker-runtime-check.sh`,
      `skills/backlog/scripts/tracker-readme-status.sh`, `skills/backlog/scripts/scoped-commit.sh`,
      `skills/backlog/verbs/file.md`, `skills/backlog/verbs/curate.md`, and
      `skills/backlog/verbs/debrief.md`.
  - Change:
    - Write red assertions first for `schema=tracker@2`, the fixed table/history paths, the dedicated
      bounded `history` envelope, `event-N` output, old-layout write-free refusal, byte-preserving
      manual conversion, and the absence of any live tracker@1/receipt compatibility branch.
    - Make the self-locating provider require a real adjacent `.trackers/tables` directory and
      non-symlink `.trackers/history.tsv`. Discover and validate queues only from
      `tables/*.tsv`; emit `wrote=tables/<stem>.tsv` for queue mutations and
      `wrote=history.tsv` plus `event=event-N` for lifecycle mutations.
    - Publish `schema=tracker@2` and the new headers/command roster from `describe`. Remove the
      receipt pseudo-row and special receipt paging. Add only
      `history --limit <n> [--after <event-id>]`, emitting `schema=tracker@2`, a bounded `next=`,
      `--`, the eight-column header, and rows in ledger order. With no cursor, traversal starts at
      the first event. A supplied cursor must be a syntactically valid ID present in history or
      refuse as invalid; emit rows strictly after it, inspect at most `limit + 1`, and set `next` to
      the last returned event ID only when another row remains. Otherwise emit an empty `next=`.
      Reject extra history filters.
    - Keep `page` queue-only and preserve all current open/consumed/unobserved derivation against
      history. Validate unique `event-N` IDs; allocate the next event globally; use retained history
      item IDs when calculating the next queue item ID; and preserve idempotent observation and
      terminal consumption behavior.
    - Make setup create and guard `tables/`, its structural marker, and default queue files beneath
      it. Make tracker add/remove and prompt reconciliation operate only on `tables/`. Publish a
      valid `history.tsv` last as the initialization boundary. Translate status/recovery and Git
      ledger-loss detection to the new path while preserving all existing refusal and repair
      behavior. A flat queue TSV or `receipts.tsv` under `.trackers` is always incompatible and is
      never moved, read as state, or overwritten.
    - Reconcile the managed README to the steady-state tracker@2 contract and add the explicit
      brownfield procedure to `verbs/setup.md`. Test that procedure with populated old-layout rows:
      current post-cut setup/runtime against that old layout first refuse without writes; the
      reviewed Git moves and first-column ID rewrite preserve row order and non-ID bytes; current
      setup installs the provider/guide; then queue views and history views reproduce the prior
      lifecycle state. Keep `/backlog migrate` absent.
    - Update Analyst and Foreman to require tracker@2 while retaining their current bounded,
      read-only consumer behavior. Analyst no longer filters a receipt pseudo-row. Update Backlog,
      root inventory, pack seam map, and portable doctrine to describe table and history ownership
      without broadening any skill boundary.
    - Convert Grimoire's deployed files with Git moves. Because the current ledger is header-only,
      its deployed rename requires no row rewrite; prove that fact before moving it. Copy/reconcile
      package-managed provider and README bytes and extend parity checks to cover the full deployed
      tracker@2 structure.
    - Extend counted red proofs so mutations to schema, provider parity, tracker README parity,
      layout, or hard-cut absence guards make the tests fail and restore fixtures byte-for-byte.
      Leave historical records and the governing ADR unchanged.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/analyst/scripts/tests/run.sh
    bash skills/foreman/scripts/tests/run.sh
    bash skills/journal/scripts/tests/run.sh
    bash skills/workspace/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    scripts/tests/run.sh
    bash -n skills/backlog/scripts/trackers.sh \
      skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/analyst/scripts/analyst-facts.sh
    shellcheck -S warning skills/backlog/scripts/trackers.sh \
      skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/tracker-layer-status.sh \
      skills/analyst/scripts/analyst-facts.sh
    git diff --check
    ```

    Expected: all commands exit zero. Fresh setup creates the tracker@2 managed layout and no legacy
    artifacts; a second setup writes nothing; zero queues remain clone-stable; catalog and page see
    only table files; history pagination is bounded and side-effect free; observe/consume write only
    history; removal and recreation preserve lifecycle identity; legacy flat layouts refuse without
    writes; the manual fixture preserves non-ID bytes; consumers reject tracker@1; and the deployed
    provider, guide, tables, and history pass parity. Commit the complete steady-state cut atomically.

## Done when

- Backlog's canonical managed `.trackers` surface consists of the fixed guide, debrief prompt,
  provider, `history.tsv`, and `tables/`; every queue TSV is beneath `tables/`, whose `.gitkeep`
  preserves an empty population. Setup refuses legacy root-level TSVs but leaves unrelated
  project-owned non-TSV entries outside its write set.
- Tracker lifecycle state is derived only from append-only `event-N` rows in `history.tsv`, and the
  public provider exposes exactly the tracker@2 queue and bounded-history surfaces in the ADR.
- Setup, repair, recovery, Analyst, Foreman, doctrine, root docs, deployed files, and all fixtures
  agree on the hard cut, with no compatibility reader, writer, migration verb, or receipt
  pseudo-tracker.
- The documented Git conversion is byte-preserving and tested, all affected harnesses and lint
  gates pass, parity red proofs are effective, and the abandoned draft plus published history remain
  untouched.

_On completion (before landing), run the host's close-the-books sweep._
