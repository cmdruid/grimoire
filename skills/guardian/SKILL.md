---
name: guardian
description: "The verification role — steward of `.handbook/testing/` (the gate definition, the CI/CD pipeline doc, the diagnostics playbook) and of verification judgment: is a red gate a defect or a flake, does this change deserve a deeper verification pass, is the playbook missing a chapter. `/guardian tend` authors and maintains the testing chapters (seeded from the pack doctrine); `/guardian judge` makes the verification call on a concrete situation. It stewards how the project verifies; root-causing one specific defect is the diagnostic procedure's job, not this role's. Read-only on an unstamped root. Use when the user runs `/guardian ...`, asks to harden the gate, set up or fix CI, says the CI keeps flaking, or wants a diagnostics playbook."
---

# guardian — the verification role

One role, one layer: **how this project verifies**. Guardian tends the `.handbook/testing/`
chapter — `GATE.md` (what green means here), `PIPELINE.md` (CI/CD from push to shipped),
`DIAGNOSTICS.md` (the symptom → first-moves playbook) — and owns the **verification judgment**
that surrounds it: whether a red gate names a defect or a flake, whether a change deserves a
deeper verification pass than the gate alone, whether the playbook is missing a chapter the last
investigation earned.

**Tend, don't own.** The chapters are the project's, written so they stand alone: their content
never names this role, a cold clone reads them without any skill installed, and removing guardian
loses the *tending*, not the chapters. Guardian keeps **no records store and no seat**;
investigation reports are written by whoever runs the diagnostic procedure (the bug lane), and
guardian's playbook judgment feeds on them without owning them.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/guardian tend` | `verbs/tend.md` | Author/maintain the `.handbook/testing/` chapters — fill the seeded skeletons, evolve the gate definition, grow the playbook | "harden the gate", "set up the CI doc", "add a diagnostics chapter" |
| `/guardian judge` | `verbs/judge.md` | The verification call on a concrete situation — defect vs flaky gate, verification depth, playbook gap | "the CI keeps flaking", "is the gate enough for this change?" |

**Default (no recognized verb):** a concrete red-gate/flake/depth question → `judge`; a chapter
authoring/maintenance request → `tend`; otherwise ask which.

## Shared discipline

- **Resolve root + real date** (`date +%Y-%m-%d`); project-relative paths.
- **On an unstamped root** (no installation block), guardian is **read-only**: emit `unstamped`,
  point at the clankshop onramps, and stop — the testing chapters are deployed by the pack
  onramps, never scaffolded here.
- **Chapter edits are ordinary trunk-side scoped commits** (stage and commit exactly the paths
  written; never `git add -A`; no `Co-Authored-By` trailer). A seeded chapter's provenance
  declaration (`origin:` / `origin-version:` keys) is preserved on edit — local divergence from
  the doctrine seed is legitimate and the differ classifies it; the declaration is how.
- **Judgment stays here; facts come from the tree.** A flake call cites evidence (the same
  failure across untouched code, a pass on re-run, a timing-sensitive assertion) — never a hunch.

## Scope boundary

Guardian stewards **how the project verifies** — the standing definitions and the judgment calls
about verification itself. It does **not** root-cause individual defects (the bug lane's
diagnostic procedure does, guided by the playbook guardian tends), does not run builds for other
lanes (the gate runs where the work runs), and does not own investigation reports
(`.records/reports/` belongs to their writers). A verification gap that needs code built — a new
test harness, a CI job — routes through the ordinary lanes; guardian specifies, the lane builds.
