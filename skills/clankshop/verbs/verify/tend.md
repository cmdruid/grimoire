# `/clankshop verify tend` — author and maintain the testing chapters

Hat: `roles/guardian.md` — read the hat first; you operate this verb wearing that hat.

Keep `.handbook/testing/` true: fill the seeded skeletons with the project's real verification
story, evolve the gate definition as the gate evolves, and grow the diagnostics playbook as
investigations earn chapters. The three docs and their jobs:

- **`GATE.md`** — what green means here: the one land-blocking command, the cheap mid-task
  suite, scoped runs, and the when-which table. The slots (`<gate>`, cheap suite, scoped runs)
  are filled at deploy; this verb keeps them true as commands change.
- **`PIPELINE.md`** — CI/CD from push to shipped: stages, triggers, what a failure at each stage
  means. A project with no CI keeps the one local row — a valid fill, not a gap.
- **`DIAGNOSTICS.md`** — symptom → first moves: the playbook the bug lane's diagnostic procedure
  consults. Per-symptom chapters accrue as the project earns them.

## When to use

- "harden the gate", "the gate doesn't cover X", "document the CI", "the pipeline changed",
  "add a diagnostics chapter for <symptom>", "the playbook is missing what that investigation
  taught us".
- After a `judge` call that ended "the playbook/gate definition is missing something" — `tend`
  executes what `judge` decided.

**Do NOT use** to root-cause a live defect (the bug lane's diagnostic procedure), to build new
test infrastructure (specify it here, route the build through the ordinary lanes), or on an
unstamped root (read-only: emit `unstamped`, point at the onramps).

## Procedure

1. **Resolve root**; confirm the root is stamped and `.handbook/testing/` exists (absent → that's
   a deploy gap; point at the pack onramps, don't scaffold here).
2. **Ground the edit.** Read the chapter as deployed; verify the claims you're about to write
   against the tree (run the gate command, read the CI config, re-read the investigation report
   that earned the playbook chapter). A verification doc that overstates coverage is worse than a
   skeleton.
3. **Edit the chapter** — standalone prose, no role names, slots filled with real commands.
   Preserve the declaration block (its `origin:`/`origin-version:` keys are the seed provenance
   the doctrine differ reads); content edits below it are exactly the legitimate local divergence
   it classifies.
4. **Keep the seams true:** if the gate command itself changed, the rules chapters that cite
   `<gate>` (INVARIANTS) were filled with the old command at deploy — flag the mismatch to the
   rulebook steward rather than editing another role's chapter.
5. **Commit** trunk-side, scoped to the chapter paths. **Report** what changed and why, citing
   the evidence from step 2.

## Done when

The chapter says what is actually true of the project's verification — commands run as written,
stages match the CI config, playbook chapters trace to real investigations — and the edit landed
as a scoped commit.
