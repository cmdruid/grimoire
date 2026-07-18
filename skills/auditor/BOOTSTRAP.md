# BOOTSTRAP -- a portable code-quality audit system

A self-contained, language-neutral blueprint for a `.agents/dev/audit/` system that audits a project's
*own code* for quality and invariant-conformance, surfaces findings as a bounded + drained tracker,
and is re-runnable each cycle. Drop this file into any project and an agent can **reconstruct the
whole system**, or **borrow a piece**.

It is a sibling to any companion dev-system blueprint (one that blueprints the surrounding `.agents/foreman/` doc-system, if the host has one). This
file blueprints only the audit subsystem. It is deliberately project-agnostic: anything specific to
a host project -- its language, its sacred invariants, its trackers -- appears here as a **slot you
fill**, marked `<like this>`.

## How to use this file

- **Full deploy:** read *Principles*, fill the *Slots*, then create the *Manifest* files using the
  *Rule-file shape* and the per-file briefs. Wire the *Metrics script* and the *drains*.
- **Partial borrow:** the most valuable standalone borrow is the *Rule-file shape* (one uniform
  contract per dimension) + the *Finding lifecycle* (a tracker that drains into your existing
  trackers). Take those two and skip the rest.
- **Adapt to your stack:** the dimensions are language-neutral; only the **anti-pattern greps** and
  the **metrics recipes** are language-specific. Swap those; keep everything else.

---

## 1. Principles (the load-bearing ideas)

These are *why* the system is shaped as it is. Keep them even if you change the file layout.

- **Bounded + drained, like every .agents/foreman/ artifact.** The methodology is durable (re-read each pass);
  the finding tracker is *living* and **drains into the host project's existing trackers**, so it
  never becomes a second graveyard. (Same principle as the dev-system blueprint.)
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
| `<drains>` | The host's **existing** trackers a finding graduates into -- never a parallel queue. | `.records/tasks.md` (feature work) + `.records/bugs/` (defects) |
| `<exemplars>` | The in-repo files a score of 5 is measured against (often one library file + one service/system file). | filled by the *Select exemplars* step |
| `<gate>` | The host's quality command + the doc-linter the audit docs must satisfy. | `./tests/scripts/ci.sh` |

---

## 3. The two lifecycles

The system splits cleanly by how often each part changes -- keep them in separate files.

- **Durable methodology** -- `GUIDE.md` (the thin hub) + `rules/` (one file per dimension). Re-read
  each pass; revised only when the *method* changes, not when findings do.
- **Living tracker** -- `FINDINGS.md` (scorecards + open findings) + append-only `logs/` (raw
  per-pass output). Churns every pass.

Never mix them: a finding in `GUIDE.md`, or methodology in `FINDINGS.md`, is the drift this split
prevents. The living tracker's mechanics -- the finding entry shape, IDs, drains, and the sweep --
are in §7.

---

## 4. Directory & file manifest

```
.agents/dev/audit/
  README.md          -- subsystem index: the two lifecycles, the audit loop, the drains, and the
                        (deferred) "Select exemplars" step
  GUIDE.md           -- durable methodology hub: framing, risk-weighted scope, the rubric index,
                        scoring rules, process, severity, drains
  TEMPLATE.md        -- the finding-entry shape + how to file (IDs, themes, status, draining)
  FINDINGS.md        -- living tracker: pass-history table + per-pass scorecard + open findings
  rules/             -- one file per dimension, all in the uniform shape (§6)
  logs/
    README.md        -- the append-only per-pass log convention
    metrics.csv      -- trend history, one row per run, written by metrics.sh
  metrics.sh         -- the <language> objective-metrics script (§8)
  history/           -- (created on first sweep) dated resolved-findings records
```

Dependency direction: `README` -> `GUIDE` -> `rules/`; `TEMPLATE` -> `FINDINGS`. Build leaves
before indexes (rules before GUIDE before README) so each commit stays `<gate>`-green.

---

## 5. The rubric -- 12 portable dimensions + your native ones

Twelve language-neutral dimensions, each with a stable theme prefix (used for finding IDs). Score
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

`FINDINGS.md` **stages** findings; the host project's trackers **own** the committed work.

