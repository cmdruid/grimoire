---
doctype: plans
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [plan]
---

# auditor review remediation — Implementation Plan

**Shipped 2026-08-17** on `stream/grok` — subject: `auditor: fold
skill-builder review findings`.

Tracer-bullet: slice 1 is the setup playbook an agent actually follows
(`BOOTSTRAP.md` How-to-use + §9 + §10) — the two must-fixes. Later
slices make the driver match that playbook, then tighten trigger,
PERF, and templates.

Spec: `docs/design/2026-08-17-auditor-review.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Invariants:** patient-zero — do not run `/auditor setup` in this
  library and do not create `docs/audit/` here. Modes stay in the
  router (no `verbs/`). Templates stay inside `BOOTSTRAP.md` (no
  `skills/auditor/templates/`). Host tracker *lines* (Backlog /
  Issues / Feedback, “host’s own tracker files”) stay; only the
  audit’s own living findings store is forbidden. Rule-file
  `Issue theme:` lines stay. Do not register against this library’s
  real `AGENTS.md`.
- **Live-API gotchas:** re-read each cited span against
  `<worktree>` HEAD before editing. Load-bearing wraps:
  `skills/auditor/BOOTSTRAP.md:25-26` (tracker that drains),
  `:117` (finding IDs), `:257-258` (audit’s tracker),
  `:269-271` (write rules from skeleton), `:277-278` (unrooted
  wiring). `skills/auditor/SKILL.md:3` (use-when), `:20-22`
  (one probe), `:31-33` (standalone home), `:53` (target depth),
  `:60-61` (no living tracker), `:73` (journal’s capture kinds),
  `:88-98` (copy bundled rules), `:103-104` (unrooted wiring),
  `:145-152` (done-when). `skills/auditor/rules/performance.md:57-59`.
  Description is 721 chars; hard cap 1024, prefer ≤750.
- **Coexisting work:** this branch is `stream/grok` in
  `/Users/cscott/Repos/grimoire/.workstreams/grok`. Sibling `feat`
  does not own auditor. Root checkout dirt (mailbox scripts + two
  untracked design docs) is disjoint — do not sweep it in.
- **CI-safety / scope:** markdown-only. Gate is
  `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`. The
  auditor symlink WARN is expected from a worktree. Do not add a
  pack version bump. Do not run `check` Pass 2
  (`docs/BOUNDARY-AUDIT.md`).
- Every slice’s requirements implicitly include this section and
  the spec’s receiving locks.

## File map

| Path | Responsibility |
|---|---|
| `skills/auditor/BOOTSTRAP.md` | Playbook, drain model, wiring paths, theme-prefix gloss, GUIDE + metrics skeletons |
| `skills/auditor/SKILL.md` | Probe, home detect, modes, drain kinds, done-when, trigger |
| `skills/auditor/rules/performance.md` | PERF measure-or-cap rule |

No other files. Do not touch `rules/` except `performance.md`.

## Coverage

| Finding | Slice |
|---|---|
| 1 must-fix playbook writes rules from skeleton | 1 |
| 2 must-fix BOOTSTRAP stands up a findings tracker | 1 |
| 10 theme prefixes as finding IDs | 1 |
| 3 standalone home detect | 2 |
| 4 workshop wiring paths | 2 |
| 5 metrics/check done-when | 2 |
| 8 journal’s capture kinds | 2 |
| 11 one-probe honesty | 2 |
| 12 `<target>` depth | 2 |
| 7 description use-when | 3 |
| 6 PERF bench | 4 |
| 9 GUIDE + metrics templates | 5 |

## Slices

- [x] **Slice 1: setup playbook (the tracer)** <requires: —>

  - Files: Modify `skills/auditor/BOOTSTRAP.md`
  - Findings: 1, 2, 10
  - Change: five surgical replacements. Do not rewrite §3 / §7
    (those already state the v2 drain model). Do not touch host
    “tracker” wording in `<drains>` or “host’s own tracker files”.

    1. **How to use — Full setup** (`:22-23`). Replace:

       ```
       - **Full setup:** read *Principles*, fill the *Slots*, then create the *Manifest* files using the
         *Rule-file shape* and the per-file briefs. Wire the *Metrics script* and the *drains*.
       ```

       with:

       ```
       - **Full setup:** read *Principles*, fill the *Slots*, then copy the bundled `rules/`
         (fill `<language>` slots; write only `<native dimensions>` from the *Rule-file shape*).
         Author `GUIDE.md` and `metrics.sh` from §12 / §13 (until those sections exist, from
         the section lists in §10 steps 3–4). Wire the *drains*.
       ```

       (Slice 5 lands §12 / §13. The parenthetical keeps slice 1
       followable before then.)

    2. **How to use — Partial borrow** (`:24-26`). Replace
       `(a tracker that drains into your existing trackers)` with
       `(a pass report that drains into the host's existing trackers,
       or is the queue when the host has none)`.

    3. **§5 theme prefixes** (`:117`). Replace
       `(used for finding IDs)` with
       `(the Dimension tag on a finding, not an ID)`.

    4. **§9 step 5** (`:257-258`). Replace the two lines with:

       ```
       5. **Which existing trackers absorb findings?** -> the `<drains>`. If the host has none, the
          pass report's own findings list is the queue.
       ```

    5. **§10 step 2** (`:269-271`). Replace with:

       ```
       2. Copy the bundled generic `rules/` into `<home>/rules/`. Fill the `<language>` greps
          and *How to quantify* recipes. Write only `<native dimensions>` from the *Rule-file
          shape* (§6). (They reference `../GUIDE.md` in backticks, since it does not exist yet.)
       ```

  - Verify: from the worktree,

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "Write the \`rules/<dimension>" skills/auditor/BOOTSTRAP.md ; \
      rg -n "tracker that drains|audit's tracker can own" skills/auditor/BOOTSTRAP.md ; \
      rg -n "used for finding IDs" skills/auditor/BOOTSTRAP.md ; \
      rg -n "Copy the bundled generic" skills/auditor/BOOTSTRAP.md ; \
      rg -n "pass report's own findings list" skills/auditor/BOOTSTRAP.md ; \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|auditor:"
    ```

    Expected: first three greps empty; the two “Copy” / “pass
    report's own” greps hit; lint `fails=0`; auditor line is only
    the symlink WARN. Host phrases
    `host's own tracker files` and `Backlog/Issues/Feedback tracker
    lines` still present.

