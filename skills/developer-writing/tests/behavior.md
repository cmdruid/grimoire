# Behavioral cases for developer-writing

These maintainer-only cases forward-test observable editorial behavior. They aren't runtime
instructions, exact-output fixtures, or phrase-matching tests.

## Dense PR description

Give the skill a technically accurate PR description with a long scope table, a section titled
"What this PR deliberately does not claim," repeated verification caveats, and an exhaustive file
index.

Pass when the result preserves consequential changes, reasons, risks, and reviewer decisions while
substantially reducing structure, repetition, and proof-of-work. A shorter result that loses a
surprising behavior or tradeoff fails.

## Security design note

Give the skill a design note in which a security invariant, threat boundary, and explicit
out-of-scope behavior are necessary to the argument.

Pass when the result preserves those terms and the structure needed to evaluate the security claim.
Blindly replacing *invariant* or deleting limitations fails.

## Short procedure

Give the skill a short deployment procedure with prerequisites, commands, placeholders, expected
results, and one optional step.

Pass when the result keeps operational detail, conditions before actions, explained placeholders,
and a clear sequence. Compressing away a prerequisite or result needed to detect failure fails.

## Agent-executed implementation plan

Give the skill, by explicit request, an implementation plan with a fixed schema, dependency-ordered
slices, exact file paths, a repeated local constraint, verification commands and expected results,
checkboxes, and completion or resumption state.

Pass when the result improves only unprotected explanatory prose while every execution affordance
remains verbatim and in its original location. Replacing exact paths with representative links,
reordering slices around likely reader questions, removing or rewording a locally repeated
constraint, compressing verification details, or altering structured state fails.

**Run evidence (2026-08-30):** Fresh agents edited the same tenant-aware cache plan under a request
to make it less repetitive and more concise. The previous skill failed by removing all four local
constraints and all four resume-state fields, relocating checkbox structure, and weakening the done
condition. The first preservation revision still reworded or narrowed local constraints. After the
rule made protected control content verbatim-and-in-place, a fresh run preserved every protected
element; a blind evaluator found only permitted heading-capitalization edits and marked it PASS.

## Cross-cutting change

Give the skill a PR description in which a small shared-library edit changes several otherwise
unrelated commands.

Pass when the result explains the shared reason near the affected behavior. Hiding the rationale in
a generic scope or exclusions section fails.

## Pairwise reader check

Compare a source draft with the edited result without showing the evaluator the skill instructions.
Ask: "After one pass, can a maintainer explain what changed, why it changed, what it affects, and any
important limitation?"

Prefer the edited result only when it improves that answer without introducing unsupported claims.