- **ID:** a themed, zero-padded sequential ID per theme (`DOC-01`, `GOD-03`, `DET-01`). Permanent
  -- never renumbered, even after resolution.
- **Entry shape** (in `TEMPLATE.md`): Status; Severity; Confidence (high/med/low); Effort (S/M/L);
  Dimension; Target; Location (`path:line` or `--`); Found (`YYYY-MM-DD (pass N)`); **`Graduated:`**
  (a link into a `<drain>`, or `--`); Finding (with the metric/`file:line` evidence); Fix;
  Resolution.
- **Drain:** an actionable finding graduates into a `<drain>` (feature work -> the backlog; a defect
  -> the bug store) and backfills `Graduated:`. There is **no parallel work queue** -- the audit
  surfaces, the host trackers schedule.
- **Sweep:** when `FINDINGS.md` grows, move resolved entries verbatim into
  `history/audit-findings-resolved-<date>.md`, keeping the live tracker short (bounded + drained).

Severity is **scaled to the audit's purpose**. For an ongoing-hygiene audit (no release gate): P0 =
a correctness / invariant violation to fix before relying on the code; P1 = a material quality gap;
P2 = a structural cleanup; P3 = polish. For a release-gating audit, redefine P0 as release-blocking
and add an exit gate. State which model you chose in `GUIDE.md`.

---

## 8. The metrics script (the `<language>` slot)

`metrics.sh` turns the rule-file grep recipes into reproducible numbers, prints a Markdown report,
and appends one trend row per run to `logs/metrics.csv`. It is the only deeply language-specific
file. Compute the quantifiable dimensions; never guess a number the script can produce. Typical
columns (rename per language):

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
5. **Which existing trackers absorb findings?** -> the `<drains>`. If the host has none, the audit's
   tracker can own the work -- but prefer draining into an existing system.
6. **What is the bar?** -> nominate `<exemplars>` (or defer to the *Select exemplars* step).

---

## 10. Deployment playbook

**Full deploy** (leaves-before-index, so each commit stays `<gate>`-green):
1. Fill the *Slots* (§2) via the *Decision walk* (§9).
2. Write the `rules/<dimension>.md` files from the *Rule-file shape* (§6) -- the 12 portable
   dimensions + your `<native dimensions>`, with `<language>` greps. (They reference `../GUIDE.md`
   in backticks, since it does not exist yet.)
3. Write `GUIDE.md` (the hub): framing, the risk-weighted `<targets>` table, the rubric index
   (linking each `rules/` file), scoring rules, process, severity, drains.
4. Write `TEMPLATE.md` then `FINDINGS.md` (the tracker skeleton).
5. Write `logs/README.md` + the `metrics.csv` header, then `README.md` (the index -- everything it
   links now exists).
6. Write `metrics.sh` (§8); run it for a baseline `metrics.csv` row; wire `--check` if you have an
   invariant to gate.
7. Wire the subsystem into the host's doc index (one pointer) and run `<gate>`.
8. Run a **lean baseline pass** (one reader per Deep/Mid target) to seed `FINDINGS.md` and prove
   the rubric is usable.

**Select exemplars (the deferred step).** Once the framework has landed, anchor it to real code:
scan the source, nominate the best-documented / cleanest representative file(s) (often one
pure-logic/library file + one service/system file), pin them as the score-5 `<exemplars>` in
`GUIDE.md`, and backfill calibrated `file:line` examples into each rule's *Calibrated examples* and
*Exemplars* sections. Do this before relying on cross-pass score comparisons.

**Build the verify automation when the rubric has stabilized.** A score-then-verify fan-out (one
agent per target reading its `rules/` file as the contract, then an adversarial verifier per high
score / gap claim) is worth authoring only after one manual pass confirms the rubric holds. Until
then, run passes by hand with the grep recipes.

---

## 11. Keeping this file current

This blueprint is a snapshot of a living system; it drifts unless maintained. Update it when
the system's *structure* changes -- a dimension added, the rule-file shape revised, the drain model
flipped -- not for routine rule-content edits. Treat it as one more thing the host's spine audit
checks, alongside a companion dev-system blueprint, if the host has one.
