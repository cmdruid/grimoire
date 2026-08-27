---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Inspector automatic refinement proposals — Spec

This specification supersedes the narrow decision in
`docs/design/2026-08-24-inspector-adequacy-and-review-close.md` that every failing review must stop
before refinement begins. It preserves independent review, propose-before-apply, status custody,
and full re-review after an accepted fold.

## Problem

Inspector currently treats every transition from document review to refinement as a separate user
decision. After a `needs-rework` verdict, it reports actionable findings, offers `/inspector
refine`, and stops. A later request enters the refinement machine, verifies and classifies those
same findings, and only then presents concrete amendments.

That intermediate stop has no useful decision value for specs and plans. Their supported review
findings already have defined in-place amendment locations, and the user consistently wants to see
Inspector's disposition and recommended amendments before deciding what to apply. Requiring a
second invocation hides useful judgment behind a predictable confirmation and adds a turn without
protecting the artifact: refinement still has a later proposal stop before any write.

The same shortcut is not sound for every kind. Founding documents and ADRs may expose unresolved
product decisions; roadmap and runbook findings may belong upstream; host-added kinds have unknown
custody; and implementation review must never become code remediation. Inspector therefore needs a
kind-sensitive review continuation rather than a global automatic fold.

## Goal

For specs and plans, a review with any material finding proceeds directly into Inspector's existing
refinement verification and proposal flow. The human sees the verdict, findings, Inspector's
dispositions, and concrete recommended amendments without first asking to refine. Inspector still
stops before editing, and an accepted proposal applies in place and receives a full queued
re-review.

All other kinds retain an explicit, inspectable continuation policy. Clean reviews retain their
existing acceptance/publication close, standalone refinement remains available, and no review path
silently edits an artifact.

## Approach

**Chosen: make review continuation a kind policy and reuse the existing refinement machine.** Each
effective kind doctrine selects one of three continuations:

- `automatic-proposal` — material findings enter refinement immediately;
- `offered` — review stops and offers refinement explicitly;
- `unavailable` — review emits its verdict and findings with no refinement path.

Bundled `spec` and `plan` select `automatic-proposal`. Bundled `founding`, `adr`, `roadmap`, and
`runbook` select `offered`. Bundled `implementation` selects `unavailable`. A host-added document
kind with no declaration defaults conservatively to `offered`; it may opt into either document
continuation. Host policy cannot create an implementation refinement path.

The continuation changes when Inspector shows its refinement judgment, not when it writes. Review
still completes first and reports its deterministic verdict. Refinement still verifies every
finding as a claim, classifies the whole batch, asks only material questions, prepares concrete
amendments, and stops for package confirmation. The artifact is unchanged through that stop.

**Rejected: automatically apply review findings.** Review findings remain claims until refinement
verifies them, and the proposed amendment package still requires human authorization.

**Rejected: add a combined verb.** A second public verb would duplicate routing and leave ordinary
`review` with the same friction. Kind-sensitive continuation belongs behind the existing review
entrypoint.

**Rejected: enable automatic proposals for every document.** Several kinds routinely surface
decisions or wrong-owner work that cannot be translated directly into an amendment package. Those
kinds keep the explicit boundary until usage supports a narrower change.

**Rejected: merge the review and refinement judgments.** Review determines defects and verdict;
refinement independently verifies, disposes, and translates those findings. Keeping both phases
makes disagreement visible and preserves the thrash brake.

## Mechanism

### Kind continuation policy

Every bundled kind file gains a `## Review continuation` section containing exactly one policy
line:

```text
refinement-after-review: automatic-proposal | offered | unavailable
```

The value is package doctrine read by the agent, not a runtime configuration parser. Kind doctrine
owns only the continuation selection; the shared verbs own verdict mapping, status custody,
confirmation, proposal/apply behavior, and the meaning of each transition. This is a narrow
exception to the current rule that kind files do not own stop boundaries, not permission for a kind
to replace the shared state machine.

The effective workspace kind file remains a complete replacement for the bundled file. A readable
project copy wins; a missing copy uses the bundle; an invalid incumbent remains an error. When the
effective file omits `## Review continuation`, resolve the default by detected kind regardless of
whether that file is bundled or a workspace incumbent: `spec` and `plan` use
`automatic-proposal`; other document kinds use `offered`; `implementation` uses `unavailable`.
Consequently, project copies deployed before this policy existed gain deterministic behavior
without setup, migration, or an overwrite.

