---
doctype: design
status: open
created: 2026-08-21
updated: 2026-08-22
tags: [spec]
---

# Records `status` / `stage` — Spec

This library's design home is `docs/design/` (patient-zero). This
spec lives here. The **portable** contract it produces is registered
on `skill-builder` (Mechanism → Registry), so it travels with the
toolmaker.

Settled 2026-08-21 in conversation. Human: one generic `status` all
records follow so `journal` can filter; a skill-owned secondary key
for workflow gates; journal does not police uniqueness on behalf of
other skills.

## Problem

`status:` is doing two jobs, and neither well.

Journal's contract today is a closed set of six values (`open` |
`current` live; `done` | `dropped` | `superseded` | `consumed`
closed). Writers restate that set in-package (`skill-builder`
doctrine, record-writing rule 5). `records.sh list --status` and
`check` enumerate it.

That set mixes **record lifecycle** (is this the live official file,
or has it left the board?) with **close reasons** (consumed vs
dropped) and a **writer uniqueness convention** (`current` = “the
one living spec per subject”). An independent agent that sees
`needs-rework` or `current` cannot tell a gate from a catalog
state. Skills that want `approved` / `implemented` have nowhere
legal to put them — `check` rejects unknown `status:` values.

Close reasons already have a home: the `history.tsv` disposition
column, written only by `records.sh done`. Repeating them on the
file is a second copy of the same fact.

## Goal

Every record carries one journal-owned `status` with three values
an independent agent already understands: **draft**, **published**,
**archived**.

Writer skills that need a workflow gate own an optional **`stage`**
key. Journal does not enumerate it, does not require it, and does
not enforce cardinality of `published` records.

`list` / `grep` grow filters that match that split. Existing TSV
columns stay stable.

Portable authoring contracts (this one, later ones of the same
kind) live in a `skill-builder` `specs/` registry. Feature specs
for other skills (architect, inspector) do **not**.

## Approach

**Chosen:** two keys, split by owner.

- `status` — journal, required, closed set of three. Live vs
  official vs left-the-board. Filterable.
- Close reason — ledger only (`done` / `dropped` / `superseded` /
  `consumed`). Two predicates, not one: file closed ⇔
  `status: archived`; disposition ⇔ the four ledger words.
  `done` stamps the file `archived` and appends `--as` to the
  ledger. Do not reuse today’s single `is_closing` for both
  (HEAD `records.sh` lines 62, 340, 351, 476–488).
- `stage` — optional, non-empty string. The minting skill's
  `SKILL.md` is the authority for values on its doctypes. Journal
  `check` verifies presence-implies-non-empty; it does not enum-
  check.

**Chosen: `skill-builder/specs/`.** Portable format/authoring
contracts that lint, `new`, and writer rule 5 must honor. Doctrine
(`skills/skill-builder/docs/DOCTRINE.md`) stays philosophy and
**points** at the registered spec; it does not restate the enum. This library's
`docs/design/` stays the argued design record (patient-zero).
`docs/spec/pack-format.md` stays at repo root — `install.sh` reads
it there; this change does not move it.

**Rejected: keep six-value `status` and add `stage` beside it.**
`current` and `consumed` remain opaque; `list --status current`
still is not “the citable catalog.”

**Rejected: journal enforces one `published` spec per subject.**
Cardinality is a writer rule if a skill wants it. Journal does not
police other skills.

**Rejected: `rejected` as a `status` or required `stage`.** A
failing review leaves `draft`. Abandonment is `archived` + ledger
`dropped`.

**Rejected: put kind-templates or inspector feature specs in
`skill-builder/specs/`.** Those are not authoring contracts. Kind
templates land under `<agent-workspace>` when inspector exists.
Architect / inspector feature specs stay in `docs/design/`.

**Rejected: add `stage` as a `list` TSV column in this change.**
Callers parse six fields today. `--stage` filters internally;
agents that need the value read the file. A seventh column is a
later, breaking decision.

## Mechanism

### `status` (journal, required)

| value | means | migrates from |
|---|---|---|
| `draft` | not the official record yet | `open` |
| `published` | in the live, citable set | `current` |
| `archived` | left the live set | `done`, `dropped`, `superseded`, `consumed` |

`touch --status` accepts only `draft` | `published`. It refuses
`archived` (“closing goes through `done`”).

