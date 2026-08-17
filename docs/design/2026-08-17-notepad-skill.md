---
doctype: design
status: open
created: 2026-08-17
updated: 2026-08-17
tags: []
---

# notepad — project memory for agents

**Status:** proposed (2026-08-17). Settled in conversation on stream `grok`. A new
`clankshop` helper: the skill agents reach for to take, find, update, and
supersede durable project facts. The `notes/` store stays the format
authority's; this skill is how notes get written and retrieved.

Companion plan: `docs/design/2026-08-17-notepad-skill-plan.md`.

## Why this is a skill

`/backlog note` is the wrong reach-for. Backlog is the follow-up lifecycle
(trackers, tickets, debrief, curate). A durable fact is not a todo. Agents
that want to write something down should load a skill whose description fires
on that job.

Neighbors this is **not**:

- `backlog` — capture of things to do / concerns / tickets; tracker grooming;
  the sweep. It stops minting notes.
- `journal` — format authority for the records layer (stores, contract,
  `records.sh`, ledger). It does not become a floor for taking a note.
- A session scratchpad — notes persist as records, not chat.

## Decision summary (settled with the human, 2026-08-17)

- **Job: project memory.** Write, find, update, supersede. Not a renamed
  `/backlog note`.
- **Path-first, opportunistic `records.sh`.** Notes live at
  `<records-root>/notes/` (declared `records-root:` in the front-door
  `AGENTS.md`, else `.records/notes`). Notepad creates that directory. It
  does not run journal setup and does not refuse when `records.sh` is
  missing. If `records.sh` is present, use it for `new` / `touch` / `done`
  so dates and collisions stay mechanical. If it is not, notepad writes the
  same shape itself via a bundled mint script.
- **Contract-conformant at birth.** Dated slug path
  (`YYYY-MM-DD-<slug>.md`) and the five front-matter keys, from notepad's
  own `templates/notes.md` (moved off backlog). Valid `notes/` records
  immediately. Journal `check` / `curate` is a backstop, not the author.
- **Journal is optional hygiene.** It may later fix front-matter or
  formatting. It is not a gate and not the minter of first resort.
- **Notepad does not own the store.** Journal still lists `notes` among the
  eight stores and still defines the contract. Ownership of the *template*
  follows the minting verb (already the contract rule): it moves from
  backlog to notepad.
- **`/backlog note` is deleted.** Debrief routes facts by invoking notepad
  `write` with its commit step skipped. Only notepad mints `notes/`.
- **No `init`.** Lazy-create `<records-root>/notes/` (and the records-root
  directory if needed). Do not scaffold the rest of the layer — no
  `history.tsv`, no `records.sh`, no other stores. Do not register against
  this library's real `AGENTS.md` (patient-zero).
- **Pack member.** Optional-but-default helper, same tier as backlog.
  Manifest `version:` 2.2.0 → 2.3.0 (`PACK.md` versioning rule: member-set
  change).
- **Bugs stay on backlog.** Filing-without-chase is still `/backlog bug`.
  Debugger may mint a `bugs/` record on defer in a later design; not this
  work.

## 1. Shape and placement

- Path: `skills/notepad/`.
- Invocation: `/notepad write|find|supersede`. No default verb — ask which.
- Standalone package. Works on a bare repo. Workshop-aware only in that it
  honors `records-root:` and will use a deployed `records.sh` when that
  file exists.
- Tier: **not durable-home.** Recorded disposition: records-path client.
  Nothing private to scaffold; the notes directory is a conventional path
  in the host repo, created on first write.
- Inventory: README table row + pack roster. `install.sh` discovers the
  new directory the same way it discovers every other skill.

**Description** (routing surface — trigger only; names no sibling):

> Use when the user runs `/notepad`, asks to write down a project fact, look
> up or update existing notes, or supersede a note that is no longer true.
> Keywords: note, notes, notepad, write this down, how does this work,
> project memory, capture this fact.

**Edges**

```
produces: note — a notes/ record
handoff:  — (write/find/supersede complete in place)
consumes: note — find/update/supersede read existing notes
```

**When not to use:** an action item (someone should build or fix something);
a reproducible defect to file for later; a decision between alternatives
that belongs in an `adr` record; session scratch that must not persist.

## 2. Package layout

```
skills/notepad/
  SKILL.md                    # trigger, dispatch, shared discipline, edges
  verbs/write.md              # find-or-update, else mint
  verbs/find.md               # list / retrieve
  verbs/supersede.md          # close old, mint replacement
  templates/notes.md          # moved from skills/backlog/templates/notes.md
  scripts/note-mint.sh        # facts: resolve root, mint or stamp, print path
  scripts/scoped-commit.sh    # copy of the contended-index commit mechanic
  scripts/tests/note-mint-test.sh
  scripts/tests/run.sh
```

`note-mint.sh` is stateless and prints `key=value` facts plus the minted
path. It never decides whether to update vs mint, which note covers a
fact, or whether to commit. Those stay in the verb prose.

## 3. Records root and mint

**Resolve the records root** the same way every other client does: first
`^records-root:` in the host `AGENTS.md` / `CLAUDE.md`, else `.records`.
Inline the doctrine resolver in `note-mint.sh` (self-contained; do not
source a sibling).

