# Technical Debt -- audit rule
> Is transitional code removed, or fenced and dated -- not quietly permanent?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `DEBT`.

## Why it matters

Technical debt takes two forms:

1. **Debt markers** (`TODO`, `FIXME`, `HACK`, `XXX`) that name a known deficiency
   but carry no owner, date, or linked backlog item. A bare `// TODO: fix this`
   committed without context becomes invisible maintenance debt: the original
   author's intent is lost, the fix is never scheduled, and the comment
   accumulates alongside feature work until no one knows which TODOs are still
   relevant.
2. **Dead or transitional code** -- commented-out blocks, dead-code suppressors
   on non-test code, and scaffolding that was never removed after a refactor. Dead
   code inflates the cognitive load of every file that contains it and silently
   diverges from the live path.

The invariant this dimension enforces: **transitional code is either removed
(the default) or fenced AND dated (the exception).** A fenced exception requires
a comment that names the owner or issue and a target date or milestone for
removal. A bare marker with none of these is a finding.

**Boundary with TYPE:** `DEBT` owns transitional and dead code, including
commented-out blocks and bare `TODO` markers. The `TYPE` dimension owns unsafe /
type-escape blocks -- those carry their own annotation discipline (a safety comment).
An unsafe block without a safety comment is a TYPE finding, not a DEBT finding.
A `// TODO: make this safe` on the same block is both.

## Scoring anchors (1-5)

- 5 -- Zero bare `TODO`/`FIXME`/`HACK`/`XXX` markers in source. Any transitional
  comment that must remain is dated, owned, and linked to a backlog item. No
  dead-code suppressors outside test or generated code. No large commented-out
  blocks.
- 4 -- One or two dated `TODO` comments with an owner or backlog link; no bare
  markers. No dead-code suppressors on non-test, non-generated code.
- 3 -- A handful of bare `TODO` markers (3-7) with no date or owner; at least
  one dead-code suppressor on production code that should be triaged.
- 2 -- Ten or more bare debt markers, some clearly stale (the code they reference
  has since changed). One or more large commented-out blocks.
  Dead-code suppressors used as a routine suppressor rather than an exception.
- 1 -- Pervasive unowned markers; the codebase has a "TODO graveyard" where
  markers have accumulated across multiple features. Dead code sections exceed
  the live code in some files.

## Decision logic

1. Run the marker grep (see Anti-patterns). If the output is empty, the codebase
   has no unresolved markers -- confirm with a broader search before scoring 5.
2. For each marker hit, check:
   - Does the comment include an owner, a date, or a link to a backlog or bug
     item? -> **acceptable; note as fenced**.
   - Is the marker bare (e.g., `// TODO: refactor this`) with no context? ->
     **finding candidate**.
3. Grep for dead-code suppressors in production (non-test) code. Each hit needs
   a comment explaining why the code is retained (e.g., "used by upcoming
   feature X"). A bare suppressor is a finding.
4. Scan the five largest files (from the god-files grep) for commented-out code
   blocks (three or more consecutive comment lines that look like disabled code).
   Each block should be removed or given a dated fence.
5. Score against the anchors. If the marker count is zero, assign 5 provisionally
   and note it in the calibrated examples.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: find all TODO/FIXME/HACK/XXX markers in source -- an empty result means zero markers.>
<language: count debt markers (the denominator for scoring).>
<language: find dead-code suppressors in non-test code.>
<language: find commented-out code blocks: three or more consecutive comment lines that look like disabled code.>
<language: find unimplemented/not-yet-implemented markers outside test code -- these are DEBT AND ERR findings.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Unimplemented markers in test code.** An unimplemented stub in a test-only
  block is a test scaffold placeholder, not a production debt marker. Do not flag.
- **`TODO` in doc comments.** A `TODO:` in a documentation comment is a
  doc-quality issue (DOC dimension), not a DEBT marker. Review any doc-comment
  hits as DOC candidates instead.
- **Dead-code suppressors on items exported for external use.** A public function
  that is unused within the package but exported for integration tests, a bench
  harness, or a feature-gated inspector path may legitimately carry a suppressor.
  Check whether the item is used from tests or other feature contexts before filing.
- **Markers in auto-generated code.** If any source files are generated (e.g., by
  a build script or codegen tool), markers in them are not actionable. Check the
  build configuration for codegen before filing.
- **Comment blocks that are documentation, not dead code.** Long comment blocks that
  explain an algorithm (e.g., a noise function derivation) are documentation.
  The heuristic grep for commented code will miss most of these; read the context
  before flagging.

## How to quantify

<language: count debt markers (primary metric); count dead-code suppressors excluding
test code; count unimplemented/not-yet-implemented markers outside tests.
Report as: `debt markers: N; dead-code suppressors: D; runtime stubs: U`.
A zero across all three is the target. Record each pass; a rising marker count is
an early signal that the convention is slipping.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
