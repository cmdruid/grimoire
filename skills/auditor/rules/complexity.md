# Complexity -- audit rule
> Is authored control-flow complexity proportionate, isolated, and adequately tested?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `CPLX`.

## Why it matters

Each independent path through authored control flow adds a behavior a maintainer must understand and
a verification surface the project must cover. Necessary decisions are not defects, but avoidable
policy coupling, interacting flags, and accumulated special cases make correctness harder to
establish. The risk is highest when such paths sit in a Deep target or cross a safety boundary.

`CPLX` owns independent-path count, avoidable decision multiplication, hotspot isolation, and the
resulting verification burden. `READ` owns legibility, length, nesting, naming, signatures, and
mental backtracking. Give one defect one primary finding and dimension; adjacent evidence may inform
that finding, but do not file or score the same defect twice.

## Scoring anchors (1-5)

- 5 -- Reproducible analyzer facts or specific `file:line` evidence cover the target, the highest
  candidates have been read and refuted, and required decision logic is isolated behind clear,
  independently verifiable boundaries.
- 4 -- Control-flow complexity is generally proportionate, with only limited low-risk deviation or
  one well-contained candidate whose material paths have adequate evidence.
- 3 -- At least one localized hotspot contains avoidable decision or state coupling with a concrete
  maintainability or verification consequence.
- 2 -- Multiple avoidable hotspots, or one high-blast-radius hotspot, combine weak isolation with
  missing evidence for material paths.
- 1 -- Unbounded decision growth is pervasive: core behavior depends on coupled modes and special
  cases whose material paths cannot be stated or verified with confidence.

Analyzer unavailability lowers confidence but does not mechanically select a score. Until the host
calibrates numeric anchors, apply these qualitative anchors and cite the evidence inspected.

## Decision logic

1. Resolve the audited target, its blast-radius depth, and this rule's configured analyzer recipe,
   declared population, and exclusions.
2. Run the configured analyzer when available. Before interpreting results, record analyzer,
   version, status, population, exclusions, and coverage counters.
3. Inspect the highest-complexity authored functions, every function above the host's calibrated
   hotspot threshold when one exists, and any hotspot in a Deep target.
4. Name the decisions responsible for each candidate. Decide whether they are inherent,
   table/exhaustive structure, or avoidable policy or state coupling.
5. Trace material branches and interactions to test evidence. A score of `N` does not require
   exactly `N` tests; it signals a larger verification surface.
6. Refute the Known false-positives, score against the host-calibrated anchors, and file only a
   consequential finding with a concrete remedy. A threshold crossing is a candidate, not a finding.

## Anti-patterns (greppable smells)

```<shell>
<language: run the project-pinned parser-backed complexity analyzer and normalize its output.>
<language: optionally search for interacting flags, nested decisions, and repeated special-case branches as qualitative candidates only.>
```

Text searches are prompts for reading, never cyclomatic-complexity measurements. Do not count branch
keywords with regexes, install an analyzer, or invent a numeric value when the configured tool is
unavailable.

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units and the host calibrates
its analyzer-specific anchors.)_

## Known false-positives

- **Excluded generated or vendored code.** It is outside the authored population and must be excluded rather
  than scored.
- **Exhaustive dispatch over a closed set.** Enum or variant handling may have many necessary arms;
  read the arms and their evidence before judging it.
- **Named lookup tables.** Declarative data can replace decision logic even when it is long.
- **Parser and state machine code.** Many branches may directly model an inherent grammar or explicit
  state space. The exception holds only when states and transitions are clear and verified.
- **Framework-generated branches.** Expansion not authored in the attributed source population is
  not a hotspot in that population.
- **Intentionally sequential tests.** Setup and assertion sequences may be long without multiplying
  independent behavior paths.

Category resemblance alone is not a waiver. Read the candidate and state why its paths are inherent
or adequately isolated.

## How to quantify

Record the project-pinned analyzer's stable invocation, version command, declared source-file
population, and exclusions here. Test code is excluded by default. Include it only when the host
deliberately audits test maintainability; otherwise keep it in the exclusions or report it as a
separate population. The adapter emits one authored function per UTF-8 TSV row:

```text
<score><TAB><repo-relative-path><TAB><line><TAB><symbol>
```

`score` is an integer at least one, `line` is a positive integer, and path and symbol are nonempty.
Malformed rows or duplicate `(path, line, symbol)` identities refuse aggregation. Report status as
`available`, `partial`, or `unavailable` with expected, analyzed, skipped, and parse-error file
counts. A complete zero-function population is `available`. Partial results may select candidates,
but p90, threshold counts, and cross-pass comparisons remain unavailable. Never substitute a regex
count. For unavailable status, state the limitation and inspect qualitatively.

The summary reports analyzer, version, status, population, exclusions, all four coverage counters,
authored-function count, maximum, nearest-rank p90 for a complete population of at least ten
functions, count strictly above a host-calibrated threshold when one exists, and the ten highest
functions with locations. Quote those Complexity facts in the pass report.

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled exemplars and calibrated
threshold, when any, live in its deployed GUIDE and rule.)_
