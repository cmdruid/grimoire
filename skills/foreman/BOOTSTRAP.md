# BOOTSTRAP -- a portable agent-development documentation system

A self-contained, generic blueprint for a `.agents/dev/` documentation system that lets parallel agents
develop a software project without clobbering each other or letting the docs rot. Drop this file
into any project and an agent can **reconstruct the whole system**, or **borrow a module or two**.

It is deliberately project-agnostic: anything specific to a host project (its tech stack, its
quality gate, its sacred invariants) appears here as a **slot you fill**, marked `<like this>`.

**How `/foreman init` uses this file (mechanism vs. composition).** This blueprint is the
**mechanism** — *how* to instantiate the glue, pack-agnostic; it never names a specific companion
skill or pack. *Which* skills to wire, and the **cross-skill seams** that bind them, are the
**composition**, and they come from **outside** this file: from a **pack runbook** (e.g.
`packs/clankshop.md`) when one drives `init`, or, on a bare install, from **baseline** introspection
of the installed skills. `/foreman init` reads the composition, then instantiates the system below.
The seams live *between* skills, in no single skill's frontmatter — so only a runbook can supply
them; baseline wires the members but not the seams. (See `verbs/init.md` Step 0.)

_A distillation of the bundled `docs/` + `templates/` -- those files are the source of truth for
their own content; this blueprint carries the structure, contracts, and playbook around them.
When they change structurally, update this file (see §13 *Keeping this file current*)._

## How to use this file

- **Full deploy:** read *Principles*, fill the *Slots*, then create the *Manifest* files using the
  bundled `docs/` + `templates/` and the per-file briefs. Wire the *Gate* and the *Linter*.
- **Partial borrow:** pick modules from the *Module map* (each notes its dependencies) and create
  only those files.
- **Adapt to your stack:** the *Gate*, the *Linter*, and the *Worktree pipeline* assume nothing
  beyond "a test/quality command" and "git." Swap implementations freely; keep the contracts.

---

## 1. Principles (the load-bearing ideas)

These are *why* the system is shaped as it is. Keep them even if you change the file layout.

- **Living docs drift and rot, so every artifact is bounded and drained.** Nothing grows without
  bound; every capture file has a *drain* (a routine that empties it) and every doc has an *audit*
  that catches drift. An artifact with no drain is a future graveyard -- don't create one.
- **One source of truth per fact; point, don't duplicate.** A fact lives in exactly one doc;
  everything else links to it. Duplication is what rots -- the moment a fact lives in two places,
  one goes stale.
- **Tiered entry.** One front door routes to an index, which routes to routers, which route to
  how-tos. An agent should never need to know which doc holds what -- it should be *routed* there.
- **Match planning weight to the work.** Over-planning a small change wastes as much as
  under-planning a large one. Offer tiers; default to the lightest that fits.
- **Convention over enforcement -- with a mechanical backstop for the rot-prone parts.** Most
  discipline is documented convention (cheap, flexible). A small linter mechanically guards only
  the things that silently rot: dead links and unindexed docs.
- **Keep the "memory" tiny -- the constraint is the feature.** The one doc agents *internalize*
  holds only load-bearing invariants. A small trusted memory beats a big stale one.
- **Earn abstractions.** Extract a shared structure at the second (or third) consumer, not the
  first. This applies to the docs as much as the code.

---

## 2. Slots -- fill these for your project

The system is generic; these make it yours. Decide them before reconstructing.

| Slot | What it is | Example fill (replace) |
|---|---|---|
| `<keystone>` | Your project's one or few **sacred invariants** -- the rules that, if broken, break the project. | "Worldgen is a pure function of `(seed, position)`." |
| `<gate>` | The **one command** that must pass before any commit (tests + lint). | `./scripts/ci.sh` |
| `<linter>` | The mechanical doc check, wired into `<gate>` (see *Module: Linter*). | a test in your test suite |
| `<stack>` | Language/framework specifics referenced by the content docs. | (your runtime) |
| `<content docs>` | Project-specific reference docs (architecture, known traps, debugging, perf). Named slots here; *you* write their content. | see *Module: Reference docs* |

---

## 3. Module map (compose what you need)

**Core (always):** the front door, the index, the capture trackers, the memory, the templates.
Everything else is optional and depends on Core.

