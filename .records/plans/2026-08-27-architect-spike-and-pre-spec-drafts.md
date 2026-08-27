---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Architect spikes and saved drafts — Implementation Plan

Tracer-bullet: first prove one confirmed feasibility question end to end—qualified question,
authorized draft, isolated experiment, and directly published evidence record. Later slices widen
the same primitives to ordinary brainstorm persistence, specification promotion, and package-wide
integration.

Spec: `→ specs/2026-08-26-architect-spike-and-pre-spec-drafts.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- The governing spec is `status: published`; do not reopen its design decisions while walking this
  plan. A new product branch goes back to the spec rather than being decided in code.
- Brainstorm is write-free unless the user explicitly saves. A direct `spike` invocation still
  requires the necessity check, a bounded charter, and explicit confirmation before any draft write
  or experimental command.
- Architect may execute disposable measurement code but never creates production implementation,
  a project patch, an implementation plan, or a durable probe job.
- Experiment code, fixtures, generated data, and build output remain in disposable isolation. The
  only durable project writes from a confirmed spike are its Architect draft and completed spike
  record; external effects retain their ordinary approval boundary.
- `draft.md` and `spikes.md` are package-only outlines. `/architect setup` continues to deploy only
  `adr.md` and `specs.md`; ordinary use must work with no setup and no deployed Journal tool.
- Keep Architect standalone: resolve `<agent-workspace>` and `<agent-records>` in the verb, pass
  explicit roots to helpers, use `records.sh` only when executable, and preserve file-mode parity.
- All path-writing code rejects unsafe relative paths, symlink parents/destinations, title/slug
  collisions, and writes outside Architect's namespace or owned record store. Bash remains compatible
  with the repository's existing macOS/Bash 3.2 shell style.
- Every new absence or rejection assertion receives a mutation red-proof in a throwaway fixture.
  Tests never create patient-zero `.spaces/` or `.records/` assets in this repository.
- Coexisting work is present. `README.md` is the only currently modified path this plan also needs;
  preserve its checkpoint wording at lines 88–96 while changing only the workspace-kind sentence
  near line 78. Other dirty Inspector, Checkpoint, Foreman, Workstream, PACK, and record paths are
  out of scope. Re-read `git status --short` before every slice and do not stage unrelated changes.

## Task 0 — Re-ground the plan against the live tree

- Files: read only—governing spec; `AGENTS.md`; `README.md`; `skills/architect/`;
  `skills/workspace/`; `skills/skill-builder/docs/DOCTRINE.md`;
  `skills/skill-builder/scripts/skills-lint.sh`; `skills/foreman/scripts/operations-index.sh`;
  `scripts/tests/`.
- Sweep:
  - Run `skills/contractor/scripts/ground-check.sh root
    .records/specs/2026-08-26-architect-spike-and-pre-spec-drafts.md`; expect
    `unresolved_count=0`.
  - Search capability-wide for `architect/spike@1`, `brainstorm save`, `verbs/spike.md`,
    `architect/drafts`, `doctype: spikes`, and prospective helper names. Confirm no implementation
    already exists outside the governing spec.
  - Census every live closed-workspace-kind list, including multiline prose. The current load-bearing
    sites are Workspace's contract/checker/tests, portable doctrine, README, Skill-builder's
    kind-first lint vocabulary/test, and Foreman's reserved-owner filter/test.
  - Run `git status --short` and capture baseline targeted-test failures caused by coexisting work.
    Re-read each target path immediately before editing; a changed target invalidates this sizing.
- Verify: the spec is still published, the plan's paths exist, prior art is absent, and the complete
  kind-vocabulary population is accounted for. This task writes nothing.

## Slices

- [x] **Slice 1: Confirmed spike tracer** <requires: Task 0>
  - Files—create:
    - `skills/architect/verbs/spike.md`
    - `skills/architect/templates/draft.md`
    - `skills/architect/templates/spikes.md`
    - `skills/architect/scripts/architect-artifacts.sh`
    - `skills/architect/scripts/tests/artifacts-test.sh`
  - Files—modify:
    - `skills/architect/SKILL.md`
    - `skills/architect/scripts/tests/run.sh`
    - `skills/architect/scripts/tests/skill-doc-test.sh`
    - `skills/workspace/SKILL.md`
    - `skills/workspace/scripts/workspace-check.sh`
    - `skills/workspace/scripts/tests/workspace-check-test.sh`
    - `skills/skill-builder/docs/DOCTRINE.md`
    - `skills/skill-builder/scripts/skills-lint.sh`
    - `skills/skill-builder/scripts/tests/lint-workspace-path-test.sh`
    - `skills/foreman/scripts/operations-index.sh`
    - `skills/foreman/scripts/tests/operations-index-test.sh`
    - `README.md`
  - Change:
    - Add `drafts` as the seventh nested-Markdown workspace kind everywhere the live vocabulary is
      authoritative. Reserve it as an owner name, make Workspace validate it like `doctrine` and
      `templates`, make Skill-builder reject kind-first `drafts` paths, and keep Foreman's
      cross-owner operation scan from treating `drafts` as an owner.
    - Add package-only draft and spike outlines with the exact body fields in the spec. Keep both
      outside Architect's `## Project templates` inventory and setup copy set.
    - Add one package-local artifact entrypoint with two operations:
      `draft-save --root <root> --workspace <relative> --slug <slug> --title <title> --body <file>`
      atomically installs or updates an authored draft, while
      `spike-publish --root <root> --records-root <relative> --title <title> --body <file>
      [--records-tool <path>]` stages, validates, and publishes `architect/spike@1`. Both print the
      resulting repo-relative `path=`. The draft operation accepts only a safe kebab slug and
      same-title replacement; the spike operation uses the executable records tool passed by the
      verb when present and otherwise emits byte-equivalent front matter in file mode. Both record
      paths remain `draft` until the complete five-section body validates, then change to
      `published`; failure never exposes a partial published record.
    - Route `spike [draft-or-question]`. The verb performs the read-only necessity gate, presents the
      six-field charter, stops for confirmation, writes the authorized draft, runs arbitrary
      measurement code only in disposable isolation, records observations, and publishes a direct
      positive, negative, or inconclusive account, then adds the returned record link to the draft.
      One invocation answers one question. Incomplete work remains draft notes; resume rechecks the
      charter and reconfirms only when assumptions or cost changed. Published spike records are
      never overwritten—later evidence mints a distinct record that cites its predecessor. The verb
      never invokes itself from another verb or offers experimental code as a deliverable.
    - Update Architect's description, status exception, record contract, structure, and typed
      `produces` edge while retaining `spec` as its only handoff.
    - Fixture tests exercise safe creation, same-title update, collisions, symlink/path refusal,
      split roots, tool/file publication parity, required sections, executor/context, and failure
      remaining draft. A controlled experiment writes payload only outside the fixture project;
      the canary writes one payload inside it and proves the isolation assertion turns red. An
      interrupted spike creates no record; a successor leaves the original checksum unchanged and
      appears in the originating draft's related links.
  - Verify:
    - `bash skills/architect/scripts/tests/run.sh` → all green.
    - `bash skills/workspace/scripts/tests/run.sh` → `drafts` accepted as nested Markdown; unsafe
      content, symlinks, unknown kinds, and top-level/owner `drafts` rejected.
    - `bash skills/foreman/scripts/tests/operations-index-test.sh` → a `drafts` top-level directory is
      never indexed as an operation owner.
    - `bash skills/skill-builder/scripts/tests/lint-workspace-path-test.sh` → owner-first drafts paths
      pass and kind-first drafts paths fail.
    - `shellcheck skills/architect/scripts/architect-artifacts.sh
      skills/workspace/scripts/workspace-check.sh skills/foreman/scripts/operations-index.sh` → clean.

