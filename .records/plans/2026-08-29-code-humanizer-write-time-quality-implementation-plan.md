---
doctype: plans
status: published
schema: contractor/plan@1
stage: implemented
tags: [plan]
---

# Code-humanizer write-time quality — Implementation Plan

Spec: → specs/2026-08-29-code-humanizer-write-time-quality-and-visual-scanability.md

## Global constraints

- The published spec is authoritative. Do not broaden `code-humanizer` into review, debugging,
  infrastructure, repository-wide cleanup, or arbitrary documentation work.
- Automatic application is role- and lifecycle-based: durable application, service, library,
  shipped CLI, and maintained test source are in scope. Repository automation and operational
  scripts, disposable code, fixtures, snapshots, generated code, and vendored code are not.
- Infrastructure-as-code, deployment manifests, and CI/build infrastructure are outside the skill
  even under explicit invocation. An explicit invocation loads only far enough to refuse before
  file listing or editing. Do not add infrastructure types to
  `skills/code-humanizer/scripts/scope.sh`.
- Preserve `mark`'s intent-summary approval stop and semantics-preserving boundary. Preserve
  `map`/`walk`, the map record contract, typed edges, and the no-setup disposition.
- The host formatter and checked-in configuration win. Never install or configure a formatter,
  silently format the repository, or rerun checks already satisfied by the underlying coding task.
- `README.md` and `PACK.md` already contain unrelated user changes. Preserve every incumbent hunk;
  edit only their existing `code-humanizer` inventory sentences.
- This library is patient zero for its skill mechanisms. Do not add route blocks, deployed layout,
  or setup content to `AGENTS.md`.

## Task 0 — Re-ground the job against HEAD

- Files: none; read-only inspection.
- Re-read the published spec and the complete current versions of `skills/code-humanizer/SKILL.md`,
  `skills/code-humanizer/verbs/mark.md`, `skills/code-humanizer/references/landmarks.md`,
  `skills/code-humanizer/scripts/scope.sh`, the package tests, `README.md`, and `PACK.md`. Search
  capability-wide for any newer routing or formatting implementation before editing.
- Capture `git status --short -- skills/code-humanizer README.md PACK.md` and the existing
  `git diff -- README.md PACK.md`. Treat those diffs as incumbent user work, not cleanup material.
- Run:

  ```text
  skills/contractor/scripts/ground-check.sh <root> <published-spec>
  skills/code-humanizer/scripts/tests/run.sh
  skills/skill-builder/scripts/skills-lint.sh .
  scripts/tests/run.sh
  ```

  Expected baseline at plan time: five grounded references and no unresolved paths; package tests
  report `passed=29 failed=0` and `passed=33 failed=0`; library lint reports `fails=0` with only the
  three existing orphan-edge warnings for `goal`, `goal-pursuit`, and `session-evidence`; repository
  integration tests report `ALL GREEN`. If HEAD has moved, investigate the delta before sizing or
  editing.

## Slices

