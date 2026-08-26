---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Clankshop project configuration — Implementation Plan

Spec: `→ specs/2026-08-25-clankshop-project-configuration.md`

## Global Constraints

- **Hard cut:** ordinary template resolution is canonical incumbent → recognized-legacy refusal →
  bundled read-only fallback. No first-use copy, compatibility alias, setup receipt, Clankshop face,
  marker, or pack executor survives or is introduced.
- **Owner boundary:** every deployer is package-local, writes only its declared owner/kind surface,
  preserves project-editable incumbents, and rechecks every existing parent immediately before a
  write. Journal's records standup and Backlog's delimited route remain the named exceptions.
- **Commit custody:** standalone setup makes one pathspec-scoped commit over exactly its reported
  writes and no commit on a no-op rerun. Inside an announced configuration sweep, every member
  setup is write-only; the caller may commit the complete approved configuration once.
- **Patient zero:** never deploy project configuration into grimoire's own `.spaces` or front door.
  Exercise setup and glue only in disposable fixtures.
- **Schemas stay packaged:** setup deploys active authoring templates, hooks, flows, doctrine, and
  tools only. It never deploys schema identifiers, validators, or migration chains.
- **Portability:** scripts remain Bash 3.2 compatible and self-contained inside each skill package;
  no leaf sources or executes a sibling package.
- **Coexisting work:** preserve the existing Inspector refinement and every unrelated worktree item,
  including the untracked root `.DS_Store`. Use explicit pathspecs and never stage broadly.
- **Host gates:** every changed skill runs its own `scripts/tests/run.sh` when present; Auditor gains
  such an entrypoint. The final gate also runs `skills/skill-builder/scripts/skills-lint.sh .`,
  `skills/skill-builder/scripts/tests/run.sh`, `scripts/tests/install-pack-test.sh`, and
  `cargo test --locked`.

## Slices

- [x] **Slice 1: explicit template setup tracer — Notepad and the portable contract** <requires: —>
  - Modify `skills/skill-builder/docs/DOCTRINE.md`: replace first-use template locking with explicit
    setup plus bundled fallback; define editable-content versus managed-tool refresh, immediate
    parent recheck, partial-safe rerun, owner-specific reporting, the standalone-versus-sweep commit
    custody split, and the no-live-reader/no-deploy rule.
  - Modify `skills/skill-builder/scripts/skills-lint.sh` and
    `skills/skill-builder/scripts/tests/lint-records-writer-test.sh`: a nonempty `## Project
    templates` inventory requires a routed `setup`, every listed template must appear in setup
    coverage, and removing that route is a failing red-proof.
  - Create `skills/notepad/verbs/setup.md` and a package-local setup script; modify
    `skills/notepad/SKILL.md`, `skills/notepad/scripts/note-mint.sh`, and
    `skills/notepad/scripts/tests/{note-mint-test.sh,setup-test.sh,run.sh}`. Setup deploys only
    `notes.md` absent-only; ordinary mint uses a canonical incumbent or bundled bytes without
    creating `.spaces`; legacy paths refuse. The setup route owns a pathspec-scoped standalone
    commit path and an explicit write-only sweep mode. Tests inject the post-preflight parent
    exchange and a package/sibling destination so the safety and boundary assertions fail when
    disabled; they also prove the exact standalone commit, no commit on a no-op rerun, preservation
    of unrelated staged and unstaged state, and zero member commits in sweep mode.
  - Verify: `bash skills/notepad/scripts/tests/run.sh && bash
    skills/skill-builder/scripts/tests/lint-records-writer-test.sh && bash
    skills/skill-builder/scripts/skills-lint.sh .` → all tests pass and lint reports `fails=0`.
  - Result (2026-08-26): Notepad 65 assertions green; lint red-proof 26 assertions green;
    repository lint `fails=0 warns=0`.

- [x] **Slice 2: widen active templates, hooks, and flows** <requires: Slice 1>
  - Create routed setup verbs, package-local deployers, and setup tests for
    `skills/architect/`, `skills/contractor/`, `skills/workstream/`, and `skills/debugger/`; modify
    their `SKILL.md`, ordinary template resolvers or authoring instructions, and test entrypoints.
  - Architect deploys only `adr.md` and `specs.md`; Contractor only `plan.md` and `roadmap.md`.
    Package-only templates remain package-only and the setup tests red-prove their exclusion.
  - Workstream deploys `templates/{manifest,debrief}.md` plus empty
    `hooks/{feature-completion,after-eventful-ship}.md`; `hooks.sh` continues treating missing and
    empty files identically. Hand-off, compaction, coordinator, debug, and design templates remain
    package-only.
  - Debugger deploys `templates/{bugs,investigation}.md` and a bundled
    `flows/diagnostics.md` carrying `title` and `use-when`; `bug-mint.sh` uses bundled fallback without
    project writes. Setup does not deploy schemas or record shells.
  - Verify: run `skills/{architect,contractor,workstream,debugger}/scripts/tests/run.sh` and require
    fresh deploy, incumbent preservation, legacy refusal, unsafe/recheck refusal, package-only
    exclusion, owner boundaries, partial-safe rerun, and zero-write second setup.
  - Result (2026-08-26): Architect, Contractor, Workstream, and Debugger harnesses all green;
    setup suites report 16, 16, 24, and 20 passing assertions respectively.