- [x] **Slice 2: Opt-in brainstorm persistence and specification promotion** <requires: 1>
  - Files—create:
    - `skills/architect/scripts/tests/procedure-contract-test.sh`
  - Files—modify:
    - `skills/architect/SKILL.md`
    - `skills/architect/verbs/brainstorm.md`
    - `skills/architect/verbs/spec.md`
    - `skills/architect/docs/ideal-use.md`
    - `skills/architect/scripts/architect-artifacts.sh`
    - `skills/architect/scripts/tests/artifacts-test.sh`
    - `skills/architect/scripts/tests/skill-doc-test.sh`
  - Change:
    - Make bare and topic brainstorm conversational and write-free. Parse explicit
      `brainstorm save [name]` before treating `save` as a topic; synthesize one current draft via
      the Slice 1 entrypoint. Permit resume only from an explicitly named, contained Architect draft.
      Duration, importance, open questions, multi-agent participation, or an agent recommendation
      never imply persistence.
    - Preserve existing `architect/spec@1` draft records as valid `grill`/`spec` inputs. Teach
      `spec <draft>` to consume the workspace outline, incorporate settled decisions and completed
      spike citations, create or update the specification first, and only then mark the draft
      `promoted` with the new record link. Never copy transient code or raw spike notes.
    - Replace the worked ideal-use arc with both legitimate branches: ordinary conversation that
      leaves no artifact, and an explicit save that later promotes. Keep the accepted specification
      as Architect's sole feature baton.
    - Add transcript/fixture assertions for no-write defaults, every forbidden save heuristic,
      explicit save/resume, same-title replacement, collision refusal, promotion ordering, spike
      citations, and historical draft-spec compatibility. Mutation-red-prove each absence guard.
  - Verify:
    - `bash skills/architect/scripts/tests/run.sh` → all green with no project writes from bare/topic
      brainstorm or before spike confirmation.
    - Run the artifact helper against split and coincident root fixtures; expect exactly the
      authorized draft/spec/record paths and no sibling-owner writes.
    - `git diff --check -- skills/architect` → clean.