- [x] **Slice 2: driver holes** <requires: 1>

  - Files: Modify `skills/auditor/SKILL.md`,
    `skills/auditor/BOOTSTRAP.md`
  - Findings: 3, 4, 5, 8, 11, 12
  - Change:

    1. **Probe honesty (F11).** Replace `SKILL.md:19-23`
       (“That single fact picks the homes; nothing else about the
       host is probed…”) with:

       ```
       Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a line matching
       `Seeded from clankshop`)? That fact picks the homes. On a workshop host, also read the
       declared `records-root:` (front-door `AGENTS.md`), else `.records/`. No mode ever refuses
       or stalls for lack of a workshop — standing one up is the human's separate decision
       (the clankshop onramps), never an audit side effect.
       ```

       Leave the workshop / standalone bullets, but drop the
       duplicate “rooted at the declared `records-root:` …” clause
       from the workshop bullet (`:29-30`) so the probe is the one
       place that names it. Workshop bullet then ends at the
       `context.sh test` sentence and “Deliverables drain through
       the **records layer** (see *Deliverables*).”

    2. **Standalone detect (F3).** Replace the standalone bullet
       (`:31-33`) with:

       ```
       - **Standalone** → the rubric home is **confirmed once at setup** (default `docs/audit/`).
         Later modes detect `<home>/GUIDE.md`: workshop path first; else `docs/audit/GUIDE.md`;
         else ask once (do not scan the repo). Pass reports are dated files in that home, and
         findings drain into the host's **own** trackers where any exist. Skip every
         records-layer seam rather than stalling on it.
       ```

       Replace “The non-`setup` modes need the rubric to exist —
       no rubric yet → point at `setup` and stop.” (`:55-56`) with
       “The non-`setup` modes need `<home>/GUIDE.md` — missing →
       point at `setup` and stop.”

    3. **Target depth (F12).** Replace the `<target>` mode bullet
       (`:53`) with:

       ```
       - **`<target>`** — a path scopes a pass to that path. Look it up in GUIDE's targets table
         for Deep / Mid / Light. If missing: Light unless the user named Deep.
       ```

    4. **Journal name (F8).** In `:73` replace
       `per journal's capture kinds:` with `by kind:`.

    5. **Wiring paths (F4).** In `SKILL.md:103-104` replace
       `` (`core/ROUTING.md` `` with
       `` (`.handbook/core/ROUTING.md` `` and
       `` `test/POLICY.md` `` with
       `` `.handbook/test/POLICY.md` ``.
       In `BOOTSTRAP.md:277-278` the same two path upgrades. Leave the
       standalone doc-index pointer as a human breadcrumb; detect does
       not parse it.

    6. **Done-when (F5).** After the setup sentence in
       `SKILL.md:145-152`, append:

       ```
       For **metrics**: `metrics.sh` printed its report; no scores filed.
       For **check**: show the script output. Exit 0 → stop. Non-zero → treat as a P0
       defect and drain it (workshop: a `bugs` record; standalone: the host tracker or a
       dated report), then stop. If `metrics.sh` has no `--check`, say so and stop — that
       is not a fail.
       ```

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "nothing else about the host is probed|journal's capture kinds|no rubric yet →" skills/auditor/SKILL.md ; \
      rg -n "\`core/ROUTING.md\`|\`test/POLICY.md\`" skills/auditor/SKILL.md skills/auditor/BOOTSTRAP.md ; \
      rg -n "handbook/core/ROUTING.md|handbook/test/POLICY.md" skills/auditor/SKILL.md skills/auditor/BOOTSTRAP.md ; \
      rg -n "ask once \\(do not scan|<home>/GUIDE.md" skills/auditor/SKILL.md ; \
      rg -n "Light unless the user named Deep" skills/auditor/SKILL.md ; \
      rg -n "If \`metrics.sh\` has no" skills/auditor/SKILL.md ; \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: first two greps empty (unrooted paths and stale
    phrases gone; `SKILL.md:14` “no rubric yet” without the arrow
    stays). Rooted paths, detect rule, depth rule, and check
    done-when all hit; `FAIL:` empty.

- [x] **Slice 3: trigger** <requires: 2> (parallel with 4)

  - Files: Modify `skills/auditor/SKILL.md` (frontmatter
    `description:` only)
  - Finding: 7
  - Change: replace the use-when clause only. Keep `/auditor`,
    `setup` / `metrics` / `check`, the workshop/standalone
    sentence, and “Audits PROJECT CODE against a rubric.”

    Current `description:` (721 chars) becomes:

    ```
    description: "Drive a rubric-based code-quality audit on any repo: calibrate against the host's audit rubric (GUIDE.md + per-dimension rules/ + metrics.sh), scope by risk-weight, score with evidence, drain actionable findings. Standalone by default (rubric home confirmed once, default docs/audit/); on a workshop host the rubric is test-station doctrine and findings drain through the records layer (a reports record per pass, bugs records for defects, tracker lines for the rest). Use when the user runs `/auditor`, asks to score project code against that rubric, or to stand up the rubric. `setup` stands up the rubric; `metrics` runs metrics.sh; `check` runs the invariant gate. Not a PR review, docs sweep, or skill lint. Audits PROJECT CODE against a rubric."
    ```

    Count chars inside the quotes. Must be ≤1024, prefer ≤750.
    If the count exceeds 750, drop “Not a PR review, docs sweep,
    or skill lint.” and rely on “score project code against that
    rubric” alone — do not drop the verb names.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      python3 -c 'import re; t=open("skills/auditor/SKILL.md").read(); s=re.search(r"^description:\s+\"(.*)\"\s*$",t,re.M).group(1); print(len(s)); assert "/auditor" in s and "setup" in s and "metrics" in s and "check" in s; assert "audit/quality-check" not in s; assert len(s)<=1024' && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|auditor:"
    ```

    Expected: printed length ≤1024; assert exits 0; lint
    `fails=0`; auditor line is only the symlink WARN.

- [x] **Slice 4: PERF measure-or-cap** <requires: —> (parallel with 3; different file)

  - Files: Modify `skills/auditor/rules/performance.md`
  - Finding: 6
  - Change:

    1. Replace the paragraph at `:20-22`
       (“For real measurement, use the project's benchmark
       harness. Greps surface *candidates* only -- never file a
       PERF finding without a measurement.”) with:

       ```
       Greps surface *candidates* only. A PERF *finding* requires a measurement from a
       harness named in GUIDE or the decision-walk. If the host has no harness and no
       documented measure command, do not file a PERF finding; score from the structural
       greps and cap the score at 4 (a 5 still requires a number).
       ```

    2. Replace decision-logic step 5 (`:57-59`) with:

       ```
       5. If GUIDE or the decision-walk named a bench command, run it and compare to the
          recorded baseline. If none exists, skip this step -- do not invent a harness.
          Do not file a PERF finding without a measurement.
       ```

    3. Append to *How to quantify* (`:100-101`):
       `If no bench, omit the finding and cap the score at 4.`

    4. **Scoring anchors** (`:26-36`). Keep a bench as the 5-bar.
       Replace the 4-anchor’s “Bench baseline is stable.” with
       “If a bench exists, its baseline is stable.”
       Replace the 2-anchor’s “The benchmark shows measurable
       regression from a prior pass.” with “If a bench exists, it
       shows a measurable regression from a prior pass.”
       Leave the 5-anchor’s “The benchmark harness shows stable
       baselines across passes.” — a 5 still requires a number.

    Do not empty Calibrated examples / Exemplars.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "See the project's performance documentation" skills/auditor/rules/performance.md ; \
      rg -n "cap the score at 4" skills/auditor/rules/performance.md ; \
      rg -n "do not invent a harness" skills/auditor/rules/performance.md ; \
      rg -n "If a bench exists, its baseline is stable|If a bench exists, it" skills/auditor/rules/performance.md
    ```

    Expected: first grep empty; the new phrases hit. 5-anchor still
    names the harness.

- [x] **Slice 5: GUIDE + metrics skeletons** <requires: 2>

  - Files: Modify `skills/auditor/BOOTSTRAP.md`,
    `skills/auditor/SKILL.md`
  - Finding: 9
  - Change: append two sections after current §11. Do **not**
    renumber §8–§11 (`SKILL.md` cites them). Point §10 steps 3–4
    at the new sections. Drop the slice-1 parenthetical
    “until those sections exist…”.

    1. **§10 step 3** — replace the “Write `GUIDE.md` …” sentence
       with: `Write GUIDE.md from §12; fill the slots.`

    2. **§10 step 4** — replace the “Write `metrics.sh` …”
       sentence with: `Write metrics.sh from §13; run it for a
       baseline; wire --check if you have an invariant to gate.`

    3. **How to use — Full setup** — delete the parenthetical
       about §12 / §13 not existing yet.

    4. **Append §12** (copy-paste skeleton, slots left as
       `<like this>`):

       ````
       ## 12. GUIDE.md skeleton

       Copy into `<home>/GUIDE.md` and fill the slots. Do not invent
       extra stores.

       ```markdown
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

       <workshop: bugs records + Backlog / Issues / Feedback tracker lines.
       standalone: the host's own trackers; if none, this report's findings list is the queue.>

       ## Bench (optional)

       <command to measure PERF, or "none". If none, do not file PERF findings; cap PERF at 4.>

       ## Exemplars (score-5 anchors)

       _Pin after the baseline pass. Until then, the written standard in each rule file is the bar._
       ```
       ````

    5. **Append §13** — a copy-paste stub. It is a template inside
       `BOOTSTRAP.md`, not a file under `skills/auditor/`.

       ````
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
       ````

    6. **`SKILL.md` setup steps 4–5** — add “(from `BOOTSTRAP.md`
       §12)” after “Write the hub”. Retarget the existing
       `BOOTSTRAP.md §8` cite on the metrics step to
       “`BOOTSTRAP.md` §8 columns, copy §13 stub”. Do not stack
       a second §13 pointer.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      test ! -e skills/auditor/templates && \
      rg -n "^## 12. GUIDE.md skeleton|^## 13. metrics.sh stub" skills/auditor/BOOTSTRAP.md && \
      rg -n "Write GUIDE.md from §12|Write metrics.sh from §13" skills/auditor/BOOTSTRAP.md && \
      rg -n "until those sections exist" skills/auditor/BOOTSTRAP.md ; \
      rg -n "from \`BOOTSTRAP.md\` §12|§8 columns, copy §13 stub" skills/auditor/SKILL.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: no `skills/auditor/templates` directory; both new
    headings and both “from §12/§13” pointers hit; “until those
    sections exist” gone; lint `FAIL:` empty. §8 / §9 / §10
    headings still at those numbers.

## Done when

All twelve findings in the spec have a landed slice. From the
worktree:

```
cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
  rg -n "Write the \`rules/<dimension>|tracker that drains|audit's tracker can own|used for finding IDs|journal's capture kinds|audit/quality-check|nothing else about the host is probed|See the project's performance documentation" \
    skills/auditor && \
  test ! -e skills/auditor/templates && \
  test ! -e docs/audit && \
  skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
```

Expected: the stale-phrase grep is empty; no `templates/` and no
`docs/audit/` in this library; lint `FAIL:` empty.

_On completion (before landing), run the host's close-the-books sweep._
