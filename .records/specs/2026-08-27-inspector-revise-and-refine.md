---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Inspector revise and refine verb split — Spec

This specification makes a hard-cut distinction between correcting an artifact and simplifying
one. It supersedes the verb names and continuation-policy key in
`.records/specs/2026-08-26-inspector-automatic-refinement-proposals.md` while preserving that
specification's review, confirmation, status-custody, and re-review behavior under the new
`revise` name.

## Problem

Inspector's current `refine` verb verifies review findings, classifies them, proposes amendments,
and folds an accepted package into the reviewed document. That operation is corrective: its input
is a findings set and its success condition is that supported defects are addressed. `Revise` is a
more accurate name for it.

The same workflow creates an accumulation problem. A spec or plan may receive several rounds of
review and corrective amendment. Each round is biased toward adding a missing constraint,
exception, mechanism, slice, gate, or explanation. Review protects soundness and groundedness, but
neither review nor the findings-driven fold asks whether the surviving artifact is still the
minimum sufficient contract. After enough cycles, an individually defensible series of additions
can produce an artifact that is redundant, substrate-shaped, speculative, and expensive to
implement or follow.

Inspector has no explicit operation whose objective is simplification. Humans can ask an agent to
"refine" a spec today, but that phrase routes to the findings-fold machine, requires findings or a
recent review, and does not ask whether a simpler artifact would still cover everything required.
The overloaded name therefore obscures both jobs and leaves over-engineering untreated.

## Goal

Make `revise` the findings-driven corrective verb without changing its established safety or
review-continuation behavior. Reclaim `refine` as an explicit, optional simplification pass for
specs and plans that removes unnecessary complexity while preserving every unique requirement,
ownership boundary, safety constraint, and verification obligation.

The change is a hard cut. Current package doctrine, project-facing policy names, tests, and live
catalog/design surfaces use the new vocabulary only. There is no public verb alias, legacy policy
fallback, migration verb, compatibility shim, or dual-read period.

## Approach

**Chosen: split correction from simplification.** Inspector exposes three distinct judgments:

| Verb | Primary input | Objective | Invocation |
|---|---|---|---|
| `review` | document or completed implementation | judge soundness and groundedness | explicit |
| `revise` | supported document findings | correct defects without changing the artifact's goal | explicit or review continuation |
| `refine` | spec or plan | produce the minimum sufficient artifact | explicit only |

`Revise` retains the current proposal-before-apply machine. `Refine` uses the same human write
boundary but a different analysis: it searches for deletions, consolidations, and simpler
equivalent mechanisms, then checks that the surviving artifact still covers its contract.

**Rejected: add simplification as a mode of the findings-fold verb.** A flag or conversational
mode would preserve the ambiguity. Correction begins from reviewer claims; simplification begins
from the whole artifact and asks what can disappear. They need separate routing, inputs, and
done-when conditions.

**Rejected: automatically refine after review or revision.** Automatic simplification would make
the review loop oscillate, surprise users with deletions, and turn every ordinary correction into
another mandatory judgment. `Refine` is an optional, explicit intervention when the artifact has
become heavy or when the owner wants a minimum-sufficiency pass.

**Rejected: use word, section, slice, or finding counts as the success metric.** Those measures are
easy to game and do not identify the mechanism's target class. A shorter artifact can still be
more complex, and a longer artifact can carry necessary evidence. Refinement succeeds through
traceable deletion or consolidation with preserved obligations, not a numeric compression target.

**Rejected: support every document kind initially.** Founding documents and ADRs encode product
decisions; roadmaps and runbooks coordinate ownership across artifacts; host-added kinds have
unknown preservation rules. The first version supports only detected `spec` and `plan` kinds.

## Mechanism

### Hard-cut rename

The current findings-fold behavior moves intact from `refine` to `revise`:

- the current `skills/inspector/verbs/refine.md` findings-fold file moves to the sibling revise
  verb file before the new refinement verb is added;
- `skills/inspector/scripts/tests/refine-test.sh` becomes `revise-test.sh`, retaining and renaming
  the existing correction-state fixtures;
- every live router, prompt, diagram, status rule, confirmation parser, setup statement, edge, and
  test calls the findings fold `revise`;
- every kind heading `## Refine legal locations` becomes `## Revision legal locations`;
- `refinement-after-review:` becomes `revision-after-review:` with the same exact values and
  omission defaults:

  ```text
  revision-after-review: automatic-proposal | offered | unavailable
  ```

- review's `automatic-proposal` and `offered` branches enter or offer `revise`, never `refine`;
- standalone `/inspector revise [<findings>] [<artifact>]` retains the present resolver,
  classification, questions, empty-package, proposal, confirmation, apply, status, thrash-brake,
  and optional re-review cancellation semantics.

The cut has no compatibility substrate:

1. `/inspector refine` never means "fold findings," even when findings are supplied.
2. `/inspector revise` is the only public findings-fold invocation.
3. `revision-after-review:` is the only recognized continuation declaration.
4. An effective workspace kind containing `refinement-after-review:` is invalid doctrine, not an
   omission. Name the file and require the owner to replace the key; do not apply the detected-kind
   omission default.
5. A file containing both old and new declarations is invalid.
6. Setup remains absent-only and never refreshes an incumbent. No `migrate` verb is added.
7. Published historical specs, plans, and superseded design records remain unchanged as historical
   evidence. The live skill package, responsibility spine, and catalog surfaces use only the new
   vocabulary.

### Review and revision flow

Review keeps its deterministic verdict mapping and kind-sensitive continuation. Only the name of
the correction transition changes:

