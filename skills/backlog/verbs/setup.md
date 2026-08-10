# `/backlog setup` — stand up backlog's own home + register its route (self-init, no floor)

Create the tracker stores `/backlog` owns and register backlog's route into the project's
always-loaded front-door doc — **on any repo, framework or not**, depending on nothing having
scaffolded anything first. This is the records instrument building its own drawer: a bare install
of `/backlog` alone stands up a working, visible capture home. Both halves are **idempotent** and
**never clobber filed entries** — re-running `setup` converges to the same state.

Two principles hold here: **self-init, no floor** (the instrument creates its own home, depending
on no other skill having run first) and **visibility by construction** (it registers its route where
the harness already loads it, so it surfaces with no composer present).

## When to use

- A project has `/backlog` installed but **no capture home yet** — a fresh repo, framework or not.
  The capture verbs call `setup` **lazily** when the trackers are missing, so a first capture
  self-initializes.
- The user runs `/backlog setup`, or says "stand up the trackers", "set up the backlog", "make the
  capture home".
- **Re-running is safe and expected** — to refresh the front-door registration stamp after the skill
  changes, or to backfill a tracker deleted by hand. `setup` only *creates what's missing* and *rewrites
  its own delimited block*; it touches nothing else.

**Do NOT use** to file an item (that's the capture verbs — `/backlog task|bug|issue|note|feedback`) or
to scaffold the *wider* records tree (`plans/`, `archive/`, `adr/`, `reports/`, `logs/`, `audit/`)
— those homes belong to other skills' setup / the pack onramps. `/backlog setup` makes **only backlog's
own drawers**, not the whole cabinet.

## Where the trackers land — the records root

The trackers live under the project's **records root**: the front door's `records-root:`
declaration when one exists (a legacy layout — `records-root: dev` — is respected in place), else
`.records/`. `scripts/scaffold-records.sh` resolves this itself and prints the resolved
`records-root=` fact; never hardcode the default over a declared root.

## What `setup` creates

**1. Backlog's tracker home** (the five capture stores it owns, per `docs/TAXONOMY.md`), under
`<records-root>/trackers/`:

| path (under the records root) | kind | seed |
|---|---|---|
| `trackers/tasks.md` | flat living list | header + domain sections (`Loose ends` / `Adjacent improvements` / `Open questions` / `Future scope`) |
| `trackers/issues.md` | flat log | header + `##` category sections (`I-` entries) |
| `trackers/feedback.md` | flat dated list | header + live-region marker |
| `trackers/notes/` | store dir | `README.md` (store doc, no frontmatter) |
| `trackers/bugs/` | store dir | `README.md` (store doc, no frontmatter) |

**2. Backlog's door registration block** in the front-door doc's `## Skill routes
(self-registered)` section — body and stamp resolved by host:

- **Clankshop host** (the root carries the installation block): the body is backlog's entry in
  the pack doctrine's **door profile** (the fenced `### /backlog` block in
  `skills/clankshop/doctrine/README.md` — the single source every pack route writer copies, never
  authored here), stamped `built-against:clankshop@<pack-version>` read from the installation
  block, carrying **no `Edges:` lines**. An existing pack-style block written by the composer is
  **adopted** (re-running converges byte-identically), never overwritten with a different body.
- **Any other host:** backlog's own bundled body (below), stamped `built-against:standalone` —
  there is no pack to version against. A later pack install upgrades the block (re-run `setup` on
  the then-stamped root, or let the onramp rewrite it):
  ```markdown
  ### /backlog — the records instrument
  Route: capture by kind (task / bug / issue / note / feedback), escalate via tickets, complete via
  `done`, curate the stores, debrief finished work.
  ```

`setup` writes **no installation block and no `.handbook/` chapter** — standing the framework up
is the human's separate decision (the clankshop onramps), never a capture-home side effect.

## The two mechanical helpers (facts/mutation split)

Every write is a deterministic mechanical mutation, so each lives in a script (siblings
of `scripts/scoped-commit.sh` — each mutates only the paths it is handed); the verb keeps the
judgment (which front-door, what the route says):

- **`scripts/scaffold-records.sh <root>`** — create-if-absent for the five stores under the
  resolved records root's `trackers/`. Prints the resolved `records-root=` plus
  `created=`/`exists=` per path; an existing tracker is **never** rewritten. Idempotent by
  construction.
- **`scripts/register-route.sh <front-door> backlog [<built-against>]`** (block body on stdin) — the
  idempotent front-door writer: **absent → append** a fresh block (creating the section if needed);
  **present → replace only between the delimiters**; **malformed (a broken delimiter pair) → report and
  touch nothing** (safe-by-default; never clobber hand-edited content). The skill owns only the bytes
  between its own `skill:backlog` delimiters; everything around them (section header, block ordering,
  any composer-derived seam notes) is preserved verbatim (model §3.4).

## Procedure

1. **Resolve the root + the host.** Project root from a project dir the conversation references,
   else cwd, else ask. The host is clankshop when the front door carries the installation block
   (an `<!-- installation v1 -->` block — read directly; no pack script is needed to look);
   anything else is a standalone host.
2. **Scaffold the home.** Run `scripts/scaffold-records.sh <root>` and report its
   `records-root=` / `created=` / `exists=` facts. No composer is required or consulted.
3. **Resolve the front-door doc — parameterized, never assumed.** The registration target is the
   project's **always-loaded** front-door (`AGENTS.md` / `CLAUDE.md` at the project root, whichever the
   harness auto-loads). It must exist; if the project has none, say so and **offer** to create a
   minimal one — creating a front door is the human's call, never a silent side effect.
   **Grimoire caveat (patient-zero):** never register against grimoire's own authored `AGENTS.md` — see
   *The fixture caveat* below.
4. **Register the route.** Resolve the body + stamp by host (*What `setup` creates*, above) and
   feed the body on stdin to `scripts/register-route.sh <front-door> backlog <stamp>`. Report
   `appended` / `replaced`. If it reports **malformed**, surface that — a delimiter was
   hand-broken; the human repairs it, then re-run. Do **not** force it.
5. **Report** the records root, the created stores, the front-door path + result, and the
   `built-against` stamp. On a clankshop host the deployed check chain (clankshop `check`)
   validates this projection and flags drift against the stamp.

**Commit policy.** `setup` writes new shared content, so it follows the same trunk-only, pathspec-atomic
rule as the capture verbs (see `SKILL.md` → *Shared discipline*): standalone, scoped-commit the created
records paths **and** the front-door doc in one step via
`scripts/scoped-commit.sh <root> "backlog: set up capture home + register route" <paths…>`, then run the
host's cheap doc gate if it has one. (Inside a larger pack `setup`/`migrate` or a sweep, only write; the caller commits.)

## Idempotency + the write protocol (why re-running is safe)

- **Scaffolding is create-if-absent** — a filed `tasks.md` line, a captured bug report, an existing
  tracker are never touched. `setup` on a populated home is a no-op beyond reporting `exists=`.
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
scratchpad) — never the real one. In a genuine consuming project the parameter
resolves to that project's real front-door, which is the whole point. The pilot's A4 acceptance
transcript (`docs/design/2026-07-18-phase1-pilot-acceptance.md`) runs the full mechanism against such a
fixture.

## Done when

The resolved records root carries backlog's five capture stores (each seeded, none clobbered), the
resolved front-door doc carries a stamped `skill:backlog` block inside its `## Skill routes
(self-registered)` section, both writes are idempotent and non-destructive to sibling content, and
the chat reports the records root + created stores + the front-door result + the `built-against`
stamp — with **no composer having been required** at any point.
