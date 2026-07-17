# Type Safety -- audit rule
> Do the types carry the invariants, or are they escaped?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `TYPE`.

## Why it matters

The type system is the primary defense against a class of bugs that would be
invisible at runtime until they corrupt data or cause incorrect output. When two
values with the same primitive type but distinct semantic roles are used without
distinct wrapper types, a transposition is a silent correctness bug -- the compiler
cannot distinguish them. When `<language: type escape hatches (raw casts, any, unsafe)>`
silently truncate or widen a value, the error is not a crash but a wrong result,
which is worse. In a codebase with purity invariants, type-level encoding of
semantic roles (e.g., "which seed", "which coordinate space", "which ID namespace")
is the first defense against a class of invariant violations that no test can
reliably catch.

This rule owns: newtypes over bare primitives at module boundaries, cast safety,
dispatch exhaustiveness (catch-all arms that hide new cases), and unsafe /
type-escape blocks. The paired error-handling rule (`error-handling.md`) owns
the result/panic side; a missing-variant unreachable in a default dispatch arm is
both a TYPE and an ERR finding -- file it under TYPE (structural escape) and note
the ERR implication.

## Scoring anchors (1-5)

- 5 -- Distinct semantic roles at module boundaries are distinct types (newtypes or
  enums, not raw primitives). `<language: type escape hatches>` are bounded and
  annotated. Dispatch on domain enums is exhaustive (no naked catch-all arms that
  would silently pass on a new case). No `<language: unsafe / unchecked blocks>` in
  the codebase; if any exist, each block is commented with a safety proof.
- 4 -- One or two casts on known-bounded values in leaf utilities without
  comments; one catch-all arm in a non-critical dispatch that explicitly handles
  "unknown case" as a documented default. No unsafe blocks. The blast-radius
  modules have no naked casts or catch-all arms.
- 3 -- Several unchecked casts in blast-radius code; at least one catch-all arm
  that silently swallows a new case without a comment. Semantic values passed as
  bare primitives across more than two module boundaries.
- 2 -- Casts throughout without comments; multiple catch-all arms in critical
  dispatch paths that would silently produce wrong output if a new case were
  added; no newtypes at any meaningful boundary.
- 1 -- Pervasive: raw primitive types passed through the whole codebase as
  semantic values, no newtypes, liberal unsafe casts including potentially lossy
  ones, and catch-all arms in core dispatch.

## Decision logic

1. Run the smell greps (see Anti-patterns). Collect all casts, all catch-all
   dispatch arms, and all unsafe / type-escape blocks.
2. For each cast, classify the source and target types:
   - Float-to-integer (potentially lossy, NaN risk) -> **finding candidate**: add
     a bounds check or use a checked conversion.
   - Size-type to smaller type where the value comes from a runtime collection
     length -> **finding candidate**: could fail on large inputs.
   - Integer-to-float in a tight loop where the range is proven bounded ->
     **acceptable with a comment**.
3. For each catch-all arm in a dispatch on a domain enum, ask: would adding a new
   case silently fall through to the default producing a wrong result?
   - If yes and there is no comment acknowledging the default -> **finding**.
   - If a comment explicitly says "any future case: use default behavior"
     and that is a correct policy -> **acceptable documented default**.
4. For each unsafe / type-escape block, verify a comment explaining the invariant
   that makes it safe. An unchecked block with no comment is a TYPE finding
   regardless of whether the code is actually correct.
5. Survey module boundaries for bare primitive types where newtypes would encode
   an invariant. Focus on semantic IDs, coordinate parameters, and domain values
   passed as raw integers.
6. Score against the anchors. Use the lower anchor when two fit.
7. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: list all type-escape casts to numeric types -- the primary triage list.>
<language: count type-escape cast sites.>
<language: list catch-all / wildcard dispatch arms. Each hit: is the dispatched type a domain enum? Would a new case silently fall here?>
<language: find unsafe / unchecked / type-escape blocks (any hit is a finding candidate).>
<language: find semantic-value primitives (e.g., seed, id, coordinate) at function boundaries -- newtype candidates.>
<language: find float-to-integer casts (potential floor/truncation confusion; NaN risk).>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Geometry arithmetic casts.** A float-to-integer cast in a tight render or
  physics loop where the caller guarantees the value is in a sane coordinate range
  is a low-severity cast. Annotate it and move on; do not require a checked
  conversion in a hot path without profiling evidence.
- **Catch-all as an event skip.** A catch-all arm in a dispatch that intentionally
  skips unrecognized event cases is idiomatic in many frameworks. Flag it only if
  the dispatched type is a domain enum where new cases would break existing behavior.
- **Exhaustiveness guard with `unreachable`.** An `unreachable` in a catch-all arm
  after a full manual enumeration is a programming-error guard, not a silent
  default. It is acceptable with a comment; without a comment it is a TYPE + ERR
  finding.
- **Collection length casts on small, bounded collections.** A cast from a size
  type to a smaller integer where the collection is always fewer than that type's
  max entries is low-risk. Note it but do not require a checked conversion unless
  the collection can grow unbounded.
- **Coordinate space casts in the presentation layer.** A float-to-integer cast for
  converting world-space position to a discrete coordinate is a known-safe pattern
  when the coordinate range is bounded by the application's design. Accept with a
  comment; flag without one.

## How to quantify

<language: count type-escape casts (all numeric targets); count catch-all dispatch arms;
count unsafe/unchecked blocks (should be zero); count semantic bare-primitive parameters
at module boundaries (newtype gap proxy). Report as:
`casts: N; catch-all arms: M; unsafe blocks: U; bare-semantic params: S`.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
