# DRY -- audit rule
> Is each rule expressed exactly once?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `DRY`.

## Why it matters

Duplication means a rule lives in two (or more) places; a fix to one misses the
others. The most dangerous duplication is in the core domain layer: if a mapping
from a concept to a parameter is encoded in two separate conditional blocks in two
separate files, one will drift when a new case is added.

DRY violations also compound maintenance cost in repeated structural patterns:
a registry-load contract, a validation shape, or an error-default behavior that
appears across multiple modules means a fix to the contract must be applied in N
places. The decision to tolerate such repetition is sometimes defensible; what is
not defensible is repeating it without a comment explaining why no abstraction was
chosen.

## Scoring anchors (1-5)

- 5 -- Each rule appears in exactly one place. Shared shape (a repeated struct
  layout or protocol) is factored behind a trait, interface, or abstraction with a
  clear seam. Any deliberate duplication is accompanied by a comment explaining the
  exception ("// deliberate: enforces the invariant that ...").
- 4 -- One or two minor duplications exist in low-blast-radius code; they are
  bounded and would require at most one additional edit to fix a bug in them.
  No duplication in the blast-radius modules.
- 3 -- At least one rule in a blast-radius module is expressed in two separate
  places. Fixing a bug would require two edits. No comment acknowledges the
  duplication.
- 2 -- Several rules are duplicated; a bug fix requires touching 3+ files.
  Logic is copy-pasted rather than extracted; the copies have already drifted
  slightly from each other (a reliable sign of real-world pain).
- 1 -- Pervasive: the same logic (domain mappings, load-error handling, core
  formulas) appears in many files with no shared abstraction and no
  acknowledgment. Adding a new concept requires touching 6+ files.

## Decision logic

1. Identify the *family* first -- what rule is being expressed? (A "load with
   defaults" contract, a domain-to-parameter mapping, a specific formula.)
2. Locate the *logic core* -- find every site that encodes the same rule. Use
   the smell greps to find literal and structural candidates; read the bodies to
   confirm they encode the same decision.
3. Apply the *extract test*: how many files would you have to edit to fix a
   bug in this logic? One is ideal; two or three is a DRY candidate; four or
   more is a finding.
4. Check for the *documented-exception clause*: deliberate duplication that
   enforces an invariant (e.g., two independent checks in different modules to
   guarantee a bound is never exceeded) is acceptable ONLY when a comment says
   so explicitly. Silence is not permission.
5. Score against the anchors. Use the lower anchor when two fit.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: search for repeated structural patterns (e.g., load/validate/with_defaults) across multiple files.>
<language: find copy-paste sentinels: the same hardcoded string or literal appearing in many files.>
<language: find duplicated named constants with the same numeric value in unrelated files with no shared definition.>
<language: find domain-literal strings (e.g., enum variant names as strings) appearing in multiple production files.>
<language: find identical function signatures repeated across files (structural copy-paste).>
<language: find inline comments that flag deliberate duplication -- these are GOOD (count them).>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Shared *shape*, not shared *rule*.** Similar conditional arms over *different*
  domain concepts that happen to have the same structure are not DRY violations. The
  arms look alike; the rule is distinct.
- **Symmetric error paths.** Two distinct error returns ("too low" / "too high") in
  separate validation functions share a shape but each encodes a distinct
  constraint. Not a DRY finding.
- **Protocol implementations.** Implementing a conversion in both directions is
  structurally symmetric but semantically independent. Both must exist because they
  encode different directions.
- **Test fixtures.** Duplicate setup blocks inside test-only modules are
  acceptable -- they keep tests readable and independent. Do not flag test
  duplication unless it masks a gap in a shared helper that would catch a
  real defect.
- **Framework wiring.** Registering a component or system in two different
  framework-level modules because each is independently composable is intentional
  separation of concerns, not duplication. The rule being expressed in each
  case is "this belongs to this context" -- two different rules.

## How to quantify

<language: count files that implement the repeated structural pattern; count domain-literal
sites in non-test production code (proxy for unextracted config); count inline deliberate-exception
comments (higher is better). Record as: `pattern files: N; domain-literal sites: M; documented exceptions: K`.
There is no single precision metric for DRY; the quantitative pass surfaces candidates and the reader
applies the extract test.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
