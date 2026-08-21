---
doctype: plans
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [plan]
---

# auditor field calibration — Implementation Plan

Field use of `auditor` during the completed DUCAT UNIT Bridge audit exposed
four portable workflow gaps: brownfield rubric/output discovery, an
adversarial-verification step that is stated but not executable, no dedicated
final re-audit contract, and no audit-command authorization taxonomy. This
plan changes the skill library only. DUCAT product remediation, its final
scorecard, and its completed plans remain separate and untouched.

Spec: accepted 2026-08-18 skill-review findings from the DUCAT UNIT Bridge
field audit. Prior art:
`docs/design/2026-08-17-auditor-review.md` and
`docs/design/2026-08-17-auditor-review-remediation-plan.md`.

## STALE-PREMISE NOTICE — recorded 2026-08-18 by `stream/feat`

_Recorded here because Slice 0 requires it: "Record any refutation in this plan before
implementation; do not implement a stale premise." This notice adds nothing else and changes
no other line._

**What moved.** This plan was written against root `e49acbc`. Since then `stream/feat` shipped
**front-door path homes** to `main` @ `ce7e758` (spec:
`docs/design/2026-08-18-agent-doctrine-home.md`, `status: current`). It rewrote
`skills/auditor/SKILL.md` and `skills/auditor/BOOTSTRAP.md`, among others.

**Three premises are now false and must be re-decided before Slice 1:**

1. **"A new standalone host still uses `docs/audit/` … a workshop still uses
   `.handbook/test/workflows/audit/`"** (Global Constraints → *Portable default*). Both halves
   are now wrong. The rubric home **resolves**: declared `agent-doctrine:` (front-door
   `AGENTS.md` then `CLAUDE.md`), else `<agent-records>/doctrine`. `<agent-doctrine>/test/
   workflows/audit/` is the resolved home; `docs/audit/` survives as **legacy detection only**
   — detected so deployed rubrics keep working, never created fresh.

2. **The `audit-rubric:` front-door declaration** (Global Constraints → *Explicit brownfield
   contract*; File Map → `DOCTRINE.md`). This is now a **fourth home for an artifact that
   already has one**, and `DOCTRINE.md`'s bar for adding a front-door variable (the value must
   truly vary per host; readers must consume it) is harder to clear when `agent-doctrine:`
   already provides exactly the per-host override the brownfield case needs. The open question
   is no longer "how do we spell `audit-rubric:`" but **"is the brownfield contract simply
   *declare `agent-doctrine:`*?"** Decide that explicitly; do not add the variable by default.

3. **The `DOCTRINE.md` File Map row assumes blank space.** That doc now carries a
   *Front-door variables* section defining three homes plus a *Doctrine-touching skills*
   section (which-home test, two-level access, incumbent-wins standup, sanctioned resolution
   literals). Edits there are amendments to live content, not additions.

**A gate in Slice 0 will now FALSE-PASS — do not trust it.** Its verify block runs
`git diff --name-only main...stream/feat -- skills/auditor` and expects empty. It *is* empty —
**because the overlap already merged into `main`.** That check compares branches while the
change now sits in the base. Re-ground against `main` @ `ce7e758` directly (`git log -- skills/auditor`),
not against sibling-branch diffs.

