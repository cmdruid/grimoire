---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Backlog brownfield migration and front-door hard cut — Implementation Plan

Decision: → `adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md`

Input exceptions:

- The owner explicitly chose an ADR-governed mechanical change instead of a feature spec.
- After that ADR was published, the owner made one controlling hard-cut decision: Backlog must not
  modify `AGENTS.md`; this applies to every Backlog verb, including `migrate`. The implementation
  corrects the ADR's conflicting declaration-removal clause before changing code.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Hard-cut migration edge:** `/backlog migrate [<source-root>]` is the only tracker@1 reader.
  Setup, repair, queue administration, the installed provider, runtime checks, and consumer skills
  remain tracker@2-only and must not probe, adopt, alias, dual-read, or repair a prior layout.
- **No Backlog front-door ownership:** no Backlog command creates, edits, removes, or commits
  `AGENTS.md` or `CLAUDE.md`. Setup and queue administration do not inspect either file as a
  prerequisite. Remove the route reconciler, classifier, anchor template, and their dedicated tests;
  do not leave dormant compatibility code. Existing installed Backlog blocks and retired
  `agent-trackers:` declarations are project/future-workflow cleanup, never a migration side effect.
- **Replacement composition is deferred:** this job does not configure, populate, document a
  concrete recipe for, or otherwise modify Workstream lifecycle hooks. Preserve `skills/workstream/`
  and `.spaces/workstream/hooks/` exactly as found. A future project-level change may compose
  `/backlog debrief` into those seams and may add a lean project-authored `.trackers/README.md`
  pointer to its front door; neither change belongs to Backlog or this implementation.
- **Doctrine correction, not an exception:** revise portable doctrine so a durable-home skill owns
  explicit setup for its state but registers a front-door route only when route ownership is an
  independently justified public surface. Existing skills with intentional routes remain valid;
  this job does not remove or redesign their registration.
- **Exact v1 converter:** without `<source-root>`, migration examines only `<root>/.trackers`.
  An external source is accepted only through an explicit safe repo-relative argument and only when
  `.trackers` is absent. Never infer a source from a front-door declaration or filesystem scan.
  Accept only a clean, fully tracked, non-symlink, dedicated tracker@1 TSV installation with the
  exact known root population: regular `README.md`, `DEBRIEF.md`, executable `trackers.sh`,
  `receipts.tsv`, and zero or more `<stem>.tsv` queue files. Require the exact queue and receipt
  headers and valid tracker@1 rows. Unknown files or directories, unknown formats, mixed versions,
  record/Markdown trackers, untracked or ignored entries, collisions, malformed IDs or fields,
  nested Git roots, detached HEAD, and unsafe parents refuse before the first write.
- **Byte preservation:** move each root queue to `.trackers/tables/<stem>.tsv`, rename
  `receipts.tsv` to `history.tsv`, and rewrite only leading first-column `receipt-N` values to
  `event-N`. Preserve row order, line endings, and every non-ID byte. Reconcile current provider,
  managed README block, structural `.gitkeep`, and prompt sections through Backlog's existing setup
  reconciler; never reinterpret table or lifecycle semantics in the migration helper.
- **Preview, confirmation, and recovery:** preview is read-only and enumerates the exact source,
  destination, and path population. Apply requires a distinct explicit confirmation, repeats the
  complete preflight immediately before writing, and creates one exact scoped commit. Git is the
  only rollback surface. A failure after the first move reports the ordinary Git diff and never
  creates a manifest, intent, backup tree, automatic resume, or rollback routine.
- **Preserve current Backlog behavior:** tracker@2 schema, `.trackers/tables/`, lifecycle history,
  queue/prompt population, setup resumability, repair scope, README ownership, concurrency guards,
  provider adjacency, consumer APIs, and explicit `/backlog debrief` behavior remain unchanged.
  Removing the always-loaded anchor removes automatic cadence from Backlog; this plan does not
  invent or implement the replacement workflow hook.
