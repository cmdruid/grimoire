# Record front matter

Portable record metadata contract. Writer rule 5, Skill-builder lint, and Journal `check` honor
this file. Artifact validators and migration chains remain inside their owning skill package.

## Current profile

Every current record has exactly these four required keys between top-of-file `---` delimiters:

- `doctype`: the open record type; front matter, not the parent directory, is authoritative.
- `status`: `draft` or `published` while live; `archived` when closed.
- `schema`: `<writer>/<artifact>@<positive-integer>`, with lowercase kebab-case names. The writer
  component is the owning skill name. Shared tools validate this grammar, not artifact registries.
- `tags`: a YAML-style inline list; it may be empty.

`created`, `updated`, `created_at`, `updated_at`, and `revision` are retired reserved keys. They are
invalid on a current record and may appear only in a registered legacy input selected by the owning
skill's explicit `migrate` verb. Migration removes them; ordinary readers never rewrite them.

The first ten filename characters in `YYYY-MM-DD-<slug>.md` are the creation-date authority.
Journal date filters and sorting use that date. Git path history is the durable modification source;
ordinary edits do not stamp generic dates or revision counters.

Extra domain-specific keys remain legal. A project template is a body-only authoring scaffold and
cannot declare or select `schema`; schema identifiers, validators, and migrations are package-owned.

## `status` (Journal, required)

| value | means | registered legacy input |
|---|---|---|
| `draft` | not the official record yet | `open` |
| `published` | in the live, citable set | `current` |
| `archived` | left the live set | `done`, `dropped`, `superseded`, `consumed` |

`touch --status` accepts only `draft` or `published`. Closing goes through `done`.

Two predicates remain distinct:

- File closed iff `status: archived`.
- Disposition is `done`, `dropped`, `superseded`, or `consumed` in ledger `--as` only.

`records.sh done` changes only the file's `status` and appends the six-field ledger line. An
`archived` file must have a ledger row for its path; the disposition need not equal the status.
File-mode close changes only `status: archived` and never writes `history.tsv`.

## `stage` (writer, optional)

- `stage` is not one of the four required keys.
- If present, its trimmed value is non-empty.
- Journal does not own the value vocabulary. `list --stage` and `grep --stage` exact-match it.
- A writer that uses `stage` declares its values inside its own package.

## Mint and filters

`records.sh new <doctype> --schema <schema> --title <title> [--dir <rel>] [--tag <tag>]...
[--template <body-template>]` synthesizes the current front matter. A body template is optional and
supports literal `<title>` and `<date>` substitution. `<schema>` and `<tags>` body slots refuse.

Filters are AND across dimensions and OR within repeated flags. `list` defaults to `draft` plus
`published`; `grep` searches the whole corpus. `list` TSV columns are path, doctype, status,
filename date, tags, and title, sorted by filename date descending and then path.
