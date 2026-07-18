---
name: auditor
description: Deploy and operate a code-quality audit framework via a project's .agents/dev/audit/ system. Calibrate against the host's .agents/dev/audit/GUIDE.md, scope by risk-weight, run metrics.sh, score targets against the rules/ dimensions, log raw output, record findings, and drain actionable findings to the host's trackers. Use when the user runs `/auditor`, asks to audit/quality-check the codebase or a module, or to stand up the audit framework on a project that lacks one. `/auditor deploy` bootstraps .agents/dev/audit/ from the bundled BOOTSTRAP.md; `/auditor metrics` runs metrics.sh; `/auditor check` runs the invariant gate. This audits PROJECT CODE -- distinct from any .agents/foreman/ docs-system maintenance sweep.
---

# auditor — the code-quality audit driver

Drive a **code-quality audit** over a project's own code using a `.agents/dev/audit/` system.
This skill is a **thin driver**: the methodology, rubric, scoring rules, and severity
model live in the host's `.agents/dev/audit/GUIDE.md` (+ the per-dimension `rules/` files) and
are the single source of truth -- **re-read `GUIDE.md` each pass**; this skill
orchestrates the loop, it does not restate the rubric.

If the host project has **no `.agents/dev/audit/` yet**, deploy it first (see *Deploy mode*),
then operate it. The skill is self-contained: it bundles the blueprint and a worked
example so it can stand the system up anywhere.

## What this skill bundles

- **`BOOTSTRAP.md`** -- the portable blueprint: principles, slots, the uniform
  rule-file shape, the metrics-script structure, the decision-walk + deployment
  playbook. The generic templates live inside it.
- **`rules/`** -- a generic, language-neutral rule-set for the 12 portable dimensions
  (host-specific greps/exemplars as `<slots>`). The deployable rubric.

There is **no generated worked-example mirror.** Scaffold from `BOOTSTRAP.md` (its
deployment playbook + the inline rule/template shapes) and use the **host repo's own
`.agents/dev/audit/`**, as it fills in, as the live example.

**Scope boundary:** `/auditor` audits **project code** (quality + the host's sacred
invariants). It is **not** a docs-system maintenance sweep. Different domain.

## Modes (selected by argument)

- **`deploy`** (alias `init`) -- stand up `.agents/dev/audit/` on a project that lacks one.
- **(no arg) -- a pass.** Run the audit loop, scoped to a risk-weighted target (or all).
- **`metrics`** -- run the host's `.agents/dev/audit/metrics.sh`: print the report, append the
  trend row to `.agents/dev/audit/logs/metrics.csv`. No scoring.
- **`check`** -- run `.agents/dev/audit/metrics.sh --check`: the invariant gate (a non-zero
  count of the host's native-invariant smell is a P0 and fails).
- **`<target>`** -- a path scopes a pass to that target at its depth.

## Deploy mode

When the host has no `.agents/dev/audit/`, follow the bundled `BOOTSTRAP.md`:

1. **Decision-walk (`BOOTSTRAP.md §9`)** -- with the user, fill the slots: the
   `<language>`, the `<native dimensions>` (the host's sacred invariants), the
   `<targets>` (Deep/Mid/Light by blast radius), the `<drains>` (existing trackers),
   and the audit's purpose (hygiene vs release-gating -> severity model).
2. **Author the rubric** -- copy the bundled generic `rules/` into the host's
   `.agents/dev/audit/rules/`, fill the `<language>` greps and `How to quantify` recipes, and
   add a rule file per `<native dimension>`, following the uniform rule-file shape in
   `BOOTSTRAP.md` (a native dimension states the host's sacred invariant + the grep that
   smells a violation).
3. **Write the hub + tracker** -- `GUIDE.md`, `TEMPLATE.md`, `FINDINGS.md`,
   `logs/README.md` + `metrics.csv` header, then `README.md`, following the manifest
   and leaves-before-index order in `BOOTSTRAP.md §4`/`§10`.
4. **Write `metrics.sh`** (`BOOTSTRAP.md §8`) for the `<language>`; run it for a
   baseline `metrics.csv` row; wire `--check` on the native invariant.
5. **Wire + gate** -- add one pointer from the host's doc index; run the host's gate.
6. **Baseline pass + Select exemplars** -- run a lean pass to seed `FINDINGS.md`, then
   pin the score-5 `<exemplars>` and backfill calibrated examples (`BOOTSTRAP.md §10`).

## The audit loop (a pass)

Follow the host's `.agents/dev/audit/GUIDE.md` -> *Process*; in brief:

1. **Calibrate.** Read `GUIDE.md` and its pinned score-5 exemplars (GUIDE's
   pinned-exemplars section); read
   each `rules/` file's anchors before scoring it.
2. **Map / scope.** Pick targets by blast-radius depth (GUIDE's targets table), or honor a
   `<target>` arg. Plan the reading order Deep -> Mid -> Light.
3. **Quantify.** Run `.agents/dev/audit/metrics.sh` for reproducible counts *before* scoring;
   quote the latest `logs/metrics.csv` numbers in the scorecard.
4. **Score.** Each applicable dimension against its `rules/` file, one at a time.
   **Back every 5 with a metric or `file:line`**; **refute each rule's known
   false-positives** before filing; conservative bias when two anchors fit.
5. **Log.** Append raw output + per-run notes under `.agents/dev/audit/logs/` (dated, one
   file/pass).
6. **Record.** Curate findings into `FINDINGS.md` using `TEMPLATE.md`'s entry shape --
   permanent themed IDs, Severity, evidence in the **Finding** field.
7. **Drain.** Graduate actionable findings into the host's `<drains>` and backfill the
   `Graduated:` field. The audit surfaces and prioritizes; the host trackers schedule.
   **No parallel work queue.** If the host has no trackers, the audit's own tracker
   owns the work (`BOOTSTRAP.md §9`).

When `FINDINGS.md` grows large, sweep resolved entries into `.agents/dev/audit/history/`.

## Relationship to neighboring skills

- If the host has a **bug-filing** skill, a drained *defect* graduates via it; else
  file a report under the host's defect store directly.
- If the host has a **backlog** skill/file, a drained *feature* finding graduates into
  it; else into the host's equivalent.
- If the host has a **heavier, parallelized audit workflow** (score -> adversarially
  verify -> synthesize), reach for it when a single-reader pass isn't thorough enough.

## Keeping the bundle current (host = this skill's home repo)

`BOOTSTRAP.md` is **canonical here** -- edit it in place (there is no `.agents/foreman/` copy). The
generic `rules/` are an authored distillation -- update them by hand when a dimension's
*method* changes. There is no mirror to re-sync; this repo's own `.agents/dev/audit/` is the
live worked example.

## Done when

For a **pass**: reproducible `metrics.sh` numbers, targets scored against the `rules/`
contracts (every 5 evidence-backed, false-positives refuted), raw output logged,
findings recorded with permanent IDs, and **every** actionable finding drained with
`Graduated:` backfilled. For a **deploy**: a `.agents/dev/audit/` that passes the host's gate,
a baseline `FINDINGS.md`, pinned exemplars, and a wired doc-index pointer.