- [x] **Slice 3: Ownership, setup, migration, and distribution closure** <requires: 1, 2>
  - Files—create:
    - `skills/architect/scripts/tests/migrate-contract-test.sh`
  - Files—modify:
    - `skills/architect/SKILL.md`
    - `skills/architect/verbs/migrate.md`
    - `skills/architect/verbs/setup.md`
    - `skills/architect/scripts/tests/run.sh`
    - `skills/architect/scripts/tests/setup-test.sh`
    - `skills/architect/scripts/tests/skill-doc-test.sh`
    - `scripts/tests/install-pack-test.sh`
    - `scripts/tests/configure-clankshop-test.sh`
  - Change:
    - Register `architect/spike@1` as Architect-owned current shape. Explicit selection of a valid
      current spike is a no-op; unknown declared versions and schema-less would-be spikes refuse.
      Do not invent a legacy draft, spike, or template location, and never migrate workspace drafts.
    - Keep setup's active copy set exactly `adr.md` and `specs.md`. Assert `founding.md`, `draft.md`,
      and `spikes.md` remain package-only, incumbent active templates remain untouched, and reruns
      converge to zero writes. Fresh setup, partial recovery, and no-op reruns also leave
      `<agent-workspace>/architect/drafts/` and `<agent-records>/spikes/` absent.
    - Extend skill-document and install fixtures so the new verb, helper, and package-only outlines
      travel with Architect without being deployed into a consuming project's workspace.
    - In the repository integration fixture, use the actually deployed Journal records tool once to
      publish a completed spike through Architect's helper; assert four-key metadata, five-section
      body, `status: published`, and no extra project configuration. Retain file-mode coverage in the
      package test so the tool is an optimization, never a floor.
    - Run a final closed-kind census and remove every live six-kind claim outside immutable published
      historical records. Preserve all unrelated dirty bytes, especially the existing README edit.
  - Verify:
    - `bash skills/architect/scripts/tests/run.sh` → all green.
    - `bash skills/workspace/scripts/tests/run.sh` → all green.
    - `bash skills/foreman/scripts/tests/run.sh` → all green, or only Task 0 baseline failures from
      unrelated coexisting Foreman edits remain and are reported before landing.
    - `bash skills/skill-builder/scripts/tests/run.sh` → all green.
    - `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0`.
    - `bash scripts/tests/run.sh` → all green.
    - `git diff --check` → clean; `git status --short` shows no patient-zero workspace/records assets
      and no newly modified path outside this plan's declared files.

## Done when

- Bare/topic brainstorm performs no write; explicit save creates or updates one resumable Architect
  draft; existing draft spec records still work.
- A spike runs only after necessity, charter, and confirmation; experimental payload remains
  disposable; a completed attributed account publishes directly as `architect/spike@1` in tool and
  file modes without an independent review workflow.
- `spec <draft>` promotes only after the specification exists and cites every completed spike on
  which its design relies.
- All live workspace authorities agree on seven kinds, including nested-Markdown `drafts`, and all
  new safety/absence assertions have demonstrated red-proofs.
- Architect remains standalone, setup still deploys exactly two active templates, no legacy
  locations or durable probe lifecycle were invented, and no production feature code was added.
- Targeted package tests, Skill-builder lint, repository integration tests, shell checks, and diff
  checks pass after coexisting work is reconciled.

_On completion (before landing), run the host's close-the-books sweep._