```text
clean document review → accept/publish
material review + automatic kind → revise verify/classify → questions? → proposal → confirm
  → apply + queued full review
material review + offered kind → explicit revise offer → stop
unavailable document + approve/approve-with-changes → accept/publish as-is
unavailable document + needs-rework → verdict only
implementation → verdict only
```

Every automatic or offered review-origin revision carries queued full re-review exactly as the
current refinement machine does. A standalone revision queues re-review only when review dispatched
it or the human names re-review. Applying a revision keeps `status: draft`, drops
`stage: approved`, never mints a successor or Review history, and never writes `published`.

At a clean spec or plan review's acceptance stop, an explicit request to `refine` does not accept
or publish the artifact. It enters the optional refinement flow on that named artifact. A pending
revision question or proposal has precedence: `refine` cannot bypass unresolved must-fix findings
or reinterpret revision confirmation.

### Optional refinement

The new invocation is:

```text
/inspector refine [<spec-or-plan>]
```

A named readable artifact must kind-detect as `spec` or `plan`. With no path, use only the last
named spec or plan in the current session; otherwise ask. Never scan the current directory or guess
from Git state. Other document kinds and implementation are unsupported. Findings, a findings
file, or a request to correct review findings belong to `revise`, not `refine`.

Do not refine an artifact while must-fix review findings or a revision proposal remain unresolved.
Correction must be completed, rejected, or explicitly abandoned first. The
`revision-after-review:` selector controls correction only; it never enables or disables an
explicit refinement of a spec or plan.

Read the complete artifact and ground it using Inspector's ordinary review posture. For a plan,
also resolve and read its governing published spec or applicable accepted roadmap phase. If that
source is missing or ambiguous, ask and stop before proposing changes.

Look for duplicated requirements, repeated verification, speculative machinery not required by a
goal or accepted decision, one-use abstractions with no independent invariant, substrate-shaped
mechanisms, repeated prose that adds no instruction, and mechanisms or slices that can be combined
without losing a distinct responsibility or failure boundary.

Only propose a change when all required content remains covered:

- a spec retains its goal, accepted decisions, constraints, required behavior, ownership
  boundaries, rationale needed to keep decisions closed, and verification obligations;
- a plan retains every in-scope requirement from its governing source, its end-to-end tracer,
  blocking order, independently testable slices, and a real verification gate for every surviving
  slice.

Refinement never adds a requirement, changes the artifact's goal, settles a new decision, or moves
work to another artifact. If Inspector cannot determine whether content is required, ask one
focused question and stop. Content outside those limits is simply omitted from the proposal.
Refinement is not a copyedit; style-only shortening is out of scope.

Present only the supported edits: the exact section or slice to remove, consolidate, or simplify,
the replacement when needed, and why the change preserves the contract. Do not inventory retained
content, assign classifications, calculate a compression score, or create a second artifact. If
there is no supported simplification, say so and stop without a proposal, write, status change, or
automatic review.

Every non-empty proposal stops for confirmation. Rejection writes nothing; adjustments produce an
updated proposal and stop again. Acceptance applies the package to the same file, preserves stable
headings and slice ids that survive, removes obsolete cross-references, leaves `status: draft`, and
drops `stage: approved` when present. It writes no Review history and mints no successor.

Every accepted refinement immediately runs a full two-axis review. `Apply only`, `without
re-review`, and equivalent wording may accept the package but cannot cancel that review. Any
resulting correction follows the ordinary review-to-`revise` proposal boundary; refinement needs
no additional restoration or oscillation protocol.

`Refine` does not add new kind policy. It reads the existing `Revision legal locations` section
only to learn which parts of the document it may edit. It ignores that section's instructions for
correcting findings, such as adding missing coverage or classifying findings, because those belong
to `revise`. The shared `verbs/refine.md` owns the restricted spec/plan analysis, proposal boundary,
status custody, and mandatory re-review.

The live responsibility spine at
`docs/design/2026-08-21-architect-contractor-inspector.md` must describe review, revision, and
optional refinement as three jobs. `README.md` and any current pack seam that describes Inspector's
verbs must align. Historical design/spec/plan files keep their original vocabulary.

## Verification

The test harness must prove the split and its small safety boundary:

- `run.sh` invokes distinct `revise-test.sh` and `refine-test.sh` suites;
- review continuations and standalone findings folds use `revise` with the current behavior intact;
- the old verb meaning and `refinement-after-review:` selector are invalid, while omission keeps
  the existing kind defaults;
- refinement accepts only a named or last-in-session spec or plan, refuses findings and tells the
  user to use `revise`, and waits until unresolved correction is settled;
- plan refinement loads its governing source and stops when that source is missing or ambiguous;
- questions and proposals write nothing, and a no-op produces no proposal ceremony;
- spec fixtures retain unique requirements and verification obligations while permitting supported
  duplicate or speculative-content removal;
- plan fixtures retain governing requirements, the tracer, blocking order, and per-slice gates
  while permitting a safe slice consolidation;
- accepted refinement returns the same artifact to draft, drops plan approval, and always runs a
  full review even when the confirmation tries to cancel it;
- setup remains absent-only, and the router, responsibility spine, README, and current pack seams
  use the new vocabulary.

Red-prove each new behavioral guard by planting one defect at a time, requiring its assertion to
fail, restoring the fixture, and confirming byte identity before the final green run.

Run:

```sh
skills/inspector/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
skills/inspector/scripts/ground-check.sh \
  "$(git rev-parse --show-toplevel)" \
  .records/specs/2026-08-27-inspector-revise-and-refine.md
```

Then re-read the complete router, review/revise/refine verbs, all seven kind files, the live
responsibility spine, and current catalog entries. A clean grep is not evidence that revision and
refinement preserve distinct state machines.