- **Governing-record alignment:** amend the published migration ADR only to remove its
  `agent-trackers:` mutation and record the no-front-door rule. Amend the published Callback design
  only to remove its unimplemented Backlog route and Backlog debrief-subscription requirements; do
  not replace them with Workstream integration in this job. Older superseded debrief-anchor
  specifications remain historical evidence and are not rewritten.
- **Patient zero:** never modify Grimoire's real `AGENTS.md`. Exercise current setup, queue
  administration, migration, malformed-front-door independence, and byte preservation only against
  throwaway Git fixtures. Snapshot and preserve the live `skills/workstream/` population; the
  project Workstream hook paths are currently absent and must remain absent.
- **Coexisting work:** the untracked
  `.records/specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` belongs to
  another session. Do not inspect, edit, stage, commit, or derive requirements from it. Re-establish
  the unrelated status population before implementation and preserve any additional entries.
- **Plan gate:** re-read the ADR and Callback spec, rerun Slice 0's census against execution `HEAD`,
  and recheck every named script signature before editing. This plan is a snapshot, not authority
  over later tree changes.

## Slices

- [ ] **Slice 0: Re-ground migration and front-door ownership** <requires: —>
  - Files: read-only inspection of the governing ADR; the published Callback and Backlog
    debrief-anchor specs; `README.md`; `PACK.md`; `skills/backlog/`;
    `skills/skill-builder/docs/DOCTRINE.md`; `skills/skill-builder/verbs/new.md`; and
    `scripts/tests/`.
  - Change: make no project write. Record `HEAD` and `git status`; run Contractor's ground check;
    then save a sorted candidate census outside the repository for all occurrences of
    `register-route`, `route-status`, `debrief-anchor`, `skill:backlog`, `backlog-route`,
    `AGENTS.md`, `agent-trackers:`, `tracker@1`, `receipts.tsv`, and `/backlog migrate`. Classify
    each as production code to remove, migration/rejection evidence to retain, current doctrine to
    revise, integration coverage to replace, or historical evidence to preserve. Re-read the
    tracker@1 provider from Git history only as prior-art evidence for exact headers and row
    validation; do not restore or execute it.
  - Verify: this command reports `unresolved_count=0`:

    ```sh
    skills/contractor/scripts/ground-check.sh <root> \
      .records/adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md
    ```

    Every production caller of Backlog's route scripts and every current tracker@1/manual-conversion
    assertion is accounted for; there is one current tracker@2 provider; and all unrelated worktree
    entries are named and excluded.

