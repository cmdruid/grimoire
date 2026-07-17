# Testing -- audit rule
> Do the tests prove it is safe to ship?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `COV`.

## Why it matters

A test suite serves two distinct roles, and both must be present for the suite to
be meaningful:

1. **Unit tests** (`<language: test markers>`, run without a network or external
   service) -- fast, in-process assertions over pure logic: domain computations,
   data encoding, registry loading, config parsing, math utilities. These run in CI
   and catch regressions within seconds.

2. **Integration / E2E tests** (the application run against scripted input, with
   artifacts read back and asserted) -- the only layer that catches end-to-end
   regressions (a rendering artifact, a stale output, an integration contract
   broken) that no unit test can see.

The two layers are complementary and both are required for a high score.

**If the project has a core purity invariant** (e.g., a generator is a pure
function of its inputs and must produce identical output regardless of scheduling
or build configuration), that invariant MUST be tested. A test that runs the same
computation twice from the same inputs and compares outputs is the minimum. A
boundary / seam test (two adjacent computed regions agree on their shared edge) is
the second level. Without invariant tests, any refactor of the core is unverified.

**Do not claim "untested."** Before filing a COV finding for an untested surface,
search for a test. The test may be in a different file from the code it exercises.
Refute a "no test" claim by searching for `<language: test markers>` across source
and inspecting the results.

## Scoring anchors (1-5)

- 5 -- Unit tests cover all pure-logic modules in the blast-radius directories. Any
  core purity invariant is explicitly asserted by a dedicated test (same inputs ->
  same outputs; adjacent regions agree). At least one integration / E2E test
  exercises the main application flow and produces an artifact. The CI gate is green.
- 4 -- The purity invariant is tested; unit coverage of core modules is solid; the
  integration harness exists but exercises only a subset of features. One or two
  pure-logic functions lack a direct unit test.
- 3 -- The purity invariant test exists; unit tests cover core encoding and loading;
  but a major processing layer (e.g., parsing, persistence, presentation) has no unit
  tests and no integration scenario exercises it. Test count is growing but coverage
  is uneven.
- 2 -- No explicit purity-invariant test. Unit tests exist for a few isolated
  utilities but miss the blast-radius modules. The integration harness exists but no
  scenario exercises core correctness.
- 1 -- Minimal or no tests. No purity-invariant assertion. No integration scenario.
  A core refactor cannot be validated without running the application and inspecting
  the output manually.

## Decision logic

1. Run the test-count recipe (see Anti-patterns). Note total count and per-module
   breakdown.
2. Verify the purity-invariant test exists (if applicable to this project):
   - Find the test that runs the same computation twice from the same inputs and
     asserts output equality. Confirm it is non-vacuous (the output was actually
     produced, not empty).
   - Find a boundary / seam test if one is called for (two adjacent computed regions
     agree on their shared edge).
3. Check the integration harness: are scenario / fixture files present? Does the CI
   gate invoke at least one? If the harness exists but is never run in CI, it is a
   COV finding (coverage, not just presence).
4. For each blast-radius module, list the public functions and check whether any
   major surface has zero test coverage. Use judgment: a large serialization format
   with no round-trip test is a finding; a rendering helper with no unit test is
   acceptable if the integration scenario covers it.
5. Refute "untested" claims: search for `<language: test markers>` and check whether
   the function is exercised indirectly (e.g., a core function called by a higher-
   level test even though it has no dedicated test of its own).
6. Score against the anchors; use the lower anchor when two fit.

## Anti-patterns (greppable smells)

```<shell>
<language: count total tests (the primary denominator).>
<language: show per-module test distribution (spot which modules have tests).>
<language: check for the purity-invariant test -- search for determinism/fingerprint/seam test names.>
<language: list integration / E2E scenario or fixture files.>
<language: list public functions in blast-radius modules -- cross-reference with test calls.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Test count includes integration tests and doc-tests.** A `<language: test marker>`
  search counts in-module unit tests only. The integration E2E harness and any
  doc-test framework are separate and add to the total. Do not claim "only N tests"
  from the marker search alone.
- **A function is "untested" because it is called in a test of its caller.** Core
  functions are often exercised transitively by higher-level tests. Run the test
  suite and observe the call path before filing "no test for X."
- **Integration files that do not run in CI.** The integration harness is only
  meaningful if it runs. Check the CI gate for the invocation. If a scenario file
  exists but is not invoked, it is a COV finding -- but a minor one if the scenario
  can be run manually with the documented command.
- **Test-only helper blocks that do not contain test functions.** Helper functions
  and fixtures inside a test-only module do not increment the test count but are not
  gaps. Do not flag them.
- **Tests that assert existence, not just correctness.** An assertion that ensures a
  test is non-vacuous (e.g., "a real structure was generated") counts as correct test
  design, not as "only testing for existence."

## How to quantify

<language: count unit tests (primary metric); count test-bearing files (coverage
breadth); count total source files (denominator for coverage breadth ratio);
note purity-invariant test: present/absent; count integration scenario files;
note CI gate: green/red. Report as:
`unit tests: N; test-bearing files: F of T; invariant test: present/absent;
scenario files: S; CI gate: green/red`.
The invariant test is a binary gate: absent = score cap at 2 regardless of test count.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
