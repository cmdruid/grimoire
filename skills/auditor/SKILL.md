---
name: auditor
description: "Drive a rubric-based code-quality audit on any repo: calibrate against the host's audit rubric (GUIDE.md + per-dimension rules/ + metrics.sh), scope by risk-weight, score with evidence, and drain actionable findings. The rubric resolves under Auditor's fixed `.agents/skilldata` doctrine home. Pass reports land in fixed `.records`; defects stay in the report and promote via the host's bug-filing lane. Use when the user runs `/auditor`, asks to score project code against that rubric, or to stand up the rubric. `setup` stands up the rubric; `metrics` runs metrics.sh; `check` runs the invariant gate. Audits PROJECT CODE against a rubric."
---

# auditor — the code-quality audit driver

Drive a **code-quality audit** over a project's own code against a **project-resident rubric**:
`GUIDE.md` (the methodology hub), `rules/` (one file per scored dimension), and `metrics.sh`
(the objective-counts script). This skill is a **thin driver**: the methodology, scoring rules,
and severity model live in the host's rubric and are the single source of truth — **re-read the
host's `GUIDE.md` each pass**; this skill orchestrates the loop, it does not restate the rubric.

If the host has **no rubric yet**, offer the optional, time-intensive `/auditor setup` separately,
then stop. The skill is self-contained: it bundles the blueprint and generic rules so it can stand
the system up anywhere, but core project configuration never waits for it.

## One environment probe (at entry)

The rubric is Auditor-owned doctrine, so its fixed home is
`.agents/skilldata/auditor/doctrine/`. Locating the home is not finding the rubric — locate it, **then**
detect `GUIDE.md`. No pack lifecycle is a prerequisite; rubric setup is this
skill's explicit operation.

Detect `GUIDE.md` only at
`.agents/skilldata/auditor/doctrine/test/workflows/audit/`. The rubric is project doctrine
(`GUIDE.md`, `rules/`, `metrics.sh`) and is loaded directly for each pass. If it is absent,
ask once; do not scan the repo.

`setup` stands the rubric up at the resolved home; **incumbent wins** — an existing rubric is
never overwritten, since a re-run would otherwise destroy the host's accumulated calibration.

Pass reports are `.records/reports/` records on every host (file-mode if no tool).
Findings stay in the report; promote a defect via the host's bug-filing lane. If no
lane exists, stay in the report. Tracker lines only when the tracker file already exists.

## What this skill bundles

- **`BOOTSTRAP.md`** — the portable blueprint: principles, slots, the uniform rule-file shape,
  the metrics-script structure, the decision-walk + setup playbook. The generic templates live
  inside it.
- **`rules/`** — a generic, language-neutral rule-set for the 13 portable dimensions
  (host-specific greps/exemplars as `<slots>`). The rubric `setup` stands up.

**Scope boundary:** `/auditor` audits **project code** (quality + the host's sacred
invariants). It is **not** a docs-system maintenance sweep. Different domain.

## Modes (selected by argument)

- **`setup [<root>]`** — read `verbs/setup.md`; deploy the report template and interactively
  calibrate the rubric without running an audit.
- **(no arg) — a pass.** Run the audit loop, scoped to a risk-weighted target (or all).
- **`metrics`** — run the host's `metrics.sh`: print the report. No scoring.
- **`check`** — run `metrics.sh --check`: the invariant gate (a non-zero count of the host's
  native-invariant smell is a P0 and fails).
- **`migrate <source-path>`** — read `verbs/migrate.md`; upgrade owned audit records/templates.
- **`<target>`** — a path scopes a pass to that path. Look it up in GUIDE's targets table
  for Deep / Mid / Light. If missing: Light unless the user named Deep.

Every mode works on any repo. The non-`setup` modes need `<home>/GUIDE.md` — missing →
point at `setup` and stop.

## Deliverables — drain through the records layer (workshop) or plain files (standalone)

The audit stages nothing in a home of its own: **no living findings tracker, no trend CSV, no
sequential finding IDs, no resolved-findings archive**. The path is the ID and the records
layer (or the dated report file) is the memory.

**Every host**, per pass:

