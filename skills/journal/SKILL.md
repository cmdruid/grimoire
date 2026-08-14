---
name: journal
description: "The records-layer format authority — defines a project's `.records/`: the eight typed stores (adr, bugs, design, notes, plans, reports, tickets, trackers), the record front-matter contract, the templates, and the deployed `records.sh` tool (query + lifecycle + the `history.tsv` closure ledger). Verbs: `setup` (stand up the records layer — standalone, or as the workshop's delegated records seam), `done` (close a record in place: disposition + ledger line), `curate` (substrate hygiene: contract check, link rot, duplicate merge, prune proposals). Use when the user runs `/journal ...`, stands up the records layer, closes a record, asks about the record format/contract, or tidies the stores."
---

# journal — the records format authority

One skill: the **definition** of a project's records layer. It owns the stores under the records
root (default `.records/`), the **record contract** (below — the one citable place), the
**templates** records are minted from, and the deployed tool **`records.sh`** (query + lifecycle;
sole writer of the `history.tsv` closure ledger). Journal stands records up on a bare repo by
itself, and the workshop's `setup` delegates its records step here. Skills that save or track
artifacts in the records layer — follow-up capture, debugger reports, auditor findings, workstream
plan closures, blueprint plans — are **clients**: they cite the contract below instead of
restating it, and at runtime they talk to the **deployed** `records.sh` (it travels with the
records layer), never to this skill's bundled copy.

_Lineage: v1's `backlog` skill was this whole records instrument (renamed `journal` in v2); the
follow-up workflow that ran on it (capture, debrief, tracker grooming) moved out to the v2
`backlog` skill, leaving journal the format authority._

The layer's shape (the deployed `.records/README.md` restates it in-project):

- **Stores are directories; the path is the ID.** Eight stores — `adr`, `bugs`, `design`,
  `notes`, `plans`, `reports`, `tickets`, `trackers` — each holding
  `YYYY-MM-DD-<slug>.md` records minted by `records.sh new`. No counters, no typed IDs, no
  stored index: querying is a live front-matter scan. `templates/`, `scripts/`, and
  `history.tsv` are reserved (never scanned).
- **Micro-items are tracker lines, not records.** A tracker record's body holds one-line
  items in the contract's line form (below); detailed material — a bug repro, a durable fact —
  gets its own dated record, linked from a tracker line when it needs scheduling. Which
  trackers exist and what belongs on them is the follow-up workflow's judgment, not the
  format's.
- **Closure is in place; history is a ledger.** A finished record never moves: `records.sh
  done` sets the closing status and appends the one ledger line to `history.tsv` — its sole
  writer, never hand-edited. A tracker *line-item* completes by flipping `[ ]` → `[x]` + a
  `touch`, not through the ledger.

## The record contract (cite this section; never restate it)

What `records.sh check` mechanically enforces, plus the two body conventions it scans:

- **Front-matter: five keys**, between `---` delimiters at the top of every record —
  `doctype` (must equal the store directory name), `status`, `created`, `updated` (both
  ISO `YYYY-MM-DD`), `tags`.
- **Status vocabulary**: `open` | `current` while live; `done` | `dropped` | `superseded` |
  `consumed` to close. A closing status **requires** a matching `history.tsv` ledger line
  (`check` flags a hand-closed record); the ledger line is six tab-separated fields — date,
  disposition, records-root-relative path, doctype, title, note — written only by
  `records.sh done`.
- **Record links**: `→ <store>/<file>.md`, resolved against the records root; `check` flags
  rot.
- **Tracker line form**: `- [ ] YYYY-MM-DD — <item, one sentence>` under `## Items`, newest
  last, optionally linking a record (`→ <store>/<file>.md`); completes as `[x]` + the
  completion date + a `records.sh touch` of the tracker (no ledger line).

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/journal setup` | `verbs/setup.md` | Stand up the records layer — stores, templates, `records.sh`, ledger (standalone, or as the workshop `setup`'s delegated records step) | "stand up the records", the workshop's records seam |
| `/journal done <record>` | `verbs/done.md` | **Close** a record in place — disposition + note + the ledger line (or flip a tracker line-item) | "mark that done", "close out that plan" |
| `/journal curate` | `verbs/curate.md` | **Substrate hygiene** — `check`, close what quietly finished, repair link rot, merge duplicates, propose prunes | "check the records", "tidy the stores" |

`/journal` with no recognized verb: ask whether the intent is standing the layer up, closing a
record, or store hygiene. Filing a follow-up is not journal's job (scope boundary, below).

## Shared discipline (every verb relies on this — stated here once)

- **Resolve the records root, then let `records.sh` own the facts.** The root is the project's
  declared `records-root:` (front-door `AGENTS.md` declaration), else `.records/`. The deployed
  tool is `<records-root>/scripts/records.sh` — invoke **it** for every date, path, and
  conformance fact (`new`/`touch`/`done`/`list`/`history`/`prune-candidates`/`check`); never
  guess a date, never hand-stamp front-matter, never write `history.tsv` by hand.
- **Scripts compute facts; the verb prose decides.** Whether a record is really done and under
  which disposition, what merges with what — that judgment lives in the verb files. The scripts
  (`records.sh`, `scripts/standup.sh`, `scripts/scoped-commit.sh`) do only deterministic
  mechanics; never push a decision into a script.
- **Commit on the integration trunk, never a work branch.** Record writes are shared state, so
  they land on the root checkout's current branch, which must be the integration trunk (never
  hardcode `main`). Guard: if `git -C <root> branch --show-current` is empty (detached HEAD) or
  a work branch (`stream/*`, `feature/*`), STOP and say so. **Exception:** record writes inside
  an active workstream worktree commit on the stream's branch; its ship lands them.
- **Pathspec-atomic commit (the shared root index is contended).** Stage *and* commit scoped to
  exactly the paths you wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>"
  <paths…>`. Never `git add -A`, never `commit -a`, never leave staged work in the root index
  across steps. No `Co-Authored-By` trailer.
- **Commit policy.** A verb invoked **standalone** makes its own scoped commit, then runs the
  host's cheap doc gate if it has one. A verb invoked **inside a client's sweep** (a debrief)
  only writes — the sweep makes the single atomic multi-file commit.

## Scope boundary + host conduct

`journal` defines the format, stands it up, closes records, and keeps the stores conformant.
The follow-up **workflow** that runs on the layer — capturing items by kind, escalating to the
human, sweeping finished work, grooming the trackers — is a client's job (the pack's `backlog`
member where installed), and what a captured signal *means* for the system is judged further
downstream still. Journal owns no judgment beyond its own formats.

**Standalone by default, framework-aware when present.** Every verb works on any repo: the
stores live under the records root, and no verb refuses or stalls for lack of a workshop.
On a workshop host the deployed handbook's routing applies downstream; elsewhere it is simply
absent — never demand the workshop as a precondition.