**Also affected:** `skills/auditor/scripts/auditor-context.sh` (File Map: "new read-only fact
resolver for workshop/standalone/brownfield homes") — home resolution is now standard doctrine
with a canonical resolver, so this script's scope should shrink to whatever remains genuinely
auditor-specific.

**Believed unaffected** (orthogonal to home resolution, premises appear intact): Slice 2
adversarial verification, Slice 3 final re-audit contract, Slice 4 command-authorization
taxonomy. Re-verify rather than assume.

**Patient-zero is intact:** the shipped work added no declaration to grimoire's own
`AGENTS.md` and ran `auditor` against no real host.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Separation invariant:** modify only Grimoire skill/doctrine/discoverability
  files named below. Do not edit, copy, close, or supersede any DUCAT plan,
  tracker, audit log, product file, or workstream handoff.
- **Portable default:** a new standalone host still uses `docs/audit/` for its
  rubric and `<agent-records>/reports/` for pass reports. A workshop still uses
  `.handbook/test/workflows/audit/`. Brownfield compatibility must not silently
  migrate history or create a parallel output store.
- **Explicit brownfield contract:** add one optional, repo-relative
  `audit-rubric:` front-door declaration. Do not scan the repository for
  plausible `GUIDE.md` files. An existing guide may explicitly own its
  established report and finding destinations; absent that declaration, the
  portable agent-records contract wins.
- **Approval invariant:** the audit skill classifies planned commands but does
  not grant authority. Host/harness approval policy remains authoritative.
  Audit authorization never implies wallet, funding, deployment, database,
  service, public-chain, or other external mutation authority.
- **Verification can be inline:** mandatory adversarial verification must not
  depend on subagents or a second skill. Parallel readers remain an optional
  acceleration only.
- **Patient-zero:** do not run `auditor setup` against Grimoire or add
  `audit-rubric:` to Grimoire's real `AGENTS.md`. Exercise setup and resolution
  only in throwaway fixtures.
- **Plan-grounding exception:** before implementation, `ground-check` is
  expected to report only the three files this plan explicitly creates and the
  intentionally absent patient-zero example `docs/audit/`. Any other
  unresolved reference is a blocker.
- **Coexisting work:** at planning root `e49acbc`, `stream/app`, `stream/feat`,
  and `stream/grok` do not touch `skills/auditor`; recheck before build and
  stop on overlap.
- **Scope:** no generic rule-file scoring changes unless Task 0 demonstrates a
  direct dependency. No pack-version bump; the member set and typed edges do
  not change.

## File Map

| Path | Responsibility |
|---|---|
| `skills/auditor/SKILL.md` | Entry probe, modes, pass/re-audit loop, delivery precedence, command-boundary rules, done-when |
| `skills/auditor/BOOTSTRAP.md` | Portable setup doctrine, GUIDE skeleton, pass/re-audit output contracts |
| `skills/auditor/templates/reports.md` | Auditor report record shell and required audit sections |
| `skills/auditor/scripts/auditor-context.sh` | New read-only fact resolver for workshop/standalone/brownfield homes |
| `skills/auditor/scripts/tests/auditor-context-test.sh` | New throwaway-fixture red/green contract |
| `skills/auditor/scripts/tests/auditor-prose-contract-test.sh` | New mechanical contract for pass, re-audit, and execution-boundary requirements |
| `skills/skill-builder/docs/DOCTRINE.md` | Front-door-variable rationale and `audit-rubric:` contract |
| `README.md` | Discover the final re-audit capability without expanding routing scope |
| `skills/clankshop/PACK.md` | Keep the auditor helper summary aligned if its capability sentence changes |

## Requirement Coverage

| Accepted finding | Slice |
|---|---:|
| Established host rubric/output contract is overridden | 1 |
| Adversarial verification is optional/underspecified in the executable loop | 2 |
| No post-remediation final re-audit contract | 3 |
| No command side-effect/data-egress authorization taxonomy | 4 |
| Cross-file discoverability and regression closure | 5 |

## Slices

- [ ] **Slice 0: Re-ground every field finding against current HEAD**
  <requires: —>

  - Files: read only all paths in the File Map plus
    `docs/design/2026-08-17-auditor-review.md`,
    `docs/design/2026-08-17-auditor-review-remediation-plan.md`, and recent
    `git log -- skills/auditor`.
  - Change: none. Reproduce the four gaps against the current driver and
    blueprint; inventory existing rubric-home, agent-records, report-shape,
    adversarial, mode, and approval wording. Recheck sibling branch path
    overlap. Record any refutation in this plan before implementation; do not
    implement a stale premise.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    git status --short
    git rev-parse HEAD
    rg -n "audit-rubric|re-audit|adversarial|approval|read-only|live action|reports record" \
      skills/auditor skills/skill-builder/docs/DOCTRINE.md
    git diff --name-only main...stream/app -- skills/auditor
    git diff --name-only main...stream/feat -- skills/auditor
    git diff --name-only main...stream/grok -- skills/auditor
    ```

    Expected: clean tree; all four premises either reproduced or explicitly
    amended; no sibling path overlap. Current counts are remeasured rather than
    copied from this plan.

- [ ] **Slice 1: Resolve brownfield rubric and output ownership (tracer)**
  <requires: 0>

  - Files: create `skills/auditor/scripts/auditor-context.sh` and
    `skills/auditor/scripts/tests/auditor-context-test.sh`; modify
    `skills/auditor/SKILL.md`, `skills/auditor/BOOTSTRAP.md`, and
    `skills/skill-builder/docs/DOCTRINE.md`.
  - Change:
    - add the optional front-door line `audit-rubric: <repo-relative-dir>`;
      values that are absolute, empty, or escape through `..` fail closed;
    - implement a Bash-3.2-compatible, read-only resolver with invocation
      `auditor-context.sh <root> [--rubric <repo-relative-dir>]` and precedence:
      stamped workshop home; explicit `--rubric`; first line-start
      `audit-rubric:` in `AGENTS.md` then `CLAUDE.md`; existing default
      `docs/audit/`; else `missing`;
    - print facts only: `mode=`, `rubric_home=`, `guide=`, `metrics=`,
      `metrics_fingerprint=`, and `agent_records=`. Use `git hash-object` for an
      existing metrics file and `missing` otherwise; make no recommendation in
      the script;
    - replace “confirmed once” chat-only persistence with the declaration
      above. `setup` writes the line only for a confirmed non-default
      standalone home and only in a throwaway/consuming host;
    - add `Pass outputs` to the GUIDE skeleton. Default is an audit-tagged
      `<agent-records>/reports/` record. A brownfield guide may explicitly name
      its incumbent report and finding homes; when present, follow them and do
      not also mint the default record. This is compatibility, not migration.
  - Red first: add the fixture test before the resolver. It must fail because
    the command is absent, then pass after implementation.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    shellcheck skills/auditor/scripts/auditor-context.sh \
      skills/auditor/scripts/tests/auditor-context-test.sh
    bash skills/auditor/scripts/tests/auditor-context-test.sh
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: fixtures prove default standalone, configured brownfield,
    workshop precedence, explicit override, missing rubric, invalid absolute
    path, traversal rejection, `agent-records:` and legacy `records-root:`.
    The brownfield fixture writes no `.records/` tree.

- [ ] **Slice 2: Put adversarial verification inside every audit pass**
  <requires: 1>

  - Files: modify `skills/auditor/SKILL.md`,
    `skills/auditor/BOOTSTRAP.md`, and
    `skills/auditor/templates/reports.md`; create
    `skills/auditor/scripts/tests/auditor-prose-contract-test.sh`.
  - Change:
    - insert `Verify` between `Score` and `Record` in the executable audit loop
      and GUIDE skeleton;
    - challenge every provisional 4/5 against its lower anchor and each rule's
      known false positives;
    - require every candidate finding to reproduce a mechanism or be retained
      as an unverified observation, never scheduled work;
    - require coverage/absence claims to show a red-capable proof or explain
      concretely why the exercised fixture reaches the failing arm;
    - record the challenges and refutations under `Adversarial verification` in
      the pass report. Inline execution is the baseline; parallel verification
      is optional and does not change the evidence contract.
  - Red first: the prose-contract test asserts the new loop step and report
    section; it fails on the current package before the prose/template change.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    shellcheck skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    bash skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: both SKILL and GUIDE skeleton contain the ordered Verify step;
    the report template owns adversarial evidence; no instruction requires a
    subagent or unnamed heavier workflow.

- [ ] **Slice 3: Add a comparable final re-audit mode** <requires: 2>

  - Files: modify `skills/auditor/SKILL.md`,
    `skills/auditor/BOOTSTRAP.md`,
    `skills/auditor/templates/reports.md`, and the prose-contract test.
  - Change:
    - add `/auditor re-audit <baseline-report> [<target>]` as an overlay on the
      normal pass, not a second audit system;
    - regular pass reports record exact project/target revision, rubric
      revision, metrics command, and the resolver's metrics fingerprint;
    - re-audit requires the baseline report, reuses the same target population
      and rubric, and emits: baseline/current identities, metric comparability,
      per-dimension before/after/delta, prior-finding closure ledger,
      new/reopened dispositions, gate matrix, and final acceptance decision;
    - a changed population, rubric, or metrics recipe is reported as
      non-comparable unless the report supplies an explicit mapping. Never
      manufacture a numeric delta;
    - green gates prove acceptance boundaries but do not independently raise a
      quality score.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    bash skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    rg -n "re-audit|metrics_fingerprint|Before/after|closure ledger|non-comparable|acceptance decision" \
      skills/auditor/SKILL.md skills/auditor/BOOTSTRAP.md \
      skills/auditor/templates/reports.md
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: all six required re-audit outputs resolve to one named owner;
    missing baseline or incompatible metrics fails closed without a false
    delta; ordinary pass mode remains complete.

- [ ] **Slice 4: Classify command execution and authorization boundaries**
  <requires: 2; parallel-eligible with 3>

  - Files: modify `skills/auditor/SKILL.md`,
    `skills/auditor/BOOTSTRAP.md`,
    `skills/auditor/templates/reports.md`, and the prose-contract test.
  - Change: before executing gates, inventory each command into exactly one
    class and record its authorization/result:
    1. local non-mutating — execute normally;
    2. disposable local mutation — execute only inside its declared fixture,
       with cleanup ownership;
    3. external read or live-derived data egress — require applicable explicit
       approval; “read-only” alone is not authorization;
    4. external/state-changing action — separately authorized and never
       implied by an audit request.
    Commands crossing more than one class use the strictest class. When
    authorization or prepared-machine inputs are absent, record the exact
    blocker and retain the safe evidence boundary; do not retry indirectly,
    synthesize inputs, start/restart a profile, or perform a partial live
    action. Add a required `Live-action ledger`, including an explicit zero
    when nothing crossed an external boundary.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    bash skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    rg -n "local non-mutating|disposable local|live-derived data egress|external/state-changing|strictest class|Live-action ledger" \
      skills/auditor/SKILL.md skills/auditor/BOOTSTRAP.md \
      skills/auditor/templates/reports.md
    skills/skill-builder/scripts/skills-lint.sh .
    ```

    Expected: all four classes, strictest-class rule, exact-blocker behavior,
    and zero-action ledger are present; no sentence grants approval.

- [ ] **Slice 5: Integrate, route, and independently re-review**
  <requires: 1, 2, 3, 4>

  - Files: modify `README.md` and `skills/clankshop/PACK.md` only if their
    existing auditor summaries need the `re-audit` capability; amend earlier
    slice files only to resolve verified integration defects.
  - Change:
    - keep the frontmatter description under 1,024 characters (prefer 750),
      preserving `/auditor`, `setup`, `metrics`, `check`, target scoring, and
      adding re-audit without routing on generic “review” or “audit a skill”;
    - run both fixture suites, package lint, install discovery, and an
      independent skill review against the current skill-review brief;
    - verify every accepted finding maps to executable prose plus a red-capable
      contract and that no DUCAT file changed.
  - Verify:

    ```bash
    cd /Users/cscott/Repos/grimoire
    shellcheck skills/auditor/scripts/auditor-context.sh \
      skills/auditor/scripts/tests/auditor-context-test.sh \
      skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    bash skills/auditor/scripts/tests/auditor-context-test.sh
    bash skills/auditor/scripts/tests/auditor-prose-contract-test.sh
    skills/skill-builder/scripts/skills-lint.sh .
    ./install.sh --list
    git diff --check
    ```

    Expected: fixture suites pass; lint reports `fails=0`; `auditor` remains
    installable/discoverable; the independent review is `approve` or only
    contains separately dispositioned nice-to-haves; diff is limited to the
    declared Grimoire paths.

## Done When

- A configured brownfield host resolves its established rubric and declared
  outputs without a repository scan, chat-only memory, migration, or duplicate
  agent-records report; new standalone and workshop defaults are unchanged.
- Every audit pass performs and records adversarial verification of high scores
  and candidate findings, inline-capable and red-proof aware.
- `re-audit` produces a comparable before/after decision only when revisions,
  population, rubric, and metric identity support it; otherwise it says
  non-comparable.
- Every planned command is classified before execution, external read/data
  egress is not treated as automatically approval-free, and the report carries
  an exact live-action ledger.
- All tests/lint/install/diff gates pass, an independent skill review accepts
  the package, no active sibling work overlaps, and no DUCAT file or plan was
  changed.

_On completion, run Grimoire's close-the-books sweep before landing._
