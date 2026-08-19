# The bug lane — root-cause before any fix

Diagnose a reproducible defect to its root cause before proposing any fix — never patch a
symptom. The investigation is the deliverable; the fix then lands through the patch or feature
lane at whatever size the root cause demands.

**Enter from:** the routing walk's reproducible-defect row — after the GOTCHAS check: a match
there means working-as-coded, so capture a note and stop; no bug lane.

**Policy:** the fix commit follows patch-lane policy (INV-1, INV-3); `bugs/` is a store, never a
work queue — the actionable item is a linked tracker entry (INV-8). The diagnosis follows the
test station's playbook (`test/workflows/diagnostics.md`); `/debugger`, where installed,
runs the same discipline.

## The walk

1. File the defect first via `/debugger file`. Do not file-and-link in one
   step. A tracker entry is a later `/backlog task` when the defect needs
   scheduling (INV-8).
2. Reproduce it. No fix before a reproduction; a flaky reproduction is itself a finding.
3. Read the actual error in full — the stack trace, the log line, the failing assertion.
4. Trace the data flow backward from the failure to its origin; check `core/GOTCHAS.md` again
   with what you now know.
5. Form one testable hypothesis; verify it with the smallest possible probe. Three failed
   minimal fixes means the architecture is the suspect — stop and question the frame before a
   fourth.
6. Record the findings, evidence, and root cause in the bug record (or a `reports/` record if
   the investigation outgrows it).
7. Fix the root cause via the patch lane (or the feature lane if the fix is feature-sized);
   `<gate>` green; land on `<trunk>`.
8. Close the loop: `records.sh done` on the linked entry; a working-as-coded surprise becomes a
   note; a durable trap the investigation proved lands in `core/GOTCHAS.md`.

**Done when:** the root cause is named in a written record, the fix (if any) is landed on
`<trunk>` with the gate green, and the linked tracker entry is closed or explicitly re-routed.
