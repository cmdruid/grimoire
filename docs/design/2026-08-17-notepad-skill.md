---
doctype: design
status: open
created: 2026-08-17
updated: 2026-08-17
tags: []
---

# notepad — project memory for agents

**Status:** proposed (2026-08-17). Settled in conversation on stream `grok`;
council findings folded the same day (`RESULT.md` baton). A new
`clankshop` helper: the skill agents reach for to take, find, update,
supersede, and drop durable project facts. The `notes/` store stays the
format authority's; this skill is how notes get written and retrieved.

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

- **Job: project memory.** Write, find, update, supersede, drop. Not a
  renamed `/backlog note`.
- **Path-first, opportunistic `records.sh`.** Notes live at
  `<records-root>/notes/`. The **verb** resolves the root (first
  `^records-root:` in host `AGENTS.md`, then `CLAUDE.md`, else
  `.records`) and passes it to `note-mint.sh`. Notepad creates the
  `notes/` directory. It does not run journal setup and does not refuse
  when `records.sh` is missing. The script is the single minter: if
  `records.sh` is present it uses `new` / `touch` / `done`; if not, it
  writes the same *contract* shape itself.
- **Contract-conformant at birth.** Dated slug path
  (`YYYY-MM-DD-<slug>.md`) and the five front-matter keys, from the
  template `records.sh new` would use (deployed copy if present, else
  notepad's bundled `templates/notes.md`). Slot fill is the same
  `<title>` / `<date>` substitution as `records.sh` `fill`
  (`skills/journal/scripts/records.sh:136-155`, invoked from `cmd_new`
  at `:180`). Journal `check` / `curate` is a backstop, not the author.
- **Contract equivalence, not byte identity.** An incumbent deployed
  `templates/notes.md` is left in place (lazy-deploy only when absent).
  Both minters produce contract-valid records; they need not be
  byte-identical to each other.
- **Journal is optional hygiene.** It may later fix front-matter or
  formatting. It is not a gate and not the minter of first resort.
- **Notepad does not own the store.** Journal still lists `notes` among the
  eight stores and still defines the contract. Ownership of the *template*
  follows the minting verb: it moves from backlog to notepad.
- **`/backlog note` is deleted**, including trigger prose. Backlog's
  `description:` and intro must stop matching `note` / `fact` / "write
  this down". Debrief routes facts by invoking notepad `write`
  write-only (prose contract below). Only notepad mints `notes/`.
- **No `init`.** Lazy-create `<records-root>/notes/` (and the records-root
  directory if needed). Do not scaffold the rest of the layer — no
  `history.tsv`, no `records.sh`, no other stores. Do not register against
  this library's real `AGENTS.md` (patient-zero).
- **Git checkout required.** "Bare repo" means no workshop and no
  `records.sh`, not "no git". Non-git trees STOP at the commit-tree
  probe. Out of scope: no-worktree / non-git hosts.
- **Pack member.** Optional-but-default helper, same tier as backlog.
  Manifest `version:` 2.2.0 → 2.3.0 (`PACK.md` versioning rule: member-set
  change).
- **Bugs stay on backlog.** Filing-without-chase is still `/backlog bug`.
  Debugger may mint a `bugs/` record on defer in a later design; not this
  work.

## 1. Shape and placement

- Path: `skills/notepad/`.
- Invocation: `/notepad write|find|supersede|drop`. No default verb — ask
  which.
- Standalone package. Works on a git checkout that has never stood up
  the records layer. Workshop-aware only in that it honors
  `records-root:` and will use a deployed `records.sh` when that file
  exists.
- Tier: **not durable-home.** Recorded disposition: records-path client.
  Nothing private to scaffold; the notes directory is a conventional path
  in the host repo, created on first write.
- Inventory: README table row + pack roster. `install.sh` discovers the
  new directory the same way it discovers every other skill.

**Description** (routing surface — trigger only; names no sibling):

> Use when the user runs `/notepad`, asks to write down a project fact, look
> up or update existing notes, supersede a note that is no longer true, or
> drop a note with no successor. Keywords: note, notes, notepad, write this
> down, how does this work, project memory, capture this fact.

**Edges**

```
produces: note — a notes/ record
handoff:  note — write-only sweep: skip scoped-commit; return path= / rel=
consumes: note — find/update/supersede/drop read existing notes
```

**Write-only sweep contract** (no fourth flag, no `--no-commit` verb):
when the caller is a sweep (`debrief` or `issue` graduating analysis),
skip `scoped-commit.sh`, print the `path=` / `rel=` facts from
`note-mint.sh`, and let the caller commit. The caller is identified by
being that sweep, not by a CLI switch.

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
  verbs/drop.md               # close dropped; no successor
  templates/notes.md          # moved from skills/backlog/templates/notes.md
  scripts/note-mint.sh        # mint or stamp; uses records.sh when present
  scripts/scoped-commit.sh    # copy of the contended-index commit mechanic
  scripts/tests/note-mint-test.sh
  scripts/tests/run.sh
```

`note-mint.sh` is stateless. It never decides whether to update vs mint,
which note covers a fact, or whether to commit. Those stay in the verb
prose.

**CLI (frozen):**

```
note-mint.sh mint  <records-root> <title>
note-mint.sh stamp <records-root> <abs-path> [--status <status>]
```

Exit 0 on success, non-zero on empty slug / missing path / usage.
Stdout is exactly these keys, one per line:

```
records-root=<abs>
path=<abs>
rel=notes/<file>.md
mode=file|records
```

`stamp` also prints `mode=stamp` when it only rewrote front-matter
without going through `records.sh done`; `mode=records` when `touch` or
`done` ran.

`<records-root>` is always an argument. The script does **not** scan
`AGENTS.md` / `CLAUDE.md`.

## 3. Records root and mint

**The verb resolves the records root** with the doctrine resolver
inlined in `SKILL.md` (self-contained; do not source a sibling): first
`^records-root:` in `AGENTS.md`, then `CLAUDE.md`, else `.records`.
Pass the resolved path into every `note-mint.sh` call.

**`note-mint.sh mint`:** if `<records-root>/scripts/records.sh` is
executable:

1. If `<records-root>/templates/notes.md` is absent, copy this skill's
   bundled template there. If a deployed template already exists, leave
   it (incumbent wins).
2. Run `records.sh new notes --title "<headline>"`.
3. Print `mode=records` and the path `new` wrote.

Else (no `records.sh`):

1. `mkdir -p <records-root>/notes`.
2. Write `<records-root>/notes/YYYY-MM-DD-<slug>.md` from the bundled
   template using the same `fill` substitution as
   `skills/journal/scripts/records.sh:136-155` and the same slug /
   collision rules as `cmd_new` (`:171-181`). Date from
   `date +%Y-%m-%d`. Empty slug is an error.
3. Do not create `history.tsv`, `scripts/records.sh`, `templates/`, or
   any other store.
4. Print `mode=file`.

**`note-mint.sh stamp`:** if `records.sh` is executable and the path is
under that root:

- live status change (`updated:` only, or `--status open|current`) →
  `records.sh touch`
- closing `--status` (`superseded` / `dropped` / `done` / `consumed`) →
  `records.sh done --as <status> --note "<note>"` (ledger line)

Else: rewrite `updated:` and optionally `status:` in the front-matter
block only (same two-key rewrite as `records.sh` `stamp`). Do not write
`history.tsv`.

**File-mode close and later standup.** A file-mode close sets a closing
status with no ledger line. After journal is stood up, `records.sh
check` will flag that. `records.sh done` **cannot** repair it — it
refuses an already-closing status (`skills/journal/scripts/records.sh:247`).
Repair is: rewrite `status:` back to `open`, then `records.sh done --as
<disposition> --note "…"`. That repair is journal/curate's, not
notepad's; notepad does not claim `done` will close an already-closed
file.

**Successor link (both modes).** On supersede, the old note's **body**
gets one contract record-link `→ notes/<successor-file>.md` naming the
replacement. When `records.sh done` also runs, `--note` carries the
same relative path as the ledger field. The body link is the canonical
discoverable shape; the ledger note is additional.

## 4. Verbs

Shared discipline, stated once on `SKILL.md`:

- Resolve the records root (doctrine resolver above). Never guess a
  date when `records.sh` can supply it.
- One fact per note (the path is the ID).
- **Resolve the commit tree, then commit there** — the same ordered probe
  already on journal and backlog (`skills/journal/SKILL.md:94-103`):
  detached STOP; worktree `WORKSTREAM.md` matching branch → commit here;
  in-place stream holding the root → commit here; `stream/*` /
  `feature/*` STOP; else current trunk (never hardcode `main`). Non-git
  (no `rev-parse --show-toplevel`) STOP.
- Pathspec-atomic commit via this skill's `scripts/scoped-commit.sh`.
- Standalone invocation commits (`Notepad: write — <slug>` and kin).
  Write-only sweep: see §1.

**`write`.** List live notes only: `records.sh list --type notes
--status open` and again `--status current` when `records.sh` is
present; else scan `<records-root>/notes/*.md` and skip files whose
`status:` is a closing value. If a **live** note already covers the
fact, edit it and stamp. If a **closed** note matches, do not update
it — refuse the silent edit; tell the operator to `supersede` (same
subject, new claim) or `write` a distinct fact. Otherwise mint. Prefer
one fact per note. Write-only: skip the commit; print `path=` / `rel=`.

**`find`.** List or retrieve. Same live-vs-closed visibility as the
caller asks (default: live). Print enough for the agent to cite a path.
No mint. No commit.

**`supersede`.** Mint the replacement (or confirm the successor already
exists), write the body successor link on the old note, then close the
old note `superseded` via `note-mint.sh stamp … --status superseded`.
Never silently edit a note into a different claim. No successor →
refuse (that is `drop`).

**`drop`.** The fact is no longer true and there is no successor. Close
`dropped` via `note-mint.sh stamp … --status dropped` with a body
sentence saying what changed. No mint.

## 5. Cutover from backlog

- Delete `skills/backlog/verbs/note.md` and
  `skills/backlog/templates/notes.md`.
- Drop the `/backlog note` dispatch row and the "notes" store from
  backlog's lazy-deploy list (`skills/backlog/SKILL.md` shared
  discipline currently names `bugs`, `notes`, `tickets`, `trackers`).
- **Rewrite backlog's `description:` and introductory trigger prose** so
  they no longer contain `note`, `fact`, or "write this down" / "write
  down how this works". Capture-by-kind in the description becomes
  `task|bug|issue|feedback` (plus ticket/debrief/curate as today).
- `skills/backlog/verbs/debrief.md` step 3: route facts through notepad
  `write` write-only (sweep contract in §1). The other capture kinds
  stay on backlog.
- A substantial `issue` analysis that needs a dated note is minted
  through notepad `write` write-only, then linked. Backlog no longer
  mints `notes/`.
- Do not leave `/backlog note` as an alias.

## 6. Failure states

| Situation | Behavior |
|---|---|
| Empty title / slug | refuse; ask for a headline |
| No existing notes dir | create it; do not refuse |
| `records.sh` missing | `note-mint.sh` file-mode; do not point at journal setup |
| `records.sh` present, notes template missing | lazy-deploy notepad's template, then `new` |
| Duplicate fact, live note | update that note; do not mint |
| Duplicate fact, closed note | refuse the update; point at `supersede` or a new `write` |
| Detached HEAD, non-git, or unheld `stream/*`/`feature/*` | STOP; do not commit |
| Find with no notes | say so; do not mint |
| Supersede without a successor | refuse; that is `drop` |
| `drop` without saying what changed | refuse |

## 7. Non-goals

- Moving `/backlog bug` or any other capture kind.
- Giving notepad ownership of the `notes` store or of journal's contract.
- Standing up the records layer, deploying `records.sh`, or writing
  `history.tsv`.
- Front-door registration on this library.
- A search index, embeddings, or anything beyond a live directory scan /
  `records.sh list`.
- Session-only scratch notes.
- Non-git / no-worktree hosts.
- A `--no-commit` flag or a fifth invocation.

## Key Decisions

- **Reach-for is the product.** The skill exists so "write this down"
  loads notepad, not backlog. Rationale: trigger quality; `/backlog note`
  names the wrong job. Cutover includes the description, not only the
  verb file.
- **Path convention, not journal setup.** Agents can take notes on a
  git checkout that has never run `/journal setup`. Rationale: notes
  are basic memory; requiring a records standup is the wrong floor.
- **Script is the one minter.** Verbs always call `note-mint.sh`; the
  script dispatches to `records.sh` when present. Rationale: one argv
  and one `key=value` schema; the spec and plan no longer fork.
- **Contract equivalence, not byte identity.** Incumbent deployed
  templates stay. Rationale: `records.sh new` already mints from the
  deployed file; overwriting it is not notepad's job.
- **Template follows the minting verb.** Already the contract.
- **Debrief still emits notes** via the write-only sweep contract.
- **No ledger writes without `records.sh`.** File-mode close is
  check-dirty until someone reopens and `done`s. `done` does not
  repair an already-closing status.
- **Live notes only for silent update.** Closed matches are a
  supersede/drop decision, not a `touch`.
- **`drop` is in scope.** A fact that died with no successor is a
  real close; refusing it would leave stale live notes.

## Open Questions

None remaining. Implementation sequencing lives in the companion plan.