Resolution rules are:

1. `automatic-proposal` and `offered` are legal for document kinds.
2. `unavailable` is legal for any kind whose owner does not permit in-place refinement.
3. An explicit recognized declaration overrides the omission default for a document kind.
4. A host-added document kind has no reserved stem and therefore defaults to `offered` when it
   omits the section.
5. An unrecognized value is an invalid effective policy; ask or refuse rather than guessing.
6. The reserved implementation kind remains `unavailable` regardless of host files. Existing rules
   that prevent host policy from replacing its discriminator or creating code refinement continue
   to apply.

The bundled matrix is:

| Kind | Continuation | Reason |
|---|---|---|
| `spec` | `automatic-proposal` | Findings have named in-place sections; the human benefits from seeing the proposed contract change. |
| `plan` | `automatic-proposal` | Findings have named slices; the human benefits from seeing the proposed sequencing change. |
| `founding` | `offered` | A gap can require further design conversation rather than a direct fold. |
| `adr` | `offered` | A finding can change or split the recorded decision. |
| `roadmap` | `offered` | A finding can belong to an upstream spec or a not-yet-written plan. |
| `runbook` | `offered` | A finding can be a missing upstream plan rather than a legal conductor edit. |
| `implementation` | `unavailable` | Review never remediates code. |

### Review transition

Review keeps its current soundness, groundedness, adequacy, materiality, and exact verdict mapping.
After reporting the verdict and findings, it closes according to the effective continuation:

| Verdict | `automatic-proposal` | `offered` | `unavailable` |
|---|---|---|---|
| `approve` | Existing document accept/publish close. | Existing document accept/publish close. | Existing document accept/publish close. |
| `approve-with-changes` | Enter refinement with the recommended findings. | Offer accept/publish as-is or explicit refinement; stop. | Offer document accept/publish as-is; no refinement. |
| `needs-rework` | Enter refinement with all material findings. | Offer explicit refinement; stop. | Verdict only; no refinement. |

The table applies to document kinds. Implementation review remains verdict-only for every verdict;
its lifecycle never uses document acceptance or publication. Continuation policy selects access to
refinement and does not independently remove a document's existing passing-review gate.

Automatic continuation is one invocation and one assistant turn until the refinement machine
reaches one of its existing stops. It is not a second review and does not suppress the review
report. Inspector names the artifact and verdict, then:

1. passes the complete in-context findings and already-resolved artifact/kind into refinement;
2. skips only refinement's standalone input resolver because those inputs are already known;
3. verifies and classifies every finding against the artifact and `HEAD`;
4. stops on unresolved questions or park acknowledgments when required; otherwise
5. presents the complete amendment proposal and stops for confirmation.

The continuation queues full re-review after apply for both `needs-rework` and
`approve-with-changes`. The human may clear that intent with the existing explicit no-re-review
tokens. Answering refinement questions still does not confirm the later package.

### Confirmation and publication

At the proposal stop, bare package acceptance means apply the recommended package, leave the
artifact draft, and run the queued full review. It never means publish the pre-amendment artifact.
Existing adjustment, rejection, and explicit no-re-review parsing remains in force.

For an `approve-with-changes` review only, the human may instead explicitly accept the passing
verdict without the recommendations using `publish as-is` or an unambiguous equivalent. Inspector
then applies no amendment and publishes exactly the reviewed artifact. Specs receive
`status: published`; plans receive `status: published` and `stage: approved`. A bare `approved`,
`apply`, or `go ahead` at the proposal stop accepts the proposal, not publication as-is.

`needs-rework` never offers or accepts publication. Review and automatic continuation write no
status or stage before proposal confirmation. Applying a proposal keeps `status: draft`, drops
`stage: approved` when present, and never appends Review history.

### Empty and non-amendable packages

Automatic continuation preserves refinement's no-empty-proposal rule:

- unresolved `ask` or `park` rows stop with the existing targeted questions or ownership path;
- a package containing only parked work leaves the artifact draft and explains the blocking
  upstream decision or owner;
- when an `approve-with-changes` batch leaves no recommended amendment after verification, Inspector
  offers acceptance/publication of the reviewed artifact rather than showing an empty table;
- when a `needs-rework` batch leaves no must-fix or recommended amendment because every finding was
  resolved or pushed back, Inspector immediately runs one full review of the unchanged artifact
  with those same-session dispositions in context. Extend the shared thrash brake for this path: if
  the same location + assertion returns after either `resolved` or `push-back`, classify it `ask` on
  its first return and stop instead of entering another automatic cycle. The existing brake for a
  prior `resolved` or `rejected` finding remains in force outside this immediate path.