**Two predicates** (do not collapse them):

- File closed ⇔ `status: archived`.
- Disposition ⇔ `done` | `dropped` | `superseded` | `consumed`
  (ledger `--as` only). Unchanged vocabulary.

`records.sh done` stamps the **file** `archived` (not the
disposition word — today `stamp` writes `$disposition` onto
`status:`, line 351) and appends the ledger line whose
disposition is `--as`. `done --as consumed` is legal: file
`archived`, ledger `consumed`.

`check`: an `archived` file must have *a* ledger line for that
path. It does **not** require `$disp == $status` (today’s
equality at lines 476–488 would fail every close).

File-mode close (no `records.sh`): rewrite `status: archived` and
`updated:` only. Do not write `history.tsv`. After a later standup,
`check` flags archived-without-ledger. Repair is `curate`: rewrite
`status:` back to `draft`, then `records.sh done`.

### `stage` (writer, optional)

- Not one of the five required keys (`doctype`, `status`, `created`,
  `updated`, `tags`). Extra keys remain legal.
- If the key is present, its value is a non-empty string (no leading
  / trailing whitespace after trim). Empty or missing-with-key-present
  is a `check` fail.
- Journal does not interpret the string. `list --stage` / `grep
  --stage` exact-match it.
- Templates mint **without** `stage` unless that writer’s procedure
  says otherwise.
- A writer that uses `stage` states its values in **its own**
  package (in-package contract, same independence rule as today).

### Filters

AND across dimensions; OR within a repeated flag.

| invocation | default | flags |
|---|---|---|
| `list` | `draft` ∪ `published` (hide `archived`) | `--type`, `--tag`, `--since`, `--until`, `--status`, `--stage` |
| `grep` | whole corpus, including `archived` | same flags + pattern |
| `history` | unchanged (ledger, filter by disposition) | unchanged |

Today `list` with no flags returns **all** statuses (`cmd_list`
filters only when `--status` is set). The live-set default is a
behavior change. `done` writebacks and `curate` that call
unfiltered `list` now see the live set (what they want for
open trackers). Archived rows: `list --status archived`. `check`
and `prune-candidates` still crawl every record, not `list`.
`--type` matches the front-matter `doctype:` string — an open
set. Journal still knows no store list and reserves no doctype.

`--status` accepts `draft` | `published` | `archived`. Repeatable →
OR.

`--stage` accepts any string. Repeatable → OR. Unknown strings are
not an error (journal does not own the enum); they simply match
nothing.

Citable catalog: `list --status published`.
WIP: `list --status draft`.
A writer gate (example, not a reserved type):
`list --type <doctype> --stage <value>`.

`list` TSV columns stay: path, doctype, status, updated, tags,
title.

### In-package contract (writers)

Rule 5 restates the **new** vocabulary, not the old six:

- five required keys, dated slug, record-link form — unchanged
- `status`: `draft` | `published` live; `archived` closed
- optional `stage` (non-empty if present); values declared here if
  this skill uses the key
- file-mode close → `archived`, not a ledger disposition word

Doctrine record-writing rule 5 **points** at
`skills/skill-builder/specs/records-front-matter.md` and quotes
nothing that can drift. `skill-builder new` scaffolds from that
spec.

### Registry (`skill-builder/specs/`)

New directory, bundled with the toolmaker.

- **Belongs:** portable format/authoring contracts that every
  skills library installing `skill-builder` must honor (records
  front-matter, later contracts of the same class).
- **Does not belong:** a host library’s feature specs, pack-format
  (stays `docs/spec/pack-format.md`), doctrine essays
  (`skills/skill-builder/docs/DOCTRINE.md`), or project-deployed
  kind templates.

Layout:

```
skills/skill-builder/specs/
  README.md                  # this rule, plus an index of registered specs
  records-front-matter.md    # Mechanism only (status / stage /
                             # filters / in-package contract) —
                             # not Problem / Approach
```

`SKILL.md` *What this skill bundles* lists `specs/`. `calibrate`
may add a registered spec; it does not fold enum tables back into
`DOCTRINE.md`.

### Migration

`setup` refresh **migrates, then** the new `check` applies. Do
not copy a rejecting `records.sh` onto a host whose files still
carry the old six. The rewrite:

| old `status:` | new `status:` | ledger |
|---|---|---|
| `open` | `draft` | none |
| `current` | `published` | none |
| `done` / `dropped` / `superseded` / `consumed` | `archived` | existing line stays; disposition column already holds the old word |

Do not invent ledger lines for already-closed records that have
one. Do not rewrite `history.tsv` dispositions.

This library’s **writer copies** of the old enum (not a journal
store list — journal still crawls any `doctype:`): every bundled
template that mints `status: open`, every writer `SKILL.md` that
restates the six-value set, and every mint script / fixture that
copies `is_closing` or plants `status: open` / `current` /
`done`. Slice 3 is “what the verify `rg` hits under `skills/`,”
not a taxonomy. No `stage` values are introduced in this spec.

### Out of scope

- Architect rename; inspector extract; kind templates.
- Writer-specific `stage` vocabularies (`approved`, `implemented`).
- Moving `docs/spec/pack-format.md`.
- Changing `list` TSV width.
- Uniqueness of published specs.
- Review stamps / `needs-rework` on artifacts (inspector).

## Verification

**Mechanical**

- `records.sh` tests: mint default `draft`; `touch --status
  published`; `done --as consumed` → file `archived` + ledger
  `consumed` (not equal); `touch --status archived` refuses;
  `list` hides archived; `list --status archived` shows them;
  `grep` without flags still hits an archived body; `--stage`
  filters; empty `stage:` fails `check`; unknown `stage` string
  is not a `check` fail; old six values fail `check` **after**
  migrate; archived-without-ledger fails `check`;
  archived+ledger `consumed` passes (no `$disp == $status`).
- Red-proof the new `check` arms (plant `status: open`, demand
  red, restore).
- `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`.
- `rg "open \\| current live" skills/skill-builder/docs/DOCTRINE.md`
  — no hits. Doctrine points at the registered spec.

**Judgment**

- An independent agent can filter the citable set with `list
  --status published` without knowing any writer skill.
- A writer can gate `build` on `stage` without a journal change.
- `history.tsv` still answers *why* a record left the board.

## Slices

- [ ] **Slice 1: register the contract** <requires: —>
  - Paths: `skills/skill-builder/specs/README.md` (new);
    `skills/skill-builder/specs/records-front-matter.md` (new);
    `skills/skill-builder/SKILL.md`;
    `skills/skill-builder/docs/DOCTRINE.md` (record-writing rule
    5 + References);
    `skills/skill-builder/verbs/new.md`.
  - Verify: lint `fails=0`; doctrine has no restated six-value
    enum; `new.md` scaffolds `draft` / `archived` / optional
    `stage`.

- [ ] **Slice 2: journal tool** <requires: Slice 1>
  - Paths: `skills/journal/scripts/records.sh`;
    `skills/journal/scripts/tests/records-test.sh`;
    `skills/journal/SKILL.md`; journal templates if any;
    `verbs/done.md` / `curate` / `setup` refresh: migrate
    statuses first, then the new `check`; reopen value is
    `draft` not `open`.
  - Verify: records-test.sh green, including two predicates,
    `done --as consumed` (file archived / ledger consumed),
    live-set `list`, and migrate-then-check order.

- [ ] **Slice 3: writer restatement** <requires: Slice 2>
  - Paths: whatever the verify `rg` hits under `skills/` —
    templates, in-package contract paragraphs, mint scripts
    (`record-mint.sh`, `note-mint.sh`, `bug-mint.sh`), and
    fixtures that plant the old enum. Not a doctype list.
  - Verify: `rg "status: open|status: current|is_closing.*done\\|dropped" skills/`
    no live contract copies (historical `docs/design/`
    exempt); lint `fails=0`.

_On completion (before landing), run the host's close-the-books sweep._

## Review history

### 2026-08-21 — needs-rework

Must-fix:

- **F1** Mechanism → `is_closing` is archived only — unimplementable
  against HEAD `skills/journal/scripts/records.sh`. Today one
  predicate serves two sets: file status (`open|current|done|…`)
  and `--as` disposition (`done|dropped|superseded|consumed`,
  line 340). `cmd_done` then `stamp`s that disposition onto the
  **file** (line 351). `check` requires ledger disposition
  **equals** file status (lines 476–488). After this spec, file
  status is `archived` and ledger stays `consumed` — they never
  match; `done --as consumed` also fails if `is_closing` is
  collapsed to `archived` only. **Fix:** two predicates. File
  closed ⇔ `status: archived`. Disposition ⇔ the four ledger
  words. `done` stamps the file `archived` and appends
  `--as` to the ledger. `check` requires an archived file to
  have *a* ledger line; it does not require `$disp == $status`.
  - resolved — two predicates; `done` stamps file `archived`;
    `check` requires a ledger line, not equality.