- [ ] **Slice 1: Add the narrow converter and remove Backlog's front-door subsystem atomically** <requires: 0>
  - Files:
    - Amend governing records:
      `.records/adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md` and
      `.records/specs/2026-08-29-callback-registry-and-explicit-backlog-debrief-subscription.md`.
    - Create migration surfaces: `skills/backlog/verbs/migrate.md`,
      `skills/backlog/scripts/migrate-trackers.sh`, and
      `skills/backlog/scripts/tests/migrate-test.sh`.
    - Modify Backlog runtime and prose: `skills/backlog/SKILL.md`,
      `skills/backlog/scripts/backlog-setup.sh`, `skills/backlog/verbs/setup.md`,
      `skills/backlog/verbs/tracker.md`, and `skills/backlog/verbs/repair.md`.
    - Delete the complete route subsystem:
      `skills/backlog/scripts/register-route.sh`, `skills/backlog/scripts/route-status.sh`,
      `skills/backlog/templates/debrief-anchor.md`,
      `skills/backlog/scripts/tests/route-test.sh`,
      `skills/backlog/scripts/tests/debrief-anchor-contract-test.sh`, and
      `skills/backlog/scripts/tests/fixtures/debrief-anchor-scenarios.tsv`.
    - Modify Backlog coverage: `skills/backlog/scripts/tests/run.sh`,
      `skills/backlog/scripts/tests/deploy-test.sh`,
      `skills/backlog/scripts/tests/repair-test.sh`,
      `skills/backlog/scripts/tests/setup-resume-test.sh`,
      `skills/backlog/scripts/tests/hard-cut-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`.
    - Modify library doctrine and inventory: `skills/skill-builder/docs/DOCTRINE.md`,
      `skills/skill-builder/verbs/new.md`, `README.md`, and `PACK.md`.
    - Modify integration coverage: delete `scripts/tests/backlog-anchor-contract-test.sh`; modify
      `scripts/tests/run.sh`, `scripts/tests/backlog-provider-contract-test.sh`, and
      `scripts/tests/configure-clankshop-test.sh`.
    - Review without expected edits: `skills/backlog/scripts/trackers.sh`,
      `skills/backlog/scripts/tracker-layer-status.sh`,
      `skills/backlog/scripts/tracker-runtime-check.sh`,
      `skills/backlog/scripts/tracker-readme-status.sh`,
      `skills/backlog/scripts/scoped-commit.sh`, `skills/backlog/verbs/debrief.md`,
      `skills/backlog/templates/trackers-readme-block.md`, `.trackers/`,
      `skills/analyst/`, `skills/foreman/`, `skills/workstream/`,
      `.spaces/workstream/hooks/`, and `AGENTS.md`.
  - Change:
    - Write counted red proofs first. Fresh setup with no front door must leave `AGENTS.md` absent;
      setup, repair, tracker add/remove, and migration with a present arbitrary or malformed
      `AGENTS.md` must leave its bytes unchanged. A planted Backlog production reference to
      `AGENTS.md`, `register-route`, `route-status`, `debrief-anchor`, or `skill:backlog` must fail
      the repository boundary guard, and fixture restoration must be byte-identical.
    - Correct the ADR's external-source clause: an external tracker root is always an explicit
      argument, and migration never removes a retired declaration. Add the owner rule that no
      Backlog command modifies a project front door. Correct the unimplemented Callback spec so it
      removes Backlog's old anchor without replacing it with `backlog-route@1` and removes its
      Backlog debrief-subscription contract. Do not add Workstream integration or select another
      automatic invocation mechanism.
    - Remove `DOOR`, `REG`, route preflight/reconciliation, queue-count registration, retry
      reporting, and final route validation from `backlog-setup.sh`. Setup and tracker
      administration must neither fail on nor report `AGENTS.md`. Delete the now-unreachable
      scripts/template/tests rather than retaining shims. Keep `.trackers/DEBRIEF.md` and explicit
      debrief routing intact.
    - Implement the exact interface below. Validate the exact Git root, attached branch,
      clean status, literal safe pathspecs, non-symlink parent chain, tracked/ignored population,
      dedicated allowed file set, queue stems and rows, receipt rows, destination absence for an
      external move, and all table/history collisions before writing. Preview prints stable facts
      and the full path list; apply repeats preflight, performs literal Git moves, rewrites only
      receipt ID prefixes through an outside-tree temporary file, and invokes current setup in the
      same announced write-only sweep.

      ```text
      migrate-trackers.sh preview|apply --root <absolute-root> [--source <repo-relative>] [--confirmed]
      ```
    - After setup succeeds, validate the installed tracker@2 layer with its adjacent provider:
      `describe`, `catalog`, bounded `history`, and bounded `page` over every converted queue. Form
      the exact union of source, destination, and reconciled paths, neutralize `git mv`'s incidental
      staging only for those literal endpoints, and pass that union to Backlog's existing scoped
      commit helper. Require clean status afterward. On any post-write failure, print the remaining
      Git diff and stop without rollback.
    - Route `/backlog migrate [<source-root>]` through `verbs/migrate.md`. The agent runs preview,
      shows source/destination/path count, obtains explicit confirmation, and only then runs apply.
      Replace setup's manual shell conversion with a concise pointer to the migration verb. Keep
      unknown aliases rejected; migrate is not invoked by setup, repair, runtime recovery, or
      consumer diagnostics.
    - Update doctrine so durable-home setup and front-door registration are separate declared
      capabilities. `skill-builder new` scaffolds registration only when the skill design selected
      a route surface. Update Backlog, pack, and README prose to describe the tracker layer and
      explicit debrief without claiming a universally installed Backlog route or cadence. Limit
      `PACK.md` to removing that obsolete cadence claim; do not add a Workstream hook recipe.
    - Replace route-centric integration assertions with exact ownership assertions. The aggregate
      configuration fixture must show Backlog setup and queue administration modifying only
      `.trackers`; Backlog repair still has its narrow provider/README write set. Keep unrelated
      skills' intentional `AGENTS.md` behavior and tests unchanged. Add no Workstream hook fixture,
      template, setup behavior, compiled hand-off content, or project configuration.
    - Cover in-place and explicit external migration with populated queue and lifecycle rows;
      preview no-op; missing confirmation; no source inference; exact byte preservation; event-ID
      conversion; current provider/README reconciliation; one scoped commit; repeat refusal as
      already current; dirty, detached, unsafe, symlink, untracked, ignored, mixed, malformed,
      colliding, and post-write-failure cases. Prove ordinary setup/runtime still reject tracker@1.
  - Verify:

    ```sh
    bash skills/backlog/scripts/tests/run.sh
    bash skills/skill-builder/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    scripts/tests/run.sh
    bash -n skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/migrate-trackers.sh
    shellcheck -S warning skills/backlog/scripts/backlog-setup.sh \
      skills/backlog/scripts/migrate-trackers.sh
    git diff --check
    ```

    Expected: all commands exit zero. Migration alone recognizes tracker@1 and produces an exact
    tracker@2 commit after confirmation; ordinary Backlog paths remain hard-cut; Backlog production
    code contains no front-door mutation or registration subsystem; setup and queue administration
    preserve arbitrary `AGENTS.md` bytes or leave the file absent; package and root tests contain no
    dead anchor suite; doctrine makes route ownership explicit rather than tier-derived;
    `skills/workstream/` is byte-identical to its pre-slice snapshot; `.spaces/workstream/hooks/`
    remains absent or byte-identical as found; and the unrelated worktree population remains
    untouched. Commit the slice atomically because the public migration verb, route deletion,
    doctrine, governing records, and hard-cut guards must agree.

