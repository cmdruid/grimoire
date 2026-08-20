---
doctype: design
status: open
created: 2026-08-20
updated: 2026-08-20
tags: [spec]
---

# journal records-home — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the records layer, it does not run a workshop on itself). This
spec lives here, on `stream/skills` until ship. It doubles as the
implementation plan.

Subject: `skills/journal`. Brief: make journal an independent records-home
skill — zero leftover v1 language, first-class search, honest mint/crawl
ownership — so it handles search, curation, and management of the
agent-records home.

Settled 2026-08-20 on stream `skills` from the walk-together investigation.
Human: fix all three slices. Amended 2026-08-20: delete bundled
`templates/reports.md` (human: journal does not need a reports template).

## Problem

Journal is a working **format authority**. It is not yet the skill that
**searches, curates, and manages** the agent-records home.

Three holes sit on the same package:

1. **Search is a script, not a job.** `records.sh list` / `show` /
   `history --grep` exist. There is no body search, no `/journal search`
   verb, and bare `/journal` does not offer lookup. The description
   Use-when never says find/search/list. "Look up that plan" routes to
   notepad or analyst.
2. **Mint still pretends not to own directories while creating them.**
   The crawl knows no store list (`records()` is `find` + discriminator).
   `cmd_new` still does `mkdir -p "$RR/$doctype"` (`records.sh:207`) and
   the leaf still says "owns no directory names." `curate` walks
   `list --type <doctype>` *per doctype* with no inventory to iterate.
3. **v1 language is still on the always-loaded surface.** Lineage names
   the old `backlog` skill. Description and dispatch say "tidies the
   stores" and "the workshop's delegated records seam." The seam already
   lives in `skills/clankshop/PACK.md`. Journal still bundles
   `templates/reports.md` as a "contract example" that no verb uses,
   setup does not copy, and no live writer reads — leftover from the
   Phase 6 commons-template decision. The five-key contract already
   lives in `SKILL.md`. The file forces a `## Project templates` heading
   marked **none**.

A fourth hole is forced by (1): **setup refuses a re-run** (`standup.sh`
exit 2 when `scripts/records.sh` is present). A new `grep` subcommand
never reaches an already-stood-up host. Search cannot manage the records
home unless the deployed tool can be refreshed.

## Goal

After this feature, `/journal` on a bare install:

- **searches** records by content and metadata (`/journal search`, backed
  by `records.sh grep`);
- **curates** the home by walking every record once (`list`, not a
  doctype roster);
- **manages** the tool layer: first `setup` stands it up; a later `setup`
  refreshes `records.sh` and leaves ledger and README alone;
- names no sibling, no workshop, no "stores," and no v1 lineage on the
  routing surface;
- carries **no** `templates/` directory. The contract is prose in
  `SKILL.md`. Writers that mint `reports/` keep their own `reports.md`.

Lint `fails=0`. `skills/journal/scripts/tests/run.sh` green.
`skills/clankshop/scripts/tests/setup-journal-test.sh` green against the
new standup contract.

## Approach

**Chosen: three slices on this package, plus the one consumer test that
asserts standup's old refuse.** Tracer is the new public command + the
standup refresh that ships it. The verb and the prose ride that
mechanical path. `--dir` is a small mint flag; the default path stays
`$RR/<doctype>/` so no writer changes.

**Rejected: require `--dir` / stop defaulting to `$doctype/`.** Every
live writer calls `records.sh new <doctype> ...` and asserts
`<records>/<doctype>/<date>-<slug>.md`. A flag-day for a truth-in-prose
problem.

**Rejected: document the contradiction and skip `--dir`.** Nested mint
stays impossible, and "owns no directory names" stays a lie. `--dir` is
the caller's named directory; defaulting it to the doctype argument is
the caller choosing, not journal enumerating stores.

**Rejected: a new `upgrade` / `migrate` verb.** Setup already owns the
tool layer. Refreshing `records.sh` is setup's second visit, not a
second verb. Converting *record content* stays a human-named migration
(`setup.md` already says so).

**Rejected: implement search only in the verb, leave `records.sh`
unchanged.** Would duplicate the discriminator. Clients (`analyst`,
`notepad`, `workstream`) could not grep without going through an agent
verb.