| Module | Files | Depends on | Borrow when |
|---|---|---|---|
| **Core: entry + index** | front-door `AGENTS`/`README`, `.agents/dev/README` (index), `.agents/dev/MEMORY` | -- | always |
| **Capture trackers** | `BACKLOG`, `bugs/`, `ISSUES`, `FEEDBACK` | Core | you want bounded follow-up capture |
| **Templates** | `.agents/dev/templates/*` | Core | always (consistency) |
| **Change router** | `docs/DEVELOPMENT` | Core | >1 kind of change (bug/patch/feature) |
| **Planning** | `docs/PLANNING` | Change router, Templates | features need design before build |
| **Worktree pipeline** | `docs/WORKTREES` | Planning, git | parallel agents / isolated feature work |
| **Workflow index** | `docs/WORKFLOWS` | Core | enough how-tos to need an index |
| **Maintenance** | `docs/MAINTENANCE` | Trackers, Memory | the system is big enough to drift |
| **Sync contract** | `docs/SYNC` (or a section of `docs/MAINTENANCE`) | Entry + index | the front door is volatile / multi-agent |
| **Linter** | `<linter>` in `<gate>` | Core | links + indexes are worth guarding |
| **Reference docs** | `docs/ARCHITECTURE`, `docs/GOTCHAS`, `docs/DIAGNOSTICS`, `docs/PERFORMANCE` | Core | `<content docs>` slots -- you fill |
| **Records** | `done/`, `plans/`, `adr/`, `reports/`, `notes/`, `logs/` | varies | you want durable history |

---

## 4. Directory & file manifest

The generic tree. Adjust names to your host's conventions (e.g. the front door is often
`AGENTS.md`/`README.md`/`CONTRIBUTING.md` at the repo root).

```
<repo root>/
  <front door>            -- bootstrap entry: "read first" order, build/test/run, repo map,
                             conventions, and a "making a change? -> .agents/dev/docs/DEVELOPMENT" pointer
  .agents/dev/
    README.md             -- THE index for .agents/dev/: what each dir/file is + the conventions. No
                             per-directory READMEs to chase.
    MEMORY.md             -- the tiny set of load-bearing invariants agents internalize. <keystone>
                             lives here. Kept deliberately small.
    BACKLOG.md            -- live list of product/feature follow-ups ("build X")
    ISSUES.md             -- live log of developer-friction ("the dev experience got in my way")
    FEEDBACK.md           -- qualitative observations, drained periodically
    bugs/                 -- a STORE of bug reports (one file each), not a work queue
    docs/
      DEVELOPMENT.md      -- the change router: classify (bug/patch/feature/spike), then route
      PLANNING.md         -- how much to plan + how to write each planning artifact
      WORKTREES.md        -- the build pipeline + git-worktree mechanics
      WORKFLOWS.md        -- index of common how-tos (pointers, not restatements)
      MAINTENANCE.md      -- audits (catch drift) + prune/archive (keep lean)
      SYNC.md             -- contract keeping the front door in step with .agents/dev/
      ARCHITECTURE.md     -- <content doc> one-page system map
      GOTCHAS.md          -- <content doc> running list of traps that cost time
      DIAGNOSTICS.md      -- <content doc> the debugging playbook
      PERFORMANCE.md      -- <content doc> how to benchmark
    templates/            -- copy-me starting points (bundled with this skill; see §12)
    (no sessions/ dir)    -- hand-offs are temporary: a gitignored root HANDOFF for the active
                             stream; concurrent streams use the worktree-local hand-off (see §8)
    done/                -- append-only records of shipped work (dated)
    plans/                -- design plans / roadmaps (live until shipped, then archived)
    adr/                  -- architecture decision records (Nygard form)
    reports/              -- research investigations / findings (standalone, browse-worthy)
    notes/                -- a STORE of contextual write-ups, each linked from an index entry
                             (a memory line, a tracker item); never enumerated or drained itself
    logs/                 -- captured run/measurement artifacts
  (each of plans/ reports/ bugs/ also has an archive/ subdir)
```

---

## 5. The decision walk (routing)

The spine an agent follows. Each arrow is a pointer in a doc, never a duplicated explanation.

```
<front door>  ("making a change? start at DEVELOPMENT")
   -> .agents/dev/docs/DEVELOPMENT  (classify the change)
        bug    -> DIAGNOSTICS (diagnose) + GOTCHAS (known trap?) -> file a report in bugs/
        patch  -> land directly on the main branch, committed promptly (no plan)
        feature-> PLANNING (plan it) -> WORKTREES (build it)
        spike  -> explore in isolation; capture learnings; build properly as a feature
   .agents/dev/README   answers "where does X live"
   .agents/dev/MEMORY   holds the invariants to internalize first
```

Keep the three navigation docs non-overlapping: **README** = *where things live*, **DEVELOPMENT**
= *making a change*, **WORKFLOWS** = *how to do task Y*. If two of them describe the same thing,
one is wrong.

---

## 6. The capture taxonomy (four trackers, four drains)

Each tracker answers a different question and has a drain so it can't become a graveyard.

