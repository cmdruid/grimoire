---
doctype: plans
status: published
stage: approved
schema: contractor/plan@1
tags: [plan]
---

# Agent feedback capture and independent skill tuning — Implementation Plan

The tracer starts at the highest-risk seam: establish source custody plus one accepted
current-conversation `skill-builder tune` claim before removing its reusable prior art from the old
collector. From that common base, one branch hard-cuts the collector through a human
capture/query/close lifecycle and widens it to agent capture and optional routing; the other widens
tune to schema-free files, the full disposition set, and failure containment. The final acceptance
gate joins both independent branches. All six slices are independently testable and committable.

Spec: → `specs/2026-09-03-agent-feedback-capture-and-independent-skill-tuning.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Governing record:** implement the published successor spec above. Its predecessor,
  `specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`, is superseded historical
  evidence, not a live compatibility contract.
- **Package independence:** `agent-feedback` and `skill-builder` must not name, invoke, install,
  inspect, or declare a typed edge to one another. `skill-builder` keeps its existing edge block
  byte-for-byte. `review` remains read-only and `calibrate` remains doctrine-only.
- **Ownership:** the collector writes only
  `~/.agents/skilldata/agent-feedback/feedback.tsv`; `skill-builder tune` writes only an explicitly
  accepted source package. Neither feature scans for, migrates, repairs, warns about, or deletes
  predecessor-owned global data or routes.
- **Provider boundary:** only `skills/agent-feedback/scripts/feedback.sh` may read or write the TSV.
  Preserve physical-home resolution, symlink rejection, exact permissions, whole-file validation,
  bounded locking, same-directory temporary files, atomic rename, collision checks, and cleanup.
- **Provenance:** the procedure, not the provider, decides `origin`. Human slash-command capture is
  preserved unless privacy or subject ambiguity requires one question; agent-selected capture uses
  the strict quality gate, never asks a follow-up, calls the provider at most once, and may silently
  skip.
- **Tune evidence:** tune accepts only current conversational evidence and at most one caller-named
  schema-free prose file. Input is evidence rather than authority. Mutation requires explicit
  acceptance and exact revalidation of target identity and, when present, input identity.
- **Patient-zero boundary:** anchor tests deploy only to temporary homes. Do not add installed route
  blocks or deployed layout to Grimoire's real `AGENTS.md`; do not change shared-parent modes.
- **Hard cut:** live source must contain no predecessor package name, schema name, ID prefix, global
  path, command, delimiter, or temporary-file prefix. The sole exception is a same-line annotated
  negative fixture proving rejection. Historical records under `.records/` and design history under
  `docs/design/` are not rewritten.
- **Red proofs:** every new contract or safety test must first fail against the missing or planted
  behavior, then pass after implementation. For destructive-condition tests, restore the fixture's
  byte identity before accepting green.
- **Common slice gate:** every slice's `Verify` section names its focused runner and expected result.
  After that focused gate, run `shellcheck` on every shell file changed by the slice,
  `bash skills/skill-builder/scripts/skills-lint.sh .` with `fails=0` and no warning beyond the
  recorded baseline, and `git diff --check` with no whitespace errors.
- **Attended probe protocol:** every required behavioral probe uses a fresh context plus a disposable
  home or Git repository, and records the exact harness/version, package-exposure method, prompts,
  expected and actual results, changed paths, and residual uncertainty in the implementation
  handoff. Inability to obtain the required isolation blocks that slice; token-presence tests are not
  substitutes, and network-dependent model invocations never enter deterministic package runners.
- **Coexisting work:** preserve all unrelated root changes and all other worktrees. Do not inspect or
  alter `.workstreams/` or `.worktrees/` handoffs. Before each slice, re-read the cited files against
  the current worktree rather than relying on line numbers in this plan.
- **Baseline expectations:** the full skill lint currently reports `fails=0 warns=3`; the three
  warnings are incumbent Foreman orphan-edge warnings (`goal`, `goal-pursuit`, `session-evidence`).
  No slice may add a failure or a new warning. The full lint scans shell files in adjacent worktrees
  and may take about a minute.
- **Authoring doctrine:** follow `skills/skill-builder/docs/DOCTRINE.md`; keep each skill
  self-contained and generic, route through descriptions, use typed edges only for actual handoffs,
  and keep mutable global state out of package bytes.

## Slices

- [x] **Task 0: Ground the plan against the live tree** <requires: —>
  - Evidence:
    - Recorded baseline: branch `main`, HEAD
      `8b5433110bd954268007aa8c796f3fda7a9e39ec`; only the newly published/superseded records and this
      plan are expected root changes before implementation.
    - Mapped the collector's current router, verbs, provider, content-ref resolver, anchor helper,
      source-custody helper, fixtures, and focused tests under `skills/skill-feedback/`.
    - Mapped the toolmaker's dispatch and immutable boundaries in `skills/skill-builder/SKILL.md`,
      `skills/skill-builder/verbs/review.md`, `skills/skill-builder/verbs/calibrate.md`, and its test
      runner.
    - Mapped repository integration seams in `README.md`, `scripts/tests/run.sh`,
      `scripts/tests/clankshop-contract-test.sh`, `scripts/tests/configure-clankshop-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh`. Confirmed `PACK.md` is already generic and
      Grimoire's real `AGENTS.md` has no deployed route.
    - Identified the important rewrite seams: the incumbent provider has 16 columns, `SF-` IDs,
      `resolved` lifecycle language, and batch resolution; the new contract has 20 columns, `AF-`
      IDs, one-row close, exact output, generic subject types, and distinct human/agent rules.
    - Confirmed the existing content-ref helper is suitable only for a skill subject identity; it is
      not the tune package digest. The existing source-custody helper is reusable prior art but its
      installed-package and feedback-store coupling must be removed.
  - Baseline verification:
    - `bash skills/skill-feedback/scripts/tests/run.sh` → green (305 assertions).
    - `bash skills/skill-builder/scripts/tests/run.sh` → green (151 assertions).
    - `bash scripts/tests/run.sh` → green.
    - `bash scripts/tests/clankshop-contract-test.sh` → `40 passed`.
    - `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0 warns=3`, only the three
      incumbent Foreman warnings named above.
    - `bash skills/contractor/scripts/ground-check.sh
      .records/specs/2026-09-03-agent-feedback-capture-and-independent-skill-tuning.md` → only the
      spec's package-relative provider shorthand and not-yet-created `skills/agent-feedback/`
      references.

- [ ] **Slice 1: Independent `skill-builder tune` source-identity tracer** <requires: Task 0>
  - Files:
    - Modify `skills/skill-builder/SKILL.md` and
      `skills/skill-builder/scripts/tests/run.sh`.
    - Create `skills/skill-builder/verbs/tune.md`.
    - Create `skills/skill-builder/scripts/source-custody.sh`.
    - Create `skills/skill-builder/scripts/tests/source-custody-test.sh` and
      `skills/skill-builder/scripts/tests/tune-contract-test.sh`.
    - Use `skills/skill-feedback/scripts/source-custody.sh` and
      `skills/skill-feedback/scripts/tests/source-custody-test.sh` only as read-only prior art; do not
      make the new helper call back into that package.
  - Change:
    - Red-first, establish the current-conversation tracer for
      `/skill-builder tune <skill-source>` and explicit tune-only routing. State the final optional
      input grammar, but defer its behavior matrix to Slice 6. The tracer has no producer schema,
      feedback ID, global-home scan, record, commit, issue, or publication behavior.
    - Generalize source resolution shared in meaning with review: accept a package directory,
      `SKILL.md`, current-directory-relative path, or bare slug at `<git-top>/skills/<slug>/`.
      Physically resolve the package; require a matching declared name and Git-tracked source under
      the resolved worktree; reject ambiguity, immutable package-manager stores, and unsupported
      entries. Writability, ancestry shape, and symlink targets are not custody authority.
    - Make the helper read-only and fact-only. Report the physical package root, declared name, Git
      root, HEAD object ID, tracked/custodied status, immutable-store status, and
      `package-sha256`. Give it no installed-package, global-home, or feedback-store argument.
    - Compute `package-sha256` by walking the package without following symlinks and hashing a
      deterministic length-framed stream of sorted relative path, entry type, executable bit, and
      regular-file bytes or symlink target. Include clean tracked, dirty tracked, and every untracked
      entry under the package; exclude only Git administrative internals; refuse unsupported entry
      types.
    - Complete one end-to-end agent procedure path: extract one concrete claim from current
      conversation; re-check it against the package, relevant history, and repository context;
      present its disposition, rationale, exact target identity, and smallest coherent change; obtain
      explicit human acceptance; then re-run custody and require exact identity equality before
      editing.
    - Apply only that accepted package-contained change, run the package's focused check followed by
      host lint, and report the claim, changed files, verification, and uncertainty in conversation.
      Any refusal or failure creates no external lifecycle mutation or global write. Slice 6 adds
      multi-claim clustering, every non-current disposition, named-file input, and the complete drift
      and failure matrix.
    - Assert that the existing `skill-builder` edge block and
      `skills/skill-builder/verbs/review.md` and `skills/skill-builder/verbs/calibrate.md` remain
      byte-for-byte unchanged.
  - Verify:
    - Red-prove each new test before implementation, then run
      `bash skills/skill-builder/scripts/tests/source-custody-test.sh` and
      `bash skills/skill-builder/scripts/tests/tune-contract-test.sh` → all assertions pass.
    - Fixtures cover explicit and bare-slug targets; clean tracked, dirty tracked, untracked,
      executable, and symlink digest changes; immutable and untracked-source rejection; and prove
      that symlinks and writability do not establish custody.
    - Attended probe: against a disposable tracked skill package, supply one supported
      current-conversation claim, inspect and accept the exact proposal identity, and prove that only
      the selected package changed and both its focused check and host lint ran.
    - `bash skills/skill-builder/scripts/tests/run.sh` → green.
    - A targeted diff confirms no change to review, calibrate, or the edge block and no collector
      name in `skills/skill-builder/`.

- [ ] **Slice 2: Hard-cut rename with a human capture lifecycle tracer** <requires: 1>
  - Files:
    - Rename `skills/skill-feedback/` to `skills/agent-feedback/` as one package move.
    - Modify `skills/agent-feedback/SKILL.md`, `skills/agent-feedback/verbs/capture.md`,
      `skills/agent-feedback/verbs/query.md`, `skills/agent-feedback/verbs/setup.md`,
      `skills/agent-feedback/scripts/feedback.sh`,
      `skills/agent-feedback/scripts/skill-content-ref.py`,
      `skills/agent-feedback/scripts/tests/lib.sh`,
      `skills/agent-feedback/scripts/tests/provider-test.sh`,
      `skills/agent-feedback/scripts/tests/validation-test.sh`,
      `skills/agent-feedback/scripts/tests/path-safety-test.sh`,
      `skills/agent-feedback/scripts/tests/concurrency-test.sh`,
      `skills/agent-feedback/scripts/tests/skill-content-ref-test.sh`, and
      `skills/agent-feedback/scripts/tests/run.sh`.
    - Create `skills/agent-feedback/verbs/close.md`.
    - Rename/update `skills/agent-feedback/verbs/anchor.md`,
      `skills/agent-feedback/scripts/feedback-anchor.sh`,
      `skills/agent-feedback/templates/agents-route.md`,
      `skills/agent-feedback/scripts/tests/anchor-test.sh`, and
      `skills/agent-feedback/scripts/tests/fixtures/anchor-cases.tsv` mechanically to the new package
      owner so the package is coherent; Slice 4 completes the competing-route behavior.
    - Delete `skills/agent-feedback/verbs/tune.md`,
      `skills/agent-feedback/scripts/source-custody.sh`,
      `skills/agent-feedback/scripts/tests/source-custody-test.sh`, and
      `skills/agent-feedback/scripts/tests/tune-contract-test.sh`.
    - Modify `README.md`, `scripts/tests/clankshop-contract-test.sh`,
      `scripts/tests/configure-clankshop-test.sh`, and
      `skills/backlog/scripts/tests/skill-doc-test.sh` for the new standalone identity and boundary.
  - Change:
    - Begin with one red end-to-end test: empty temporary home → human capture → default human query →
      close → closed query. Require exact `agent-feedback@1` header, `AF-` ID, provenance, lifecycle,
      output labels/order, and no count trailer.
    - Replace the package identity, frontmatter, paths, test hooks, delimiters, temporary prefixes,
      schema, and IDs. The package is global-only, standalone, outside `clankshop`, and exposes only
      automatic selection plus `capture`, `query`, `close`, `setup`, and `anchor`.
    - Rewrite the provider around exactly `describe`, `init`, `capture`, `query`, and `close` with the
      spec's flags, singleton rules, defaults, incompatibilities, exact diagnostics, exact success
      output, and canonical 20-column row. Remove batch resolution and every remediation or migration
      path.
    - Preserve and re-test the physical-home/path-safety and transactional mutation machinery. Setup
      alone may remove a conclusively stale well-formed lock and tighten only owned modes. Every read
      and mutation validates the complete store first.
    - Implement explicit human capture first: slash command required, omitted message drawn only from
      the same utterance, one concise question only when prose or subject is missing/ambiguous,
      privacy-safe near-verbatim statement, faithful summary, optional structured detail, and exact
      capture result without echoing content.
    - Implement query as a transparent provider wrapper and close as lifecycle management only.
      Preserve all non-lifecycle fields; make exact repeats idempotent and conflicts atomic failures.
    - Retain the content-ref algorithm solely for optional `subject_type=skill` identity; rename its
      live terminology without turning it into source custody.
    - Update repository inventory/contribution text and existing route/boundary tests in the same
      slice so the renamed package never leaves the root suite with a dangling live path. Leave
      `PACK.md` and the real `AGENTS.md` untouched.
  - Verify:
    - Red-prove the human lifecycle tracer, then run
      `bash skills/agent-feedback/scripts/tests/provider-test.sh`,
      `bash skills/agent-feedback/scripts/tests/validation-test.sh`,
      `bash skills/agent-feedback/scripts/tests/path-safety-test.sh`, and
      `bash skills/agent-feedback/scripts/tests/concurrency-test.sh` → green.
    - Provider tests cover exact describe/init/capture/query/close grammar and output; absent-only
      initialization; byte-preserving repeated setup; enum, bound, reference, result-ref, escaping,
      non-ASCII, malformed-row, 32,768-byte-row, ID-collision, lock, and atomicity behavior.
    - `bash skills/agent-feedback/scripts/tests/run.sh` → green.
    - `bash scripts/tests/clankshop-contract-test.sh`,
      `bash scripts/tests/configure-clankshop-test.sh`,
      `bash skills/backlog/scripts/tests/skill-doc-test.sh`, and `bash scripts/tests/run.sh` → green.
    - `test ! -e skills/skill-feedback` → succeeds.

- [ ] **Slice 3: Widen capture across origins, subjects, and quality boundaries** <requires: 2>
  - Files:
    - Modify `skills/agent-feedback/SKILL.md`, `skills/agent-feedback/verbs/capture.md`, and, only
      where validation or rendering needs adjustment,
      `skills/agent-feedback/scripts/feedback.sh`.
    - Modify `skills/agent-feedback/scripts/tests/fixtures/capture-cases.tsv`,
      `skills/agent-feedback/scripts/tests/capture-contract-test.sh`,
      `skills/agent-feedback/scripts/tests/provider-test.sh`,
      `skills/agent-feedback/scripts/tests/validation-test.sh`,
      `skills/agent-feedback/scripts/tests/concurrency-test.sh`,
      `skills/agent-feedback/scripts/tests/boundary-test.sh`, and
      `skills/agent-feedback/scripts/tests/skill-content-ref-test.sh`.
  - Change:
    - Add red behavioral contract cases for every `origin`, `subject_type`, and `kind`, then implement
      the two procedure branches without changing the provider's non-inference boundary.
    - Agent capture enforces reuse ownership, change-worthiness, incident/consequence, response, and
      privacy; selects at most one highest-signal observation; asks no follow-up; suppresses automatic
      self-feedback; returns the exact skip reason for no-change-worthy or ambiguous cases; and stays
      silent for ordinary success, generic praise, ratings, or speculative redesign.
    - Human capture treats the explicit command as storage authority: allow praise, incomplete
      suggestions, empty incident/consequence/suggestion, and a `win` without a suggestion. Preserve
      wording except necessary redaction/whitespace normalization; ask for a safe restatement only
      when privacy redaction would destroy meaning.
    - Cover `skill`, `agent`, `harness`, `tool`, and reusable `workflow`; reject project-owned product
      or local-process feedback. Normalize one unambiguous subject to lowercase kebab of at most 120
      UTF-8 bytes.
    - Define reference safety consistently: `subject_ref` is `unknown` or an encoded, valid-UTF-8,
      non-absolute, traversal-free value up to 512 bytes; skill subjects may use the existing
      `content-sha256:` identity. Apply the spec's equivalent privacy-safe grammar and 2,000-byte
      bound to `result_ref`. Do not substitute a repository commit for subject identity.
    - Derive nonempty `project_ref` only inside a project as
      `local-sha256:<first-16-lowercase-hex>` of the physically resolved project root; leave it empty
      outside a project. Prove it is absent from human query output and appears in TSV only when
      `--include-project-ref` is explicitly combined with `--format tsv`.
    - Complete the provider matrix: all bounds and conditional fields, four escapes in one pass,
      control-character refusal, query filters/orders/limits/defaults/formats/project-ref gate, exact
      empty results, all close dispositions, and exact idempotence.
    - Exercise at least 20 parallel captures and prove unique IDs, exact row count, bounded
      contention, no torn bytes, and no surviving operation-owned lock or temporary files.
  - Verify:
    - Red-prove the expanded capture cases, then run
      `bash skills/agent-feedback/scripts/tests/capture-contract-test.sh`,
      `bash skills/agent-feedback/scripts/tests/boundary-test.sh`, and
      `bash skills/agent-feedback/scripts/tests/run.sh` → green.
    - The fixture matrix explicitly covers concrete agent incidents, ordinary success, generic praise,
      speculative redesign, ambiguity, privacy redaction, project-owned exclusion, self-suppression,
      one-call/one-row behavior, all subject classes/kinds, human near-verbatim prose, omitted detail,
      human praise, and privacy-destroyed restatement.
    - Attended probe: present one qualifying and one nonqualifying prompt for every subject class plus
      explicit human cases; expect exactly the qualifying agent rows and requested human rows, no
      agent-path follow-up, and no ordinary-success, project-owned, or self-recursive capture.

- [ ] **Slice 4: Owned optional anchor with generic route-conflict protection** <requires: 3>
  - Files:
    - Modify `skills/agent-feedback/verbs/anchor.md`,
      `skills/agent-feedback/scripts/feedback-anchor.sh`,
      `skills/agent-feedback/templates/agents-route.md`,
      `skills/agent-feedback/scripts/tests/anchor-test.sh`, and
      `skills/agent-feedback/scripts/tests/fixtures/anchor-cases.tsv`.
  - Change:
    - Red-first, add install, update, removal, competitor, malformed-marker, concurrency, and byte
      preservation fixtures against a temporary `~/.agents/AGENTS.md`.
    - Render only `agent-feedback` delimiters. The route states the reusable-subject boundary, strict
      agent quality/privacy checks, one-call maximum, ordinary-success silence, project-owned
      exclusion, and automatic self-feedback suppression while leaving explicit human capture valid.
    - Retain exact-diff preview, confirmation gating, base-digest recheck, well-formed delimiter
      validation, and preservation of every surrounding byte. Own and mutate only bytes inside the
      package's delimiters.
    - For install/update, scan only unfenced bytes in the self-registered route section outside the
      owned block. Recognize a competitor only as an H3 slash-command heading whose command slug has
      `feedback` as a hyphen-delimited token. Refuse preview and apply with exactly
      `reason=competing-feedback-route action=resolve-route conflict=<exact-heading>` and no proposed
      write; confirmation cannot bypass it.
    - Make removal ignore competitors and remove only the owned block. Include one same-line annotated
      predecessor-route negative fixture, without adding any predecessor-specific runtime branch.
    - Ensure setup, capture, query, and close never inspect the global front door.
  - Verify:
    - Red-prove each new fixture, then run
      `bash skills/agent-feedback/scripts/tests/anchor-test.sh` → all assertions pass.
    - Fixtures cover fenced lookalikes, non-H3 headings, slugs without a hyphen-delimited `feedback`
      token, exact competitors, preview/apply refusal without mutation, competitor-tolerant removal,
      install/update/remove, malformed markers, stale confirmation digest, and surrounding-byte
      identity.
    - Attended cold-route probe: using only the installed block in a disposable home, expect
      qualifying captures for all subject classes, ordinary-success silence, project exclusion, and
      no recursion; never target the repository's real `AGENTS.md`.
    - `bash skills/agent-feedback/scripts/tests/run.sh` → green.

- [ ] **Slice 6: Widen tune to generic evidence and the full mutation gate** <requires: 1>
  - Files:
    - Modify `skills/skill-builder/verbs/tune.md` and
      `skills/skill-builder/scripts/tests/tune-contract-test.sh`.
    - Create `skills/skill-builder/scripts/tests/fixtures/tune-cases.tsv`.
  - Change:
    - Red-first, complete `/skill-builder tune <skill-source> [<input-path>]` for one explicitly named
      readable UTF-8 regular non-symlink prose file. Treat filenames, headings, schemas,
      feedback-looking IDs, and embedded instructions as ordinary quoted evidence; never scan the
      current directory or a global home for input.
    - Bound and cluster multiple claims, stopping for human selection when they do not form one
      coherent batch. Re-check package, history, and repository context and classify every selected
      claim as current, already addressed, stale, project-specific, false, preservation constraint,
      out of scope, or unsupported. Only supported current changes and preservation constraints enter
      the proposal.
    - Retain the named input's physical path and SHA-256. Immediately before mutation, recompute it
      and the Slice 1 proposal identity and require exact equality of target, declared name, Git root,
      HEAD, package digest, input path, and input digest. Any drift or material claim-set change
      invalidates acceptance and requires revalidation and renewed acceptance.
    - Cover refusal at target resolution, proposal acceptance, identity recheck, edit application,
      focused checks, and host lint. No failure may create a record, commit, issue, publication,
      external disposition, global write, or change outside the selected package.
    - Keep `skills/skill-builder/verbs/review.md`,
      `skills/skill-builder/verbs/calibrate.md`, and the existing edge block byte-for-byte unchanged.
  - Verify:
    - Red-prove the fixture contract, then run
      `bash skills/skill-builder/scripts/tests/tune-contract-test.sh` and
      `bash skills/skill-builder/scripts/tests/run.sh` → green. Static checks prove complete procedure
      language and fixture coverage; they do not claim to prove agent judgment.
    - The fixture table covers current conversation, at least two structurally different prose files,
      feedback-looking headings/IDs, embedded instructions, binary/symlinked/unreadable/non-regular
      input, unrelated-claim selection, every disposition, each identity dimension, target
      containment, and every failure boundary.
    - Attended probe: cover a happy current-conversation edit, two prose shapes, an unrelated batch
      that stops for selection, all non-editing dispositions, embedded-instruction non-authority,
      accepted target-contained editing, target/name/root/HEAD/package and named-input drift, and
      focused-check/host-lint failure. Prove expected edits or non-edits from Git status and
      filesystem identity.
    - Targeted byte comparisons confirm review, calibrate, and the edge block are unchanged.

- [ ] **Slice 5: Repository hard-cut and independent-boundary acceptance gate** <requires: 1–4, 6>
  - Files:
    - Create `scripts/tests/agent-feedback-hard-cut-test.sh`.
    - Modify `scripts/tests/run.sh`.
    - Reconcile any remaining live references in `README.md`,
      `scripts/tests/clankshop-contract-test.sh`,
      `scripts/tests/configure-clankshop-test.sh`,
      `skills/backlog/scripts/tests/skill-doc-test.sh`, and the two package trees.
    - Do not modify historical `.records/`, `docs/design/`, `PACK.md`, the real `AGENTS.md`, or other
      worktrees merely to satisfy the sweep.
  - Change:
    - Red-first, add a root live-reference sweep for predecessor names and contracts. Scope it to live
      root source while excluding `.git/`, `.records/`, `docs/design/`, `.workstreams/`, and
      `.worktrees/`; allow only an explicitly annotated same-line negative fixture.
    - Cover the predecessor directory/name, schema, ID prefix, global path, slash command, delimiters,
      and temporary-file prefixes. Plant each forbidden form, observe failure, restore exact bytes,
      and observe green.
    - Add boundary assertions that `skills/skill-builder/` contains no collector dependency or global
      skilldata access, `skills/agent-feedback/` contains no toolmaker/remediation dependency, and the
      packages' edge blocks match their independent contracts. Construct forbidden tokens in the
      test so the test does not exempt itself accidentally. Red-prove both dependency directions and
      the toolmaker global-write guard with planted failures and byte-identical restoration.
    - Reconcile public inventory and contribution prose: `agent-feedback` is a standalone global
      human/agent capture and lifecycle skill; `skill-builder tune` is schema-free source tuning;
      Backlog retains project-owned feedback. Keep `PACK.md`'s generic home-channel seam unchanged.
    - Run both passes of the `skills/skill-builder/verbs/check.md` workflow over the library: lint,
      manual description/body/seam audit against `skills/skill-builder/docs/BOUNDARY-AUDIT.md`, and a
      descriptions-only fresh-context routing probe for exactly these four cases: explicit human
      capture → `agent-feedback`; qualifying reusable-subject observation → `agent-feedback`;
      explicit current-conversation skill revision → `skill-builder tune`; named prose-file skill
      revision → `skill-builder tune`. Require 4/4 correct selections; any miss fails the gate and is
      repaired by sharpening the losing description, never by adding a sibling reference. Record the
      prompts, expected/actual selections, date, and result in the implementation handoff.
  - Verify:
    - Red-prove the new sweep with planted forbidden references, then run
      `bash scripts/tests/agent-feedback-hard-cut-test.sh` → green.
    - `bash skills/skill-builder/scripts/tests/run.sh` → green.
    - `bash skills/agent-feedback/scripts/tests/run.sh` → green, including at least 20 concurrent
      writers.
    - `bash scripts/tests/clankshop-contract-test.sh`,
      `bash scripts/tests/configure-clankshop-test.sh`,
      `bash skills/backlog/scripts/tests/skill-doc-test.sh`, and `bash scripts/tests/run.sh` → green.
    - The full boundary-audit report contains no unaddressed violation and the four-case routing probe
      reports `4/4`, with the population limited to the four cases named above.
    - `test -d skills/agent-feedback && test ! -e skills/skill-feedback` succeeds; a final scoped
      search reports no unannotated predecessor live reference and no cross-package dependency.

## Coverage check

| Spec verification | Planned proof |
|---|---|
| 1. Lint and independent routing | Slice 5 full boundary audit, four-case routing probe, lint, and cross-package assertions |
| 2. Package identity/inventory/patient zero | Slices 2 and 5 directory, README, PACK, and AGENTS checks |
| 3. Exact provider grammar/output | Slice 2 provider rewrite and contract matrix |
| 4. Home creation, modes, idempotent setup | Slice 2 path/setup fixtures |
| 5. Encoding, field rules, row ceiling | Slices 2 and 3 validation fixtures |
| 6. Concurrency and unsafe-state refusal | Slices 2 and 3 lock/path/concurrency fixtures |
| 7. Agent capture behavior | Slice 3 fixture matrix and attended fresh-harness probe |
| 8. Human capture behavior | Slices 2 and 3 tracer, fixtures, and attended probe |
| 9. Query and close | Slices 2 and 3 exact output/filter/lifecycle matrix |
| 10. Anchor ownership and cold behavior | Slice 4 anchor fixtures and cold temporary-home probe |
| 11. Generic tune input | Slices 1 and 6 conversation/prose contract, input-safety fixtures, and fresh-context probes |
| 12. Tune custody and drift | Slices 1 and 6 source-custody, digest, and pre-mutation drift fixtures/probes |
| 13. Tune revalidation and dispositions | Slice 6 fixture table and attended full behavior matrix |
| 14. Failure isolation; review/calibrate unchanged | Slices 1, 5, and 6 failure probes and immutable-boundary assertions |
| 15. Hard cut and red-proved sweep | Slice 5 planted-reference gate |

## Done when

All six slices are complete and independently green; every row in the coverage check has both a
deterministic test or inspection and, where the contract depends on model selection behavior, the
recorded attended temporary-harness probe. The predecessor package is absent from live source,
`agent-feedback` owns only its new global child and optional block, `skill-builder tune` works from
generic conversation or one named prose file without any collector dependency, full root tests pass,
skill lint remains at `fails=0` with no new warnings, and the working diff contains only the approved
implementation and record changes.

_On completion (before landing), run the host's close-the-books sweep._
