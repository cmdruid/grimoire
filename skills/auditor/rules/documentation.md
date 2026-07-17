# Documentation -- audit rule
> Is intent + public API documented to the exemplar bar?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `DOC`.

## Why it matters

A reader approaching a module cold cannot lean on intent that was never written
down. Undocumented public items force them to reconstruct intent from context; an
undocumented module forces them to read the whole file before knowing whether it is
relevant. The cost is paid many times over on the most-read, most-changed modules.
Documentation debt also silently invalidates adjacent rules: a poorly documented
public function that fails on a reachable input is both a DOC and an ERR finding.

## Scoring anchors (1-5)

- 5 -- Every source file has a `<language: module-header comment>` stating its job
  in one to three lines. Every public item (function/type/interface) has a
  `<language: doc comment>` stating intent. Non-obvious logic (invariants,
  workarounds, why-not notes) is annotated inline. Suggested metric: module-header
  coverage >= 95%; public-item doc coverage >= 90%.
- 4 -- One or two low-blast-radius files lack a header, or a handful of minor utility
  items lack a doc comment. The blast-radius modules are fully covered.
- 3 -- Several blast-radius files lack headers, or public-item coverage is clearly
  below 50% in a deep module. Intent must be reconstructed on each visit.
- 2 -- Most files have no header. Doc comments appear only on a few prominent types.
  Non-obvious logic is uncommented throughout.
- 1 -- Pervasive: almost no doc comments exist anywhere; the code is opaque to a new
  reader without a walkthrough from the author.

## Decision logic

1. Measure module-header coverage: files with a header vs. total (see How to
   quantify). Check blast-radius modules first.
2. Count undocumented public items: items NOT immediately preceded by a doc comment.
   Focus on non-trivial items (more than a one-field newtype or a marker type).
3. Read a sample for quality: does each doc state *intent* ("why this exists, what
   invariant it upholds") rather than restating the name?
4. Check non-obvious logic: long unsafe/numeric/bit blocks or workarounds without a
   why-comment are a DOC smell.
5. Score against the anchors; use the lower anchor when two fit.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: list source files lacking a module-header comment -- strongest candidates.>
<language: count files missing a header vs. total file count.>
<language: list public items NOT immediately preceded by a doc-comment line (file:line).>
<language: count documented vs. undocumented public items.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Self-explanatory marker / wiring types.** A zero-field type whose only role is
  framework wiring is self-explanatory from its name; a minimal or absent doc is not
  a finding.
- **Newtype wrappers with obvious semantics** in a file whose header already explains
  the concept.
- **Test-only items** (helpers, fixtures, test modules) are not public API.
- **Re-export / facade lines** -- the doc lives on the item, not the re-export.
- **Override of a well-documented interface method** -- the interface doc transfers.

## How to quantify

<language: the module-header coverage recipe and the public-item doc-coverage recipe;
record both numbers per pass.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
