# BOOTSTRAP -- a portable code-quality audit system

A self-contained, language-neutral blueprint for a code-quality audit system, split by how often
each part changes: the **rubric** (hand-curated source of truth -- `GUIDE.md`, `rules/`,
`metrics.sh`, in the host's rubric home) and the **deliverables** (per-pass output, drained into
the host's records or trackers -- never a standing store of the audit's own). It audits a
project's *own code* for quality and invariant-conformance, surfaces findings with evidence, and
is re-runnable each cycle. Drop this file into any project and an agent can **reconstruct the
whole system**, or **borrow a piece**.

The rubric home is mode-dependent (see the skill's entry probe): on a clankshop workshop host it
is `.handbook/test/workflows/audit/` (guardian doctrine, loaded on demand); standalone it is a
directory confirmed once at setup (default `docs/audit/`). `<home>` below means that directory.

It is a sibling to any companion dev-system blueprint (one that blueprints the surrounding deployed doc-system, if the host has one). This
file blueprints only the audit subsystem. It is deliberately project-agnostic: anything specific to
a host project -- its language, its sacred invariants, its trackers -- appears here as a **slot you
fill**, marked `<like this>`.

## How to use this file

- **Full setup:** read *Principles*, fill the *Slots*, then copy the bundled `rules/`
  (fill `<language>` slots; write only `<native dimensions>` from the *Rule-file shape*).
  Author `GUIDE.md` and `metrics.sh` from §12 / §13. Wire the *drains*.
- **Partial borrow:** the most valuable standalone borrow is the *Rule-file shape* (one uniform
  contract per dimension) + the *Finding lifecycle* (a pass report that drains into the host's existing trackers,
  or is the queue when the host has none). Take those two and skip the rest.
- **Adapt to your stack:** the dimensions are language-neutral; only the **anti-pattern greps** and
  the **metrics recipes** are language-specific. Swap those; keep everything else.

---

## 1. Principles (the load-bearing ideas)

These are *why* the system is shaped as it is. Keep them even if you change the file layout.

- **Bounded + drained.** The methodology is durable (re-read each pass); findings **drain into
  the host's existing records and trackers the moment a pass ends**, so the audit never grows a
  second graveyard of its own. The audit surfaces and prioritizes; the host schedules.
- **One rule file per dimension, all in one shape.** An agent (or subagent) reads exactly one file
  and has the complete scoring contract for that dimension. Uniformity is what makes the audit
  parallelizable and calibratable.
- **Score, then *verify*.** Lean single-reader scans run generous and over-claim. The second,
  adversarial pass -- re-checking every high score and every "untested"/"duplicated" claim -- is
  where finding quality comes from. Build it in (even if deferred to a later automation).
- **A 5 is earned, never asserted.** A top score requires a *metric* ("module-doc on 114/115
  files") or cited `file:line` examples -- never "looks good." This is the single rule that keeps
  scores honest across passes.
- **Anchor to real code, not an ideal.** Calibrate scores against in-repo *exemplars* ("a 5 means
  it matches `<this file>`"). Abstract ideals drift; real anchors don't.
- **Weight by blast radius.** Audit depth is allocated by how far a defect propagates, not
  symmetrically. The core library and the public surface get deep passes; leaf utilities get light
  ones.
- **The host's invariants become first-class dimensions.** Generic quality dimensions are portable;
  but a project's *sacred invariants* (determinism, a security boundary, a real-time budget) deserve
  their own scored dimension. That is where this framework earns its keep over a generic linter.

---

## 2. Slots -- fill these for your project

Decide these before reconstructing. They are what make the generic framework yours.

| Slot | What it is | Example fill (replace) |
|---|---|---|
| `<language>` | The implementation language -> drives the anti-pattern greps + metrics recipes. | Rust / TypeScript / Python |
| `<native dimensions>` | The host's sacred invariants, each promoted to a scored dimension atop the 12 portable ones. | "Determinism" (worldgen pure in `(seed, pos)`); "AI-boundary" |
| `<targets>` | The audited units, each tagged Deep / Mid / Light by blast radius. | `voxel/`, `content/` (Deep); `ai/` (Mid); `config.rs` (Light) |
| `<drains>` | The host's **existing** capture homes a finding graduates into -- never a parallel queue. | report record + `/backlog bug` for defects; tracker lines only when the tracker file already exists |
| `<exemplars>` | The in-repo files a score of 5 is measured against (often one library file + one service/system file). | filled by the *Select exemplars* step |
| `<gate>` | The host's quality command the audit run must satisfy. | `./tests/scripts/ci.sh` |

---

## 3. The two lifecycles

The system splits cleanly by how often each part changes.

- **Durable methodology -- the rubric, `<home>`.** `GUIDE.md` (the hub, carrying the
  finding-entry shape), `rules/` (one file per dimension), and `metrics.sh` (the authored
  metric-computation tool). Re-read each pass; revised only when the *method* changes, not when
  findings do. Hand-curated doctrine.
- **Per-pass deliverables -- drained, never stored by the audit.** Each pass produces one
  **pass report** (a `reports` record under the agent-records home, tagged `audit`)
  holding the scorecard, the quoted metrics, and every finding with
  evidence -- then every actionable finding **drains** to its `<drain>` and the report closes.
  The sequence of pass reports *is* the trend history; there is no separate findings tracker,
  log directory, or CSV to tend.

Never mix them: a finding in `GUIDE.md` is the drift this split prevents. The flow is not
one-way: drained findings are the signal that periodically **calibrates** the rubric
(exemplars, thresholds, known false-positives).

---

## 4. Directory & file manifest

One authored home (the rubric); deliverables drain per §3:

```
<home>/               -- the rubric (hand-curated, source of truth)
                         workshop: .handbook/test/workflows/audit/ · standalone: docs/audit/
  GUIDE.md            -- the hub: framing, risk-weighted scope, the rubric index, scoring
                         rules, process, the finding-entry shape, severity, drains
  rules/              -- one file per dimension, all in the uniform shape (§6)
  metrics.sh          -- the <language> objective-metrics script (§8)
```

Pass reports are `reports` records under the agent-records home and never live
in `<home>`. Dependency
direction: `GUIDE` -> `rules/`. Build leaves before indexes (rules before GUIDE) so each commit
stays `<gate>`-green.

---

## 5. The rubric -- 12 portable dimensions + your native ones

Twelve language-neutral dimensions, each with a stable theme prefix (the Dimension tag on a finding, not an ID). Score
each **1-5** where 5 = matches the `<exemplars>`.

| Dimension | Theme | Question it answers |
|---|:--:|---|
| Findability | `FND` | Can you locate a symbol from its name alone? |
| Readability | `READ` | Can you read it top-to-bottom without backtracking? |
| Documentation | `DOC` | Is intent + public API documented to the exemplar bar? |
| DRY | `DRY` | Is each rule expressed exactly once? |
| God-files | `GOD` | Does any unit do more than one job? |
| Error Handling | `ERR` | Are errors typed, guarded, and fail-closed? |
| Type Safety | `TYPE` | Do the types carry the invariants, or are they escaped? |
| Security | `SEC` | Are the trust boundaries held and secrets kept out of every observable sink? |
| Observability | `OBS` | Is logging structured, routed, and free of stray output? |
| Performance | `PERF` | Do hot paths avoid asymptotic/structural waste? |
| Technical Debt | `DEBT` | Is transitional code removed, or fenced and dated? |
| Testing | `COV` | Do the tests prove it is safe to ship? |

Then **add your `<native dimensions>`** with fresh theme prefixes (e.g. `DET` Determinism, `AIB`
AI-boundary). A native dimension is justified when a host invariant, if broken, breaks the project
-- and no generic dimension already owns it.

**State the boundaries.** Where two dimensions share adjacent ground, write the seam into the rule
files so a finding lands in exactly one: e.g. *Type Safety* owns casts/unsafe, *Error Handling* owns
the throw/Result side; *Observability* owns logging structure, *Security* owns "no secret reaches a
sink."

---

## 6. The uniform rule-file shape (the authoring contract)

Every `rules/<dimension>.md` follows this skeleton, in this order. Reading one file gives the full
scoring contract for that dimension. Copy it verbatim as the template:

````
# <Dimension> -- audit rule
> <the one-line question this dimension answers>

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `<PREFIX>`.

## Why it matters
<the risk this dimension guards against, in this project's terms.>

## Scoring anchors (1-5)
- 5 -- <matches the exemplars: the specific, observable bar.>
- 4 -- <minor, low-blast-radius deviations.>
- 3 -- <clear improvement candidates.>
- 2 -- <several real problems.>
- 1 -- <pervasive failure.>

## Decision logic
<the ordered steps to apply when scoring -- do not score from surface similarity alone.>

## Anti-patterns (greppable smells)
```<shell>
<language-specific grep/awk recipes that surface candidates. The grep is the PROMPT, not the finding.>
```

## Calibrated examples
<a small table of real in-repo units with score + location + why. Starts empty; filled by the
Select-exemplars step and by passes.>

## Known false-positives
<the traps: things that look like a finding but are not. Refute a candidate against these before
filing.>

## How to quantify
<the exact metric recipe (or "read-and-name -- no metric") so a number is never guessed.>

## Exemplars
<the anchor file(s) for this dimension: the positive bar, and an anti-exemplar if one exists.>
````

Until the *Select exemplars* step runs, the *Calibrated examples* and *Exemplars* sections hold an
**abstract written standard** (describe the bar in prose) rather than pinned files.

---

## 7. The finding lifecycle + drains

The **pass report** stages findings; the host's records and trackers **own** the committed
work. No sequential IDs, no living findings tracker, no resolved-findings archive: the report's
path is the ID, and a finding is cited as `<report-path>` + its heading.

- **Entry shape** (stated in `GUIDE.md`): a `###` heading per finding, then Severity;
  Confidence (high/med/low); Effort (S/M/L); Dimension; Target; Location (`path:line` or
  `--`); Drained (a link/line reference into a `<drain>`, or `--` while open); Finding (with
  the metric/`file:line` evidence); Fix.
- **Drain -- by kind, at pass end.** A **defect** stays in the report; promote it with
  `/backlog bug`. **Feature work / cleanup** becomes a Backlog tracker line only when
  that tracker file already exists. A **project problem or risk** becomes an Issues
  line the same way. Evidence the *rubric or framework itself* should change becomes
  a Feedback line. Else the report is the queue. Backfill each finding's `Drained:`
  field as it graduates. There is **no parallel work queue** -- the audit surfaces,
  the host trackers schedule. Do not mint `bugs/`.
- **Close the report.** Once every actionable finding is drained, close the pass report
  (`records.sh done <report> --as consumed --note "findings drained"` when the tool
  exists; else file-mode stamp).

Severity is **scaled to the audit's purpose**. For an ongoing-hygiene audit (no release gate): P0 =
a correctness / invariant violation to fix before relying on the code; P1 = a material quality gap;
P2 = a structural cleanup; P3 = polish. For a release-gating audit, redefine P0 as release-blocking
and add an exit gate. State which model you chose in `GUIDE.md`.

---

## 8. The metrics script (the `<language>` slot)

`metrics.sh` turns the rule-file grep recipes into reproducible numbers and prints a Markdown
report -- quote it verbatim in the pass report, which is where the numbers persist (the report
sequence is the trend; the script keeps no state of its own). It is the only deeply
language-specific file. Compute the quantifiable dimensions; never guess a number the script can
produce. Typical columns (rename per language):

- **doc coverage** -- module-header coverage + public-item doc coverage.
- **structure** -- count of files over a size threshold + the largest file.
- **robustness** -- count of the language's unsafe escape hatches (unchecked unwraps, panics, raw
  casts, `unsafe`/`any`).
- **debt** -- count of debt markers (`TODO`/`FIXME`/`HACK`).
- **testing** -- a test-quantity proxy (test count or test:src ratio).
- **invariant guard** -- a count of the host's `<native dimension>` smells in the sensitive
  modules. Wire this into an optional `--check` that **fails** when it is non-zero -- the one
  invariant worth gating even in a no-gate hygiene audit.

Keep it dependency-free (shell + the language's own grep-able source). Document each column's recipe
and its caveats (a coverage proxy is presence, not completeness).

---

## 9. The decision walk -- instantiate in a new project

Answer these in order; the answers fill the *Slots* and shape the rubric:

1. **What `<language>`?** -> derive the anti-pattern greps and the metrics recipes. (What are its
   escape hatches: unchecked errors, raw casts, `unsafe`/`any`, dynamic eval?)
2. **What is sacred here?** -> the host invariants that, if broken, break the project become your
   `<native dimensions>`. (Determinism? A fund-safety boundary? A latency budget? Backward-compat?)
3. **What is the audit *for*?** -> hygiene (no gate, drain to trackers) vs release-gating (a hard
   P0 gate). This sets the severity model (§7).
4. **Where does blast radius concentrate?** -> tag each `<target>` Deep / Mid / Light.
5. **Which existing trackers absorb findings?** -> the `<drains>`. If the host has none, the
   pass report's own findings list is the queue.
6. **What is the bar?** -> nominate `<exemplars>` (or defer to the *Select exemplars* step).

---

## 10. Setup playbook

**Full setup** (leaves-before-index, so each commit stays `<gate>`-green):
1. Fill the *Slots* (§2) via the *Decision walk* (§9); resolve `<home>` per the skill's entry
   probe (workshop: `.handbook/test/workflows/audit/`; standalone: confirm once, default
   `docs/audit/`).
2. Copy the bundled generic `rules/` into `<home>/rules/`. Fill the `<language>` greps
   and *How to quantify* recipes. Write only `<native dimensions>` from the *Rule-file
   shape* (§6). (They reference `../GUIDE.md` in backticks, since it does not exist yet.)
3. Write `GUIDE.md` from §12; fill the slots.
4. Write `metrics.sh` from §13; run it for a baseline; wire `--check` if you have an invariant to gate.
5. Wire the rubric in -- workshop: a `.handbook/core/ROUTING.md` row ("audit the code" -> this workflow)
   and, if the guardian should run it on cadence, a chore line in `.handbook/test/POLICY.md`; standalone:
   one pointer from the host's doc index. Run `<gate>`.
6. Run a **lean baseline pass** (one reader per Deep/Mid target) to produce the first pass
   report and prove the rubric is usable.

**Select exemplars (the deferred step).** Once the framework has landed, anchor it to real code:
scan the source, nominate the best-documented / cleanest representative file(s) (often one
pure-logic/library file + one service/system file), pin them as the score-5 `<exemplars>` in
`<home>/GUIDE.md`, and backfill calibrated `file:line` examples into each rule's *Calibrated
examples* and *Exemplars* sections. Do this before relying on cross-pass score comparisons.

**Build the verify automation when the rubric has stabilized.** A score-then-verify fan-out (one
agent per target reading its `rules/` file as the contract, then an adversarial verifier per high
score / gap claim) is worth authoring only after one manual pass confirms the rubric holds. Until
then, run passes by hand with the grep recipes.

---

## 11. Keeping this file current

This blueprint is a snapshot of a living system; it drifts unless maintained. Update it when
the system's *structure* changes -- a dimension added, the rule-file shape revised, the drain model
flipped -- not for routine rule-content edits. Treat it as one more thing the host's doc-audit
sweep checks, if the host has one.

---

## 12. GUIDE.md skeleton

Copy into `<home>/GUIDE.md` and fill the slots. Do not invent extra stores.

````markdown
# <project> code-quality audit — GUIDE

<one paragraph: hygiene vs release-gating, and what a 5 means here>

## Targets (blast radius)

| Target | Depth | Why |
|---|---|---|
| `<path>` | Deep / Mid / Light | `<blast-radius reason>` |

## Rubric index

| Dimension | File | Theme |
|---|---|---|
| Findability | `rules/findability.md` | `FND` |
| Readability | `rules/readability.md` | `READ` |
| Documentation | `rules/documentation.md` | `DOC` |
| DRY | `rules/dry.md` | `DRY` |
| God-files | `rules/god-files.md` | `GOD` |
| Error Handling | `rules/error-handling.md` | `ERR` |
| Type Safety | `rules/type-safety.md` | `TYPE` |
| Security | `rules/security.md` | `SEC` |
| Observability | `rules/observability.md` | `OBS` |
| Performance | `rules/performance.md` | `PERF` |
| Technical Debt | `rules/technical-debt.md` | `DEBT` |
| Testing | `rules/testing.md` | `COV` |
| `<native>` | `rules/<native>.md` | `<PREFIX>` |

## Scoring

- Score 1-5 per dimension. A 5 requires a metric or `file:line`.
- When two anchors fit, use the lower one.
- Refute each rule's known false-positives before filing.

## Process

1. Calibrate — read this file's exemplars; read each rule's anchors.
2. Map / scope — Deep → Mid → Light, or honor a `<target>` arg
   (lookup in the targets table; missing → Light unless the
   user named Deep).
3. Quantify — run `./metrics.sh`; quote the numbers in the pass report.
4. Score — one dimension at a time against its rule file.
5. Record — write the pass report (shape below).
6. Drain — every actionable finding to a `<drain>`; then close the report.

## Finding-entry shape

### <short name>
- Severity: P0–P3
- Confidence: high / med / low
- Effort: S / M / L
- Dimension: `<PREFIX>`
- Target: `<path>`
- Location: `path:line` or `--`
- Drained: `<drain link>` or `--`
- Finding: <claim + metric or file:line>
- Fix: <action>

## Severity

<hygiene: P0 = invariant/correctness; P1 = material quality; P2 = cleanup; P3 = polish.
Or the release-gating model: P0 = release-blocking.>

## Drains

<report record + `/backlog bug` for defects; tracker lines only when the
tracker file already exists; else this report's findings list is the queue.>

## Bench (optional)

<command to measure PERF, or "none". If none, do not file PERF findings; cap PERF at 4.>

## Exemplars (score-5 anchors)

_Pin after the baseline pass. Until then, the written standard in each rule file is the bar._
````

---

## 13. metrics.sh stub

Copy into `<home>/metrics.sh`, fill `<language>` greps, `chmod +x`.
Dependency-free (shell + the language's own grep-able source).
Columns are presence proxies, not completeness. Quote the printed
report in the pass report; this script keeps no state.

```bash
#!/usr/bin/env bash
# <home>/metrics.sh — objective counts for the <project> audit.
# Usage: metrics.sh [--check]
# --check: exit 1 if the native-invariant smell count is non-zero.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# <language: set src= to the source glob, e.g. '$root/src'>
src="${SRC:-$root}"

# --- recipes (fill) ---
# doc coverage: <language: module-header recipe> / <language: public-item recipe>
headers=0; files=0; pub_doc=0; pub_all=0
# structure
over=0; largest=""; largest_n=0
# robustness / debt / tests / invariant
unchecked=0; debt=0; tests=0; invariant=0

# <fill each counter from the rule-file How-to-quantify recipes>

if [ "${1:-}" = "--check" ]; then
  echo "invariant_smells=$invariant"
  [ "$invariant" -eq 0 ]
  exit $?
fi

cat <<EOF
# Metrics

| Column | Value |
|---|---|
| module-header coverage | $headers / $files |
| public-item docs | $pub_doc / $pub_all |
| files over threshold | $over (largest: $largest $largest_n) |
| unchecked-error sites | $unchecked |
| debt markers | $debt |
| unit tests | $tests |
| native-invariant smells | $invariant |
EOF
```