- [x] **Slice 3: normalize existing setup owners and defer Auditor** <requires: Slice 1>
  - Modify Analyst's setup prose/script/tests to the shared safety contract without changing its
    deployed-wins catalog semantics.
  - Modify Journal, Backlog, Delegate, and Inspector setup prose/scripts/tests where the census
    finds a missing preflight, immediate recheck, partial-safe report, or owner-boundary proof.
    Preserve refresh of package-managed tools and all project-authored bytes/data.
  - Create Auditor's setup verb/deployer/test harness; modify `skills/auditor/{SKILL.md,BOOTSTRAP.md}`.
    Setup deploys `reports.md` and calibrates only Auditor's rubric. It creates no audit record or
    host-index/routing pointer. An initial audit is a separate explicit invocation. Rerun preserves
    incumbents; its sentinel red-proofs detect both retired writes.
  - Verify: run setup suites for Analyst, Journal, Backlog, Delegate, Inspector, and Auditor; the
    instrumented Auditor setup fails loudly if a core fixture invokes it.
  - Result (2026-08-26): all six owner harnesses green. Auditor's isolated suite reports 20 passing
    assertions, including red-proofs for both retired write classes; the core fixture's direct-call
    sentinel proves Auditor remains outside the initial sweep.

- [x] **Slice 4: faceless PACK runbook and real delivery-loop glue** <requires: Slices 2, 3>
  - Modify `PACK.md` with an explicit-source Project configuration runbook: inspect and propose;
    selected member setups in write-only sweep mode; approved project-authored overlays; no-op rerun,
    owner checks, diff review, and one optional scoped commit over the complete approved path set.
    Default roots remain undeclared, and no member setup may commit during the sweep.
  - Encode the initial glue exactly: Workstream feature completion invokes Backlog debrief and
    includes Delegate byproducts; eventful ship debriefs ship-only friction without duplication;
    Delegate byproducts carry proposed task/issue/feedback class, evidence/path, and reason, but do
    not file directly. Contractor queue-source and Architect/Inspector/Contractor invocation seams
    remain content-only.
  - Create a disposable consuming-project fixture under `scripts/tests/` that invokes the actual
    Journal, Backlog, Workstream, and Delegate setup mechanics, authors the approved overlays, runs
    owner checks plus Workspace, proves no member setup commits during the sweep, makes at most one
    caller-owned aggregate commit when requested, and proves a second sweep is diff-free. Auditor is
    instrumented to fail if invoked and the core sweep must stay green.
  - Modify `scripts/tests/install-pack-test.sh` with a faceless-member setup canary. Prove the
    absence assertion fails after direct canary invocation, then prove install/update/check/remove
    never execute it or create project config, a face, or a marker.
  - Verify: `bash scripts/tests/install-pack-test.sh` plus the new configuration fixture pass.
  - Result (2026-08-26): `install-pack-test: ok` and `configure-clankshop-test: ok`; the fixture
    proves member setups make zero commits, the caller makes one aggregate commit, rerun is
    diff-free, Workspace passes, and the instrumented Auditor call is absent from both sweeps.

- [x] **Slice 5: convergence, mutation proofs, and full completion audit** <requires: Slices 1–4>
  - Update remaining live README/PACK/Skill-builder references and tests from first-use copying to
    explicit setup plus bundled fallback. Historical records remain unchanged except the published
    configuration spec's explicit supersession statement.
  - Run every changed skill suite, all mutation/sentinel red-proofs, Skill-builder mechanical and
    boundary checks, the pack suite, `shellcheck` over changed shell scripts when available, and the
    host Cargo gate.
  - Re-census all eleven setup-capable skills and all seven active-template owners against the
    published spec. For every roster row, verify the routed verb, declared deployable assets, live
    consumer, package-only exclusions, setup tests, no-op rerun, and exact owner paths from current
    files and test output. Mechanically inspect every setup owner's instructions for the standalone
    versus sweep commit-custody split. Confirm Shopbook, Workspace, Checkpoint, Mailbox, and Scheduler
    have no setup route.
  - Inspect the final Git diff against the pre-work state; preserve and report every unrelated path.
  - Verify: all named gates green, no unresolved spec requirement, and this plan's every slice has a
    recorded result.
  - Result (2026-08-26): all 18 skill harnesses passed; repository lint reports
    `fails=0 warns=0`; both pack/configuration fixtures, full-shell `shellcheck`, `git diff --check`,
    and `cargo test --locked` are green. The final census finds all eleven routed setup owners, no
    setup verb on Shopbook, Workspace, Checkpoint, Mailbox, or Scheduler, no deployed schema path,
    and no live first-use template deployment language. The pre-existing Inspector refinement and
    untracked root `.DS_Store` remain preserved and uncommitted.
  - Follow-up review remediation (2026-08-26): Check 13 now rejects prose-only and fenced-example
    setup mentions, requires a route-shaped dispatch, and verifies each declared template in an
    executable setup-test line. Every multi-asset setup owner now proves interruption after a safe
    write and deterministic rerun; Architect, Contractor, Workstream, and Debugger also exercise
    their standalone exact-path commit and no-op commit paths against real Git fixtures. The
    follow-up also removed the preserved root `.DS_Store` and added the repository ignore rule.
