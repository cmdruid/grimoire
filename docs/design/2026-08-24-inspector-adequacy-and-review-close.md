---
doctype: specs
status: published
created: 2026-08-24
updated: 2026-08-24
tags: [spec]
---

# Inspector adequacy + review-close + project doctrine — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Dependencies (land first):

- `docs/design/2026-08-24-clankshop-faceless-pack.md` — skills own their
  project lifecycle; there is no assembler.
- `docs/design/2026-08-23-workspace-kinds.md` — Inspector's canonical
  project surface is `inspector/doctrine/`.

Lineage amended now, not during implementation:
`docs/design/2026-08-21-architect-contractor-inspector.md`.

This spec owns Inspector only. Its slices do not edit Workspace,
another skill, or another spec. The sole packaging edit is I4's exact
Inspector roster span in the root faceless manifest.

## Problem

Inspector has the right broad shape—independent review followed by a
separate propose/apply fold—but four gaps make the review loop less
reliable than its contract suggests:

1. Review has no explicit adequacy/materiality gate. A reviewer can
   stop after the first true finding even when other must-fix defects
   remain.
2. Passing-review acceptance parsing already exists, but a failing
   review stops without the matching explicit refine offer, and refine
   still performs proposal ceremony when verification leaves no
   material amendment.
3. Completed implementation is not a review kind, so code conformance
   cannot use the same grounded two-axis judgment.
4. Project review policy has no explicit owner-controlled setup. A
   missing project file falls back to the bundle, but there is no safe
   operation that deploys all bundled kinds for customization.

The fix must preserve the stop boundaries: review never silently folds,
refine never silently re-reviews, and code review never publishes a
document.

## Goal

After this feature:

- Review evaluates all material axes and continues until no additional
  must-fix finding is supported by the evidence. There is no numeric
  finding cap.
- Every reported finding passes a materiality test: it is concrete,
  attributable to the artifact/change, affects correctness,
  followability, safety, scope, or verification, and has an actionable
  remedy. Unsupported speculation and style preference are omitted.
- Review verdict mapping is deterministic:
  - any must-fix finding → `needs-rework`;
  - no must-fix, at least one recommended non-blocking change →
    `approve-with-changes`;
  - no material findings → `approve`.
- A review turn ends with one explicit next-turn offer. Passing document
  reviews offer acceptance/publish; failing document reviews offer
  refine; implementation reviews stop with the verdict and never
  publish or enter refine.
- `refine` classifies the complete findings batch before proposing. If
  no material amendment remains, it says so and stops without an empty
  proposal/confirmation ceremony.
- `implementation` is the seventh bundled review kind. It judges a
  completed change against governing design/plan, surrounding code, and
  relevant gates. Its verdict is conversation-only.
- `/inspector setup [<root>]` deploys all bundled kinds absent-only to:

  ```text
  <agent-workspace>/inspector/doctrine/<kind>.md
  ```

- Inspector creates and tends only its own namespace. Normal
  review/refine never create project files. A present project kind wins;
  absent falls back to the bundled kind.
- There is no old-path read, overlay merge, project hook, runtime parser,
  automatic migration, or sibling-owned setup.
- Inspector and library lint are green.

## Approach

**Chosen: calibrate the existing verb machine, add one review target,
and make project doctrine an explicit Inspector-owned durable surface.**

The shared review/refine mechanics remain package law. Kind files define
discriminators, axes, groundedness extras, and legal refine locations;
they cannot override verdict vocabulary, status custody, or stop/confirm
semantics.

**Rejected: a maximum number of findings.** A cap optimizes output size
at the expense of adequacy. Rank findings and keep prose compact instead.

**Rejected: same-turn automatic refine.** A failing verdict is an
independent-review stop. The next user turn may accept the offered
refine route.

**Rejected: same-turn automatic publish.** Passing review still waits
for explicit acceptance.

**Rejected: code review through document status.** Implementation
review produces no record mutation and has no publish gate.

**Rejected: a project hook for review policy.** Kind doctrine is the
complete policy file; one present project copy wins. No composition
engine is needed.

**Rejected: shared or kind-first doctrine.** Inspector's policy is owned
at `inspector/doctrine/`, consistent with the workspace grammar.

## Mechanism

### Entry and kind resolution

The router remains a thin dispatcher:

| Invocation | Does |
|---|---|
| `/inspector review <artifact-or-change>` | Detect kind, run two-axis review plus adequacy, emit conversation verdict and one close offer. |
| `/inspector refine [findings] <artifact>` | Verify/classify complete findings, propose, apply only after confirmation, leave draft. |
| `/inspector setup [<root>]` | Deploy bundled kind doctrine absent-only into Inspector's namespace. |
| bare `/inspector` | Ask which verb; do not default. |

