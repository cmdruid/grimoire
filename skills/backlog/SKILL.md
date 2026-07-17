---
name: backlog
description: "The capture bureau — the single collection front-door for a project's `dev/` trackers. Owns the trackers, their formats, and the capture schema (`docs/TAXONOMY.md`). Capture verbs each file one follow-up: `/backlog bug` (defect), `/backlog backlog` (feature), `/backlog issue` (dev-friction), `/backlog feedback` (qualitative). `/backlog debrief` sweeps a finished body of work to every tracker; `/backlog groom` dedupes/ranks/weeds the backlog. Captures uniformly — the code-vs-factory cut is made downstream by `/foreman`, not at capture time. Use when the user runs `/backlog ...`, or asks to file/capture/sweep/groom a follow-up. Distinct from routing/tuning the dev system (`/foreman`) and the code audit (`/auditor`)."
---

# backlog — the capture bureau

One skill: the **single collection front-door** for a project's `dev/` trackers. It owns the tracker
artifacts (`BACKLOG.md`, `ISSUES.md`, `FEEDBACK.md`, `dev/bugs/`), their **formats**, the capture
**schema** (`docs/TAXONOMY.md`), the end-of-work **sweep**, and backlog **grooming**. Everything that
*captures a follow-up* lives here; standing up, routing, and tuning the dev system is a separate
skill, `/foreman`.

Capture is **uniform** — every byproduct lands in exactly one durable home by its *kind* (defect /
feature / friction / qualitative). The judgment about what a captured item *means for the system* —
whether a friction should reshape doctrine, whether the change is a bug-lane or feature-lane job — is
made **downstream by `/foreman`**, not at capture time. Capture broadly and honestly; let `/foreman`
sift.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in its own `verbs/<verb>.md`, **read on demand** — so the
bureau adds no always-on context beyond this file. When a verb is selected, **read `verbs/<verb>.md`
and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/backlog bug` | `verbs/bug.md` | File an observed **defect** → `dev/bugs/` (linked from an actionable item) | "file a bug", "this is broken — repro" |
| `/backlog backlog` | `verbs/backlog.md` | Capture a product/feature follow-up → `dev/BACKLOG.md` | "put X in the backlog", "remind me to…" |
| `/backlog issue` | `verbs/issue.md` | Capture dev-experience **friction** → `dev/ISSUES.md` | "the tooling got in my way" |
| `/backlog feedback` | `verbs/feedback.md` | Capture a qualitative / directional note → `dev/FEEDBACK.md` | "felt great", "docs getting heavy" |
| `/backlog debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct to its tracker | "wrap up before I reset", "capture what surfaced" |
| `/backlog groom` | `verbs/groom.md` | Tidy `BACKLOG.md` — dedupe, re-rank, sharpen, weed | "triage the backlog", "reprioritize what's left" |

**No default lane.** `/backlog` with no recognized verb is ambiguous — ask which tracker the item
belongs to (or run `/backlog debrief` if the intent is "capture everything that surfaced").

## The capture schema (backlog owns it)

The **four-tracker taxonomy** — what counts as a bug vs. friction vs. feature vs. qualitative, each
tracker's format and drain, plus the store-dir frontmatter rules — is canonical here in
`docs/TAXONOMY.md`. Every verb defers to it, and other skills reference it rather than restating it.
`/backlog` is the authority on capture format; `/foreman` is the authority on what the captured signal
*means for the system*.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — what classifies as a bug vs. friction, how to rank impact, when to dedupe, whether an
  entry is really done, whether the shipped-record exists. The bundled scripts do only the
  deterministic, mechanical work: the **read-only** fact script `scripts/dev-health.sh` (its
  `debrief-scan` subcommand — uncommitted `dev/` writes, newly added TODO/FIXME markers, recent
  done-records — for the sweep, emitting compact `key=value` facts + evidence) and the **mutating
  mechanical helper** `scripts/scoped-commit.sh` (the atomic pathspec-scoped commit — it mutates by
  design, but only ever the paths it is handed). **Never push a decision into a script:** a script is
  stateless and can't see session context, so a *verdict* it emits is sometimes confidently wrong
  (worse than none), while a *fact* the prose reasons over is not. `dev-health.sh` **complements** the
  host doc-linter (which owns link resolution, indexing, frontmatter); it never re-implements it.
- **Commit on the integration trunk, never a work branch.** A capture commit writes *new* shared
  `dev/` content, so it can't ride a feature ref — it lands on the **root checkout's current branch**,
  which must be the integration **trunk** (`main` today, `dev` later; never hardcode `main`).
  **Guard:** check `git -C <root> branch --show-current`; if it is empty (detached HEAD) or a work
  branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root to its trunk (or run
  from a trunk checkout) — landing captures on a feature branch is the W3 failure. (**Exception:**
  `debrief` invoked *inside an active `/workstream` worktree* writes + commits on the stream's branch;
  the workstream's `ship` lands it — see `verbs/debrief.md`.)
- **Pathspec-atomic commit (the shared root index is contended).** The root index is shared with
  concurrent worktree streams, and `git commit` records the **entire** index — so a bare commit
  sweeps a sibling's staged files. **Always** stage *and* commit scoped to exactly the paths you
  wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (it wraps
  `git -C <root> add -- <paths> && git -C <root> commit -m "<msg>" -- <paths>`). Never `git add -A`,
  never `commit -a`, never leave staged work in the root index across steps. Commits carry **no**
  `Co-Authored-By` trailer.
- **Capture-commit policy (unified across the capture verbs).** A capture verb invoked **standalone**
  (`/backlog bug|backlog|issue|feedback`) makes its **own** doc-only scoped commit (via
  `scripts/scoped-commit.sh`), then runs the host's doc-linter (or its gate) — so a single capture
  lands on its own rather than waiting for an unrelated commit. A capture verb invoked **inside a
  sweep** (`/backlog debrief`) only **writes** — the sweep makes the single atomic multi-file commit
  over every file it touched. `/backlog groom` follows the same rule (standalone self-commits; inside a
  `/foreman tune` sweep it write-only). Each verb file states which path applies.

## Scope boundary

`/backlog` is the **capture bureau** — it files, sweeps, and grooms the trackers, and it owns their
formats and schema. It is **not** the dev-system integration layer: standing up the `dev/` system,
the change-router (where a change starts), and the curation loop that folds captured signal back into
doctrine are `/foreman`'s (`init` / `route` / `tune` / `check`). It is **not** the code-quality audit
(`/auditor`, which scores project code against a rubric), and it does not do the development itself.

## Companion skills (separate, not absorbed)

`/foreman` (stand up / route / tune the dev system — drains this bureau's system-relevant signal via
`tune`), `/architect` (the design-system engine — `init/brainstorm/plan/prep/distill/check`),
`/feature` (the plan+build engine — `brainstorm | design | plan | build`), `/workstream` (drive a
stream in a worktree; owns landing), `/handoff` (save/resume a session snapshot), `/auditor` (score
project code). The verbs defer to these where the host has them; the by-hand fallback is always "do it
per the deployed `dev/docs/`".
