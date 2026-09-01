---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Project layer discovery anchors and standalone guides — Implementation Plan

Deliver the smallest end-to-end anchor through Journal first, where the deployed README already has
standalone lifecycle coverage; then apply the same absent-only discovery contract to Backlog while
closing its documented standalone-usage gaps. Finish with the cross-layer ownership guards that
prove setup and pack configuration remain front-door neutral.

Decision: → `adr/2026-08-31-add-explicit-project-layer-discovery-anchors.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Explicit only:** `/journal anchor` and `/backlog anchor` are the sole new front-door entrypoints.
  Setup, repair, migration, runtime, queue administration, pack configuration, and provider use
  never install, refresh, remove, or require a pointer.
- **Fixed paths:** both verbs target only repository-root `AGENTS.md`. Their literal destinations are
  `.records/README.md` and `.trackers/README.md`; accept no front-door or layer-root selector.
- **Absent-only project prose:** install the ADR's exact H2 and paragraph with no marker, version,
  build stamp, refresh, replacement, or removal behavior. A literal README-path occurrence is
  already satisfied. The canonical H2 without the path is a safe refusal, not a rewrite or duplicate.
- **Safe creation:** a missing `AGENTS.md` may be created after preview and confirmation. A present
  entry must be a regular non-symlink file. Apply rechecks every precondition immediately before an
  atomic write and reports only `wrote=AGENTS.md`; standalone commit custody remains skill-local.
- **Layer first:** anchor requires the corresponding initialized layer, current package-managed
  README block, and current adjacent provider. It never repairs them as a side effect. Provider data
  findings do not authorize package substitution or hand repair.
- **Standalone boundary:** local README plus adjacent provider covers ordinary record and tracker
  query/lifecycle work without either source skill. Setup, repair, migration, tracker-table
  administration, debrief routing, and curation judgment stay outside that promise.
- **No old anchor substrate:** do not restore Backlog's deleted route reconciler, route classifier,
  debrief-anchor template, route fixtures, `skill:backlog` block, or automatic cadence. The new
  pointer contains no skill route or verb roster.
- **No dynamic-path regression:** `agent-records:`, `records-root:`, `agent-trackers:`, root selector
  arguments, declaration parsing, aliases, and legacy discovery remain absent from ordinary code.
- **Independent packages:** Journal and Backlog each own their fixed prose and package-local helper;
  neither calls the other or a composer. Do not introduce a shared mutable front-door section.
- **README ownership:** package-managed begin/end markers remain inside `.records/README.md` and
  `.trackers/README.md`, where provider-coupled contracts need refresh. They never enter the new
  `AGENTS.md` prose.
- **Patient zero:** never modify Grimoire's real `AGENTS.md`. Exercise missing and existing front
  doors only in throwaway Git fixtures. Preserve `skills/workstream/` and project Workstream hooks.
- **Coexisting work:** the untracked
  `.records/specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` belongs to
  another session. Do not inspect, edit, stage, commit, or derive requirements from it.
- **Plan gate:** before editing, rerun Slice 0 against execution `HEAD`, inspect all named script
  signatures, and amend this draft if the implementation surface has moved.

## Slices

- [x] **Slice 0: Re-ground the two front-door and local-guide surfaces** <requires: —>
  - Files: read-only inspection of the governing ADR; both prior ADRs linked from it; `AGENTS.md`;
    `README.md`; `PACK.md`; `skills/skill-builder/docs/DOCTRINE.md`;
    `skills/journal/`; `skills/backlog/`; and `scripts/tests/`.
  - Change: make no project write. Record `HEAD` and the complete unrelated status population. Run
    Contractor's ground check on the governing ADR. Save a sorted census outside the repository for
    `AGENTS.md`, `CLAUDE.md`, `anchor`, `register-route`, `route-status`, `debrief-anchor`,
    `.records/README.md`, `.trackers/README.md`, `agent-records:`, `records-root:`, and
    `agent-trackers:`. Classify every live hit as the new explicit anchor surface, current local-guide
    ownership, a protected non-anchor path, a bounded migration rejection, or historical evidence.
    Save the starting commit as one line at
    `${TMPDIR:-/tmp}/grimoire-project-layer-anchor-base` for the final protected-path comparison.
  - Verify:

    ```sh
    skills/contractor/scripts/ground-check.sh <root> \
      .records/adr/2026-08-31-add-explicit-project-layer-discovery-anchors.md
    ```

    Expected: `unresolved_count=0`; the current Backlog route subsystem remains absent; the only
    existing Journal front-door mutation is bounded retired-declaration cleanup in migration; and
    all unrelated worktree paths are named and excluded.

- [x] **Slice 1: Prove the absent-only anchor through Journal** <requires: 0>
  - Files:
    - Modify `skills/skill-builder/docs/DOCTRINE.md`, `skills/journal/SKILL.md`,
      `skills/journal/scripts/standup.sh`, `skills/journal/scripts/tests/run.sh`,
      `skills/journal/scripts/tests/standup-test.sh`, and
      `skills/journal/scripts/tests/contract-test.sh`.
    - Create `skills/journal/verbs/anchor.md`, `skills/journal/scripts/records-anchor.sh`,
      `skills/journal/scripts/records-readme-status.sh`,
      `skills/journal/scripts/tests/anchor-test.sh`,
      `skills/journal/templates/agents-pointer.md`, and
      `skills/journal/templates/records-readme-block.md`.
    - Review without expected edits: `skills/journal/scripts/records.sh`,
      `skills/journal/scripts/scoped-commit.sh`, `skills/journal/scripts/tests/repair-test.sh`, and
      `skills/journal/scripts/tests/setup-transaction-test.sh`.
  - Change:
    - Write red fixtures first for absent and existing `AGENTS.md`, an already-mentioned literal
      `.records/README.md`, a conflicting `## Project records`, unsafe targets, missing/stale layer
      pieces, missing confirmation, changed-after-preview state, no markers, one exact scoped commit,
      and a clean idempotent rerun. Prove setup, repair, and ordinary provider calls leave arbitrary
      front-door bytes unchanged. Prove Journal migration preserves both project-layer anchor
      sections and all unrelated `AGENTS.md` and `CLAUDE.md` bytes while retaining its exact removal
      of retired `agent-records:` and `records-root:` declarations.
    - Extract Journal's managed README heredoc into the package-only
      `templates/records-readme-block.md`; keep output byte-equivalent except for the approved
      standalone-readiness additions. Make standup and a read-only README classifier consume this one
      source so anchor validation does not duplicate the provider contract.
    - Implement `records-anchor.sh preview|apply --root <absolute-root> [--confirmed]`. It validates
      the canonical Git root, attached commit custody, initialized ledger, exact executable provider,
      current managed README block, and safe `AGENTS.md`; emits the exact planned addition; and writes
      only after confirmation and a complete recheck. The verb presents preview, obtains confirmation,
      applies, and commits only a reported `AGENTS.md` path.
    - Strengthen the records guide so its installed provider and README alone expose ordinary query,
      validation, creation, update, relocation, closure, and history use. Keep schema ownership clear;
      forbid ledger hand edits and bundled-provider substitution; and say that an unavailable skill
      during required maintenance means stop and report, not improvise.
    - Extend portable doctrine with an explicit absent-only project-layer pointer shape, distinct
      from refreshable route registration. Preserve the high bar: fixed self-describing local
      interface, explicit invocation, no lifecycle coupling, and project ownership after write.
  - Verify:

    ```sh
    bash skills/journal/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    bash -n skills/journal/scripts/records-anchor.sh \
      skills/journal/scripts/records-readme-status.sh
    shellcheck -S warning skills/journal/scripts/records-anchor.sh \
      skills/journal/scripts/records-readme-status.sh skills/journal/scripts/standup.sh
    ```

    Expected: the Journal anchor is explicit, marker-free, idempotent, and fixture-only; the staged
    README/provider completes an ordinary records lifecycle with no package-runtime dependency; and
    all existing setup, repair, migration, and transaction recovery behavior remains green.

