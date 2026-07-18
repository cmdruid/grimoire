---
name: foreman
description: "Stand up, run, and tune the project's development factory. `/foreman` (no arg, or a change description) is the change ROUTER: classify a bug/patch/feature/spike and dispatch it. `/foreman init` stands up the `.agents/dev/` system where none exists; `/foreman tune` drains `/backlog`'s system-relevant signal into doctrine/workflow/AGENTS.md improvements (the self-growing curation loop); `/foreman check` validates the deployed glue against the runbook + installed skills. No-arg = `route`. Owns the change-router + curation loop; the capture bureau is `/backlog`. Use when the user runs `/foreman ...`, asks where a change starts, or asks to set up / route / tune a dev workflow. Distinct from the code-quality audit (`/auditor`)."
---

# foreman — the dev-system integration layer

One skill that **stands up, runs, and tunes** a project's `.agents/dev/` development factory. It owns the
**change-router** (where any change starts) and the **self-growing curation loop** (the system tuning
itself from its own signal). The **capture bureau** — the trackers and their capture/debrief/curate
verbs — is a separate skill, `/backlog`.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in its own `verbs/<verb>.md`, **read on demand** — so the
umbrella adds no always-on context beyond this file. When a verb is selected, **read
`verbs/<verb>.md` and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/foreman` *(no arg, or a change description)* | `verbs/route.md` | **Router** — classify a change + dispatch it to its lane | "where do I start?", "I'm about to change X" |
| `/foreman init` *(alias `deploy`)* | `verbs/init.md` | Stand up the whole `.agents/dev/` system on a project that lacks one | "set up a dev workflow / docs system" |
| `/foreman tune` | `verbs/tune.md` | Drain the system-relevant slice of `/backlog`'s signal into doctrine / workflow / `AGENTS.md` improvements (the curation loop) | "tune the dev system", "fold this friction back into the docs" |
| `/foreman check` | `verbs/check.md` | Cheap validator — flag drift between the deployed glue and the runbook / installed skills | "is the dev system still consistent?", "validate the setup" |

**Default (no recognized verb):** treat the argument as a change description and run `verbs/route.md`.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — how to classify a change, whether drift is real, which signal earns a doctrine edit.
  The bundled scripts do only the deterministic, mechanical work: the **read-only** fact script
  `scripts/dev-health.sh` (state analysis — `inventory`, `stale-refs`, `coverage` — for `tune`/`check`,
  emitting compact `key=value` facts + evidence) and the **mutating mechanical helper**
  `scripts/scoped-commit.sh` (the atomic pathspec-scoped commit — it mutates by design, but only ever
  the paths it is handed). **Never push a decision into a script:** a script is stateless and can't see
  session context, so a *verdict* it emits is sometimes confidently wrong (worse than none), while a
  *fact* the prose reasons over is not. `dev-health.sh` **complements** the host doc-linter (which owns
  link resolution, indexing, frontmatter); it never re-implements it.
- **Commit on the integration trunk, never a work branch.** A `foreman` write (a `tune` doctrine edit,
  an `init` scaffold) creates *shared* `.agents/dev/` content, so it can't ride a feature ref — it lands on the
  **root checkout's current branch**, which must be the integration **trunk** (`main` today, `dev`
  later; never hardcode `main`). **Guard:** check `git -C <root> branch --show-current`; if it is empty
  (detached HEAD) or a work branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root
  to its trunk (or run from a trunk checkout) — landing shared writes on a feature branch is the W3
  failure.
- **Pathspec-atomic commit (the shared root index is contended).** The root index is shared with
  concurrent worktree streams, and `git commit` records the **entire** index — so a bare commit sweeps
  a sibling's staged files. **Always** stage *and* commit scoped to exactly the paths you wrote, in one
  step, via `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (it wraps
  `git -C <root> add -- <paths> && git -C <root> commit -m "<msg>" -- <paths>`). Never `git add -A`,
  never `commit -a`, never leave staged work in the root index across steps. Commits carry **no**
  `Co-Authored-By` trailer.

## Scope boundary

`/foreman` stands up, routes, and tunes the **dev workflow system** (how to make a change + the doctrine
behind it). It is **not** the **capture bureau** — filing bugs/backlog/issues/feedback, sweeping a
finished body of work, and curating the tracker lists are `/backlog`'s. It is **not** the code-quality
audit (`/auditor`, which scores project code against a rubric), and it does not do the development
itself — `route` dispatches you to the lane that does.

## Companion skills (separate, not absorbed)

`/backlog` (the capture bureau — trackers + `task`/`bug`/`issue`/`feedback`/`note`/`debrief`/`curate`), `/architect`
(the design-system engine — `init/brainstorm/plan/prep/distill/check`), `/feature` (the plan+build
engine — `brainstorm | design | plan | build`), `/workstream` (drive a stream in a worktree; owns
landing), `/handoff` (save/resume a session snapshot), `/auditor` (score project code), `/chiropractor`
(general doc-spine ergonomics). The router dispatches to these where the host has them; the by-hand
fallback is always "do it per the deployed `.agents/dev/docs/`".