Bundled kinds: founding, spec, adr, plan, roadmap, runbook, and
implementation. Document detection keeps founding before spec.
Implementation detection requires a completed change target—a named
diff/range/worktree/commit plus governing design when available—and
must not steal a document matching one of the six artifact kinds.

After kind detection, resolve:

```text
<agent-workspace>/inspector/doctrine/<kind>.md
```

Present regular file → use the complete project policy. Absent → bundled
`skills/inspector/kinds/<kind>.md`. No merge. Incompatible/unreadable
entry is an error, not silent fallback. Normal review/refine never mkdir.

### Review adequacy

Review keeps soundness and groundedness as the two primary axes. Add a
shared adequacy pass after both axes and before verdict selection:

1. Enumerate every required axis and groundedness extra from the
   effective kind file.
2. For each, record internally `clear`, `finding`, or `not-applicable`
   with evidence. Do not expose a bureaucratic checklist when clear.
3. Trace every central claim or changed behavior through its governing
   mechanism and verification.
4. Re-scan interactions among findings: fixing one must not leave a
   contradictory requirement elsewhere.
5. Ask the inverse required by the kind (for specs, which mechanism
   would not exist from scratch; for implementation, which passing test
   could still encode the wrong behavior).
6. Stop only when another pass produces no new supported must-fix
   finding.

This is exhaustive over material review axes, not exhaustive over every
sentence or stylistic preference.

### Materiality

A finding is reportable only when all are true:

- **Specific:** names a location or behavior.
- **Grounded:** supported by the artifact/change and relevant source,
  test, doctrine, or reproducible scenario.
- **Consequential:** affects correctness, implementability,
  followability, safety, ownership, scope, or verification.
- **Actionable:** gives a concrete remedy within the artifact's owner or
  identifies the exact owner to which it must be pushed back.
- **Non-duplicate:** adds a distinct defect rather than restating one.

Severity:

- must-fix: the artifact/change cannot safely proceed;
- recommended change: material improvement that does not block;
- omit: nit, unsupported concern, taste, or already-covered symptom.

Confidence notes qualify uncertain evidence; uncertainty is never
presented as fact. An unresolved question that blocks classification is
an `ask`, not a speculative must-fix.

### Verdict and report

Use exactly:

```text
needs-rework
approve-with-changes
approve
```

Report in this order:

1. one actionable situation sentence;
2. verdict code;
3. must-fix findings ranked by severity;
4. recommended changes;
5. confidence notes;
6. one next-turn offer when the target is a document.

Each finding is location → defect → consequence → concrete fix. Do not
write status/stage or Review history in the verdict turn.

### Review close

Document target:

- `needs-rework` → “If you want, I can fold these findings with
  `/inspector refine`.” Stop.
- passing → “If you accept, this session will publish `<path>`.” Stop.

The next user utterance is parsed by the verb that made the offer:

- clear acceptance of a passing verdict → publish the reviewed document
  (`status: published`; job artifacts also `stage: approved`);
- clear request to refine after a failing verdict → enter refine using
  the in-context findings;
- rejection → no write;
- unclear → ask once.

An utterance may compose acceptance with further requested work; perform
the gate write first, then honor the remainder. Founding stays draft.

Implementation target: emit verdict and stop. No publish offer, status
write, refine offer, or automatic remediation.

### Refine close and empty package

Refine preserves propose-then-apply:

```text
verify/classify all → questions if needed → proposal → stop → confirm → apply → stop/optional named re-review
```

Before proposing, remove rows verified as already resolved, push back
wrong-owner findings, and omit unsupported/nit rows. If no `keep` or
taken optional row remains, state that there is nothing material to
fold and stop. Do not present an empty table or ask for confirmation.

Apply amends the named artifact in place, writes `status: draft`, updates
the date, and drops `stage: approved`. It never appends Review history.
Named re-review in the confirmation runs the full review procedure after
apply; otherwise it merely offers review.

### Implementation kind

`skills/inspector/kinds/implementation.md` defines:

**Discriminator**

- explicit completed implementation/code-change target;
- not a document matching another kind;
- governing spec/plan/runbook resolved when named or discoverable from
  the change context.

**Soundness**

- behavior matches governing design and acceptance criteria;
- control/data flow is correct at boundaries and failure paths;
- change is cohesive and contains no compatibility substrate forbidden
  by the design;
- tests exercise the real behavior, including required red-proofs;
- no unrelated mutation or unresolved conflict marker remains.

**Groundedness**

- inspect the full diff and load-bearing surrounding code;
- run relevant targeted and host gates or explain a concrete inability;
- verify claimed deletions/absence over the correct population;
- inspect call sites/configuration affected by changed interfaces;
- ask which passing test could still encode the wrong implementation.

Verdict mapping is the shared exact mapping. Refine legal locations are
none: implementation review never amends code.

### `/inspector setup`