## Done when

- `/backlog migrate [<source-root>]` previews and, only after explicit confirmation, converts one
  exact tracker@1 TSV installation through a single scoped Git commit while preserving every
  non-ID byte; all unsafe, ambiguous, incompatible, and unsupported inputs refuse at the documented
  boundary.
- Setup, repair, tracker administration, runtime, and consumers remain tracker@2-only. No alias,
  fallback, automatic migration, dual read, dynamic source discovery, manifest, resume engine, or
  rollback framework exists.
- Backlog neither creates nor mutates a project front door. Its route scripts, classifier, anchor,
  fixtures, and operative prose are gone; `.trackers/DEBRIEF.md` and explicit `/backlog debrief`
  remain available for the future workflow mechanism to invoke.
- Workstream's package, lifecycle hooks, compiled hand-offs, and project hook population are
  unchanged. No replacement glue or optional front-door pointer is configured or documented as a
  concrete project recipe in this job.
- The ADR, future Callback design, portable doctrine, skill scaffolding guidance, package docs,
  integration tests, and repository inventory agree with that ownership boundary. Older historical
  records remain untouched, Grimoire's authored `AGENTS.md` is unchanged, all affected gates pass,
  and the unrelated untracked record remains outside the commit.

_On completion (before landing), run the host's close-the-books sweep._
