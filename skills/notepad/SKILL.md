---
name: notepad
description: "Use when the user runs `/notepad`, asks to write down a project fact, look up or update existing notes, supersede a note that is no longer true, or drop a note with no successor. Keywords: notepad, write this down, project memory, capture this fact."
---

# notepad — project memory

One skill: take, find, update, supersede, and drop durable project facts.
Notes live at `<records-root>/notes/` (declared `records-root:` else
`.records/notes`). This skill creates that directory. It does not stand
up the rest of the records layer and does not refuse when `records.sh`
is missing.

This `SKILL.md` is a **thin router**: it dispatches and states the
discipline every verb shares **once**. Each verb's procedure lives in
`verbs/<verb>.md`, **read on demand**. When a verb is selected, **read
`verbs/<verb>.md` and follow it**; do not reconstruct a procedure from
memory.

Disposition: **records-path client** — no `init`, nothing private to
scaffold. The notes directory is a conventional path in the host repo,
created on first write. Do not register against a library's own
front-door (patient-zero).

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/notepad write` | `verbs/write.md` | Find-or-update a live note, else mint | "write this down", "capture this fact" |
| `/notepad find` | `verbs/find.md` | List or retrieve notes | "what did we write about X" |
| `/notepad supersede` | `verbs/supersede.md` | Close old, mint replacement | "this note is no longer true — here is the new fact" |
| `/notepad drop` | `verbs/drop.md` | Close `dropped`; no successor | "this fact is no longer true" |

**No default verb.** `/notepad` with no recognized verb — ask which.

**When not to use:** an action item; a reproducible defect to file for
later; a decision between alternatives that belongs in an `adr` record;
session scratch that must not persist.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve the records root** (doctrine resolver, inlined): first
  `^records-root:` in the host `AGENTS.md`, then `CLAUDE.md`, else
  `.records`. Pass the resolved path into every
  `scripts/note-mint.sh` call. The script does not scan the front-door.
- **One fact per note** (the path is the ID).
- **`note-mint.sh` is the one minter.** Always call it (from this
  skill's own `scripts/`, never a host path). It uses deployed
  `records.sh` when that file is executable; otherwise it writes the
  contract shape itself (matching this package's `fill` +
  slug/collision). Never write `history.tsv` by hand.
- **The record contract (this package).** Front-matter keys:
  `doctype`, `status`, `created`, `updated`, `tags`. Live statuses:
  `open`, `current`. Closed statuses: `done`, `dropped`,
  `superseded`, `consumed`. Record-link form:
  `→ <store>/<file>.md`. Do not send the agent to another skill's
  `SKILL.md`.
- **Resolve the commit tree, then commit there.** `<root>` is
  `git rev-parse --show-toplevel` of the checkout that holds the notes
  you wrote — never a different clone, and never the repo's root
  checkout from inside a stream worktree. Non-git (the command fails)
  → STOP. `<branch>` is `git -C <root> branch --show-current`. Then, in
  order: empty `<branch>` (detached HEAD) → STOP. `<root>/WORKSTREAM.md`
  exists and its Coordinates `branch:` equals `<branch>` → this tree is
  a worktree stream; commit here. A `<root>/.workstreams/*/WORKSTREAM.md`
  records `isolation: in-place` and Coordinates `branch:` equals
  `<branch>` → this tree is an in-place stream holding the root; commit
  here. `<branch>` matches `stream/*` or `feature/*` → STOP (a work
  branch this session does not hold). Otherwise commit here (the
  current trunk — never hardcode `main`).
- **Pathspec-atomic commit** via `scripts/scoped-commit.sh <root>
  "<msg>" <paths…>`. Never `git add -A`, never `commit -a`, never leave
  staged work in the root index across steps. No `Co-Authored-By`
  trailer.
- **Write-only sweep contract.** Standalone invocation commits
  (`Notepad: write — <slug>` and kin). When the caller is a sweep
  (a debrief, or an issue graduating analysis), skip
  `scoped-commit.sh`, print the `path=` / `rel=` facts from
  `note-mint.sh`, and let the caller commit. The caller is identified
  by being that sweep, not by a CLI switch. No `--no-commit` flag.

## Edges

<!-- edges:notepad -->
- produces: note — a notes/ record
- handoff: note — write-only sweep: skip scoped-commit; return path= / rel=
- consumes: note — find/update/supersede/drop read existing notes
<!-- /edges:notepad -->

## Done when

- **No recognized verb:** asked which of write / find / supersede / drop;
  did not mint.
- **A verb ran:** that verb file's Done when.
