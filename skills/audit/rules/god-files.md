# God-files -- audit rule
> Does any unit do more than one job?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `GOD`.

## Why it matters

A god-file is a single source file (or a single class/struct + its method block)
that has accumulated multiple distinct responsibilities. In framework-heavy
codebases the pattern is common: a module that started with one purpose grows to
own related-but-separate concerns because "it was convenient." The result is a file
where every change risks an unrelated regression, and where the test surface for
each concern is tangled with the others.

If the project has a purity invariant (e.g., core logic must be a pure function of
its inputs, with no side effects), a god-file that mixes pure logic with I/O,
framework mutation, or stateful infrastructure is a latent correctness defect, not
merely a structural smell.

## Scoring anchors (1-5)

- 5 -- Every file owns exactly one concept; every class/struct owns one set of
  cohesive state. No file in the blast-radius modules exceeds `<language: threshold>`
  lines (300 lines is a useful default proxy). Concern boundaries are visible in
  the module tree.
- 4 -- One or two files run slightly over threshold but for justifiable reasons
  (large dispatch tables over a domain enum, or an exhaustive const table). No
  type owns clearly unrelated fields.
- 3 -- At least one file in a blast-radius module exceeds threshold and mixes
  two separable concerns. A type carries fields that belong to different
  life cycles (e.g., both generation state and rendering state on the same type).
- 2 -- Several files exceed threshold and a reading of any one of them reveals
  multiple jobs interleaved. At least one implementation block for a single type
  spans concerns (e.g., input handling + processing + presentation).
- 1 -- Pervasive: the codebase has large catch-all files (500+ lines) that cannot
  be summarized in one sentence. The module tree does not reflect the actual
  responsibility decomposition; responsibilities are found by searching, not by
  navigating.

## Decision logic

1. Run the size sort (see Anti-patterns). Examine every file over the threshold.
2. For each flagged file, write a one-sentence description of its job. If the
   sentence requires "and" to complete, the file is a candidate.
3. Check whether the multiple jobs in a large file have different *change
   frequencies* (core logic changes rarely; presentation hints change often).
   Different change frequencies in one file is a reliable co-responsibility signal.
4. Inspect type definitions in flagged files. A type with fields spanning two
   life cycles (construction vs. runtime; generation vs. presentation) is a
   god-type even if the file is small.
5. Flag any file that mixes a pure-logic core with framework mutation, I/O, or
   event dispatch -- that is a purity violation AND a god-file finding.
6. Score against the anchors; use the lower anchor when two fit.
7. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: list source files by line count, largest first -- primary triage tool.>
<language: list files over 300 lines (or project-appropriate threshold).>
<language: find type definitions in files over threshold -- god-type candidates.>
<language: find files that mix pure-logic functions AND framework mutation/I/O calls (purity smell).>
<language: find types with many fields (10+ fields -- god-type size proxy).>
<language: list large implementation / method blocks per type.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Large dispatch arms over domain enums.** A match/switch on a domain enum with
  15 variants produces a long file mechanically. Check whether the arms are uniform
  in shape -- if yes, the file has one job (dispatch) and is not a god-file.
  A macro or a data-driven table would be cleaner, but it is not a finding here.
- **Const data tables.** A file that is mostly a large constant array (e.g., a
  parameter table or a color palette) is long by data volume, not by
  responsibility. Verify the file does only one thing (defining the table) before
  flagging.
- **Framework glue / wiring files.** A framework registration file wires systems
  and resources; it is glue by design. The file is large because it lists many
  registrations, not because it owns multiple concerns. Flag only if the file also
  *implements* logic rather than merely *registering* it.
- **Test modules.** Test-only blocks at the bottom of a file inflate line
  counts. Subtract the test block before applying the threshold.
- **Trait/interface implementations on a core type.** A file that implements several
  interfaces for one type is not a god-file; the type still has one identity. Flag
  only if the implementation blocks address different behavioral domains (e.g.,
  rendering AND physics on the same type).

## How to quantify

<language: count files over 300-line threshold (excluding test-only blocks is manual;
use raw count as a conservative over-count); record the largest file (the ceiling sets
the worst-case score); record the total file count (denominator for ratio reporting).
Report as: `files >300L: N of T (largest: F at L lines)`.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
