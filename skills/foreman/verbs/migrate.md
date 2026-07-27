# `/foreman migrate` — the brownfield onramp

Bring an **existing** project — one with a pre-grimoire or ad-hoc dev-meta setup (a `dev/` directory,
a scattered pile of `BACKLOG.md` / `PLANNING.md` / `bugs/` / `plans/`) — into the current grimoire
layout: the `.agents/{architect,foreman,auditor}/` seeds plus the `.records/` tree, with the
ownership index that maps content → location → steward. `migrate` is the **brownfield** counterpart to
`init` (greenfield): `init` scaffolds fresh onto a blank project; `migrate` **transforms what is
already there**, then scaffolds whatever the project was missing — so the project ends in the same
complete, `check`-valid state as a post-`init` one, having absorbed its existing content.

`migrate` does the **whole job**: locate the existing dev-meta → choose the records destination
(relocate to `.records/`, or keep the found root and **declare** it via the `records-root`
front-door variable) → propose a complete old→new mapping → confirm/edit with the user → relocate
with `git mv` → scaffold the gaps → write the ownership index.

## This is the highest-stakes verb — it MOVES a project's existing content

Read these three rules as non-negotiable; every step below serves them:

- **Preview-first — nothing moves until the user approves.** The classification you produce is a
  **proposal**, never applied blind. You show the *entire* mapping, the user edits/approves it, and
  only *then* does anything move. Do not `git mv` a single path before the user has confirmed the plan.
- **`git mv` every move — preserve history.** Never copy-then-delete, never a plain `mv`. Each
  relocation is `git mv <old> <new>` so the file's history follows it.
- **Never clobber an existing target.** If a move's destination already exists, **stop and ask** — do
  not overwrite. A collision means the project already has content in that home; the user decides how to
  reconcile it.

These sit on top of the shared discipline (trunk guard, pathspec-atomic scoped commit, no
`Co-Authored-By`) that every `foreman` verb carries — see `SKILL.md`.

## What this reuses from `init`

`migrate` is not a second scaffolder. For the **gap-fill** — every home that has *no* migrated content
to land in it — it **reuses `init`'s scaffold verbatim**: the `.agents/{architect,foreman,auditor}/`
seed homes + the full `.records/` tree, the copied `docs/`, and the **ownership-index write**
(`.agents/README.md` + `.records/README.md`, content → location → steward) plus the version stamp.
Do not re-specify that here — read `verbs/init.md` (its *Procedure* steps 2–3 and 8) and apply it to
the homes migrate did not fill. `migrate`'s own contribution is the **locate → classify → confirm →
relocate** front half; the back half *is* `init`.

## Procedure

### 1. Preconditions