| Tracker | Captures | Drain |
|---|---|---|
| `BACKLOG.md` | "the project needs X" (product/feature work) | when an item ships -> remove it, record in `done/` |
| `bugs/` | "X is broken" (a defect report, one file each) | fixed -> note the commit, move to `bugs/archive/`; tracked from a linked `BACKLOG` item |
| `ISSUES.md` | "the dev experience got in my way" (tooling/workflow friction) | resolved/documented -> record in `done/`, remove |
| `FEEDBACK.md` | qualitative observations, directional ideas | periodically routed to its real home (a backlog item, a bug, an issue) or acted on |

The boundary that matters: **`bugs/` is a store, not a work queue** -- you file reports there and
track the fix from a linked actionable item; you don't fish in it for work.

**Spillover store (`notes/`).** When a tracker (or memory) entry needs more than a line, write the
long form to a `notes/<slug>.md` and link it from the entry. `notes/` is a store like `bugs/` --
reached only through its link, never enumerated or drained on its own; its lifecycle follows the
entry that points at it. It is spillover for *any* tracker, not a fifth tracker. (A *standalone*
investigation belongs in `reports/`; a note is *subordinate* to the entry it backs.)

---

## 7. Planning tiers

`PLANNING.md` opens with this decision and links each artifact to its template.

| Tier | When | Artifact(s) |
|---|---|---|
| **Patch** | a fix/tweak/one self-contained change | none -- land on the main branch |
| **Small feature** | one coherent feature, a single branch's worth | one **feature brief** |
| **Track** | multi-phase, or a cross-cutting architecture call | a **roadmap** + per-phase **implementation plans**, plus one **ADR** if it makes an architecture decision |

The line: **more than one phase, or a decision worth an ADR -> track.** When unsure, start with a
brief and promote.

**Friendly to planning skills.** If agents have planning skills/tools active, they own the
*process*; the templates here define the *output* (its shape + where it lands). Run the skill,
then map its output onto these conventions -- don't run a skill *and* re-fill a template by hand.

---

## 8. The worktree / feature pipeline (assumes git)

A feature is **planned once**, then built in isolation and merged. For a multi-phase track -- or a
long-lived **stream** that ships feature after feature off a queue -- the worktree and session
**persist across all of them**; do not re-create them per item. Shipping is the steady state;
teardown is rare.

1. **Seed** (on the main branch): write the plan + a filled-in hand-off; commit; branch a worktree
   from the main ref so it carries the seed.
2. **Drive** (a fresh session rooted in the worktree): bootstrap from the hand-off + plan;
   implement task-by-task, committing on the branch; run `<gate>` as you go; keep the hand-off
   current.
3. **Land** -- rebase onto the main branch, re-verify `<gate>`, fast-forward merge. Then:
   - **Ship & continue** (a stream/track with queue left): archive the shipped item's plan, record a
     dated entry, advance the hand-off to the next item, and **keep the worktree** -- the steady state.
   - **Teardown** (a one-shot feature, or a stream whose queue is exhausted/paused): remove the
     worktree + branch, archive the plan + hand-off, record what shipped.

If your project isn't multi-agent or doesn't need isolation, skip this module: features can build
on a branch (or the main branch) directly. The pipeline earns its weight only under parallelism.

**Operations as a skill (optional).** On an agent platform with *skills* (self-surfacing
capabilities), this whole pipeline can live as a **skill** that automates seed -> drive -> land and
presents itself to the agent without a doc pointer. The docs then hold only the *policy* -- when to
use a worktree, the load-bearing invariants -- and stop short of the step-by-step. Keep the manual
version above as the portable default; a skill is an optimization for one platform, not a
replacement for the policy (and the hand-off in step 2 may then be skill-bundled rather than a
`templates/` file).

---

## 9. Maintenance (the anti-rot engine)

Two routines, run after a structural change or periodically, item by item, when the tree is quiet:

- **Audits -- catch drift.** Per living doc, ask: still true? still load-bearing? redundant?
  missing anything? do its pointers resolve? Fix in place; file bigger gaps to a tracker. The
  highest-stakes audit is the **memory** (a wrong "fact" agents internalize is actively harmful)
  and the **spine** (the entry-doc -> index onboarding path).
- **Prune / archive -- keep it lean.** Move finished/stale material out of the live docs into
  `*/archive/` and dated `done/` records, so what's live is what's *active*. Version control is
  the source of truth; `done/` is the human-readable index into it.

---

## 10. The SYNC contract (keep the front door honest)

Its own small doc, or a section of *Maintenance* -- it's the per-change half of the same anti-rot
concern as the periodic spine audit, so a small system folds the two together. The front door
(`AGENTS`/`README`) is the most volatile doc -- many agents touch it. The contract:

- **Change `.agents/dev/` -> reflect it in the front door in the same commit.** A pointer that lags the
  system is the drift this prevents.
- **The front door is an index, not a copy.** It gives one named pointer to the canonical doc for
  each thing; it never duplicates content. Tier it: name directly only what an agent reaches for
  first; let everything else hang off an index.
