# `/backlog init` — stand up backlog's own home + register its route (self-init, no floor)

Create the `.records/` trackers `/backlog` owns and register backlog's route into the project's
always-loaded front-door doc — **without depending on the pack onramps (`/clankshop setup` / `migrate`) having scaffolded anything
first**. This is the "capture bureau that can build its own drawer": a bare install of `/backlog`
alone can stand up a working, visible capture home. Both halves are **idempotent** and **never clobber
filed entries** — re-running `init` converges to the same state.

This verb realizes two corollaries of the typed-edge tenet
(`docs/design/2026-07-18-skill-self-init-model.md` §1): **self-init, no floor** (a skill creates its
own home — corollary 1) and **visibility by construction** (a skill registers its route where the
harness already loads it, so it surfaces with no composer present — corollary 2).

## When to use

- A project has `/backlog` installed but **no `.records/` capture home yet** — a fresh repo, or one
  where the pack onramps haven’t run (and may never; backlog needs no floor). The capture verbs call `init` **lazily** on an unstamped root, so a first capture self-initializes.
- The user runs `/backlog init`, or says "stand up the trackers", "set up the backlog", "make the
  capture home".
- **Re-running is safe and expected** — to refresh the front-door registration stamp after the skill
  changes, or to backfill a tracker deleted by hand. `init` only *creates what's missing* and *rewrites
  its own delimited block*; it touches nothing else.

**Do NOT use** to file an item (that's the capture verbs — `/backlog task|bug|issue|note|feedback`) or
to scaffold the *wider* `.records/` tree (`plans/`, `archive/`, `adr/`, `reports/`, `logs/`, `audit/`)
— those homes belong to other skills’ init / the pack onramps. `/backlog init` makes **only backlog's
own drawers**, not the whole cabinet.

## What `init` creates

**1. Backlog's `.records/` home** (the five capture stores it owns, per `docs/TAXONOMY.md`):

| path | kind | seed |
|---|---|---|
| `.records/trackers/tasks.md` | flat living list | header + domain sections (`Loose ends` / `Adjacent improvements` / `Open questions` / `Future scope`) |
| `.records/trackers/issues.md` | flat log | header + `##` category sections (`I-` entries) |
| `.records/trackers/feedback.md` | flat dated list | header + live-region marker |
| `.records/trackers/notes/` | store dir | `README.md` (store doc, no frontmatter) |
| `.records/trackers/bugs/` | store dir | `README.md` (store doc, no frontmatter) |

**2. The installation block** (created-or-adopted, idempotently): the front door's
`<!-- installation v1 -->` stamp that makes the root a resolvable installation. Absent → append a
layout-only block; present (including a pack-stamped one) → adopt untouched; malformed → a fact,
nothing written. `init` touches **no `.handbook/` chapter** — the trackers skeleton and the
installation block are exactly its pre-stamp write license.

**3. Backlog's door registration block** in the front-door doc's `## Skill routes
(self-registered)` section — the **pack-style block**: its body is backlog's entry in the
doctrine's **door profile** (the fenced `### /backlog` block in
`skills/clankshop/doctrine/README.md` — the single source every route writer copies, never
authored here), stamped with the pack version, carrying **no `Edges:` lines**:

```markdown
<!-- skill:backlog BEGIN built-against:clankshop@<pack-version> -->
### /backlog — the records instrument
Route: capture by kind (task / bug / issue / note / feedback), escalate via tickets, complete via
`done`, curate the stores, debrief finished work.
<!-- skill:backlog END -->
```

## The three mechanical helpers (facts/mutation split)

Every write is a deterministic mechanical mutation, so each lives in a script (siblings
of `scripts/scoped-commit.sh` — each mutates only the paths it is handed); the verb keeps the
judgment (which front-door, what the route says):

- **`scripts/scaffold-records.sh <root>`** — create-if-absent for the five stores under
  `.records/trackers/`. Prints `created=`/`exists=` per path; an existing tracker is **never**
  rewritten. Idempotent by construction.
- **`install-block.sh write <root> 1`** (the pack face's script,
  `skills/clankshop/scripts/install-block.sh` — a shared pack asset): create-or-adopt the
  installation block. Absent → a layout-only block is appended (`created=1`); present → adopted
  untouched (`adopted=1`, a pack-stamped block included); malformed → the fact, nothing written.
- **`scripts/register-route.sh <front-door> backlog [<built-against>]`** (block body on stdin) — the
  idempotent front-door writer: **absent → append** a fresh block (creating the section if needed);
  **present → replace only between the delimiters**; **malformed (a broken delimiter pair) → report and
  touch nothing** (safe-by-default; never clobber hand-edited content). The skill owns only the bytes
  between its own `skill:backlog` delimiters; everything around them (section header, block ordering,
  any composer-derived seam notes) is preserved verbatim (model §3.4).