**Rejected: `find` as the verb name.** Notepad already owns retrieve-a-note.
Journal's job is corpus search. The user's word is search. Trigger
synonyms (find, list, query, look up) live in the description, not the
verb file name.

**Rejected: search copies the bundled `records.sh` when usage lacks
`grep`.** Lookup would mutate the host tool and need a commit. Setup is
the one writer of the deployed script; search stops and names it.

**Rejected: full-text index.** Querying is a live scan. That stays.

**Rejected: changing `done.md`'s tracker writeback.** Format-coupled
(tracker line form is journal's contract). Empty `--type trackers` is a
no-op. Not leftover taxonomy.

**Rejected: editing PACK.md's transition note, BL-19, or this library's
`docs/BACKLOG.md` as the feature.** Pack-face and maintainer-tracker
walks. Journal stops carrying history; it does not mop the rest of the
library.

**Rejected: keep `templates/reports.md` as the contract example.**
Nothing in `skills/` reads it (`journal/templates/reports` has zero
hits). Debugger, auditor, and workstream already carry `reports.md`.
Tests plant templates inline. A bundled file that setup must not copy
is a fake lock-in surface: lint check 2 then requires `## Project
templates`, which journal marks **none**. The contract is the SKILL.md
section, not a second copy of the five keys. Human, 2026-08-20: we do
not need it.

**Rejected: minting this spec into `.records/`.** Patient-zero. Specs
for this library stay in `docs/design/`.

## Mechanism

### Ownership, told truthfully

The two-roots spec stands: a skill creates only the directories it needs;
the crawl knows no list; the front-matter `doctype` is the authority.

Journal's own directories remain `scripts/` (tool) and `history.tsv`
(ledger). Setup still creates no writer directories and copies no
templates.

`records.sh new` writes under a **caller-named relative directory**:

- default: the `<doctype>` positional (today's path, every writer keeps
  working);
- override: `--dir <rel>` (no leading `/`, no `..` path segment).

`mkdir -p "$RR/$dir"` is the caller creating that directory through the
tool. Journal does not enumerate, reserve, or advertise a store set.

Replace every "owns no directory names" / "the stores" claim in the
journal package with that paragraph. Delete the `_Lineage: v1's backlog…_`
block. PACK.md keeps the rename history.

### No bundled template

Delete `skills/journal/templates/reports.md` and the `templates/`
directory. Journal mints nothing, so it is not a record-writer for lint
check 2's purposes (a skill with no `templates/*.md` is out of scope).

Also delete, as sentences that only exist because of that file:

- `SKILL.md` `## Project templates` (the whole section, including
  "none — `reports.md` is the contract example");
- the template-convention clause "Journal's in-package `reports.md` is
  the contract example only; setup copies nothing" — keep "setup copies
  nothing" / "the minting skill owns the bundled template" if those
  still earn their place as the convention, without naming a journal
  file.

Do not add a journal `reports.md` anywhere else. Do not retarget
debugger / auditor / workstream at journal. Their copies stay theirs.

### `records.sh grep`

New subcommand. Same metadata filters as `list`. Pattern is the first
non-flag argument (exactly one; empty → usage).

```
records.sh grep [--type t] [--status s] [--tag g] [--since d] [--until d] <pattern>
```

- Operate only on files `is_record` accepts. Templates, doctrine, scripts,
  and the ledger are not searched.
- Match against the file **after the closing `---` of the front-matter
  block** (title lives there; `tags:` in front-matter must not match).
- `grep -q -- "$pattern"` (same `grep --` as `history --grep`: BRE, no
  extra flags).
- **Stdout:** the same six-field TSV as `list`
  (`path`, `doctype`, `status`, `updated`, `tags`, `title`), one row per
  matching record, same sort (`updated` desc, path). No per-line hits.
- No matches → exit 0, empty stdout.
- Usage lists `grep` next to `list`.

`list` is unchanged. `history --grep` stays ledger-only.

### Standup refresh

`standup.sh` today: if `$rr/scripts/records.sh` exists, exit 2.

New contract:

1. **First visit** (no `$rr/scripts/records.sh`): unchanged — `mkdir -p
   scripts/`, copy `records.sh`, empty `history.tsv` if absent, README if
   absent, `check`, print `records: $rr (journal)`.
2. **Later visit** (script present):
   - if `cmp -s` skill copy vs deployed copy → print
     `records: $rr (journal, current)`;
   - else `cp` + `chmod +x`, print
     `records: $rr (journal, refreshed)`.
   - Ledger: create empty only if missing; never truncate.
   - README: write only if missing; never overwrite.
   - then `check`, exit 0.

Exit 2 remains for a missing target directory and a missing skill-side
`records.sh`. Re-run is no longer a refuse.

`verbs/setup.md` drops "STOP and report / Do not re-run standup." Done
when: first visit stands the layer; later visit refreshes the tool and
commits only if `records.sh` bytes changed (`scoped-commit` must not run
on a no-op — "nothing to commit" is a failed commit today). Inside a
client sweep, still write-only.

`search` does **not** refresh. If the deployed tool's usage does not
list `grep`, stop and name `/journal setup` (now a refresh, not a
refuse). Search stays read-only: it does not copy `records.sh` and it
does not commit. One extra invocation on an old host is the cost of
keeping lookup off the write path.

### `/journal search`

New `verbs/search.md`. Read-only. No commit.

1. Resolve the agent-records home (existing shared discipline).
2. Deployed `records.sh` missing → say so, point at `/journal setup`,
   stop. Do not file-mode-search (that duplicates the discriminator).
3. Usage lacks `grep` → stop and name `/journal setup`. Do not copy
   `records.sh` from here.
4. Parse the user's query into a pattern and optional `list`-shaped
   filters (`--type` / `--status` / `--tag` / dates when they named
   them). Run `records.sh grep`.
5. Zero hits → say none. One hit → `show` it (or list the row and offer
   show). Many hits → print the TSV rows (path + title at least); do not
   rank; do not open every file.

Bare `/journal` with no recognized verb asks which of **setup / search /
done / curate**. Filing a follow-up is still not journal's job.

### Description (exact)

Single-line, quoted, no sibling slash-command, no "stores", no
"workshop":

```
The records-layer format authority — defines what makes a file a record (a dated filename plus front-matter declaring its doctype), the record contract, the template convention, and the deployed records.sh tool (search, query, lifecycle, and the history.tsv ledger) over the agent-records home (default `.records/`). Verbs: `setup` (stand up or refresh the tool layer), `search` (find records by content or metadata), `done` (close a record in place), `curate` (contract check, link rot, duplicate merge, prune proposals). Use when the user runs `/journal ...`, stands up or refreshes the records layer, searches or lists records, closes a record, asks about the record format/contract, or tidies the records home.
```

Must stay ≤1024 characters (FAIL) and should stay ≤750 (WARN). Count
before landing. No `: ` if the quotes were ever dropped; keep the quotes.

### Dispatch / body

| Invocation | File | Does | Trigger |
|---|---|---|---|
| `/journal setup` | `verbs/setup.md` | Tool layer: first visit stands it up; later visit refreshes `records.sh` | "stand up the records", "refresh records.sh" |
| `/journal search` | `verbs/search.md` | Find records by content or metadata | "find/search/list/query records", "what's in the records about X" |
| `/journal done <record>` | `verbs/done.md` | Close in place | unchanged |
| `/journal curate` | `verbs/curate.md` | Substrate hygiene | "check the records", "tidy the records home" |

Opening body: drop the lineage paragraph. Keep the discriminator, the
"nothing reserved" rule (rewritten per Ownership), the micro-item vs
record split, and closure-in-place. One workshop sentence may remain in
`verbs/setup.md` ("this is also the records step a workshop setup
delegates") — operational pointer, mid-task. Not in the description, not
in the dispatch trigger column, not in `SKILL.md` intro.

`curate.md` step 2: run `records.sh list` **once** (optional filters if
the human scoped the pass). Do not say "per doctype." Close / repair /
merge against that list. `check` WARNs still first.

`cmd_new` comment that says "the tool knows no taxonomy" stays true for
**templates**. Add: directory is `--dir`, defaulting to the doctype
positional.

### `--dir` rules

- `--dir <rel>` is optional.
- Reject: missing value; empty; absolute (`/*`); any `..` segment
  (including `foo/../bar`).
- After rejection the records home is unchanged (no mkdir).
- Collision suffix (`-2`, `-3`, …) keys off the resolved path, same as
  today.
- Front-matter `doctype:` is still the positional, even when `--dir`
  differs. `check` does not compare doctype to parent directory (already
  true).

### Consumer test

`skills/clankshop/scripts/tests/setup-journal-test.sh` lines 44–46 assert
double standup exit 2. Flip to: second run exit 0, stdout contains
`current` or `refreshed`, `keep` lifecycle still green. That file is in
slice 1 so the library gate does not go red overnight.

Clankshop `verbs/setup.md` step 3 wording ("Run `/journal setup`") does
not need a rewrite — refresh is compatible. Do not bump `PACK.md`
`version:` (member set unchanged).

### Out of scope

- Tracker writeback in `done.md`.
- `history --grep` semantics.
- PACK.md transition note, BL-19, `docs/BACKLOG.md`.
- Analyst / notepad description changes (routing-probe after the
  description rewrite is a verify step, not a second feature).
- Converting legacy record *files*.
- Overwriting a host-edited README.
- Nested default layout (`reports/analyst/` as journal policy).

## Verification

**Mechanical**

```
cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
  bash skills/journal/scripts/tests/run.sh && \
  bash skills/clankshop/scripts/tests/setup-journal-test.sh && \
  bash skills/skill-builder/scripts/skills-lint.sh .
```

Expect: journal tests ALL GREEN; setup-journal-test green; lint
`fails=0`. Residual WARNs: blueprint `founding-documents` /
`git-repository` orphans only.

Grep gate (must be empty under `skills/journal/`, tests may keep a
fixture named `legacy` for additive-home):

```
cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
  rg -n 'Lineage:|tidies the stores|tidy the stores|keeps the stores |owns \*\*no directory names\*\*|no directory name is owned|workshop.s delegated|workshop.s `setup` delegates|contract example|## Project templates' \
    skills/journal --glob '!scripts/tests/**'
```

Allowed leftovers: `standup.sh` / tests talking about a writer
"minting a store" or an additive "legacy" fixture home; `setup.md`'s
one operational workshop pointer. Not allowed: description, dispatch
triggers, SKILL.md intro, `curate.md` "the stores."

**Red-proofs (do not land a first clean run)**

1. **`grep` matches body, not tags.** Plant `tags: [secret]` and body
   without `secret` → `grep secret` empty. Plant `secret` in the body →
   one row. Disable the front-matter skip, confirm the tags-only plant
   starts matching, restore.
2. **`grep` does not swallow templates.** Coinciding-roots fixture with
   `templates/plans.md` containing a unique token → `grep` that token
   is empty; a minted record with the token hits.
3. **Refresh overwrites a drifted deployed script.** After first
   standup, append a marker line to deployed `records.sh`, re-run
   standup, marker gone, exit 0, stdout `refreshed`. Byte-identical
   second run: `current`, README content unchanged (compare checksum).
4. **`--dir` rejects `..` and `/abs`.** Both exit 2, no directory
   created. Happy path: `new notes --dir nested/facts --template …`
   writes `nested/facts/<date>-….md`, `list` sees it, `doctype` is still
   `notes`.
5. **Old refuse is gone.** Run the previous "exit 2 on re-standup"
   assertion against the new script once; it must fail; then invert the
   test.

**Judgment**

- Description routes "what's in the records about X" and "tidy the
  records" to journal; "write this fact down" still notepad. Same-session
  read of the four descriptions is enough; a fresh-subagent routing-probe
  is optional and recorded in the commit message if run.
- `curate.md` has no "per doctype."
- `SKILL.md` does not name `backlog` as a sibling.
- `skills/journal/templates/` does not exist. `SKILL.md` has no
  `## Project templates` heading.

## Slices

- [x] **Slice 1: `grep` + standup refresh (tracer)** <requires: —>
  - Files:
    - Modify: `skills/journal/scripts/records.sh` (`usage`, `cmd_grep`,
      dispatch `case`);
    - Modify: `skills/journal/scripts/standup.sh` (refresh vs refuse);
    - Modify: `skills/journal/scripts/tests/records-test.sh` (grep
      red-proofs 1–2);
    - Modify: `skills/journal/scripts/tests/standup-test.sh` (red-proof
      3 and 5; drop "re-standup refused rc 2");
    - Modify: `skills/clankshop/scripts/tests/setup-journal-test.sh`
      (second run exit 0).
  - Change: implement Mechanism *`records.sh grep`* and *Standup
    refresh* exactly. Do not touch SKILL.md yet (description still
    accurate enough; usage in the script header must list `grep`).
  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
      bash skills/journal/scripts/tests/run.sh && \
      bash skills/clankshop/scripts/tests/setup-journal-test.sh
    ```

    Expect ALL GREEN / setup-journal-test green. `records.sh` usage
    printed via a no-args call contains a `grep` line.

- [x] **Slice 2: `/journal search` + routing surface** <requires: 1>
  - Files:
    - Create: `skills/journal/verbs/search.md`;
    - Modify: `skills/journal/SKILL.md` (description = Mechanism
      *Description (exact)*; dispatch table; bare `/journal` four
      intents; drop lineage; drop workshop from intro and dispatch
      trigger; shared discipline lists `grep` next to `list`).
  - Change: verb procedure is Mechanism *`/journal search`*. Count the
    description; if >750, cut Use-when synonyms before cutting verbs.
  - Verify: lint `fails=0`; description length printed and ≤1024;
    grep gate empty for `Lineage:` and `workshop's delegated`;
    `verbs/search.md` exists and names `records.sh grep`. No journal
    test file required (read-only prose); do not skip slice-1 tests.

- [x] **Slice 3: mint `--dir` + curate + leftover language + drop
  `reports.md`** <requires: 1>
  - Files:
    - Modify: `skills/journal/scripts/records.sh` (`cmd_new --dir`);
    - Modify: `skills/journal/scripts/tests/records-test.sh` (red-proof 4);
    - Modify: `skills/journal/SKILL.md` (ownership paragraph, template
      convention mentions `--dir` and does not name `reports.md`,
      "stores" wording; delete `## Project templates`);
    - Modify: `skills/journal/verbs/curate.md` (one `list`, not per
      doctype; trigger wording "records home");
    - Modify: `skills/journal/verbs/setup.md` (refresh Done-when; no
      STOP on re-run; one workshop pointer allowed);
    - Modify: `skills/journal/scripts/standup.sh` README blob only if it
      still says "stores" (today it already crawls — re-read; edit only
      if a leftover remains);
    - Delete: `skills/journal/templates/reports.md` and the empty
      `templates/` directory.
  - Change: Mechanism *Ownership*, *No bundled template*, *`--dir`
    rules*, *Dispatch* curate row. Slice 2 may already have rewritten
    SKILL.md; do not revert the description. Parallel-eligible with
    slice 2 only if slice 2 has not started; otherwise apply on the
    post-slice-2 file.
  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
      bash skills/journal/scripts/tests/run.sh && \
      bash skills/skill-builder/scripts/skills-lint.sh . && \
      test ! -e skills/journal/templates
    ```

    Expect ALL GREEN, `fails=0`. Grep gate empty. `curate.md` has no
    `per doctype`. No `## Project templates` in journal `SKILL.md`.
    Lint check 2 does not fire on journal (no `templates/*.md`).

## Done when

All three slices checked. Verification block green. Journal description
fires on search and does not name a sibling, a workshop, or "stores."
`setup` on an existing fixture exits 0 and can ship a new subcommand.
`new --dir` mints off the doctype path without changing the default.
`skills/journal/templates/` is gone.

Close-the-books: update `docs/BACKLOG.md` only if this walk surfaces a
new leftover (not BL-19). Do not invoke `/backlog`.

## Review history

### 2026-08-20 — amend (owner)

Human: journal does not need a bundled reports template. Folded:
delete `templates/reports.md` and `templates/`; drop `## Project
templates`; drop the "contract example" sentences. Mechanism *No
bundled template*; slice 3; Goal and Done-when. Rejected keeping it
as an example — nothing reads it; writers already carry `reports.md`.
