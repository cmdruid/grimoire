---
name: auditor
description: "Deploy and operate a code-quality audit framework split source-vs-record: the rubric (GUIDE.md, rules/, metrics.sh) is a project's .agents/roles/auditor/ seed; deliverables (FINDINGS.md, logs/, metrics.csv, history/) accumulate in .records/audit/. Calibrate against GUIDE.md, scope by risk-weight, run metrics.sh, score targets against the rules/ dimensions, log and record findings, and drain actionable findings to the host's trackers -- which in turn calibrate the rubric. Use when the user runs `/auditor`, asks to audit/quality-check the codebase or a module, or to stand up the audit framework on a project that lacks one. `/auditor deploy` bootstraps both homes from the bundled BOOTSTRAP.md; `/auditor metrics` runs metrics.sh; `/auditor check` runs the invariant gate. This audits PROJECT CODE — code quality scored against a rubric."
---

# auditor — the code-quality audit driver

Drive a **code-quality audit** over a project's own code using a **split-home** system: the
rubric lives in `.agents/roles/auditor/` (source of truth, hand-curated); the deliverables
accumulate in `.records/audit/` (per-run outputs). This skill is a **thin driver**: the
methodology, rubric, scoring rules, and severity model live in the host's
`.agents/roles/auditor/GUIDE.md` (+ the per-dimension `rules/` files) and are the single source of
truth -- **re-read `GUIDE.md` each pass**; this skill orchestrates the loop, it does not
restate the rubric.

If the host project has **no `.agents/roles/auditor/` (rubric) or `.records/audit/` (deliverables)
yet**, deploy both first (see *Deploy mode*), then operate them. The skill is self-contained:
it bundles the blueprint and a worked example so it can stand the system up anywhere.

## What this skill bundles

- **`BOOTSTRAP.md`** -- the portable blueprint: principles, slots, the uniform
  rule-file shape, the metrics-script structure, the decision-walk + deployment
  playbook. The generic templates live inside it.
- **`rules/`** -- a generic, language-neutral rule-set for the 12 portable dimensions
  (host-specific greps/exemplars as `<slots>`). The deployable rubric.

There is **no generated worked-example mirror.** Scaffold from `BOOTSTRAP.md` (its
deployment playbook + the inline rule/template shapes) and use the **host repo's own
`.agents/roles/auditor/` + `.records/audit/`**, as they fill in, as the live example.

**Scope boundary:** `/auditor` audits **project code** (quality + the host's sacred
invariants). It is **not** a docs-system maintenance sweep. Different domain.

## Modes (selected by argument)

- **`deploy`** (alias `init`) -- stand up `.agents/roles/auditor/` (rubric) and `.records/audit/`
  (deliverables) on a project that lacks them.
- **(no arg) -- a pass.** Run the audit loop, scoped to a risk-weighted target (or all).
- **`metrics`** -- run the host's `.agents/roles/auditor/metrics.sh`: print the report, append the
  trend row to `.records/audit/logs/metrics.csv`. No scoring.