Resolve and canonicalize an existing project root, then resolve
`agent-workspace:` (default `.dev`). Reject empty, `.`, absolute, or
root-escaping declarations.

Explicit setup may create only:

```text
<agent-workspace>/inspector/doctrine/
```

Refuse any symlink or non-directory in the workspace, `inspector`, or
`doctrine` parent chain; recheck immediately before each mkdir/copy.
The deploy script resolves bundled `kinds/` relative to its own package
and never scans the front door.

For every bundled `kinds/*.md` (enumerated, not hardcoded):

1. destination absent → copy byte-for-byte;
2. existing regular file → preserve incumbent;
3. symlink, directory, or other incompatible destination → report the
   collision and exit nonzero; never follow a symlink to read or write;
4. partial success is rerunnable; copied files remain incumbents;
5. host-added extra kind files remain untouched.

Setup creates no hooks, scripts, templates, records, door registration,
or sibling namespace. Existing project kind files are never refreshed
automatically; upgrade is a human diff.

### Status and ownership

Review writes no status in its verdict turn. Accepted passing document
review publishes. Refine apply returns the artifact to draft.
Implementation review never writes status.

This spec exclusively owns:

- Inspector review/refine machine changes;
- implementation kind;
- Inspector doctrine resolver and setup;
- Inspector tests and package prose;
- Inspector's exact inventory row in the root README.

The already-amended workspace and lineage specs are inputs, not slice
paths. No implementation step edits them.

## Verification

**Adequacy/materiality**

- fixtures with two independent must-fix defects report both;
- mutation stops after the first finding and makes the fixture fail;
- nit-only fixture approves without findings;
- non-blocking material fixture maps to `approve-with-changes`;
- contradictory requirements and false-green guard tests are caught;
- no test asserts a numeric finding cap.

**Review close**

- failing document review writes nothing and offers refine for the next
  turn only;
- passing review writes nothing until a later clear acceptance;
- acceptance publishes exactly the reviewed artifact;
- reject/unclear paths write nothing;
- implementation review has no publish/refine transition.

**Refine**

- complete-batch classification precedes proposal;
- unresolved ask holds the package;
- empty material package skips proposal/confirmation;
- apply returns status to draft and does not append Review history;
- named re-review runs full review after apply.

**Implementation**

- exact mapping fixtures for must-fix, recommended-only, and clean
  changes;
- governing-design mismatch, false-green test, missed call site, and
  forbidden compatibility substrate are detected;
- all fixtures prove no code/status mutation.

**Setup and paths**

- fresh default and declared setup create only
  `inspector/doctrine/*.md` with exact bundled bytes;
- incumbents/extras survive; new bundled kind deploys on rerun;
- parent and destination collision/symlink fixtures refuse safely;
- partial deployment completes on rerun;
- review resolves project copy then bundled fallback;
- zero kind-first Inspector paths, dual reads, hook dependency, or
  sibling setup dependency;
- mutation permits a parent symlink and makes the escape fixture fail;
- the root README Inspector row names implementation review, accepted
  document publication, and Inspector-owned doctrine setup; it does not
  claim that Inspector never writes `published`.

Inspector harness and library lint green. Fresh-agent followability read
must be able to execute each verb using only router + selected verb/kind
files.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| I1 | Add shared adequacy/materiality and exact verdict mapping | review fixtures + mutation test | `skills/inspector/{SKILL.md,verbs/review.md,scripts/tests/review-test.sh,scripts/tests/run.sh}` |
| I2 | Add the failing-review next-turn refine offer and empty-refine-package behavior; retain the existing passing-accept parser | close/refine state-machine fixtures | `skills/inspector/{verbs/review.md,verbs/refine.md,scripts/tests/review-close-test.sh,scripts/tests/refine-test.sh}` |
| I3 | Add implementation discriminator and kind policy | implementation fixtures + gates | `skills/inspector/{SKILL.md,verbs/review.md,kinds/implementation.md,scripts/tests/implementation-test.sh}` |
| I4 | Add symlink-safe absent-only Inspector doctrine setup around the already-landed owner-first resolver; update Inspector's faceless-pack roster and README inventory spans | deployment harness + path/documentation gates | `skills/inspector/{SKILL.md,verbs/setup.md,scripts/kinds-deploy.sh,scripts/tests/setup-test.sh}`, `PACK.md` (Inspector roster span only), `README.md` (Inspector row only) |

I1 before I2 and I3. I4 may land after I1 and must include the final
seven-kind bundle. Portfolio integration follows Delegate to serialize
the final root-runbook span. One landing after I4.

## Out of scope

- Workspace grammar or generic path migration.
- Pack installation, project assembly, or another skill's setup.
- Automatic code remediation after implementation review.
- Same-turn auto-refine or auto-publish.
- Numeric finding caps.
- Project hooks, policy overlay merging, compatibility reads, or
  migration of old alpha files.