## Procedure

1. **Resolve the root + the built-against stamp.** Project root from a project dir the conversation
   references, else cwd, else ask. The stamp is the **pack version**:
   `clankshop@<pack-version>`, where `<pack-version>` comes from the root's installation block
   (`install-block.sh read <root>` → `pack-version=`) when the root is pack-stamped, else from the
   pack lock's `pack-version:` line (`packs/clankshop.md` frontmatter, beside the installed skills)
   — core members carry no individual version; the pack pins them. The stamp is what the check
   validator compares — a pointer to what was projected, not a guarantee.
2. **Scaffold the home + the installation block.** Run `scripts/scaffold-records.sh <root>`, then
   `install-block.sh write <root> 1` (create-or-adopt; see the helpers above). Report the
   `created=`/`exists=`/`adopted=` facts. No composer is required or consulted; a bare install of
   backlog alone yields a resolvable installation.
3. **Resolve the front-door doc — parameterized, never assumed.** The registration target is the
   project's **always-loaded** front-door (`AGENTS.md` / `CLAUDE.md` at the project root, whichever the
   harness auto-loads). It must **exist**; if the project has none, that's a project-setup gap — say so
   and stop before writing (registration only delivers visibility if it lands where the harness reads).
   **Grimoire caveat (patient-zero):** never register against grimoire's own authored `AGENTS.md` — see
   *The fixture caveat* below.
4. **Register the route — the pack-style block.** Extract backlog's body from the doctrine's door
   profile (the fenced `### /backlog` block in `skills/clankshop/doctrine/README.md`) and feed it
   verbatim on stdin to
   `scripts/register-route.sh <front-door> backlog clankshop@<pack-version>`. The body carries
   **no `Edges:` lines** — an existing pack-style block written by setup is **adopted** (re-running
   converges byte-identically), never overwritten with a different body. Report `appended` /
   `replaced`. If it reports **malformed**, surface that — a delimiter was hand-broken; the human
   repairs it, then re-run. Do **not** force it.
5. **Report** the created stores, the front-door path + result, and the `built-against` stamp. Note that
   the deployed check chain (clankshop `check`) validates this projection and flags drift against the stamp.

**Commit policy.** `init` writes new shared content, so it follows the same trunk-only, pathspec-atomic
rule as the capture verbs (see `SKILL.md` → *Shared discipline*): standalone, scoped-commit the created
`.records/` paths **and** the front-door doc in one step via
`scripts/scoped-commit.sh <root> "backlog: init capture home + register route" <paths…>`, then run the
host's cheap doc gate if it has one. (Inside a larger pack `setup`/`migrate` or a sweep, only write; the caller commits.)

## Idempotency + the write protocol (why re-running is safe)

- **Scaffolding is create-if-absent** — a filed `tasks.md` line, a captured bug report, an existing
  tracker are never touched. `init` on a populated home is a no-op beyond reporting `exists=`.
- **Registration is replace-between-delimiters** — re-running with the same `built-against` is
  byte-identical; with a fresh stamp it rewrites only backlog's own block. **A sibling skill's block is
  preserved untouched** (proven in the pilot's A4 acceptance), because backlog only ever addresses its
  own `skill:backlog` delimiters. This is corollary 3 made mechanical: backlog names no sibling, and the
  composer owns everything around the blocks.
- **Malformed → safe-by-default** — a broken delimiter pair is reported, never guessed-through.

## The fixture caveat (grimoire is patient-zero — model §3.2)

Grimoire's own `AGENTS.md` is **authored library doctrine**, not a consuming project's scaffold — self-
registration blocks must **never** accrete in it. Grimoire is where this mechanism is *built and
tested*, not a self-registering deployment. So the front-door path is a **parameter**, and in grimoire
the verb is exercised only against a **throwaway fixture front-door** (a temp `AGENTS.md` under the
scratchpad, or a `packs/` sample) — never the real one. In a genuine consuming project the parameter
resolves to that project's real front-door, which is the whole point. The pilot's A4 acceptance
transcript (`docs/design/2026-07-18-phase1-pilot-acceptance.md`) runs the full mechanism against such a
fixture.

## Done when

`.records/` carries backlog's five capture stores (each seeded, none clobbered), the resolved front-door
doc carries a stamped `skill:backlog` block inside its `## Skill routes (self-registered)` section, both
writes are idempotent and non-destructive to sibling content, and the chat reports the created stores +
the front-door result + the `built-against` stamp — with **no composer having been required** at any
point.