- **`check`** -- run `.agents/roles/auditor/metrics.sh --check`: the invariant gate (a non-zero
  count of the host's native-invariant smell is a P0 and fails).
- **`<target>`** -- a path scopes a pass to that target at its depth.

**Unstamped conduct:** `deploy` is a **writer** on an unstamped root — exactly its pre-stamp
license: the seat (`.agents/roles/auditor/`), the deliverables home (`.records/audit/`), and the
installation block (created-or-adopted). **Every other mode is read-only on an unstamped root**:
emit `unstamped`, point at the clankshop onramps (or `deploy`), and stop.

## Deploy mode

When the host has no `.agents/roles/auditor/` or `.records/audit/`, follow the bundled `BOOTSTRAP.md`:

1. **Decision-walk (`BOOTSTRAP.md §9`)** -- with the user, fill the slots: the
   `<language>`, the `<native dimensions>` (the host's sacred invariants), the
   `<targets>` (Deep/Mid/Light by blast radius), the `<drains>` (existing trackers),
   and the audit's purpose (hygiene vs release-gating -> severity model).
2. **Author the rubric** -- copy the bundled generic `rules/` into the host's
   `.agents/roles/auditor/rules/`, fill the `<language>` greps and `How to quantify` recipes, and
   add a rule file per `<native dimension>`, following the uniform rule-file shape in
   `BOOTSTRAP.md` (a native dimension states the host's sacred invariant + the grep that
   smells a violation).
3. **Write the hub + tracker** -- `GUIDE.md`, `TEMPLATE.md` (both `.agents/roles/auditor/`), then
   `FINDINGS.md`, `logs/README.md` + `metrics.csv` header (both `.records/audit/`), then
   `README.md` (`.agents/roles/auditor/`), following the manifest and leaves-before-index order in
   `BOOTSTRAP.md §4`/`§10`.
4. **Write `metrics.sh`** (`.agents/roles/auditor/metrics.sh`, `BOOTSTRAP.md §8`) for the
   `<language>`; run it for a baseline `.records/audit/logs/metrics.csv` row; wire `--check`
   on the native invariant.
5. **Wire + gate** -- add one pointer from the host's doc index; run the host's gate.
6. **Register the front-door route — the pack-style block — and stamp the root.** `deploy` keeps
   its pre-stamp write right: it self-inits both homes on an unstamped root and
   **creates-or-adopts the installation block** (the pack face's `install-block.sh write
   <root> 1`), so a bare single-role install yields a resolvable installation. The registration
   body is auditor's entry in the pack doctrine's **door profile** (the fenced `### /auditor`
   block in `skills/clankshop/doctrine/README.md` — copied verbatim, never authored here),
   stamped `clankshop@<pack-version>` (from the installation block when pack-stamped, else the
   pack manifest's `version:` — the pack face's `PACK.md`), carrying **no `Edges:` lines**. The front door must **exist**;
   a missing front door is a project-setup gap, say so and stop before writing. Feed the body on
   stdin to `scripts/register-route.sh <front-door> auditor clankshop@<pack-version>`:
   ```markdown
   ### /auditor — code quality
   Route: rubric-driven code-quality audits; findings and history in `.records/audit/`.
   ```
   An existing pack-style block written by setup is **adopted** (re-running converges
   byte-identically). Report `appended`/`replaced`; if **malformed**, surface it and stop -- a
   delimiter was hand-broken, the human repairs it, never force it. Idempotent: re-running
   `deploy` rewrites only auditor's own `skill:auditor` block, never a sibling's.
   **Grimoire caveat (patient-zero):** never register against grimoire's own authored
   `AGENTS.md` -- this step is exercised only against a throwaway fixture front-door.
7. **Baseline pass + Select exemplars** -- run a lean pass to seed `FINDINGS.md`, then
   pin the score-5 `<exemplars>` in `.agents/roles/auditor/GUIDE.md` and backfill calibrated
   examples (`BOOTSTRAP.md §10`).

## The audit loop (a pass)

Follow the host's `.agents/roles/auditor/GUIDE.md` -> *Process*; in brief:

1. **Calibrate.** Read `GUIDE.md` and its pinned score-5 exemplars (GUIDE's
   pinned-exemplars section); read
   each `rules/` file's anchors before scoring it.
2. **Map / scope.** Pick targets by blast-radius depth (GUIDE's targets table), or honor a
   `<target>` arg. Plan the reading order Deep -> Mid -> Light.
3. **Quantify.** Run `.agents/roles/auditor/metrics.sh` for reproducible counts *before* scoring;
   quote the latest `.records/audit/logs/metrics.csv` numbers in the scorecard.
4. **Score.** Each applicable dimension against its `rules/` file, one at a time.
   **Back every 5 with a metric or `file:line`**; **refute each rule's known
   false-positives** before filing; conservative bias when two anchors fit.
5. **Log.** Append raw output + per-run notes under `.records/audit/logs/` (dated, one
   file/pass).
6. **Record.** Curate findings into `.records/audit/FINDINGS.md` using
   `.agents/roles/auditor/TEMPLATE.md`'s entry shape -- permanent themed IDs, Severity, evidence
   in the **Finding** field.
7. **Drain -- two bars.** An **ordinary code finding** graduates into the host's `<drains>`
   (backfill `Graduated:`); a finding that passes the **system-improvement bar** -- evidence the
   *framework* should change, not the project's code -- feeds the improvement loop's intake,
   which stamps the entry's `processed:` field when drained. The audit surfaces and prioritizes;
   the host trackers and the loop schedule. **No parallel work queue.** If the host has no
   trackers, the audit's own tracker owns the work (`BOOTSTRAP.md §9`). Drained findings, over
   time, are also the signal that calibrates the `.agents/roles/auditor/` rubric (exemplars,
   thresholds, false-positive lists).

When `FINDINGS.md` grows large, sweep resolved entries into `.records/audit/history/`.

## Relationship to neighboring skills

- If the host has a **bug-filing** skill, a drained *defect* graduates via it; else
  file a report under the host's defect store directly.
- If the host has a **backlog** skill/file, a drained *feature* finding graduates into
  it; else into the host's equivalent.
- If the host has a **heavier, parallelized audit workflow** (score -> adversarially
  verify -> synthesize), reach for it when a single-reader pass isn't thorough enough.

## Keeping the bundle current (host = this skill's home repo)

`BOOTSTRAP.md` is **canonical here** -- edit it in place (no deployed copy exists). The
generic `rules/` are an authored distillation -- update them by hand when a dimension's
*method* changes. There is no mirror to re-sync; this repo's own `.agents/roles/auditor/` +
`.records/audit/`, once deployed, are the live worked example.

## Done when

For a **pass**: reproducible `metrics.sh` numbers, targets scored against the `rules/`
contracts (every 5 evidence-backed, false-positives refuted), raw output logged,
findings recorded with permanent IDs, and **every** actionable finding drained with
`Graduated:` backfilled. For a **deploy**: a `.agents/roles/auditor/` + `.records/audit/` pair that
passes the host's gate,
a baseline `FINDINGS.md`, pinned exemplars, a wired doc-index pointer, and a front-door
`skill:auditor` route block (Deploy mode step 6).
