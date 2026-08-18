---
name: auditor
description: "Drive a rubric-based code-quality audit on any repo: calibrate against the host's audit rubric (GUIDE.md + per-dimension rules/ + metrics.sh), scope by risk-weight, score with evidence, drain actionable findings. Standalone by default (rubric home confirmed once, default docs/audit/); on a workshop host the rubric is test-station doctrine. Pass reports land in the agent-records home; defects stay in the report and promote via the host's bug-filing lane. Use when the user runs `/auditor`, asks to score project code against that rubric, or to stand up the rubric. `setup` stands up the rubric; `metrics` runs metrics.sh; `check` runs the invariant gate. Audits PROJECT CODE against a rubric."
---

# auditor — the code-quality audit driver

Drive a **code-quality audit** over a project's own code against a **project-resident rubric**:
`GUIDE.md` (the methodology hub), `rules/` (one file per scored dimension), and `metrics.sh`
(the objective-counts script). This skill is a **thin driver**: the methodology, scoring rules,
and severity model live in the host's rubric and are the single source of truth — **re-read the
host's `GUIDE.md` each pass**; this skill orchestrates the loop, it does not restate the rubric.

If the host has **no rubric yet**, stand one up first (see *Setup mode*), then operate it. The
skill is self-contained: it bundles the blueprint and generic rules so it can stand the system
up anywhere.

## One environment probe (at entry)

The rubric is doctrine, so its home resolves like any other: the declared `agent-doctrine:`
(front-door `AGENTS.md` then `CLAUDE.md`), else `<agent-records>/doctrine` (default
`.records/doctrine/`). Resolving the home is not finding the rubric — resolve it, **then**
detect `GUIDE.md`. No mode ever refuses or stalls for lack of a workshop — standing one up is
the human's separate decision (the clankshop onramps), never an audit side effect.

Detection order, first hit wins:

1. **`<agent-doctrine>/test/workflows/audit/`** — the resolved home. The rubric is guardian
   doctrine (`GUIDE.md`, `rules/`, `metrics.sh`): an on-demand workflow of the test station,
   invisible to the always-on load set. Before a pass, summon the station's context with
   `<agent-doctrine>/scripts/context.sh test` when that loader exists.
2. **`docs/audit/GUIDE.md`** — the **legacy** home, still detected so rubrics already
   deployed there keep working (the same courtesy `records-root:` gets alongside
   `agent-records:`). Detected, never created fresh.
3. Neither → ask once (do not scan the repo).

`setup` stands the rubric up at the resolved home; **incumbent wins** — an existing rubric is
never overwritten, since a re-run would otherwise destroy the host's accumulated calibration.

Pass reports are agent-records `reports/` records on every host (file-mode if no tool).
Findings stay in the report; promote a defect with `/backlog bug`. Tracker lines only when the
tracker file already exists.

## What this skill bundles

- **`BOOTSTRAP.md`** — the portable blueprint: principles, slots, the uniform rule-file shape,
  the metrics-script structure, the decision-walk + setup playbook. The generic templates live
  inside it.
- **`rules/`** — a generic, language-neutral rule-set for the 12 portable dimensions
  (host-specific greps/exemplars as `<slots>`). The rubric `setup` stands up.

**Scope boundary:** `/auditor` audits **project code** (quality + the host's sacred
invariants). It is **not** a docs-system maintenance sweep. Different domain.

## Modes (selected by argument)

- **`setup`** — stand up the rubric on a project that lacks one (home per the probe).
- **(no arg) — a pass.** Run the audit loop, scoped to a risk-weighted target (or all).
- **`metrics`** — run the host's `metrics.sh`: print the report. No scoring.
- **`check`** — run `metrics.sh --check`: the invariant gate (a non-zero count of the host's
  native-invariant smell is a P0 and fails).
- **`<target>`** — a path scopes a pass to that path. Look it up in GUIDE's targets table
  for Deep / Mid / Light. If missing: Light unless the user named Deep.

Every mode works on any repo. The non-`setup` modes need `<home>/GUIDE.md` — missing →
point at `setup` and stop.

## Deliverables — drain through the records layer (workshop) or plain files (standalone)

The audit stages nothing in a home of its own: **no living findings tracker, no trend CSV, no
sequential finding IDs, no resolved-findings archive**. The path is the ID and the records
layer (or the dated report file) is the memory.

**Every host**, per pass:

- **The pass report** — one `reports` record under the agent-records home, tagged
  `audit`. Resolve `reports.md` via the agent-templates rule;
  `records.sh new reports --template <resolved> --title "Audit: <scope>"` when
  the tool exists; else file-mode from that path. Never write the flat
  `<agent-records>/templates/reports.md`. The reports store *is* the trend
  history. Close it `consumed` once its actionable findings are drained
  (`records.sh done` when the tool exists; else file-mode stamp).
