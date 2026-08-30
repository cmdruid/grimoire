# `/code-humanizer mark` — semantics-preserving source presentation

Make existing source easier to scan without changing what it means. The allowed
surface is landmarks, grouping, formatting, and safe indentation. Read
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
3. **Read the selected files and project format rules.** For each file, decide
   whether it needs landmarks, formatter application, or manual whitespace
   adjustment. A file that is already clear and canonical is a no-op, not a
   rewrite. Follow the formatter precedence in `references/landmarks.md`; do not
   install or configure tools. For indentation-sensitive code, stop here if
   block nesting is ambiguous.
4. **Intent summary, then stop.** Show a compact list before any edit:

   ```text
   mark: N files (cap 20, omitted M)
   - path/a.rs — module purpose; project formatter on this file
   - path/b.py — docstring on public `run`; continuation alignment
   ```

   Name what will **not** change: identifiers, APIs, behavior, control flow,
   abstractions, dependencies, or file boundaries. Wait for a short go-ahead.
   Do not print the summary and edit in the same breath. A "yes" / "go" / "do
   it" is enough; any change of mind is a stop.
5. **Edit only the approved files.** `mark` may change comments, docstrings,
   blank lines, semantics-neutral whitespace, and canonical output from the
   project's formatter. Run the formatter on the narrowest supported approved
   scope and inspect the diff. Manual indentation may align continuations but
   must not alter block nesting. If formatting exposes a parse error, ambiguous
   indentation, or a change that cannot be shown semantics-preserving, stop and
   report it instead of repairing behavior under `mark`.
6. **Check the result.** Inspect the scoped diff and run any narrow formatting,
   syntax, or other host check needed to show the presentation change is valid,
   unless the underlying task already satisfied it. Do not commit; git is the
   review after the pass.

## Done when

The intent summary was shown and a go-ahead received; every approved file
has the approved presentation work; no identifier, API, behavior, control flow,
abstraction, dependency, or file boundary changed; applicable checks passed or
were reported; nothing was committed from this verb.