- [x] **Slice 2: Apply the discovery contract to Backlog** <requires: 1>
  - Files:
    - Modify `skills/backlog/SKILL.md`, `skills/backlog/templates/trackers-readme-block.md`,
      `skills/backlog/scripts/tests/run.sh`, `skills/backlog/scripts/tests/readme-test.sh`,
      `skills/backlog/scripts/tests/skill-doc-test.sh`, and
      `scripts/tests/backlog-provider-contract-test.sh`.
    - Create `skills/backlog/verbs/anchor.md`, `skills/backlog/scripts/trackers-anchor.sh`,
      `skills/backlog/scripts/tests/anchor-test.sh`, and
      `skills/backlog/templates/agents-pointer.md`.
    - Review without expected edits: `skills/backlog/scripts/tracker-runtime-check.sh`,
      `skills/backlog/scripts/tracker-readme-status.sh`, `skills/backlog/scripts/trackers.sh`,
      `skills/backlog/scripts/backlog-setup.sh`, `skills/backlog/scripts/migrate-trackers.sh`,
      `skills/backlog/scripts/scoped-commit.sh`, and the deleted route-subsystem paths guarded by the
      repository test.
  - Change:
    - Port Slice 1's red anchor matrix to the tracker layer with literal `.trackers/README.md` and
      `## Project trackers`. Use the existing runtime and README classifiers rather than recreating
      layer validation. Prove setup, repair, migration, tracker add/remove, and ordinary provider
      calls remain front-door neutral.
    - Implement the fixed `trackers-anchor.sh` preview/apply entrypoint and `/backlog anchor` verb with
      the same confirmation, atomic-write, path-reporting, and scoped-commit contract as Journal.
      Do not share a runtime dependency or restore any retired Backlog route files.
    - Expand the deployed tracker guide to explain derived open/consumed state, consumer-scoped
      idempotent observation, tracker-wide terminal consumption, stable consumer keys,
      `--consumer ... --unobserved`, queue/history cursors, `.trackers/DEBRIEF.md`, mutation outputs,
      Git custody, and the skill-unavailable maintenance stop. Ensure the README or adjacent
      provider exposes every ordinary command form, then execute each documented family using only
      the staged layer.
    - Narrow the repository Backlog boundary guard so the new anchor helper is the only production
      script allowed to name `AGENTS.md`; retain and red-prove the prohibition for setup, repair,
      migration, provider, and all retired route/cadence surfaces.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/run.sh
    bash scripts/tests/backlog-provider-contract-test.sh
    bash -n skills/backlog/scripts/trackers-anchor.sh
    shellcheck -S warning skills/backlog/scripts/trackers-anchor.sh
    ```

    Expected: Backlog's local layer is independently usable for ordinary queue and lifecycle work;
    the explicit anchor writes only project-owned prose; and all steady-state and migration paths
    remain hard-cut and front-door neutral.

- [x] **Slice 3: Lock the cross-layer public boundary** <requires: 1, 2>
  - Files: modify `README.md` and `scripts/tests/run.sh`; create
    `scripts/tests/project-layer-anchor-contract-test.sh`; review without expected edits `PACK.md`,
    `scripts/tests/configure-clankshop-test.sh`, `AGENTS.md`, `skills/workstream/`, and
    `.spaces/workstream/hooks/`.
  - Change:
    - Update the library inventory to name each explicit anchor and standalone local guide without
      advertising an automatic front-door install or a skill-independent maintenance capability.
    - In a throwaway repository, install both anchors in both orders over a missing and an authored
      `AGENTS.md`. Prove the exact two project-owned sections coexist, custom prose survives, reruns
      are no-ops, either literal-path mention independently satisfies its anchor, no marker or route
      block appears, and each standalone commit contains only `AGENTS.md`.
    - Run ordinary records and tracker lifecycles using only the installed `AGENTS.md`, layer
      READMEs, and adjacent providers. Make the source skill directories unavailable to the simulated
      operator after installation. Separately prove pack configuration and both setup/repair paths do
      not create or mutate `AGENTS.md`.
    - Red-prove the cross-layer guards by planting one automatic anchor call in setup and one managed
      pointer marker in each template; require the fixture to fail and restore byte-identically.
  - Verify:

    ```sh
    scripts/tests/run.sh
    git diff --check
    test ! -e .spaces/workstream/hooks
    anchor_base_file="${TMPDIR:-/tmp}/grimoire-project-layer-anchor-base"
    test -s "$anchor_base_file"
    anchor_base_sha="$(sed -n '1p' "$anchor_base_file")"
    git diff --exit-code "$anchor_base_sha" -- AGENTS.md skills/workstream
    ```

    Expected: all host and package gates pass; the real Grimoire front door and Workstream package
    are unchanged; no setup path advertises a layer; and the unrelated worktree population remains
    outside every commit.

## Done when

- `/journal anchor` and `/backlog anchor` preview and, after explicit confirmation, append their
  exact project-owned sections to root `AGENTS.md` or create the missing file. Literal-path mentions
  make reruns no-ops; conflicts and unsafe inputs refuse without writes; no pointer markers exist.
- Neither anchor repairs or initializes its layer. Setup, repair, migration, runtime, tracker
  administration, provider operations, pack configuration, and Workstream remain anchor-blind.
- `.records/README.md` plus `.records/records.sh` supports ordinary record discovery and lifecycle,
  and `.trackers/README.md` plus `.trackers/trackers.sh` supports ordinary queue and lifecycle use,
  without source skill access. Required maintenance without the skill stops with a clear report.
- Dynamic root declarations, Backlog's retired route/debrief-anchor subsystem, automatic cadence,
  compatibility aliases, and shared front-door ownership remain absent.
- Portable doctrine, both skills, their deployed guides, library inventory, package tests, and host
  integration tests agree; all affected gates pass; the authored root `AGENTS.md`, Workstream paths,
  and unrelated untracked spec remain untouched.

_On completion (before landing), run the host's close-the-books sweep._