- **Defects stay in the report.** Do not mint `bugs/`. Promote a defect with
  `/backlog bug`. Tracker lines only when the tracker file already exists;
  else the report is the queue.

Either way the drain discipline holds: the audit **surfaces and prioritizes**; the host's
trackers **own and schedule** the work. No parallel work queue. Drained findings, over time,
are also the signal that calibrates the rubric (exemplars, thresholds, false-positive lists).

## Setup mode

Follow the bundled `BOOTSTRAP.md`:

1. **Decision-walk (`BOOTSTRAP.md §9`)** — with the user, fill the slots: the `<language>`,
   the `<native dimensions>` (the host's sacred invariants), the `<targets>` (Deep/Mid/Light by
   blast radius), the `<drains>` (records layer or the host's existing trackers), and the
   audit's purpose (hygiene vs release-gating → severity model).
2. **Confirm the home** — resolved: `<agent-doctrine>/test/workflows/audit/` (no confirmation needed —
   doctrine has one home); standalone: propose `docs/audit/` and confirm once.
3. **Author the rubric** — copy the bundled generic `rules/` into `<home>/rules/`, fill the
   `<language>` greps and `How to quantify` recipes, and add a rule file per
   `<native dimension>`, following the uniform rule-file shape in `BOOTSTRAP.md`.
4. **Write the hub** (from `BOOTSTRAP.md` §12) — `<home>/GUIDE.md`: framing, the risk-weighted `<targets>` table, the
   rubric index, scoring rules, the finding-entry shape, severity, drains.
5. **Write `metrics.sh`** (`<home>/metrics.sh`, `BOOTSTRAP.md` §8 columns, copy §13 stub) for the `<language>`; run it
   for a baseline report; wire `--check` on the native invariant.
6. **Wire + gate** — workshop: add the routing hook (`<agent-doctrine>/core/ROUTING.md` classifies "audit the
   code" → this workflow) and a chore line in `<agent-doctrine>/test/POLICY.md` if the guardian should run it on
   cadence; standalone: one pointer from the host's doc index. Run the host's gate.
7. **Baseline pass + select exemplars** — run a lean pass to seed the first pass report, then
   pin the score-5 `<exemplars>` in `GUIDE.md` and backfill calibrated examples
   (`BOOTSTRAP.md §10`).

**Grimoire caveat (patient-zero):** never stand the system up in grimoire itself — exercise
setup only against throwaway fixtures.

## The audit loop (a pass)

Follow the host's `GUIDE.md` → *Process*; in brief:

1. **Calibrate.** (Workshop: summon test-station context first.) Read `GUIDE.md` and its
   pinned score-5 exemplars; read each `rules/` file's anchors before scoring it.
2. **Map / scope.** Pick targets by blast-radius depth (GUIDE's targets table), or honor a
   `<target>` arg. Plan the reading order Deep → Mid → Light.
3. **Quantify.** Run `metrics.sh` for reproducible counts *before* scoring; quote its numbers
   in the pass report.
4. **Score.** Each applicable dimension against its `rules/` file, one at a time. **Back every
   5 with a metric or `file:line`**; **refute each rule's known false-positives** before
   filing; conservative bias when two anchors fit.
5. **Record.** Write the pass report (reports record / dated file): scorecard + findings with
   evidence, per GUIDE's finding-entry shape.
6. **Drain.** Route every actionable finding per *Deliverables*; then close the report
   (`records.sh done <report> --as consumed` on a workshop host).

## Relationship to neighboring skills

- A drained *defect* graduates via the host's bug-filing lane (`/backlog bug` on a workshop
  host); a *feature* finding via its backlog capture (`/backlog task`); else the host's own
  equivalent.
- If the host has a **heavier, parallelized audit workflow** (score → adversarially verify →
  synthesize), reach for it when a single-reader pass isn't thorough enough.

## Keeping the bundle current (host = this skill's home repo)

`BOOTSTRAP.md` is **canonical here** — edit it in place (no deployed copy exists). The generic
`rules/` are an authored distillation — update them by hand when a dimension's *method*
changes. There is no mirror to re-sync.

## Project templates

- `reports.md`

## Done when

For a **pass**: reproducible `metrics.sh` numbers, targets scored against the `rules/`
contracts (every 5 evidence-backed, false-positives refuted), one pass report recorded, and
**every** actionable finding drained (report record + `/backlog bug` for defects;
tracker lines only when the tracker file exists; the report closed `consumed`).
For a **setup**: a rubric home that passes the host's gate, a
baseline pass report, pinned exemplars, and the wiring hook (routing/chore line or doc-index
pointer) in place.
For **metrics**: `metrics.sh` printed its report; no scores filed.
For **check**: show the script output. Exit 0 → stop. Non-zero → treat as a P0
defect and drain it (stay in the report; `/backlog bug` to promote), then stop.
If `metrics.sh` has no `--check`, say so and stop — that
is not a fail.
