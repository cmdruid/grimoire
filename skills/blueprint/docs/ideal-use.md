# Ideal use — a worked arc through the spine

A *"how to use me"* example, read on demand. It shows the spine verbs as **blueprint's own arc**
on one concrete feature. The arc ends at the **approved plan** and hands off to the host's build
lane (on a workshop host, the build station's feature workflow owns building, landing, and the
close-the-books sweep) — building is not blueprint's job.

---

## The feature: "add a `--json` output mode to the `report` command"

**1. `brainstorm "let users get report output as JSON"`**
Harvests the conversation first (the user already said a downstream tool will consume it →
stability matters, version the shape), then reads the `report` command's code and the host's
design context. Proposes two approaches — a new `--json` flag vs. a separate `report-json`
subcommand — and recommends the flag (less surface, reuses the existing arg parse). Weight
call: one phase, no cross-cutting decision → small feature, no roadmap.
*Output:* a draft design doc in the `design/` store (`status: open`), open questions at its
foot. → proceed to `spec`.

**2. `spec <draft>`**
Synthesizes the draft, then **grills the gaps** — two rounds of numbered questions with
recommended answers (*envelope versioning: a top-level `"v": 1`, or a header field?* —
recommends the field; *pretty-print or compact?* — recommends compact + a `--pretty` flag
deferred as YAGNI). Writes the argued spec: **Problem** (consumers can't machine-read report
output), **Approach** (+ the subcommand alternative, rejected), **Mechanism** (serialize the
already-computed report model; no new data path), **Verification** (a golden-file test of the
envelope). Self-reviews, then gates on the human reading it. On approval:
`records.sh touch <spec> --status current`.
*Output:* the accepted spec. Small feature → skip `roadmap`. → proceed to `plan`.

**3. `plan <spec>`**
Re-grounds the spec against `HEAD` (`ground-check.sh` + re-reading the report model's field
names and the arg-parse signature) — the spec's *reasoning* aged well, but a literal type name
may have moved. Slices tracer-first: *Slice 1* — the thinnest end-to-end path (flag parsed →
envelope emitted for the smallest report, golden test red-first); *Slice 2 (requires: 1)* —
full model coverage. Every spec requirement maps to a slice; each slice carries its verify
command. Runs `review` on the plan (recommended by default for multi-slice work): both axes
pass.
*Output:* the implementation plan in `plans/` (`status: open`). **Blueprint stops here.**

---

## Where the arc ends — and what continues it

The approved plan hands off to the **host's build lane**: on a workshop host the build
station's feature workflow builds it red-first to the green gate, lands it on the trunk, closes
the shipped plan (`records.sh done` — the ledger line), and sweeps follow-ups
(`/journal debrief`). A `/workstream` loop runs those steps as its own ritual per queue item;
standalone, the human walks the project's own conventions. Either way the seam is the same —
blueprint produces the argued spec and the approved plan; the lane's execution consumes them.
