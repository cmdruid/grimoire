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
