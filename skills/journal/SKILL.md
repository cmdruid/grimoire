---
name: journal
description: "The records-layer format authority — defines what makes a file a record (a dated filename plus front-matter declaring its doctype), the record contract, the template convention, and the staged records.sh tool (search, query, lifecycle, and the history.tsv ledger) in fixed `.records/`. Verbs: `setup`, `repair`, `migrate`, `anchor` (an explicit project-owned discovery pointer), `search`, `done`, and `curate`. Use when the user runs `/journal ...`, initializes, repairs, migrates, or anchors the records layer, searches or lists records, closes a record, asks about the record contract, or tidies the records home."
---

# journal — the records format authority

One skill: the **definition** of a project's records layer. It owns the **discriminator**
(what makes a file a record — below), the **record contract** (below), the **template
convention** (writers own schemas and may pass a body-only project template), and the
staged tool **`records.sh`** (search, query + lifecycle; sole writer of the `history.tsv` closure
ledger). A skill creates only the directories it needs; the crawl knows no
store list; `/journal setup` stands or refreshes the **tool layer** —
`.records/records.sh`, empty `history.tsv`, and a Journal-owned delimited tool block in the
records README — and is never a floor for writers.
Writers state the in-package contract in their own package; they do not send
the agent here for those bytes. At runtime they talk to the **staged**
`records.sh` when that file is executable, never to this skill's bundled copy.

The layer's shape (the deployed `.records/README.md` restates it in-project):

- **A file is a record iff it is named `YYYY-MM-DD-<slug>.md` AND carries front-matter
  declaring a `doctype`.** That is the whole discriminator, and the path is the ID. Both
  conjuncts earn their place: front-matter alone could swallow undated typed scaffolds; the
  dated shape alone would swallow any dated prose file. No counters, no typed IDs, no stored
  index — querying is a live scan, crawling the root at **any depth**.
- **Nothing is reserved.** A skill creates only the directories it needs for its own
  work, so the set under the root is open-ended and unknown to this tool: it crawls rather
  than matching a list. Journal owns `records.sh`, `history.tsv`, and only the delimited
  `journal:records-tool` block inside the records README. Setup creates no writer directories and
  copies no templates; project prose outside that block remains the project's.
  `.records/records.sh new` writes under a **caller-named relative directory**: default is the
  `<doctype>` positional; `--dir <rel>` overrides (no leading `/`, no `..` segment).
  `mkdir -p` of that path is the caller creating the directory through the tool — journal
  does not enumerate, reserve, or advertise a store set. `templates/`, `scripts/`, a
  `doctrine/` tree — none need reserving, because their files fail one conjunct or the other
  and simply are not records. The **authoritative doctype is the front-matter key**, never the
  parent directory — there is no second copy of the fact to disagree with.
- **Micro-items are tracker lines, not records.** A tracker record's body holds one-line
  items in the contract's line form (below); detailed material — a bug repro, a durable fact —
  gets its own dated record, linked from a tracker line when it needs scheduling. Which
  trackers exist and what belongs on them is the follow-up workflow's judgment, not the
  format's.
- **Closure is in place; history is a ledger.** A finished record never moves: `records.sh
  done` stamps the file `archived` and appends the one ledger line to `history.tsv` — its sole
  writer, never hand-edited. A tracker *line-item* completes per the contract's line form
  (below), not through the ledger.

## The record contract

`.records/records.sh check` enforces front-matter, the status vocabulary (including ledger
coherence), and record-link resolution. Tracker line form is a prose convention —
`check` does not scan it. `new` synthesizes shared metadata; project templates supply body prose.

