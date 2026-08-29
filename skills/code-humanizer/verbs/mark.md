# `/code-humanizer mark` — landmarks on existing source

Make existing source skimmable without changing what it does. Landmarks only:
file or module purpose, section banners, grouping, docstrings. Read
[`references/landmarks.md`](../references/landmarks.md) before editing.

## Procedure

1. **Resolve `<root>`** — `git rev-parse --show-toplevel`. Non-git → ask.
2. **List the files.** Run `scripts/scope.sh <root> [--path <rel>]` from this
   skill's own `scripts/` (default cap 20). A named path wins; otherwise the
   script uses the current git change. If `git=0`, ask for a git checkout.
   If `selected=0`, say so and stop. If `omitted` is nonzero, name the cap
   and stop — do not silently skip the rest, and do not raise the cap. Whole
   repository: only when the human said the whole repository in so many
   words. A path of `.` is not that permission.
3. **Read the selected files.** For each one, decide which landmarks it
   actually lacks. A file that already has purpose, grouping, and docstrings
   is a no-op, not a rewrite.
4. **Intent summary, then stop.** Show a compact list before any edit:

   ```text
   mark: N files (cap 20, omitted M)
   - path/a.rs — module purpose; section banners around parse/write
   - path/b.py — docstring on public `run`
   ```

   Name what will **not** happen: no renames, no extracts, no control-flow
   changes. Wait for a short go-ahead. Do not print the summary and edit in
   the same breath. A "yes" / "go" / "do it" is enough; any change of mind
   is a stop.
5. **Edit only the approved files.** Follow `references/landmarks.md`. Match
   the file's existing comment style. Leave token-level formatting to the
   project's formatter when it has one. Do not commit; git is the review
   after the pass.

## Done when

The intent summary was shown and a go-ahead received; every approved file
has the landmarks it lacked; no identifier, control flow, or file boundary
changed; nothing was committed from this verb.
