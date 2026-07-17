# Readability -- audit rule
> Can you read it top-to-bottom without backtracking?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `READ`.

## Why it matters

A language's type system may enforce correctness at a structural level, but it
does not enforce that the logic inside a function is legible. In frameworks where
the call graph is implicit (dependency injection, scheduler-wired systems, etc.),
signatures can accumulate parameters until they alone require several scrolls to
parse. When a reader cannot follow a function top-to-bottom -- because of deep
nesting, unexplained numeric constants, or a 200-line body that mixes concern A
and concern B -- they are forced to hold more context in working memory than the
change requires. In blast-radius modules with the most invariant constraints, a
readability failure is not cosmetic; it is a correctness risk.

## Scoring anchors (1-5)

- 5 -- Functions are short enough to read in one screenful. Nesting is at most
  two or three levels deep. Magic numbers are named constants with a comment
  stating their origin. Complex signatures are decomposed into type aliases or
  query-filter types so the intent is visible at a glance. A reader can follow
  any function from top to bottom without jumping to a definition.
- 4 -- A few functions run long or have one extra nesting level, but the critical
  paths are clean. Magic constants are rare and their values are at least plausible
  from context even without a name.
- 3 -- One or two functions in a blast-radius module exceed ~80 lines or have
  four-plus nesting levels. Some numeric literals appear without names or
  comments. Dense one-liners using iterator or pipeline chains obscure intent.
- 2 -- Several functions require mental simulation to follow. Deep nesting is the
  norm in at least one module. Magic constants appear in hot paths. Long signatures
  require horizontal scrolling to read the return type.
- 1 -- Pervasive: the module reads like a transcript of the author's reasoning
  process rather than a statement of intent. Nesting routinely exceeds five
  levels, function bodies exceed 150 lines, and unlabeled numbers appear
  throughout.

## Decision logic

1. Identify the longest functions in the target using the line-count recipe below.
   Read the top three by line count -- they set the ceiling for the module.
2. Measure nesting depth for those functions. Count the maximum indentation
   level (each `<language: indentation unit>` = one level).
3. Search for bare numeric literals in non-trivial positions (not `0` or `1`
   used as an index or loop bound). Each unexplained constant in a formula or
   threshold is a candidate.
4. Check complex signatures for parameter count. More than five framework-injected
   parameters without type aliases is a smell.
5. Score against the anchors; use the lower anchor when two fit.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: find long functions (bodies exceeding ~60 lines) -- list function name + line count.>
<language: find lines with 5+ levels of indentation.>
<language: find bare numeric literals that are not 0, 1, or 2 and are not in comment lines.>
<language: find files/modules with many framework-injected parameters per function signature.>
<language: find long single-line pipeline/iterator chains that chain map/filter/fold-style operations.>
```

(Bare unchecked-error escape hatches are owned by the `error-handling.md` (`ERR`)
rule, not this one. Flag dense one-liners above as readability; file an unsafe escape as `ERR`.)

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Generated or macro-expanded code.** Framework-generated expansions and
  code-generation tool output are not authored code; do not score them for readability.
- **Match arms over large enums.** A `match` on a 20-variant enum will have 20
  arms; the nesting depth is structural, not an authoring choice. Score the
  *content* of each arm, not the match itself.
- **Const arrays and lookup tables.** A constant block defining a palette or a
  weight table will be long and numeric by nature. These are not magic
  constants -- they are data. Check whether the array is named and documented,
  not whether the numbers are plain.
- **Framework-injected signatures -- type aliases present.** If long signatures
  are already wrapped in type aliases, the raw parameter count at the call site
  is fine; do not double-count.
- **Test functions.** Integration and unit test bodies are often long and
  sequential by design (Arrange / Act / Assert). Apply a relaxed standard: flag
  only if the test itself is unreadable, not merely long.

## How to quantify

<language: count functions over 60 lines; count lines with 5+ indent levels; record as
`long fns (>60L): N; deep-nesting lines (5+): M`. Record each pass for trend tracking.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