- **Trigger -> action:** added a tracker -> name it in the front door's capture section; added a
  how-to -> add it to the workflow index; added a tool/command -> add it to build/test/run; added
  a top-level dir -> add a repo-map line; renamed/removed something -> repoint or drop every
  reference.

The maintenance *spine audit* periodically enforces this; the contract is the per-change
discipline that keeps the audit boring.

---

## 11. The linter (mechanical backstop)

A small check wired into `<gate>` (implement in your stack -- it's a spec, not code). It must:

1. **Resolve internal links.** Every internal doc link (`](path)` and, ideally, backtick path
   refs to docs) points at a file that exists. Catches renames/deletes that leave dead links.
2. **Index enumerable doc series.** Every file in an enumerable directory (e.g. `.agents/dev/docs/`,
   `.agents/dev/adr/`) is named in its index (`.agents/dev/README`). Catches docs that exist but are unreachable.
3. **Forbid stray paths.** Any path your conventions ban (e.g. a skill's default output dir you
   don't use) does not exist. Catches convention violations silently reintroduced.
4. **Validate store-dir frontmatter.** Every file in an artifact-instance store dir (`.agents/dev/plans/`,
   `.agents/dev/adr/`, `.agents/backlog/bugs/`, `.agents/dev/done/`, ... -- the explicit gated-dir list) carries a valid
   frontmatter block: `type` legal for the dir, `status` in that type's set, `updated` shaped
   `YYYY-MM-DD` (schema: the host's capture-taxonomy doc). Catches records that would silently escape the
   type/status search recipes.

Keep it small and fast (no network, no build). Its job is to guard the rot-prone bits that humans
miss, not to enforce style.

---

## 12. Templates

The authored template set ships as **files in `templates/` directories** -- copy them
into the host's `.agents/dev/templates/` (playbook step 3): this skill ships `plan-design`,
`plan-implementation`, `roadmap`, `adr`, `report`, `done-record`; the **capture** templates
(`bug-report`, `note`, `feedback`) ship with `/backlog`. Those files are the
**single source of truth** for each artifact's shape, frontmatter block included (the linter's
store-dir check, §11.4, rejects an instance without it; schema in the host's capture-taxonomy doc). Do **not**
restate template bodies here -- an inline copy drifts from the authored file.

The small-feature **brief** deliberately has no template: it is prose -- problem & approach, a task
list, a done-when (`docs/PLANNING.md` -> *The artifacts*).

Two shapes have no bundled file and live inline below: **`handoff.md`** (gitignored scratch, not a
store-dir instance -- no frontmatter) and **`perf-log.md`** (an example *host extension*: a host
that adopts it adds the template, a `TAXONOMY.md` row, a store dir, and a linter rule together).

### `handoff.md`
```
# <Stream> -- hand-off
_Last updated: <date>_

## START HERE
<pwd + branch guard: confirm you are in the right working directory / branch before acting.>

## TL;DR
<what this stream is, where it stands, what's next -- one paragraph.>

## What's done / Repo state / What's pending
<artifacts with paths; current branch + gate status; numbered next steps.>

## Critical considerations & pointers
<constraints + the WHY; links to the wider doc set.>

## Suggested first action
<one concrete, self-contained next move.>

## Checkpoint routine
<at each pause: drain the run's context to the trackers, update this hand-off, run <gate>.>
```

### `perf-log.md`
```
# <YYYY-MM-DD> -- <slug> (perf)
## Context / Run / Results / Analysis / Follow-ups
<what you measured, the machine, the numbers, the verdict, next steps.>
```

---

## 13. Deployment playbook

**Full deploy:**
1. Fill the *Slots* (§2): `<keystone>`, `<gate>`, `<stack>`.
2. Create the *Manifest* tree (§4). Start the front door, `.agents/dev/README`, and `.agents/dev/MEMORY`.
3. Copy the bundled `templates/` into `.agents/dev/templates/` (§12).
4. Add the *Trackers* (§6) as empty files with a one-line "what goes here" header each.
5. Add the routing + planning + worktree + maintenance + sync docs (§5, §7-§10), genericized to
   your stack.
6. Implement the *Linter* (§11) and wire it into `<gate>`.
7. Write your `<content docs>` (architecture/gotchas/diagnostics/perf) -- these are yours.

**Partial borrow:** pick modules from the *Module map* (§3); honor their dependencies. The most
valuable standalone borrow is **Core + the four trackers + Templates** -- bounded capture and
consistent artifacts with almost no overhead.

**Keeping this file current:** `BOOTSTRAP.md` is a snapshot of a living system; it drifts unless
maintained. Update it whenever the system's *structure* changes (a doc added/removed, a convention
flipped) -- not for routine content edits. Treat it as one more thing the spine audit checks.