- **The pass report** — one record under `.records/reports/`, tagged
  `audit`. Resolve `reports.md` at `.agents/skilldata/auditor/templates/` when present; otherwise
  read bundled `templates/reports.md` without a project write. Only `/auditor setup` deploys a
  project copy. A recognized legacy location requires `/auditor migrate <path>` rather than silent adoption.
  `.records/records.sh new reports --schema auditor/audit@1 --template <resolved> --title "Audit: <scope>" --tag audit` when
  the tool exists; else file-mode with the same schema and resolved body, naming the file
  `YYYY-MM-DD-<slug>.md` (the record shape). Never write the flat
  `.records/templates/reports.md`. A project template carrying `schema:` refuses. Current front matter requires `doctype`, `status`,
  `schema`, and `tags`; ordinary edits stamp no generic date or revision. The reports store *is* the trend
  history. Close it `consumed` once its actionable findings are drained
  (`.records/records.sh done` when the tool exists; else file-mode stamp).
- **Defects stay in the report.** Do not mint `bugs/`. Promote a defect via
  the host's bug-filing lane. If no lane exists, stay in the report. Tracker
  lines only when the tracker file already exists; else the report is the queue.

Either way the drain discipline holds: the audit **surfaces and prioritizes**; the host's
trackers **own and schedule** the work. No parallel work queue. Drained findings, over time,
are also the signal that calibrates the rubric (exemplars, thresholds, false-positive lists).

## Setup mode

`/auditor setup [<root>]` reads and follows `verbs/setup.md`. It seeds the active report template
and rubric leaves, then performs `BOOTSTRAP.md`'s decision walk and rubric calibration with the user.
It does not run the audit loop, mint the first report, or add a host-index/routing pointer.

**Grimoire caveat (patient-zero):** never stand the system up in grimoire itself — exercise
setup only against throwaway fixtures.

## The audit loop (a pass)

Follow the host's `GUIDE.md` → *Process*; in brief:

1. **Calibrate.** Read `GUIDE.md` and its
   pinned score-5 exemplars; read each `rules/` file's anchors before scoring it.
2. **Map / scope.** Pick targets by blast-radius depth (GUIDE's targets table), or honor a
   `<target>` arg. Plan the reading order Deep → Mid → Light.
3. **Quantify.** Run `metrics.sh` for reproducible facts *before* scoring; quote its output
   in the pass report. An explicit unavailable metric is reproducible when its analyzer identity,
   population, exclusions, and limitation are stated; never invent a replacement number.
4. **Score.** Each applicable dimension against its `rules/` file, one at a time. **Back every
   5 with a metric or `file:line`**; **refute each rule's known false-positives** before
   filing; conservative bias when two anchors fit. Score only a rule indexed by the host GUIDE;
   an absent-only seeded leaf is inactive until the owner adopts and indexes it.
5. **Record.** Write the pass report (reports record / dated file): scorecard + findings with
   evidence, per GUIDE's finding-entry shape.
6. **Drain.** Route every actionable finding per *Deliverables*; then close the report
   (`.records/records.sh done <report> --as consumed` on a workshop host).

## Relationship to neighboring skills

- A drained *defect* graduates via the host's bug-filing lane; a *feature* finding via
  the host's backlog capture; else the host's own equivalent. Stay in the report if no
  lane exists.
- If the host has a **heavier, parallelized audit workflow** (score → adversarially verify →
  synthesize), reach for it when a single-reader pass isn't thorough enough.

## Keeping the bundle current (host = this skill's home repo)

`BOOTSTRAP.md` is **canonical here** — edit it in place (no deployed copy exists). The generic
`rules/` are an authored distillation — update them by hand when a dimension's *method*
changes. There is no mirror to re-sync.

## Project templates

- `reports.md`

## Edges

<!-- edges:auditor -->
- produces: report — a pass report tagged audit
- handoff: — (none; findings drain through the host's capture lane)
- consumes: doctrine — the host's resolved audit rubric
<!-- /edges:auditor -->

## Done when

For a **pass**: reproducible `metrics.sh` facts, targets scored against the `rules/`
contracts (every 5 evidence-backed, false-positives refuted), one pass report recorded, and
**every** actionable finding drained (report record + the host's bug-filing lane for
defects; tracker lines only when the tracker file exists; the report closed `consumed`).
For **setup**: the active report template and calibrated rubric pass their checks; no audit report
or host-index/routing pointer was created. The first pass remains a separate explicit invocation.
For **metrics**: `metrics.sh` printed its report; no scores filed.
For **check**: show the script output. Exit 0 → stop. Non-zero → treat as a P0
defect and drain it (stay in the report; host's bug-filing lane to promote), then stop.
If `metrics.sh` has no `--check`, say so and stop — that
is not a fail.