No branch manufactures an amendment solely to justify the automatic continuation.

### Standalone refinement and explicit kinds

`/inspector refine` remains a public verb for human-pasted findings, council results, findings
files, open Review-history items, and prior in-session reviews. Standalone refinement retains its
current proposal and confirmation stops and queues re-review only when dispatched from review or
explicitly requested.

For `offered` kinds, `needs-rework` offers refinement and `approve-with-changes` offers the explicit
choice between publication as-is and refinement. For `unavailable` kinds, review and standalone
refine both refuse amendment while an otherwise passing document keeps its acceptance/publication
gate. Host-added document kinds may opt into `automatic-proposal`, but they cannot create a
code-refine path or override shared confirmation, status, verdict, or apply rules.

### Package alignment

The Inspector router, review verb, and refine verb must describe one state machine:

```text
clean document review → accept/publish
material review + automatic kind → verify/classify → questions? → proposal → confirm
  → apply + queued full review
material review + offered kind → explicit refine offer → stop
unavailable document + approve/approve-with-changes → accept/publish as-is
unavailable document + needs-rework → verdict only
implementation → verdict only
```

Update the Inspector router and live responsibility-spine design to say that effective kind policy
selects the continuation while shared verbs own all transition semantics, confirmation, verdict,
status, and apply behavior. In the responsibility spine, revise both the paragraph that currently
assigns every stop boundary to the verb machine and the unconditional “failing review stops”
statement. The earlier adequacy/review-close spec remains historical evidence; this specification
explicitly supersedes only its same-turn-refinement rejection and affected close behavior.

## Verification

The Inspector test harness must exercise behavior, not only the presence of prose:

- `spec` and `plan` with `needs-rework` transition directly to refinement classification without a
  refine-request turn;
- `spec` and `plan` with `approve-with-changes` transition directly to a proposal;
- clean `spec` and `plan` reviews retain the existing accept/publish stop;
- bare proposal acceptance applies and queues a full re-review;
- explicit `publish as-is` is accepted only after `approve-with-changes` and performs no amendment;
- `founding`, `adr`, `roadmap`, and `runbook` retain the explicit refine offer;
- `implementation` remains verdict-only and refuses refinement;
- workspace-incumbent `spec` and `plan` files that predate and omit the continuation section resolve
  to `automatic-proposal` without a setup call, migration, or file write;
- a host-added kind defaults to `offered`, can opt into `automatic-proposal`, and cannot replace the
  implementation boundary;
- questions and parks stop before a proposal; a proposal stops before any write;
- an immediately recurring finding classified `resolved` or `push-back` becomes `ask` on its first
  return, so an empty verified package cannot enter a second automatic cycle;
- unavailable documents retain the specified passing publication gate while failed unavailable
  documents and every implementation verdict remain verdict-only;
- the Inspector router and responsibility spine contain no stale claim that kind policy cannot
  select a stop boundary;
- status/stage custody and the no-Review-history rule remain unchanged.

For the new continuation checks, prove the tests red by temporarily changing a copied fixture's
policy or transition and confirming the expected assertion fails before restoring it. Run:

```sh
skills/inspector/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
```

Then run `skills/inspector/scripts/ground-check.sh` against every edited document and re-read the
load-bearing Inspector prose. A clean path check is not evidence that the state machines agree.

## Slices

### I1 — Kind-sensitive automatic refinement proposal

- **Change:** Add the continuation policy to all bundled kinds; update the shared router,
  `review`, and `refine` machines; cover the transition matrix, confirmation semantics, empty
  packages, incumbent omission defaults, status custody, and implementation boundary; align the
  router and live responsibility spine around the kind-selection/shared-semantics ownership split.
- **Paths:** `skills/inspector/SKILL.md`, `skills/inspector/verbs/review.md`,
  `skills/inspector/verbs/refine.md`, `skills/inspector/kinds/{founding,spec,adr,plan,roadmap,runbook,implementation}.md`,
  `skills/inspector/scripts/tests/{review-close-test,refine-test}.sh`,
  `docs/design/2026-08-21-architect-contractor-inspector.md`.
- **Verify:** `skills/inspector/scripts/tests/run.sh &&
  skills/skill-builder/scripts/skills-lint.sh`.
