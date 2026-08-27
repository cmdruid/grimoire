# `refine` · simplify a spec or plan

An optional minimum-sufficiency pass. It removes, consolidates, or simplifies unnecessary content
without changing the artifact's goal or losing required behavior. It accepts only specs and plans,
always proposes before editing, and always runs a full review after an accepted change.

Review findings are not refinement input. A request to correct findings belongs to `revise`;
explain that distinction and stop rather than switching verbs automatically.

## Invocation

```text
/inspector refine [<spec-or-plan>]
```

Resolve a named readable artifact first. With no path, use only the last named spec or plan in the
current session; otherwise ask. Never scan the current directory or infer a target from Git state.
Kind-detect once through SKILL.md. Founding documents, ADRs, roadmaps, runbooks, host-added kinds,
and implementation are unsupported.

Do not begin while this session has unresolved must-fix review findings or a pending revision
question or proposal for the artifact. Correction must be completed, rejected, or explicitly
abandoned first. The kind's `revision-after-review:` value controls correction only; it does not
control explicit refinement.

## Procedure

1. **Load the contract.** Read the complete artifact and its effective kind file. Use the kind
   file's `## Revision legal locations` section only to learn which parts of the document may be
   edited. Ignore its instructions for correcting findings, adding missing coverage, or classifying
   findings; those belong to `revise`.

   For a plan, resolve and read the governing source named by the plan: a published spec or the
   applicable approved roadmap phase. A missing or ambiguous source is an `ask` stop before any
   proposal.
2. **Ground the artifact.** Use the same posture as document review: run this package's
   `scripts/ground-check.sh`, then re-read the load-bearing sources and signatures. A clean path
   check is not proof that the prose is still correct.
3. **Find supported simplifications.** Look for duplication, repeated verification, speculative
   machinery not required by a goal or accepted decision, one-use abstractions with no independent
   invariant, substrate-shaped mechanisms, repeated prose that adds no instruction, and mechanisms
   or slices that can be combined without losing a distinct responsibility or failure boundary.
   Refinement is not a copyedit; style-only shortening is out of scope.
4. **Protect required content.** Propose a change only when:
   - a spec still retains its goal, accepted decisions, constraints, required behavior, ownership
     boundaries, decision-preserving rationale, and verification obligations; or
   - a plan still retains every in-scope requirement from its governing source, its end-to-end
     tracer, blocking order, independently testable slices, and a real verification gate for every
     surviving slice.

   Never add a requirement, change the goal, settle a new decision, or move work to another
   artifact. If whether something is required is unclear, ask one focused question and stop. An
   answer settles the uncertainty but never confirms an edit package.
5. **No-op.** If no supported simplification remains, say the artifact is already
   minimum-sufficient under the available evidence. Stop without a proposal, write, status change,
   or automatic review.
6. **Propose; do not edit.** Show only the exact section or slice to remove, consolidate, or
   simplify; the replacement when needed; and why the change preserves the contract. Do not list
   retained content, assign classifications, calculate a compression score, or create another
   artifact. Then stop. No invocation token skips this proposal boundary.
7. **Parse confirmation.** Rejection writes nothing. An adjustment produces an updated proposal and
   stops again. Any clear acceptance applies the shown package. `Apply only`, `without re-review`,
   and equivalent wording may accept the package but cannot cancel the mandatory review.
8. **Apply in place.** Amend the same file only after confirmation. Preserve surviving headings and
   stable slice ids, remove obsolete cross-references, keep `status: draft`, and drop
   `stage: approved` when present. Do not mint a successor or create `## Review history`.
9. **Review.** Immediately follow the complete `verbs/review.md` procedure on the amended artifact.
   This is a full two-axis review, not a delta check. Any correction then follows review's ordinary
   transition to `revise`; refinement adds no restoration or oscillation protocol.

## Done when

The target was a grounded spec or plan, every proposed change preserved its required contract, no
write occurred before confirmation, and every accepted change completed a full review. A refusal,
question, rejection, or supported no-op stopped without changing the artifact.