- [x] **Slice 1: Route only durable product source — tracer** <requires: Task 0>
  - Files: modify `skills/code-humanizer/SKILL.md` and
    `skills/code-humanizer/scripts/tests/skill-doc-test.sh`.
  - Change: replace the broad frontmatter trigger with the published self-contained trigger, keeping
    it strict-YAML-valid and below 1024 characters. Add an applicability section before the
    write-time standard that classifies by role and intended lifetime, defaults ambiguous roles to
    skipping implicit application, distinguishes shipped CLIs from repository scripts, and refuses
    infrastructure before dispatch, scope listing, or editing. Preserve explicit invocation for
    supported non-infrastructure scripts and disposable programs. Update the dispatch text and
    write-time done condition so only an applicable or explicitly requested scope carries the
    standard. Replace obsolete documentation assertions with assertions for the positive route,
    automatic exclusions, ambiguous-case skip, explicit non-infrastructure override, and hard
    infrastructure refusal. Red-prove each new contract assertion against a deliberately altered
    temporary package copy, then restore and confirm byte identity.
  - Verify:

    ```text
    skills/code-humanizer/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: package tests pass; lint has zero failures. Then run the routing-probe method in
    `skills/skill-builder/docs/BOUNDARY-AUDIT.md` using only available descriptions. Positive prompts
    cover a service module, shipped single-file CLI, and maintained test; negative prompts cover a
    release helper, scratch spike, and ordinary infrastructure work; an ambiguous tools migration
    defaults to no selection; explicit `mark` on a supported release script selects; explicit
    invocation on infrastructure selects only to return the refusal. Record the observed selection
    for every prompt in the implementation handoff. For that explicit infrastructure case, load the
    skill against an isolated infrastructure fixture and require refusal before `scope.sh`, file
    enumeration, proposed edits, or modification; record the loaded-behavior trace. Any routing or
    refusal mismatch blocks Slice 2.

- [x] **Slice 2: Make the loaded skill produce maintainable, visually scannable code** <requires: 1>
  - Files: modify `skills/code-humanizer/SKILL.md`,
    `skills/code-humanizer/references/landmarks.md`, `skills/code-humanizer/verbs/mark.md`, and
    `skills/code-humanizer/scripts/tests/skill-doc-test.sh`.
  - Change: replace presentation proxies with the published quality hierarchy: correctness and task
    constraints, project fit, simple cohesive design, scanability, then applicable verification.
    Limit automatic work to introduced or materially reshaped code and its immediate formatting
    context. Replace screen/file-count slogans with cohesion and responsibility decisions; make
    purpose comments and docstrings conditional; add error-path, invariant, public-surface, and
    readability-theater guidance. Add formatter precedence, narrow touched-scope formatting,
    indentation and wrapping rules, the no-configuration/no-repository-reformat boundary, and the
    rule that existing task verification is reused rather than repeated. Expand `mark` to approved
    landmarks, grouping, formatting, and safe indentation while retaining its preview, confirmation,
    no-commit, and no-semantic-change guarantees. In indentation-sensitive languages, allow a trusted
    formatter on parseable code or semantics-neutral continuation whitespace; refuse ambiguous
    nesting. Update and red-prove the package contract assertions for each new invariant.
  - Verify:

    ```text
    skills/code-humanizer/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: all package tests pass and lint has zero failures. Trace the loaded instructions against
    a new formatted application module, a one-line legacy fix, a trivial exported API, idiomatic
    compact code, a parseable indentation-sensitive file, ambiguous indentation, and explicit
    `mark` formatting. Each trace must match the published acceptance table; `map` and `walk` remain
    read-only by default.

- [x] **Slice 3: Align the public inventory and run the complete gate** <requires: 2>
  - Files: modify only the existing `code-humanizer` sentences in `README.md` and `PACK.md`.
  - Change: describe the skill as keeping durable source fit for human ownership, with the narrowed
    automatic write-time scope and `mark`/`map`/`walk` preserved. Keep the inventory concise; do not
    duplicate the exclusion roster or change pack membership. Apply narrow patches around the
    `code-humanizer` lines so the unrelated incumbent changes remain byte-for-byte.
  - Verify:

    ```text
    skills/code-humanizer/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh .
    scripts/tests/run.sh
    git diff --check -- skills/code-humanizer README.md PACK.md
    git diff -- README.md PACK.md
    ```

    Expected: the package and repository integration tests pass; lint has zero failures; the scoped
    diff check is clean; inspection shows only the intended `code-humanizer` inventory lines added to
    the pre-existing `README.md`/`PACK.md` diffs. Re-run the Slice 1 routing probes after the final
    description is fixed in place and require the same results.

## Done when

- Every goal and mechanism in the published spec maps to one of the three slices.
- The final description routes durable product source, skips automatic script/disposable work,
  defaults ambiguous roles to skip, and hard-refuses infrastructure under explicit invocation.
- The write-time and `mark` contracts cover quality, formatting, indentation, narrow scope, and
  verification reuse without changing `map`, `walk`, `skills/code-humanizer/scripts/scope.sh`,
  schemas, edges, or setup behavior.
- All package tests, the library lint gate, repository integration tests, scoped diff checks, routing
  probes, and loaded-behavior traces pass with their expected results.
- Existing unrelated changes are preserved, the plan remains uncommitted unless separately asked,
  and no implementation is shipped to trunk from the plan walk.

_On completion (before landing), run the host's close-the-books sweep._
