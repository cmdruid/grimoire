---
name: auditor
description: "Drive a rubric-based code-quality audit on any repo: calibrate against the host's audit rubric (GUIDE.md + per-dimension rules/ + metrics.sh), scope by risk-weight, score with evidence, drain actionable findings. Standalone by default (rubric home confirmed once, default docs/audit/); on a workshop host the rubric is test-station doctrine and findings drain through the records layer (a reports record per pass, bugs records for defects, tracker lines for the rest). Use when the user runs `/auditor`, asks to audit/quality-check the codebase or a module, or to stand up the audit framework. `setup` stands up the rubric; `metrics` runs metrics.sh; `check` runs the invariant gate. Audits PROJECT CODE against a rubric."
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

Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a line matching
`Seeded from clankshop`)? That single fact picks the homes; nothing else about the host is
probed, and **no mode ever refuses or stalls for lack of a workshop** — standing one up is the
human's separate decision (the clankshop onramps), never an audit side effect.

- **Workshop present** → the rubric is guardian doctrine:
  `<root>/.handbook/test/workflows/audit/` (`GUIDE.md`, `rules/`, `metrics.sh`) — an
  on-demand workflow of the test station, invisible to the always-on load set. Before a pass,
  summon the station's context: `<root>/.handbook/scripts/context.sh test`. Deliverables drain
  through the **records layer** (see *Deliverables*), rooted at the declared `records-root:`
  (front-door `AGENTS.md` declaration), else `.records/`.
- **Standalone** → the rubric home is **confirmed once at setup** (default `docs/audit/`);
  pass reports are dated files in that home, and findings drain into the host's **own**
  trackers where any exist. Skip every records-layer seam rather than stalling on it.

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
- **`<target>`** — a path scopes a pass to that target at its depth.

Every mode works on any repo. The non-`setup` modes need the rubric to exist — no rubric yet →
point at `setup` and stop.

## Deliverables — drain through the records layer (workshop) or plain files (standalone)

The audit stages nothing in a home of its own: **no living findings tracker, no trend CSV, no
sequential finding IDs, no resolved-findings archive**. The path is the ID and the records
layer (or the dated report file) is the memory.

On a **workshop host**, per pass:

- **The pass report** — one `reports` record (`records.sh new reports --title "Audit: <scope>"`,
  tagged `audit`): the scorecard, the quoted `metrics.sh` numbers, and every finding with its
  evidence. The reports store *is* the trend history
  (`records.sh list --type reports --tag audit`). Close it `consumed` once its actionable
  findings are drained.
- **Defects** — each detailed defect finding becomes a `bugs` record (repro + evidence), linked
  from the pass report.
- **Everything actionable else** — one tracker line each, per journal's capture kinds: feature
  work / cleanup → **Backlog**; a project problem or risk → **Issues**; evidence the *rubric or
  framework itself* should change → **Feedback**. A line links its record
  (`[→ reports/… ]`) so the finding's evidence stays one hop away.

**Standalone**, per pass: one dated report file in the rubric home
(`<home>/YYYY-MM-DD-audit-<scope>.md`, same content shape); findings graduate into the host's
existing trackers, or — when the host has none — the report's own findings list is the queue.

Either way the drain discipline holds: the audit **surfaces and prioritizes**; the host's
trackers **own and schedule** the work. No parallel work queue. Drained findings, over time,
are also the signal that calibrates the rubric (exemplars, thresholds, false-positive lists).

## Setup mode

Follow the bundled `BOOTSTRAP.md`:

1. **Decision-walk (`BOOTSTRAP.md §9`)** — with the user, fill the slots: the `<language>`,
   the `<native dimensions>` (the host's sacred invariants), the `<targets>` (Deep/Mid/Light by
   blast radius), the `<drains>` (records layer or the host's existing trackers), and the
   audit's purpose (hygiene vs release-gating → severity model).
2. **Confirm the home** — workshop: `.handbook/test/workflows/audit/` (no confirmation needed —
   doctrine has one home); standalone: propose `docs/audit/` and confirm once.
3. **Author the rubric** — copy the bundled generic `rules/` into `<home>/rules/`, fill the
   `<language>` greps and `How to quantify` recipes, and add a rule file per
   `<native dimension>`, following the uniform rule-file shape in `BOOTSTRAP.md`.
4. **Write the hub** — `<home>/GUIDE.md`: framing, the risk-weighted `<targets>` table, the
   rubric index, scoring rules, the finding-entry shape, severity, drains.
5. **Write `metrics.sh`** (`<home>/metrics.sh`, `BOOTSTRAP.md §8`) for the `<language>`; run it
   for a baseline report; wire `--check` on the native invariant.
6. **Wire + gate** — workshop: add the routing hook (`core/ROUTING.md` classifies "audit the
   code" → this workflow) and a chore line in `test/POLICY.md` if the guardian should run it on
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

- A drained *defect* graduates via the host's bug-filing lane (`/journal bug` on a workshop
  host); a *feature* finding via its backlog capture (`/journal task`); else the host's own
  equivalent.
- If the host has a **heavier, parallelized audit workflow** (score → adversarially verify →
  synthesize), reach for it when a single-reader pass isn't thorough enough.

## Keeping the bundle current (host = this skill's home repo)

`BOOTSTRAP.md` is **canonical here** — edit it in place (no deployed copy exists). The generic
`rules/` are an authored distillation — update them by hand when a dimension's *method*
changes. There is no mirror to re-sync.

## Done when

For a **pass**: reproducible `metrics.sh` numbers, targets scored against the `rules/`
contracts (every 5 evidence-backed, false-positives refuted), one pass report recorded, and
**every** actionable finding drained to its home (workshop: bugs records + tracker lines, the
report closed `consumed`). For a **setup**: a rubric home that passes the host's gate, a
baseline pass report, pinned exemplars, and the wiring hook (routing/chore line or doc-index
pointer) in place.