- **F2** Slice 3 / Migration — writer restatement is templates +
  SKILL.md paragraphs. Duplicated enums live in mint scripts
  and fixtures: `skills/backlog/scripts/record-mint.sh:21`,
  `skills/notepad/scripts/note-mint.sh:21`,
  `skills/notepad/scripts/tests/note-mint-test.sh`,
  `skills/analyst/scripts/tests/facts-test.sh` (plants
  `status: open` / `done`). Slice 3’s `rg "^status: open$"`
  under `templates/` misses them. **Fix:** name those scripts
  and tests in Slice 3; expand the verify `rg` to `skills/`
  (or list the copies).
  - resolved — Slice 3 names the mint scripts and fixtures;
    verify `rg` covers live contract copies under `skills/`.

- **F3** Migration → “on first `records.sh` that implements this
  contract, `check` rejects the old six.” A `setup` refresh
  that copies the new script before rewriting hosts fails every
  record. **Fix:** refresh order is migrate (rewrite statuses),
  *then* the new `check` applies. Name that as Slice 2, not
  “or a dedicated migrate path.”
  - resolved — setup refresh migrates, then `check`; Slice 2
    owns the order.

Nice-to-have:

- **N1** Mechanism cites `docs/DOCTRINE.md`; ground-check
  reports repo-root `docs/DOCTRINE.md` missing. Real file:
  `skills/skill-builder/docs/DOCTRINE.md`. Slice 1 already
  uses the long path.
  - resolved — Approach cites
    `skills/skill-builder/docs/DOCTRINE.md`.

- **N2** Today `list` with no flags returns **all** statuses
  (`cmd_list` only filters when `--status` is set). Hiding
  archived is a behavior change. Call it out so `curate` /
  `done` writebacks (they call `list` unfiltered) are walked
  against the live-set default.
  - resolved — Filters names the live-set default as a change;
    `check` / `prune-candidates` still crawl every record.

- **N3** Portable `records-front-matter.md` — say it is the
  Mechanism (`status` / `stage` / filters / in-package
  contract), not a copy of Problem / Approach.
  - resolved — Registry: Mechanism only.

### 2026-08-22 — needs-rework

Delta pass after the F1–F3 / N1–N3 fold. Prior items remain
resolved. Same-session author; depth dial off.

Must-fix:

- **F4** Mechanism → Filters — the `list` / `grep` / `history`
  table is broken. N2’s live-set paragraph was inserted **inside**
  the table (after the `list` row, before `grep` / `history`).
  An implementer cannot copy the filter matrix. **Fix:** close
  the `list` row, put the live-set note **under** the table, then
  the `grep` and `history` rows.
  - resolved — table is three rows; live-set note sits under it;
    `--type` is an open `doctype:` string, not a store list.

- **F5** Slice 3 path list still misses
  `skills/debugger/scripts/bug-mint.sh` (same `is_closing`
  four-word copy as the mint scripts F2 named). The widened
  verify `rg` would catch it at build; the slice does not name
  the file it breaks. **Fix:** add it to Slice 3 paths (and any
  other `is_closing() { case ... done|dropped` copy the `rg`
  finds).
  - resolved — Slice 3 is “what the verify `rg` hits,” including
    `bug-mint.sh`; not a doctype taxonomy.

Nice-to-have:

- **N4** Registry “Does not belong … (`docs/DOCTRINE.md`)”
  still ground-checks as a missing repo-root path. Write
  `skills/skill-builder/docs/DOCTRINE.md`.
  - resolved — Registry cites
    `skills/skill-builder/docs/DOCTRINE.md`.

### 2026-08-22 — approve

Delta pass after the F4–F5 / N4 fold. F1–F5 and N1–N4
resolved. Filters table is three rows; `--type` is an open
`doctype:` string; Slice 3 is the verify `rg`, not a store
list. Same-session author; depth dial off.

Must-fix: none.
