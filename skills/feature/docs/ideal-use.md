# Ideal use — a worked arc through the spine

A *"how to use me"* example, read on demand. It shows the four spine verbs as **feature's own arc** on
one concrete feature. The arc ends where the feature lane's plan-and-build walk ends — at
**gate-green** — and hands back to whoever orchestrates the lane (the installation's
`.handbook/workflows/feature.md` owns the steps around it: landing, the done-log line, the debrief
sweep).

---

## The feature: "add a `--json` output mode to the `report` command"

**1. `brainstorm "let users get report output as JSON"`**
Reads the `report` command's code and the project's invariants first, then asks one question at a time:
*who consumes the JSON — humans debugging, or a downstream tool?* (a tool → stability matters, version
the shape). Proposes two approaches — a new `--json` flag vs. a separate `report-json` subcommand —
and recommends the flag (less surface, reuses the existing arg parse). Classifies the **tier**: one
phase, no cross-cutting decision → **small feature**. The human approves the approach.
*Output:* an approved approach + the tier call, held in context. → proceed to `design`.

**2. `design`** (small-feature weight → a brief that doubles as the plan)
Writes `.records/plans/2026-07-18-report-json-design.md` from the `plan-design.md` template: **Problem**
(consumers can't machine-read report output), **Approach** (a `--json` flag on the existing command,
emitting a versioned envelope), **Mechanism** (serialize the already-computed report model; no new data
path), **Verification** (a golden-file test of the envelope). Self-reviews for placeholders/ambiguity,
then gates on a human reading the written brief.
*Output:* the design doc (`status: draft`). → proceed to `plan`.

**3. `plan <design-file>`**
Re-grounds the brief against `HEAD` (the report model's field names, the arg-parse signature) — the
design's *reasoning* aged well, but a literal type name may have moved. Decomposes into bite-sized,
independently testable tasks with exact paths and complete code: *Task 1* — add the flag + envelope
type (red-first golden test); *Task 2* — wire the serializer into the command. Confirms every design
requirement maps to a task.
*Output:* `.records/plans/2026-07-18-report-json-implementation.md`. → proceed to `build`.

**4. `build <plan-file>`**
Runs each task red-first: write the failing golden-file test → confirm it fails for the right reason →
minimal implementation → green → commit. Runs the host's full gate plus a real end-to-end check
(`report --json | <a JSON validator>`) before the final commit.
*Output:* code at **gate-green**, tasks checked off. **`build` stops here.**

---

## Where the arc ends — and what continues it

`build` ends at gate-green and **hands back**. It does not land the branch and does not sweep up
follow-ups — those are *outside* the spine, owned by the feature lane's remaining steps (the
installation's `.handbook/workflows/feature.md`): land on the trunk (rebase, re-verify the gate,
merge), write the item's done-log line, and run the debrief sweep (`/backlog debrief`) so every
follow-up the build surfaced reaches the trackers.

Who runs those steps is the orchestrator's call, not this skill's: a `/workstream` loop runs them as
its landing ritual per queue item; standalone, the human walks the lane by hand. Either way the seam
is the same — `/feature` produces code at gate-green, and the lane's close-out consumes it.
