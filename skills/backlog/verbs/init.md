# `/backlog init` — stand up backlog's own home + register its route (self-init, no floor)

Create the `.records/` trackers `/backlog` owns and register backlog's route into the project's
always-loaded front-door doc — **without depending on `/foreman init` having scaffolded anything
first**. This is the "capture bureau that can build its own drawer": a bare install of `/backlog`
alone can stand up a working, visible capture home. Both halves are **idempotent** and **never clobber
filed entries** — re-running `init` converges to the same state.

This verb realizes two corollaries of the typed-edge tenet
(`docs/design/2026-07-18-skill-self-init-model.md` §1): **self-init, no floor** (a skill creates its
own home — corollary 1) and **visibility by construction** (a skill registers its route where the
harness already loads it, so it surfaces with no composer present — corollary 2).

## When to use

- A project has `/backlog` installed but **no `.records/` capture home yet** — a fresh repo, or one
  where `/foreman init` hasn't run (and may never; backlog needs no floor).
- The user runs `/backlog init`, or says "stand up the trackers", "set up the backlog", "make the
  capture home".
- **Re-running is safe and expected** — to refresh the front-door registration stamp after the skill
  changes, or to backfill a tracker deleted by hand. `init` only *creates what's missing* and *rewrites
  its own delimited block*; it touches nothing else.

**Do NOT use** to file an item (that's the capture verbs — `/backlog task|bug|issue|note|feedback`) or
to scaffold the *wider* `.records/` tree (`plans/`, `archive/`, `adr/`, `reports/`, `logs/`, `audit/`)
— those homes belong to other skills' init / `/foreman init`. `/backlog init` makes **only backlog's
own drawers**, not the whole cabinet.

## What `init` creates

**1. Backlog's `.records/` home** (the five capture stores it owns, per `docs/TAXONOMY.md`):

| path | kind | seed |
|---|---|---|
| `.records/tasks.md` | flat living list | header + domain sections (`Loose ends` / `Adjacent improvements` / `Open questions` / `Future scope`) |
| `.records/issues.md` | flat log | header + `P#` / `R#` category sections |
| `.records/feedback.md` | flat dated list | header + live-region marker |
| `.records/notes/` | store dir | `README.md` (store doc, no frontmatter) |
| `.records/bugs/` | store dir | `README.md` (store doc, no frontmatter) |

**2. Backlog's route block** in the front-door doc's `## Skill routes (self-registered)` section — the
delimited, stamped projection a bare reader sees without opening the skill (model §3.3):

```markdown
<!-- skill:backlog BEGIN built-against:<sha-or-version> -->
### /backlog — capture bureau
Route: file/sweep/curate follow-ups into `.records/` trackers. `/backlog task|bug|issue|note|feedback|debrief|curate`.
Edges: produces `tracker-entry`.
<!-- skill:backlog END -->
```

## The two mechanical helpers (facts/mutation split)

Both writes are deterministic mechanical mutations, so they live in **read-scoped scripts** (siblings
of `scripts/scoped-commit.sh` — each mutates only the paths it is handed); the verb keeps the
judgment (which front-door, what the route says):

- **`scripts/scaffold-records.sh <root>`** — create-if-absent for the five stores. Prints
  `created=`/`exists=` per path; an existing tracker is **never** rewritten. Idempotent by construction.
- **`scripts/register-route.sh <front-door> backlog [<built-against>]`** (block body on stdin) — the
  idempotent front-door writer: **absent → append** a fresh block (creating the section if needed);
  **present → replace only between the delimiters**; **malformed (a broken delimiter pair) → report and
  touch nothing** (safe-by-default; never clobber hand-edited content). The skill owns only the bytes
  between its own `skill:backlog` delimiters; everything around them (section header, block ordering,
  any composer-derived seam notes) is preserved verbatim (model §3.4).

## Procedure

1. **Resolve the root + the built-against stamp.** Project root from a project dir the conversation
   references, else cwd, else ask. Compute `<built-against>` as backlog's own version: the skill dir's
   short git sha where it lives in a repo (`git -C <skill-dir> rev-parse --short HEAD`), else a version
   string, else `v0-<date>` (`date +%Y-%m-%d`, never guessed). The stamp is what the drift validator
   compares — a pointer to what was projected, not a guarantee.
2. **Scaffold the home.** Run `scripts/scaffold-records.sh <root>`. Report what was created vs. already
   present (the facts are its output). No `/foreman` is required or consulted.
3. **Resolve the front-door doc — parameterized, never assumed.** The registration target is the
   project's **always-loaded** front-door (`AGENTS.md` / `CLAUDE.md` at the project root, whichever the
   harness auto-loads). It must **exist**; if the project has none, that's a project-setup gap — say so
   and stop before writing (registration only delivers visibility if it lands where the harness reads).
   **Grimoire caveat (patient-zero):** never register against grimoire's own authored `AGENTS.md` — see
   *The fixture caveat* below.
4. **Register the route.** Feed the block body (the three lines: `### /backlog …` heading, the `Route:`
   line, the `Edges: produces \`tracker-entry\`.` echo) on stdin to
   `scripts/register-route.sh <front-door> backlog <built-against>`. Report `appended` / `replaced`. If
   it reports **malformed**, surface that — a delimiter was hand-broken; the human or composer repairs
   it, then re-run. Do **not** force it.
5. **Report** the created stores, the front-door path + result, and the `built-against` stamp. Note that
   a composer (`/foreman check`, later) re-derives this projection and flags drift against the stamp.

**Commit policy.** `init` writes new shared content, so it follows the same trunk-only, pathspec-atomic
rule as the capture verbs (see `SKILL.md` → *Shared discipline*): standalone, scoped-commit the created
`.records/` paths **and** the front-door doc in one step via
`scripts/scoped-commit.sh <root> "backlog: init capture home + register route" <paths…>`, then run the
host doc-linter. (Inside a larger `/foreman init` or a sweep, only write; the caller commits.)

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
the front-door result + the `built-against` stamp — with **no `/foreman` having been required** at any
point.
