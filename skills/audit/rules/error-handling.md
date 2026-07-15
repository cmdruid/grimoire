# Error Handling -- audit rule
> Are errors typed, guarded, and fail-closed?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `ERR`.

## Why it matters

Unhandled errors produce the worst class of failure: silent data corruption or a
crash that neither the user nor the developer can diagnose. When a core layer is a
pure function of its inputs, an unchecked-error escape hatch on a derived value
turns a programming error into a crash that is indistinguishable from a defect in
non-debug builds and impossible to reproduce deterministically. A "missing file ->
log + default" contract is a common graceful-degradation pattern; an unchecked
call in that path breaks the contract and bricks startup on any missing asset,
exactly the fault the contract was designed to prevent.

This rule owns *unchecked-error escape discipline* and the shaping of error types.
The readability rule explicitly defers to this rule for unchecked-error discussion.
The paired type-safety rule (`type-safety.md`) owns the cast / unsafe side; a
typed-error-return vs. crash question always lands here.

## Scoring anchors (1-5)

- 5 -- Errors are typed with domain error types at module boundaries.
  `<language: unchecked-error escape hatches>` appear only in test code or
  where a statically-proven invariant makes the value infallible AND a comment
  says so. No reachable panic/abort/fatal on any production path. The graceful
  "log + default" contract is consistently upheld wherever it is declared.
- 4 -- One or two unchecked calls exist on provably-infallible values (e.g., a
  literal parsed at compile time) with a justifying comment. No panics on
  reachable paths outside test code.
- 3 -- Several bare unchecked-error calls exist on I/O or parse results without
  justification; at least one reachable panic or fatal is present in a non-test
  path. Error types at module boundaries are inconsistent.
- 2 -- Pervasive unchecked calls on I/O or parse results in production code. At
  least one reachable panic in a core domain layer. Error propagation is mostly by
  early-return generic message with no domain types.
- 1 -- Failure modes are not designed: unchecked calls throughout, panics on
  ordinary inputs (bad config, missing file), no typed error discipline, and no
  clear distinction between "this should never happen" and "this can happen".

## Decision logic

1. Run the smell greps (see Anti-patterns). Collect every unchecked-error escape
   hatch, panic, and abort site.
2. For each unchecked call, categorize the value being unwrapped:
   - Test code or a test fixture -> **acceptable, skip**.
   - A value statically known to be safe AND annotated with a comment ->
     **acceptable, note as justified**.
   - An I/O result, a parse of runtime input, or a lookup with a non-literal key
     and no comment -> **finding candidate**.
3. For each panic / fatal / unreachable hit, ask: can this line be reached in a
   correct production run?
   - Unreachable by construction (exhaustive dispatch after a full enumeration, a
     postcondition that a type system invariant makes impossible) + comment ->
     **acceptable**.
   - Any path reachable from a runtime input (a bad config file, a missing asset,
     an unexpected network response) -> **finding**.
4. Check module boundaries: do functions that can fail return a typed error, or do
   they use generic messages in ways that lose error context?
5. Score against the anchors. Use the lower anchor when two fit.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: list all unchecked-error escape-hatch sites (e.g., unwrap/expect/force-unwrap) -- test and non-test; triage manually.>
<language: count unchecked-error sites (total denominator for scoring).>
<language: list panic/abort/fatal/unreachable calls in production code.>
<language: find functions at module boundaries returning generic string errors instead of domain types.>
<language: find loader/IO functions that call unchecked escape hatches inside -- breaks the log+default contract.>
<language: find unimplemented/not-yet-implemented markers that may be hit in normal operation.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Unchecked calls in test code.** Test code is allowed to panic; panicking on a
  bad fixture is the correct behavior for a test. Do not flag unchecked calls or
  panics inside test-only modules.
- **Statically-proven infallibility with a comment.** An unchecked call on a
  literal or on a value produced by the code in the same expression is acceptable
  when a nearby comment confirms the invariant.
- **`unreachable` on proven-exhaustive arms.** In a dispatch on an enum where all
  variants are covered, an `unreachable` in a catch-all arm introduced as a
  refactoring guard is acceptable if a comment explains it. The smell is an
  `unreachable` in the default arm of a dispatch that will actually be reached
  when a new variant is added -- that is both an ERR and a TYPE finding.
- **Panic on programmer error during initialization.** A panic on "this required
  component was not registered" during startup initialization is a programmer
  error, not a runtime error. It is acceptable if the precondition is documented
  and the panic fires only during development.
- **Precondition guards on internal contracts.** Panics that guard against a
  framework-internal contract violation (not a user input) are edge-case guards.
  Track them: if a code path outside the guarded context can ever violate the
  precondition, they become ERR findings.

## How to quantify

<language: count unchecked-error escape hatches (all; test and non-test combined);
count reachable panic/abort/unreachable sites (manual triage required);
count module-boundary functions returning generic string errors instead of domain types.
Report as: `unchecked calls: N; reachable panics: P (manual); generic-error fns: S`.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
