# `/guardian judge` — the verification call

Make the verification judgment on a concrete situation and hand back a grounded verdict. Three
recurring calls own this verb:

- **Defect or flake?** A red gate on a change that shouldn't affect it: same failure across
  untouched code? passes on re-run? timing/order-sensitive assertion? external dependency?
  Verdict: *defect* (route to the bug lane — file it, then the diagnostic procedure),
  *flake* (name the flaky test and what makes it flaky — that finding is itself tend-worthy), or
  *can't tell yet* (name the cheapest experiment that would tell).
- **Does this change need a deeper pass?** The gate is the floor, not the ceiling: a data/param
  retune needs the cheap suite *plus* a visual/scenario check; a migration or wire-format change
  deserves an end-to-end walk; a pure refactor with green gate usually doesn't. Verdict: the
  specific extra check, or "the gate suffices" — with why.
- **Is the playbook missing a chapter?** An investigation that navigated a symptom the playbook
  doesn't cover, twice, has earned its chapter. Verdict: the chapter to add (then `tend` writes
  it).

## When to use

- "the CI keeps flaking", "is this a real failure?", "does this change need more than the gate?",
  "should the playbook cover this?", or the bug lane asking whether a red gate is even a defect
  before opening an investigation.

**Do NOT use** to perform the root-cause investigation itself (that's the bug lane's diagnostic
procedure, playbook-guided), or to edit chapters (`tend` executes what this verb decides). On an
unstamped root: read-only — emit `unstamped`, point at the onramps.

## Procedure

1. **Gather the evidence before the verdict**: the failing output in full, the re-run result, the
   diff between passing and failing context, the gate/pipeline definitions as deployed. A verdict
   without evidence is a hunch — say "can't tell yet" and name the experiment instead.
2. **Make the call** (one of the three above), stated with its evidence and its consequence:
   what happens next, and who owns it (the bug lane, a `tend` edit, an ordinary lane build, or
   nothing).
3. **Route the consequence**: a defect → file it (`/backlog bug`) and hand to the diagnostic
   procedure; a proven flaky test worth fixing → a tracker entry; an earned playbook/gate change →
   `tend`; a call only the human can make (e.g. relaxing the gate) → the promotion bar.
4. **Report** verdict + evidence + the routed next step. This verb writes no chapter and no
   report — its output is the grounded call.

## Done when

The situation has a named verdict backed by cited evidence, and its consequence is routed to the
owner that executes it — nothing here was patched, papered over, or guessed.
