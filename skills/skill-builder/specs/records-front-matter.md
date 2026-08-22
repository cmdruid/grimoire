# Record `status` / `stage`

Portable front-matter contract. Writer rule 5, `new`, and journal
`check` honor this file. Doctrine points here; it does not restate
the enum.

## `status` (journal, required)

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

`records.sh done` stamps the **file** `archived` and appends the
ledger line whose disposition is `--as`. `done --as consumed` is
legal: file `archived`, ledger `consumed`.

`check`: an `archived` file must have *a* ledger line for that
path. It does **not** require `$disp == $status`.

File-mode close (no `records.sh`): rewrite `status: archived` and
`updated:` only. Do not write `history.tsv`. After a later standup,
`check` flags archived-without-ledger. Repair is `curate`: rewrite
`status:` back to `draft`, then `records.sh done`.

## `stage` (writer, optional)

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

## Filters

AND across dimensions; OR within a repeated flag.

| invocation | default | flags |
|---|---|---|
| `list` | `draft` ∪ `published` (hide `archived`) | `--type`, `--tag`, `--since`, `--until`, `--status`, `--stage` |
| `grep` | whole corpus, including `archived` | same flags + pattern |
| `history` | unchanged (ledger, filter by disposition) | unchanged |

The live-set default is a behavior change. `done` writebacks and
`curate` that call unfiltered `list` now see the live set (what they
want for open trackers). Archived rows: `list --status archived`.
`check` and `prune-candidates` still crawl every record, not `list`.
`--type` matches the front-matter `doctype:` string — an open set.
Journal still knows no store list and reserves no doctype.

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

## In-package contract (writers)

Rule 5 restates this vocabulary, not a six-value set:

- five required keys, dated slug, record-link form — unchanged
- `status`: `draft` | `published` live; `archived` closed
- optional `stage` (non-empty if present); values declared here if
  this skill uses the key
- file-mode close → `archived`, not a ledger disposition word
