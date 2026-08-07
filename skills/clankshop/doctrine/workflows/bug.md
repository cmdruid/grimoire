# The bug lane — root-cause before any fix

<!-- spine-doc v1
kind: workflow
doctrine: clankshop
doctrine-version: 1
refs: .handbook/**
budget: 60 lines
-->

Diagnose a reproducible defect to its root cause before proposing any fix — never patch a
symptom. The investigation is the deliverable; the fix then lands through the patch or feature
lane at whatever size the root cause demands.

**Enter from:** the routing walk's reproducible-defect row — after the GOTCHAS check: a match
there means working-as-coded, so capture a note and stop; no bug lane.

**Project policy:** the fix commit follows patch-lane policy (INV-1, INV-3); the report and any
linked entry follow the record formats (`.handbook/rules/RECORDS.md`); `bugs/` is a store, never
a work queue — the actionable item is a linked tracker entry (INV-7).

**Seam glue:** file the defect first (`/backlog bug` — the report plus its linked tracker entry);
the diagnosis is the diagnostic instrument's procedure (`/debugger` — reproduce → trace →
hypothesize → verify → fix, human-confirm before the fix lands), guided by the diagnostics
playbook (`.handbook/testing/DIAGNOSTICS.md`) when one exists. A routed report whose linked entry
is paused is refused — the pause fact says a ticket owns it. A decision only the human can make
mid-investigation → promote per the promotion bar.

## The walk

1. Reproduce it. No fix before a reproduction; a flaky reproduction is itself a finding.
2. Read the actual error in full — the stack trace, the log line, the failing assertion.
3. Trace the data flow backward from the failure to its origin; check `GOTCHAS.md` again with
   what you now know.
4. Form one testable hypothesis; verify it with the smallest possible probe. Three failed minimal
   fixes means the architecture is the suspect — stop and question the frame before a fourth.
5. Write the investigation report (`investigation-<date>-<slug>.md` per
   `.handbook/rules/RECORDS.md`) — findings, evidence, the root cause.
6. Fix the root cause via the patch lane (or the feature lane if the fix is feature-sized);
   `<gate>` green; land on `<trunk>`.
7. Close the loop: done-log line for the linked entry; a working-as-coded surprise becomes a note;
   a durable trap the investigation proved lands in `GOTCHAS.md` via the improvement loop.

**Done when:** the root cause is named in a written investigation, the fix (if any) is landed on
`<trunk>` with the gate green, and the linked tracker entry is completed or explicitly re-routed.