- **Front-matter: four required keys**, between `---` delimiters at the top of every record —
  `doctype` (the record's type, and the authority on it), `status`, `schema`, and `tags`.
  `schema` follows `<writer>/<artifact>@<positive-integer>` with lowercase kebab-case names;
  Journal validates only this grammar. `created`, `updated`, `created_at`, `updated_at`, and
  `revision` are retired reserved keys and invalidate a current record. The dated filename is the
  creation authority; Git is the durable modification history. A missing or empty `doctype` means the file is not a
  record at all; `check` reports it as a **WARN** when the filename wears the record shape,
  so a malformed record is surfaced rather than silently skipped by the crawl.
- **Status vocabulary**: `draft` | `published` while live; `archived` to close. A closing
  status is `archived` and **requires a** `history.tsv` ledger line (disposition is the
  ledger `--as` word, not the file status). `check` flags a hand-closed record; the ledger
  line is six tab-separated fields — date, disposition, path relative to `.records`, doctype,
  title, note — written only by `.records/records.sh done`.
- **Record links**: `→ <dir>/<file>.md` — the record's path relative to `.records`, whatever
  directory its writer put it in; `check` flags rot.
- **Tracker line form**: under `## Items`, newest last. Live and completed (same optional
  ` → <dir>/<file>.md` before the completion date):

      - [ ] 2026-08-01 — wire the alpha → notes/2026-08-01-fact.md
      - [x] 2026-08-01 — wire the alpha → notes/2026-08-01-fact.md — 2026-08-17

  Completing a line is that rewrite + a `.records/records.sh touch` of the tracker (no ledger line).
- **Schema and template convention**: `.records/records.sh new <doctype> --schema <owned-schema> --title <title>`
  `[--template <resolved-body>] [--dir <rel>] [--tag t]...` synthesizes the four shared keys.
  `--template` is optional and supplies body-only authoring scaffolding; literal `<title>` and
  `<date>` slots are filled, while `<schema>` or `<tags>` slots refuse. The minting skill resolves
  declared active templates only at `.agents/skilldata/<skill>/templates/`; recognized legacy
  locations require its explicit `migrate` verb. Schema identifiers, validators, and migration
  chains stay in the skill package and are never project-customizable. Setup copies nothing.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/journal setup` | `verbs/setup.md` | Tool layer: first visit stands it up; later visit refreshes `records.sh` | "stand up the records", "refresh records.sh" |
| `/journal repair` | `verbs/repair.md` | Restore only the provider and managed README block on an initialized layer | "repair records.sh", "restore the records tool" |
| `/journal migrate <source-root>` | `verbs/migrate.md` | Preview, confirm, and Git-move one explicitly named dedicated records root to `.records` | "migrate the records root", "move records to .records" |
| `/journal anchor` | `verbs/anchor.md` | Add an explicit project-owned pointer to `.records/README.md` | "make records discoverable", "anchor the records layer" |
| `/journal search` | `verbs/search.md` | Find records by content or metadata | "find/search/list/query records", "what's in the records about X" |
| `/journal done <record>` | `verbs/done.md` | **Close** a record in place — disposition + note + the ledger line; write back inbound `→` links | "mark that done", "close out that plan" |
| `/journal curate` | `verbs/curate.md` | **Substrate hygiene** — `check`, close what quietly finished, repair link rot, merge duplicates, propose prunes | "check the records", "tidy the records home" |

`/journal` with no recognized verb: ask which of **setup / repair / migrate / anchor / search / done / curate**. Filing a
follow-up is not journal's job (scope boundary, below).

## Shared discipline (every verb relies on this — stated here once)

- **Use the fixed home, run the ordered runtime preflight, then let `records.sh` own the facts.**
  Records live at `<root>/.records`. Search, done, and curate first run
  `scripts/records-runtime-check.sh --root <root>` and use its sole success line as the absolute
  staged-provider path. It derives recovery only from the public layer, in this order:
  1. `.records/history.tsv` absent, non-regular, or unsafe → stop with exactly
     `reason=setup-required action=/journal setup`.
  2. `.records/records.sh` absent, non-regular, non-executable, byte-different from the bundled
     provider, unsafe, or failing the exact current bare-usage surface → stop with exactly
     `reason=repair-required action=/journal repair`.
  No runtime verb resolves or inspects `.agents/skilldata`. The staged usage probe must exit 1, begin with the
  current usage line, and name every current command. Never execute the bundled provider against
  project records. Only after both checks pass may a runtime verb invoke the returned staged tool.
  Invoke **the staged tool** for every date, path, and
  conformance fact (`new --schema <owned-schema> [--template <resolved-body>]` / `touch` / `done` / `list` /
  `grep` / `history` / `prune-candidates` / `check`); never guess a date, never
  hand-stamp front-matter, never write `history.tsv` by hand. `search` / `done` /
  `curate` use this same scan.
- **Scripts compute facts; the verb prose decides.** Whether a record is really done and under
  which disposition, what merges with what — that judgment lives in the verb files. The scripts
  (`records.sh`, `scripts/records-layer-status.sh`, `scripts/records-runtime-check.sh`,
  `scripts/standup.sh`, `scripts/scoped-commit.sh`) do only deterministic
  mechanics; never push a decision into a script.
- **Resolve the commit tree, then commit there.** `<root>` is `git rev-parse --show-toplevel`
  of the checkout that holds the records you wrote — never a different clone, and never the
  repo's root checkout from inside a stream worktree (that lands the commit on the trunk
  through the shared index). `<branch>` is `git -C <root> branch --show-current`. Then, in
  order: empty `<branch>` (detached HEAD) → STOP. `<root>/WORKSTREAM.md` exists → this tree is a
  worktree stream; commit here. `<branch>` matches `stream/*` or `feature/*` → STOP (a work branch this session
  does not hold). Otherwise commit here (the current trunk — never hardcode `main`).
- **Pathspec-atomic commit (the shared root index is contended).** Stage *and* commit scoped to
  exactly the paths you wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>"
  <paths…>`. Never `git add -A`, never `commit -a`, never leave staged work in the root index
  across steps. No `Co-Authored-By` trailer.
- **Commit policy.** A verb invoked **standalone** makes its own scoped commit, then runs the
  host's cheap doc gate if it has one. A verb invoked **inside a client's sweep** (a debrief)
  only writes — the sweep makes the single atomic multi-file commit.
- **Front-door boundary.** Only explicitly invoked `/journal anchor` may create or append to the
  repository-root `AGENTS.md`, and it writes only the fixed project-owned records pointer after a
  preview and confirmation. Setup, repair, migration, runtime, and curation never install, refresh,
  require, remove, or inspect that pointer.

## Scope boundary + host conduct

`journal` defines the format, stands it up, closes records, and keeps the records home
conformant. Filing, sweeping, and grooming follow-ups is a client's job — point at the
host's follow-up lifecycle; do not file from here. Journal owns no judgment beyond its own
formats.

**Standalone by default, framework-aware when present.** Every verb works on any repo: the
records live under fixed `.records`, and no verb refuses or stalls for lack of a workshop.
On a workshop host the deployed doctrine's routing applies downstream; elsewhere it is simply
absent — never demand the workshop as a precondition.

## Edges

<!-- edges:journal -->
- produces: record — the record contract and deployed records.sh
- handoff: — (none; writers consume the tool, journal does not terminate a workflow)
- consumes: — (none; it defines the format)
<!-- /edges:journal -->

## Project templates

None. Journal's README block and front-door pointer are package-only provider resources; setup
refreshes only the managed README block, and explicit anchor installs project-owned prose.

## Done when

- **No recognized verb:** asked which of setup / repair / migrate / anchor / search / done / curate; did not file a follow-up.
- **A verb ran:** that verb file's Done when.