- **Resolve root + real date** (shared discipline): project-relative paths; resolve the root from a
  project dir the conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d`.
- **Trunk guard** (shared discipline): `git -C <root> branch --show-current`. If it is empty (detached
  HEAD) or a work branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root to its
  integration trunk — `migrate`'s relocations are shared `.agents/` / `.records/` writes and must land
  on the trunk, not a feature ref.
- **Say what migrate does, up front:** it MOVES existing content. Make sure the working tree is clean
  (`git -C <root> status`) so the relocation commit is reviewable in isolation; if there are unrelated
  staged/dirty changes, ask the user to stash or commit them first.
- **Already migrated?** If the project *already* has a current grimoire layout (`.agents/foreman/` +
  `.records/` present with a valid ownership index), say so and point the user at `/foreman check`
  (drift validation) instead — there is nothing to migrate.

### 2. Locate the existing dev-meta

- **Default to a `dev/` directory at the repo root** — the convention prior projects use. This is a
  *smart starting point*, not a hardcoded remap: the wizard classifies whatever it finds there.
- If `dev/` is absent, **ask the user where the existing dev-meta lives** and accept a path (it may be
  an old `.agents/dev/` from an earlier grimoire version, a `docs/dev/`, or anywhere else — the same
  classify-what-you-find logic handles all of them).
- If there is **no** existing dev-meta at all, this is a greenfield project: direct the user to
  `/foreman init` and **stop**.

### 3. Choose the records destination — relocate, or declare in place

Seed-kind content (doctrine, design, rubric) has exactly one home — it **always** relocates to the
`.agents/{architect,foreman,auditor}/` seeds. The **records** tree, though, is a pointer with a
default: the `records-root` front-door variable (default `.records` — skill-builder's DOCTRINE,
*Front-door variables*). So record-kind content has two valid destinations; ask the user which:

- **Relocate (default):** target `.records/` — the standard layout, full `git mv`.
- **Declare in place:** keep the located root (e.g. `dev/`) as the records root. The plan gains one
  extra edit — a `records-root: dev` line at line start in the host's front-door doc — and the
  mapping's record-kind rows target `dev/…` instead of `.records/…`. Right when the churn of a
  top-level rename isn't worth it. Two things this does **not** change: seed-kind rows still move
  to `.agents/…`, and the **internal shape is still normalized** — companion skills expect
  `<records-root>/tasks.md`, `<records-root>/plans/`, … so a `dev/BACKLOG.md` still becomes
  `dev/tasks.md` (via `git mv`). A project whose located root already matches the records shape
  internally migrates with just the declaration line plus the gap scaffold.

The choice (and the declaration line it implies) is part of the **proposed plan** — previewed in
step 5, written only on approval, like every other row.

### 4. Classify + build the mapping (fact-gathering — propose, don't decide)

Walk the located tree. For each artifact, classify it against the **current** taxonomy + ownership
index (read the host's `.agents/README.md` / `.records/README.md` if present, else the target layout
below) and record a proposed destination. This is index-driven so it stays correct as the layout
evolves — it is **not** a frozen old→new table. Default heuristics (all user-confirmable):

| found (under `dev/` or wherever) | → current home | kind |
|---|---|---|
| `BACKLOG.md` / a task list | `.records/tasks.md` | tasks (backlog) |
| `ISSUES.md` / friction log | `.records/issues.md` | issues |
| `FEEDBACK.md` | `.records/feedback.md` | feedback |
| `bugs/` (defect reports) | `.records/bugs/` | bugs |
| `notes/` (durable facts) | `.records/notes/` | notes |
| dev-process docs (how-we-work — ROUTING/PLANNING…) | `.agents/foreman/docs/` | doctrine |
| `MEMORY.md` / invariants, `GOTCHAS.md` | `.agents/foreman/` | doctrine |
| design docs (vision/philosophy/product architecture) | `.agents/architect/` | design seed |
| `plans/` (design/impl plans, roadmaps) | `.records/plans/` | plans |
| `done/` / shipped records | `.records/archive/` | archive |
| ADRs | `.records/adr/` | adr |
| audit rubric (GUIDE/rules) vs findings | `.agents/auditor/` vs `.records/audit/` | audit |
| reports, logs | `.records/reports/`, `.records/logs/` | records |
| **unrecognized** | (flag — ask the user) | `?` |

Destinations above are shown with the default records root; under a **declared** root (step 3),
substitute `<records-root>/` for every `.records/` row — the `.agents/…` rows never change.

Produce a **complete** old→new relocation table covering everything found. Mark any artifact you can't
confidently place as `?` — that becomes a targeted question, not a guess.

### 5. Present + confirm (preview-first — the gate)

- Show the **entire** proposed mapping in one table (old path → new path, plus the `?` rows).
- Ask targeted questions **only** on the `?` rows and anything genuinely worth a sanity-check — "basic
  questions," not a file-by-file interrogation.
- Let the user **edit or approve any row**. **Nothing moves until the user approves the plan.** If they
  change a destination, update the table and re-confirm.

### 6. Apply (only after approval)

**If the plan declares the records root** (step 3), write the `records-root: <path>` line into the
host's front-door doc **first** — the companion skills' scripts resolve the variable from the
front-door, so the declaration must exist before any scaffold runs. It is a normal edit, committed
with this step's scoped commit. Then, for each approved row:

- **`git mv <old> <new>`** — preserve history. Create target parent dirs first if needed
  (`mkdir -p`), but the move itself is always `git mv`.
- **Never overwrite a target.** Before each move, if `<new>` already exists, **STOP and ask** the user
  how to reconcile — do not clobber. Resume the remaining moves once resolved.
- **Commit scoped to exactly the moved paths** via the pathspec-atomic helper (shared discipline —
  the root index is contended): `scripts/scoped-commit.sh <root> "<msg>" <paths…>`. Never `git add -A`.
  **No `Co-Authored-By` trailer.**

### 7. Scaffold the gaps + write the index (this is `init`'s back half)

- For every home that received **no** migrated content, **scaffold it by reusing `init`** (read
  `verbs/init.md`): the `.agents/{architect,foreman,auditor}/` seed homes + the full records tree,
  the generic `docs/` copied into `.agents/foreman/docs/` with slots filled, and the trackers. Under
  a declared records root no extra wiring is needed — the scaffolding scripts resolve the
  `records-root` variable from the front-door (which step 6 wrote first) and land the records homes
  under the declared root automatically.
- **Write/update the ownership index** — `.agents/README.md` + `<records-root>/README.md` (default
  `.records/README.md`) mapping content → location → steward — over the combined result (migrated +
  scaffolded), and add the front-door pointer, exactly as `init` does.
- **Stamp the version** (init's snapshot doctrine): record what this run built against and point at
  `/foreman check` as the drift validator, so the project ends `check`-valid.
- Commit the scaffold + index scoped to their paths via the pathspec-atomic helper (may be the same
  commit as step 6, or a follow-on — either way, scoped, no `Co-Authored-By`).

### 8. Report

Chat summary (not a written file unless asked):

- **What moved where** — the applied old→new table, and, under a declared records root, the
  `records-root: <path>` line written to the front-door.
- **What was scaffolded** — the homes that had no content to migrate.
- **Unrecognized artifacts** — anything left as `?` for the user to place by hand, with a pointer to
  the ownership index so they know the destinations.

## Done when

The existing dev-meta has been located, the records destination **chosen** (relocate to `.records/`,
or kept in place with `records-root` declared in the front-door), the **complete** mapping proposed
and **user-approved**, relocated with `git mv` (history preserved, no target clobbered), the gaps
scaffolded via `init`'s scaffold, and the **ownership index written + version stamped** — so the
project is fully set up and passes `/foreman check`, having absorbed its prior content.
