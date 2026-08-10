---
distilled_through_adr: <none | NNNN>
distilled_through_commit: <none | sha>
distilled_through_date: <none | YYYY-MM-DD>
---

# <System> — Standing Spec

## Contract (BINDING)
- **Purpose:** <what this system is for, present tense>
- **Invariants:** <the sacred constraints; cite PHILOSOPHY tenets>
- **Interfaces / seams:** <how neighbors consume this; the boundary an implementation must
  preserve — ALL binding seams live here, NOT in reference-arch>
- **Behavior:** <what it does, present tense; observable rules>
- **Acceptance:** <CONCRETE and non-placeholder — the exact scenarios/gates/determinism checks
  the implementation must pass; `design health` flags a spec whose acceptance is still a placeholder>
- **Why the hard constraints:** <rationale, so an implementation does not "improve" them away>

## Reference Architecture (DISPOSABLE — current best guess; an implementer MAY discard this)
> Pointer-heavy: cite `src/…:line`, do not paste code. This tier is a snapshot; verify before
> trusting.
- <current module/data/algorithm shape, as `src/…` pointers>
