---
name: dev
description: "The dev-workflow umbrella — one skill, many verbs over a project's dev/ system. `/dev` (no arg, or a change description) is the change ROUTER: classify a bug/patch/feature/spike and dispatch to the right lane. `/dev init` stands up the dev/ system on a project that lacks one. Capture verbs each file one follow-up into its tracker: `/dev bug`, `/dev backlog`, `/dev issue`, `/dev feedback`. `/dev debrief` sweeps a finished body of work to its trackers; `/dev upkeep` runs the periodic docs-system health pass. Use when the user runs `/dev ...`, asks where a change starts, asks to set up a dev workflow/docs system, or to capture/route/maintain follow-ups. The DEV WORKFLOW router — distinct from the code-quality audit (/audit)."
---

# dev — the dev-workflow umbrella

One skill over a project's `dev/` development system. It absorbs the old `develop` + `bug` +
`backlog` + `debrief` + `upkeep` skills into a single command with **verbs**, and adds two new
quick-capture verbs (`issue`, `feedback`) so every tracker has a one-shot path.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in its own `verbs/<verb>.md`, **read on demand** — so the
umbrella adds no always-on context beyond this file. When a verb is selected, **read
`verbs/<verb>.md` and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/dev` *(no arg, or a change description)* | `verbs/route.md` | **Router** — classify a change + dispatch to its lane | "where do I start?", "I'm about to change X" |
| `/dev init` *(alias `deploy`)* | `verbs/init.md` | Stand up the whole `dev/` system on a project that lacks one | "set up a dev workflow / docs system" |
| `/dev bug` | `verbs/bug.md` | File an observed **defect** → `dev/bugs/` (linked from an actionable item) | "file a bug", "this is broken — repro" |
| `/dev backlog` *(+ `groom`/`triage`)* | `verbs/backlog.md` | Capture a product/feature follow-up → `dev/BACKLOG.md`; groom the list | "put X in the backlog", "remind me to…" |
| `/dev issue` | `verbs/issue.md` | Capture dev-experience **friction** → `dev/ISSUES.md` | "the tooling got in my way" |
| `/dev feedback` | `verbs/feedback.md` | Capture a qualitative / directional note → `dev/FEEDBACK.md` | "felt great", "docs getting heavy" |
| `/dev debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct to its tracker | "wrap up before I reset", "capture what surfaced" |
| `/dev upkeep` *(+ `spine`/`memory`/`backlog`/`issues`/`feedback`/`prune`)* | `verbs/upkeep.md` | Periodic `dev/` docs-system health pass (drift + drain) | "tidy dev/", "drain the trackers" |

**Default (no recognized verb):** treat the argument as a change description and run `verbs/route.md`.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — what classifies as a bug vs. friction, how to rank impact, when to dedupe, whether an
  entry is really done. The bundled scripts do only the deterministic, mechanical work: the
  **read-only** fact script `scripts/dev-health.sh` (state analysis — `inventory`, `stale-refs`,
  `coverage`, `debrief-scan` — for the sweep/groom verbs, emitting compact `key=value` facts +
  evidence) and the **mutating mechanical helper** `scripts/scoped-commit.sh` (the atomic
  pathspec-scoped commit — it mutates by design, but only ever the paths it is handed). **Never push a decision into a script:** a
  script is stateless and can't see session context, so a *verdict* it emits is sometimes confidently
  wrong (worse than none), while a *fact* the prose reasons over is not. Reach for a fact-script
  whenever a verb would otherwise read many files and reason over raw output to find candidates — it
  saves tokens and turns and makes the pass deterministic. `dev-health.sh` **complements** the host
  doc-linter (which owns link resolution, indexing, frontmatter); it never re-implements it.
- **Commit on the integration trunk, never a work branch.** A capture/route commit writes *new*
  shared `dev/` content, so it can't ride a feature ref — it lands on the **root checkout's current
  branch**, which must be the integration **trunk** (`main` today, `dev` later; never hardcode
  `main`). **Guard:** check `git -C <root> branch --show-current`; if it is empty (detached HEAD) or
  a work branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root to its trunk (or
  run from a trunk checkout) — landing captures on a feature branch is the W3 failure.
- **Pathspec-atomic commit (the shared root index is contended).** The root index is shared with
  concurrent worktree streams, and `git commit` records the **entire** index — so a bare commit
  sweeps a sibling's staged files. **Always** stage *and* commit scoped to exactly the paths you
  wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (it wraps
  `git -C <root> add -- <paths> && git -C <root> commit -m "<msg>" -- <paths>`). Never `git add -A`,
  never `commit -a`, never leave staged work in the root index across steps. Commits carry **no**
  `Co-Authored-By` trailer.
- **Capture-commit policy (unified across the capture verbs).** A capture verb invoked **standalone**
  (`/dev bug|backlog|issue|feedback`) makes its **own** doc-only scoped commit (via
  `scoped-commit.sh`), then runs the host's doc-linter (or its gate). A capture verb invoked
  **inside a sweep** (`debrief`/`upkeep`) only **writes** — the sweep
  makes the single atomic multi-file commit. Each verb file states which path applies.

## Scope boundary

`/dev` routes the **dev workflow** (how to make a change) and deploys/maintains the `dev/`
doc-system. It is **not** the code-quality audit (`/audit`, which scores project code against a
rubric), and it does not do the development itself — `route` dispatches you to the lane that does.

## Companion skills (separate, not absorbed)

`/design` (the design-system engine — `init/brainstorm/plan/prep/distill/check`), `/feature` (the plan+build engine — `brainstorm | design | plan | build`), `/workstream` (drive a
stream in a worktree; owns landing), `/handoff` (save/resume a session snapshot), `/audit` (score
project code). The router dispatches to these where the host has them; the by-hand fallback is
always "do it per the deployed `dev/docs/`".
