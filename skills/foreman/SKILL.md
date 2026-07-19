---
name: foreman
description: "Stand up, run, and calibrate the project's development factory. `/foreman` (no arg, or a change description) is the change ROUTER: classify a bug/patch/feature/spike and dispatch it. `/foreman init` stands up the `.agents/foreman/` system on a greenfield project; `/foreman migrate` is the brownfield onramp — bring an existing (pre-grimoire / ad-hoc) project into the layout (locate, propose a mapping, confirm, git-mv, scaffold gaps); `/foreman calibrate` drains the captured dev-experience signal into doctrine/workflow/AGENTS.md improvements (the self-growing curation loop); `/foreman check` validates the deployed glue against the runbook + installed skills. No-arg = `route`. Owns the change-router + curation loop. Use when the user runs `/foreman ...`, asks where a change starts, or asks to set up / route / calibrate a dev workflow."
---

# foreman — the dev-system integration layer

One skill that **stands up, runs, and calibrates** a project's `.agents/foreman/` development factory. It owns the
**change-router** (where any change starts) and the **self-growing curation loop** (the system calibrating
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
| `/foreman init` *(alias `deploy`)* | `verbs/init.md` | **Greenfield** — stand up the whole `.agents/foreman/` system on a project that lacks one | "set up a dev workflow / docs system" |
| `/foreman migrate` | `verbs/migrate.md` | **Brownfield onramp** — bring an existing (pre-grimoire / ad-hoc) project into the layout (locate → propose mapping → confirm → git-mv + scaffold gaps) | "migrate our `dev/` setup", "onboard this old project" |
| `/foreman calibrate` | `verbs/calibrate.md` | Drain `/backlog`'s dev-experience signal into doctrine / workflow / `AGENTS.md` improvements — tune the doctrine to its correct settings (the curation loop) | "calibrate the dev system", "fold this friction back into the docs" |
| `/foreman check` | `verbs/check.md` | Cheap validator — flag drift between the deployed glue and the runbook / installed skills | "is the dev system still consistent?", "validate the setup" |

**Default (no recognized verb):** treat the argument as a change description and run `verbs/route.md`.

The verb set is **`route` / `init` / `migrate` / `calibrate` / `check`**. `init` and `migrate` are the
two onramps and share a seam: **`init` = greenfield** (scaffold fresh onto a blank project) while
**`migrate` = brownfield** (locate an existing `dev/` / ad-hoc setup, relocate it into the layout, then
scaffold the gaps). A project with no `.agents/foreman/` yet goes to one of them; both leave it
`check`-valid.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — how to classify a change, whether drift is real, which signal earns a doctrine edit.
  The bundled scripts do only the deterministic, mechanical work: the **read-only** fact script
  `scripts/foreman-health.sh` (state analysis — `inventory`, `stale-refs`, `coverage`, `derive-seams`,
  `check-projection` — for `calibrate`/`check`/`init`, emitting compact `key=value` facts + evidence)
  and the **mutating mechanical helper**
  `scripts/scoped-commit.sh` (the atomic pathspec-scoped commit — it mutates by design, but only ever
  the paths it is handed). **Never push a decision into a script:** a script is stateless and can't see
  session context, so a *verdict* it emits is sometimes confidently wrong (worse than none), while a
  *fact* the prose reasons over is not. `foreman-health.sh` **complements** the host doc-linter (which owns
  link resolution, indexing, frontmatter); it never re-implements it.
- **Commit on the integration trunk, never a work branch.** A `foreman` write (a `calibrate` doctrine edit,
  an `init` scaffold) creates *shared* `.agents/foreman/` content, so it can't ride a feature ref — it lands on the
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

`/foreman` stands up, routes, and calibrates the **dev workflow system** (how to make a change + the
doctrine behind it). It **routes, it does not execute**: capturing follow-ups, auditing code, designing
the seed, and doing the development itself each belong to a **lane** `route` dispatches to — not to
`foreman`. *Which* lane owns *what* is the runbook's seam map (`packs/clankshop.md`) and the deployed
**ownership index** (`.agents/README.md` / `.records/README.md`), not this file.

## Companion skills (separate, not absorbed)

`route` dispatches to whichever companion skills the host has installed. The **composition and the
seams between them** live in `packs/clankshop.md` (the runbook) and, once deployed, in the **ownership
index** `init` writes (`.agents/README.md` / `.records/README.md`) — the authoritative map of
content → location → steward. This file deliberately does **not** restate each companion's verbs: that
list rots (it is each skill's own `description:` to state). Where a recognized companion is absent, the
by-hand fallback is always the deployed `.agents/foreman/docs/`.
