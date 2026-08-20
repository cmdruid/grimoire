---
name: journal
description: "The records-layer format authority — defines what makes a file a record (a dated filename plus front-matter declaring its doctype), the record contract, the template convention, and the deployed records.sh tool (search, query, lifecycle, and the history.tsv ledger) over the agent-records home (default `.records/`). Verbs: `setup` (stand up or refresh the tool layer), `search` (find records by content or metadata), `done` (close a record in place), `curate` (contract check, link rot, duplicate merge, prune proposals). Use when the user runs `/journal ...`, stands up or refreshes the records layer, searches or lists records, closes a record, asks about the record format/contract, or tidies the records home."
---

# journal — the records format authority

One skill: the **definition** of a project's records layer. It owns the **discriminator**
(what makes a file a record — below), the **record contract** (below), the **template
convention** (writers carry templates; mint from a caller-supplied `--template` path), and the
deployed tool **`records.sh`** (search, query + lifecycle; sole writer of the `history.tsv` closure
ledger). A skill creates only the directories it needs; the crawl knows no
store list; `/journal setup` stands or refreshes the **tool layer** —
`records.sh`, empty `history.tsv`, README — and is never a floor for writers.
Writers state the in-package contract in their own package; they do not send
the agent here for those bytes. At runtime they talk to the **deployed**
`records.sh` when that file is executable, never to this skill's bundled copy.

The layer's shape (the deployed `.records/README.md` restates it in-project):

- **A file is a record iff it is named `YYYY-MM-DD-<slug>.md` AND carries front-matter
  declaring a `doctype`.** That is the whole discriminator, and the path is the ID. Both
  conjuncts earn their place: front-matter alone would swallow the record *templates*, which
  necessarily carry a doctype block (it is what `new` copies into the minted record); the
  dated shape alone would swallow any dated prose file. No counters, no typed IDs, no stored
  index — querying is a live scan, crawling the root at **any depth**.
- **Nothing is reserved.** A skill creates only the directories it needs for its own
  work, so the set under the root is open-ended and unknown to this tool: it crawls rather
  than matching a list. Journal's own directories remain `scripts/` (the tool) and
  `history.tsv` (the ledger). Setup creates no writer directories and copies no templates.
  `records.sh new` writes under a **caller-named relative directory**: default is the
  `<doctype>` positional; `--dir <rel>` overrides (no leading `/`, no `..` segment).
  `mkdir -p` of that path is the caller creating the directory through the tool — journal
  does not enumerate, reserve, or advertise a store set. `templates/`, `scripts/`, a
  `doctrine/` tree — none need reserving, because their files fail one conjunct or the other
  and simply are not records. This is what lets the records home be **shared** with another
  home: a host may point `<agent-workspace>` and `<agent-records>` at the same directory
  without a carve-out. The **authoritative doctype is the front-matter key**, never the
  parent directory — there is no second copy of the fact to disagree with.
- **Micro-items are tracker lines, not records.** A tracker record's body holds one-line
  items in the contract's line form (below); detailed material — a bug repro, a durable fact —
  gets its own dated record, linked from a tracker line when it needs scheduling. Which
  trackers exist and what belongs on them is the follow-up workflow's judgment, not the
  format's.
- **Closure is in place; history is a ledger.** A finished record never moves: `records.sh
  done` sets the closing status and appends the one ledger line to `history.tsv` — its sole
  writer, never hand-edited. A tracker *line-item* completes per the contract's line form
  (below), not through the ledger.

## The record contract

`records.sh check` enforces front-matter, the status vocabulary (including ledger
coherence), and record-link resolution. Tracker line form is a prose convention —
`check` does not scan it. The template convention is enforced by `new` (missing
template → error), not by `check`.

