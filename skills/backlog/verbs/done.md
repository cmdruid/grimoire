# `/backlog done <id>` — complete a tracker entry, one log line

The **canonical completion verb**: finish a tracker entry the schema's way — mutate the entry per
its store's completion rule, append exactly one line to the done log, and nothing else. The record
schema (the installation's `.handbook/rules/RECORDS.md`) is the contract this verb executes; it is
stated there once and not restated here.

**The writer map** (who completes what): a fast-path item finished → this verb; a ticket resolved
or wontfixed → `/backlog close` (it writes the log line itself); a dispatched improvement item
landed → the improvement loop confirms uptake, then this verb with `--outcome drained`; a
workstream ship → this verb per shipped item, plus the stream's own full done-record file (from
`templates/done-record.md`) into `.records/done/`; dropped at curation → `/backlog curate` logs the
`dropped` outcome. Full done-record files are a feature-lane / workstream artifact — this verb
writes only the log line.

## When to use

- An entry's work has **landed on the trunk** (the completion moment — not gate-green): "mark
  T-041 done", "/backlog done I-017", "close out that task".
- With `--outcome dropped | wontfix | drained` when the entry ends without work landing (the
  outcome vocabulary is the schema's).

**Do NOT use** for resolving a *ticket* (`/backlog close` — it owns the ticket lifecycle and its
log line), for weeding entries at curation (that's `/backlog curate`, which logs `dropped`
itself), or to archive a store-dir file (curation ages resolved files into `archive/`).

## What it does (the schema's completion table, executed)

- **Flat entries** (`T-` / `I-` / `F-`) are **removed** from the live file — the done-log line is
  the archive. A heading-led entry's span runs to the next heading of equal or higher rank, so
  category headers survive.
- **Store-dir items** (`B-` / `N-`) are **retained** — frontmatter advances to `status: resolved`
  + today's date.
- **One log line** appends to `.records/done/log.md` (created with its header on first use):
  `- <date> · <id> · <gist> · commits: <shas|-> · <outcome>`. Work commits cite the entry ID; a
  no-work outcome writes `commits: -`.
- **Refusals** (facts, nothing mutated, no log line): an **absent** ID, an **already-completed**
  ID, a **paused** ID (its ticket must resolve first — `/backlog close`, never this verb).

## Procedure

1. **Resolve root + date** (`date +%Y-%m-%d`; shared discipline in the router). On an **unstamped
   root** (no installation block) this verb **refuses**: report `unstamped` and point at the
   clankshop onramps (`setup` / `migrate`) — completion presumes the stores exist.
2. **Confirm the completion is real.** The work landed on the trunk (or the outcome is
   `dropped`/`wontfix`/`drained` per the writer map). Collect the work-commit shas that cite the
   entry ID — `git log --oneline --grep <id>` grounds the list.
3. **Run the mutation:**
   `scripts/done-entry.sh <root> <id> <outcome> "<one-line gist>" [<sha,sha>]` — it executes the
   completion table above and emits facts (`mutation=… logged=1`, or a `refused=…`/`unstamped=1`
   fact). A promoted entry's completion belongs to its ticket's resolution — on `refused=paused`,
   stop and use `/backlog close`.
4. **Commit (trunk-side, pathspec-atomic).** The completion touches the live tracker and the done
   log: `scripts/scoped-commit.sh <root> "Done <id>: <gist>" <tracker-path> .records/done/log.md`.
   The log mutation's own commit is never cited in the line it writes.
5. **Report** the mutation fact, the log line, and the outcome — or the refusal fact verbatim.

## Relationship to neighboring verbs

- **`/backlog close`** — the ticket sibling: resolving a ticket un-pauses its origin and writes
  the log line itself (the origin's ID for a promoted ticket, the `TK-` ID for a direct one).
- **`/backlog curate`** — weeds dead entries (`dropped` outcome) and ages resolved store-dir
  files; stamps pending IDs at landing.
- **`/backlog debrief`** — captures byproducts at completion time; it never completes entries.

## Done when

The entry is completed per its store's rule (removed, or frontmatter-advanced), exactly one
done-log line records it with the right outcome and commits, the change is a trunk-side scoped
commit — or the refusal fact (absent / completed / paused / unstamped) is reported verbatim and
nothing was mutated.