**`records.sh` present** (`<records-root>/scripts/records.sh` is
executable):

1. If `<records-root>/templates/notes.md` is absent, copy this skill's
   bundled template there.
2. `records.sh new notes --title "<headline>"` (or `touch` on update,
   `done --as superseded --note "<successor>"` on supersede).
3. Fill the body from the verb (one fact; why it holds; where it bites;
   links).

**`records.sh` absent:**

1. `mkdir -p <records-root>/notes`.
2. `note-mint.sh` writes `<records-root>/notes/YYYY-MM-DD-<slug>.md` from
   the bundled template. Slug and collision rules match `records.sh`
   `cmd_new` (`skills/journal/scripts/records.sh:171-181`): lowercase,
   non-alphanumerics to `-`, empty slug is an error, existing path gets
   `-<n>` starting at 2. Date from `date +%Y-%m-%d`. Print the path.
3. Do not create `history.tsv`, `scripts/records.sh`, or any other store.
4. Do not write `history.tsv` by hand on supersede. Rewrite `status:
   superseded` in the old file's front-matter and name the successor in
   the body. If journal is later stood up, `records.sh check` may flag a
   closing status with no ledger line — that is journal `done`'s repair,
   not notepad's.

Update stamps `updated:` the same way: `records.sh touch` when present,
else `note-mint.sh` rewrites that one key.

## 4. Verbs

Shared discipline, stated once on `SKILL.md`:

- Resolve the records root. Never guess a date when `records.sh` can
  supply it.
- One fact per note (the path is the ID).
- **Resolve the commit tree, then commit there** — the same ordered probe
  already on journal and backlog (`skills/journal/SKILL.md:94-103`):
  detached STOP; worktree `WORKSTREAM.md` matching branch → commit here;
  in-place stream holding the root → commit here; `stream/*` /
  `feature/*` STOP; else current trunk (never hardcode `main`).
- Pathspec-atomic commit via this skill's `scripts/scoped-commit.sh`.
- Standalone invocation commits (`Notepad: write — <slug>` and kin).
  Invoked write-only from a sweep → no commit.

**`write`.** Check existing notes first (`records.sh list --type notes`
when present, else scan `<records-root>/notes/*.md`). If one already
covers the fact, edit it and stamp. Otherwise mint. Prefer one fact per
note. Write-only mode: skip the commit step (the caller commits).

**`find`.** List or retrieve. Print enough for the agent to cite a path.
No mint. No commit.

**`supersede`.** Mint the replacement (or confirm the successor already
exists), then close the old note `superseded` naming the successor.
Never silently edit a note into a different claim.

## 5. Cutover from backlog

- Delete `skills/backlog/verbs/note.md` and
  `skills/backlog/templates/notes.md`.
- Drop the `/backlog note` dispatch row and the "notes" store from
  backlog's lazy-deploy list (`skills/backlog/SKILL.md` shared
  discipline currently names `bugs`, `notes`, `tickets`, `trackers`).
- `skills/backlog/verbs/debrief.md` step 3: route facts through notepad
  `write` write-only. The other capture kinds stay on backlog.
- A substantial `issue` analysis that needs a dated note is minted
  through notepad `write` write-only, then linked. Backlog no longer
  mints `notes/`.
- Do not leave `/backlog note` as an alias.

## 6. Failure states

| Situation | Behavior |
|---|---|
| Empty title / slug | refuse; ask for a headline |
| No existing notes dir | create it; do not refuse |
| `records.sh` missing | mint/stamp via `note-mint.sh`; do not point at journal setup |
| `records.sh` present, notes template missing | lazy-deploy notepad's template, then `new` |
| Duplicate fact | update the existing note; do not mint |
| Detached HEAD or unheld `stream/*`/`feature/*` | STOP; do not commit |
| Find with no notes | say so; do not mint |
| Supersede without a successor | refuse |

## 7. Non-goals

- Moving `/backlog bug` or any other capture kind.
- Giving notepad ownership of the `notes` store or of journal's contract.
- Standing up the records layer, deploying `records.sh`, or writing
  `history.tsv`.
- Front-door registration on this library.
- A search index, embeddings, or anything beyond a live directory scan /
  `records.sh list`.
- Session-only scratch notes.

## Key Decisions

- **Reach-for is the product.** The skill exists so "write this down"
  loads notepad, not backlog. Rationale: trigger quality; `/backlog note`
  names the wrong job.
- **Path convention, not journal setup.** Agents can take notes on a
  repo that has never run `/journal setup`. Rationale: notes are basic
  memory; requiring a records standup is the wrong floor.
- **Same bytes either minter.** Opportunistic `records.sh` plus a
  matching script means one record shape. Rationale: journal `check`
  stays meaningful; two formats in one store is the failure mode.
- **Template follows the minting verb.** Already the contract. Rationale:
  journal must not become the dump for other skills' templates.
- **Debrief still emits notes.** The sweep calls `write` write-only.
  Rationale: facts that surface mid-feature are byproducts; they must
  not vanish because the mint moved.
- **No ledger writes without `records.sh`.** Rationale: the ledger has
  one writer; a closing status without a line is journal's to repair.

## Open Questions

None remaining from the grill. Implementation sequencing lives in the
companion plan.