- **Front-matter: five keys**, between `---` delimiters at the top of every record —
  `doctype` (the record's type, and the authority on it), `status`, `created`, `updated`
  (both ISO `YYYY-MM-DD`), `tags`. A missing or empty `doctype` means the file is not a
  record at all; `check` reports it as a **WARN** when the filename wears the record shape,
  so a malformed record is surfaced rather than silently skipped by the crawl.
- **Status vocabulary**: `open` | `current` while live; `done` | `dropped` | `superseded` |
  `consumed` to close. A closing status **requires** a matching `history.tsv` ledger line
  (`check` flags a hand-closed record); the ledger line is six tab-separated fields — date,
  disposition, records-root-relative path, doctype, title, note — written only by
  `records.sh done`.
- **Record links**: `→ <dir>/<file>.md` — the record's records-root-relative path, whatever
  directory its writer put it in; `check` flags rot.
- **Tracker line form**: under `## Items`, newest last. Live and completed (same optional
  ` → <dir>/<file>.md` before the completion date):

      - [ ] 2026-08-01 — wire the alpha → notes/2026-08-01-fact.md
      - [x] 2026-08-01 — wire the alpha → notes/2026-08-01-fact.md — 2026-08-17

  Completing a line is that rewrite + a `records.sh touch` of the tracker (no ledger line).
- **Template convention**: `records.sh new <doctype> --template <resolved>`
  `[--dir <rel>] [--tag t]...` mints from the caller-supplied path (usually
  `<agent-workspace>/templates/<skill>/<doctype>.md`) into `--dir` (default:
  the `<doctype>` positional). `--template` is **required** — the tool knows
  no taxonomy, so it cannot guess a template location from a doctype name,
  and there is no flat fallback. Repeatable `--tag` fills the template's
  `<tags>` slot (`tags: [a, b]`; omitted → `tags: []`). The minting skill
  owns the bundled template and copies it to
  `<agent-workspace>/templates/<skill>/`, never to the flat
  `<agent-records>/templates/<doctype>.md`. Templates are undated, so the
  discriminator leaves them alone wherever they sit. Setup copies nothing.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/journal setup` | `verbs/setup.md` | Tool layer: first visit stands it up; later visit refreshes `records.sh` | "stand up the records", "refresh records.sh" |
| `/journal search` | `verbs/search.md` | Find records by content or metadata | "find/search/list/query records", "what's in the records about X" |
| `/journal done <record>` | `verbs/done.md` | **Close** a record in place — disposition + note + the ledger line; write back inbound `→` links | "mark that done", "close out that plan" |
| `/journal curate` | `verbs/curate.md` | **Substrate hygiene** — `check`, close what quietly finished, repair link rot, merge duplicates, propose prunes | "check the records", "tidy the records home" |

`/journal` with no recognized verb: ask which of **setup / search / done / curate**. Filing a
follow-up is not journal's job (scope boundary, below).

## Shared discipline (every verb relies on this — stated here once)

- **Resolve the agent-records home, then let `records.sh` own the facts.** The home is
  the first line-start `agent-records:` or `records-root:` in `AGENTS.md`, then
  `CLAUDE.md`; else `.records/`. (`agent-records:` preferred; `records-root:` still
  accepted so already-declared hosts do not break.) The deployed tool is
  `<agent-records>/scripts/records.sh`. If that file is **missing or not
  executable**, stop, name `/journal setup`, and do not run this skill's bundled
  copy. `search` also stops when the deployed usage list has no `grep` line (a
  later setup refreshes). Invoke **the deployed tool** for every date, path, and
  conformance fact (`new --template <resolved>` / `touch` / `done` / `list` /
  `grep` / `history` / `prune-candidates` / `check`); never guess a date, never
  hand-stamp front-matter, never write `history.tsv` by hand. `search` / `done` /
  `curate` use this same scan so a host that only declared `agent-records:` is
  not silently aimed at `.records/`.
- **Scripts compute facts; the verb prose decides.** Whether a record is really done and under
  which disposition, what merges with what — that judgment lives in the verb files. The scripts
  (`records.sh`, `scripts/standup.sh`, `scripts/scoped-commit.sh`) do only deterministic
  mechanics; never push a decision into a script.
- **Resolve the commit tree, then commit there.** `<root>` is `git rev-parse --show-toplevel`
  of the checkout that holds the records you wrote — never a different clone, and never the
  repo's root checkout from inside a stream worktree (that lands the commit on the trunk
  through the shared index). `<branch>` is `git -C <root> branch --show-current`. Then, in
  order: empty `<branch>` (detached HEAD) → STOP. `<root>/WORKSTREAM.md` exists and its
  Coordinates `branch:` equals `<branch>` → this tree is a worktree stream; commit here. A
  `<root>/.workstreams/*/WORKSTREAM.md` records `isolation: in-place` and Coordinates
  `branch:` equals `<branch>` → this tree is an in-place stream holding the root; commit
  here. `<branch>` matches `stream/*` or `feature/*` → STOP (a work branch this session
  does not hold). Otherwise commit here (the current trunk — never hardcode `main`).
- **Pathspec-atomic commit (the shared root index is contended).** Stage *and* commit scoped to
  exactly the paths you wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>"
  <paths…>`. Never `git add -A`, never `commit -a`, never leave staged work in the root index
  across steps. No `Co-Authored-By` trailer.
- **Commit policy.** A verb invoked **standalone** makes its own scoped commit, then runs the
  host's cheap doc gate if it has one. A verb invoked **inside a client's sweep** (a debrief)
  only writes — the sweep makes the single atomic multi-file commit.

## Scope boundary + host conduct

`journal` defines the format, stands it up, closes records, and keeps the records home
conformant. Filing, sweeping, and grooming follow-ups is a client's job — point at the
host's follow-up lifecycle; do not file from here. Journal owns no judgment beyond its own
formats.

**Standalone by default, framework-aware when present.** Every verb works on any repo: the
records live under the agent-records home, and no verb refuses or stalls for lack of a workshop.
On a workshop host the deployed doctrine's routing applies downstream; elsewhere it is simply
absent — never demand the workshop as a precondition.

## Edges

<!-- edges:journal -->
- produces: record — the record contract and deployed records.sh
- handoff: — (none; writers consume the tool, journal does not terminate a workflow)
- consumes: — (none; it defines the format)
<!-- /edges:journal -->

## Done when

- **No recognized verb:** asked which of setup / search / done / curate; did not file a follow-up.
- **A verb ran:** that verb file's Done when.
