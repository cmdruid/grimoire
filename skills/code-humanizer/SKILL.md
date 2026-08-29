---
name: code-humanizer
description: "Use when writing or editing source so a human can scan it; when the user runs /code-humanizer; or when they ask to mark, humanize, comment, add docstrings, make generated code readable, map a tree, or walk through code they did not write. Keywords: code-humanizer, mark, map, walk, landmarks, docstrings, comments, readable, generated code, navigate, I'm lost."
---

# code-humanizer — make source a human can scan

Help a human find their way around code they did not write, especially
agent-written code. One skill, three verbs, one reading of the tree: entry
points, file roles, density, landmarks.

Disposition: **in-place steward of source** — no project home, no setup, no
front-door registration. Map snapshots, when asked, are records under
`<agent-records>/maps/`. Missing `records.sh` is not an error. Journal standup
is never a precondition.

This `SKILL.md` is a **thin router**. The write-time standard lives here because
it must fire while source is being written. Each verb's procedure lives in
`verbs/<verb>.md` — **read it and follow it**; do not reconstruct it from
memory. Landmark grammar is `references/landmarks.md`.

## Write-time standard

Apply this to every source file this session is already creating or editing.
Do not start a second sweep of the tree. No extra confirmation.

- File or module purpose at the top, in that language's usual form.
- Section landmarks for distinct phases in a long file.
- Blank-line grouping of related statements.
- Docstrings on exported or public entry points a reader will land on.
- Names a human can scan; one-screen functions; one job per file.
- No dense one-liners that hide control flow.

Write *why* that is not obvious from the code. Do not narrate the next line.
Do not split files or extract helpers as a cleanup; if a new file is growing
into two jobs, stop and keep it one job. Read
[`references/landmarks.md`](references/landmarks.md) when the form is unclear.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| writing or editing source (no verb) | (this file, *Write-time standard*) | landmarks, names, and shape on files already being touched |
| bare `/code-humanizer`, or `mark [<path>]` | `verbs/mark.md` | landmarks only on existing code, after an intent summary |
| `map [<path>]` | `verbs/map.md` | conversational navigation snapshot; save only if asked |
| `walk [<path>]` | `verbs/walk.md` | conversational tour of one path |

`mark` is the default verb for an explicit invocation. Free-text "make this
readable", "add comments", "add docstrings", or "humanize this" is `mark`.
"I'm lost" / "how do I navigate this" is `map`. "Walk me through" is `walk`.

## Scope

`<root>` is `git rev-parse --show-toplevel`. Non-git → ask. Resolve `scripts/`
and `references/` from this skill's own base directory.

A named path wins. Otherwise the current git change: dirty and untracked
source files, or the last commit if the tree is clean. Whole-repo only when
the human says the whole repository, never because the path is `.`.

The package-local lister is the sole deterministic entry point:

```text
scripts/scope.sh <root> [--path <rel>] [--cap N]
```

Default cap is 20. It prints `key=value` facts and `file=` lines; it never
edits. Truncation is a fact (`omitted=N`), not a license to continue past the
cap. Markdown and other non-source files are out of v1.

## Record contract (map save only)

Ordinary `mark` / `map` / `walk` write no records. A map is saved only when
the human asks. Then mint under `<agent-records>/maps/` (first line-start
`agent-records:` or `records-root:` in `AGENTS.md`, then `CLAUDE.md`, else
`.records/`). Front-matter keys: `doctype`, `status`, `schema`, `tags`; schema
`code-humanizer/map@1`; live `draft` / `published`; closed `archived` (ledger
`--as` is `done` / `dropped` / `superseded` / `consumed` when the tool exists).
File-mode close changes only status. Ordinary edits stamp no generic date or
revision. Filenames are `YYYY-MM-DD-<slug>.md`; record links are
`→ <store>/<file>.md`. Optional `stage` is non-empty if present. Use
`records.sh --root <root> --records-root <records-root-relative> new maps
--schema code-humanizer/map@1 --title "…"` when that tool is executable;
otherwise write the same four-key shape in file mode. Never write
`history.tsv` by hand.

## Not v1

File splits, helper extracts, documentation passes, and renaming existing
identifiers are later work. Do not stretch `mark` into them.

## Project templates

none

## Edges

<!-- edges:code-humanizer -->
- produces: record — an optional stamped map snapshot under maps/ when the human asks to save
- handoff: — (none; mark edits source in place; map and walk inform)
- consumes: — (the repository working tree and git change are direct input, not a typed artifact)
<!-- /edges:code-humanizer -->

## Done when

For write-time, every source file this session touched carries the standard
and no extra tree was swept. For a named verb, that verb file's Done when.
