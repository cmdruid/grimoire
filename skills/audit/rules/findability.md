# Findability -- audit rule
> Can you locate a symbol from its name alone?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `FND`.

## Why it matters

In a codebase where the call graph is implicit (e.g., systems, components, and
resources wired at runtime through a framework scheduler rather than explicit call
sites), a reader who cannot predict *which file* a symbol lives in must search the
whole tree on every visit. Poor findability means every refactor starts with an
archaeology pass, and every new contributor pays that tax repeatedly. A single
catch-all module or an overloaded entry-point file immediately erases the
module-tree legibility that the repo layout is meant to provide.

## Scoring anchors (1-5)

- 5 -- Every public symbol is in a module whose name predicts it. Module boundaries
  match single responsibilities. Entry-point / index files are thin re-export
  facades, not logic holders. A newcomer can guess the file from the type or
  function name without searching.
- 4 -- A few low-blast-radius helpers live in slightly wrong modules, or one
  index file holds minor glue logic that would fit better in a named sibling.
  Guessability is good; one search per session.
- 3 -- One or two dumping-ground modules (`util`, `helpers`, or a bloated index
  file) exist but are bounded. Vague verb-noun names (`handle_stuff`, `do_update`)
  appear in non-trivial paths. A reader searches more than once per visit.
- 2 -- Several catch-all modules blur responsibilities across a subsystem. Function
  names are generic enough that a search for `fn handle` returns a long list with
  no obvious hierarchy. The module tree does not map to the feature decomposition.
- 1 -- Pervasive: the module tree is flat or random, names are generic across the
  board, and locating any non-trivial symbol requires reading multiple files in
  sequence.

## Decision logic

1. List the public symbols in the target and ask: does the module name predict each
   one? Start with the top-level directory names, then open the largest index files.
2. Run the smell greps (see Anti-patterns). A hit is a *candidate*, not a finding:
   follow up by reading the function. A two-line wrapper in a `helpers` module that
   is truly miscellaneous is a lower-severity candidate than a 60-line algorithm.
3. Check index / entry-point files for logic. A file that only re-exports is fine;
   one that defines types or non-trivial functions is a findability smell.
4. Score against the anchors. If two anchors both fit, pick the lower one -- the
   scoring bias is conservative (a 5 must be earned, not asserted).
5. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: search for vague function names containing util/helper/do_it/stuff/misc/common.>
<language: search for functions named exactly "handle" (not handle_player_input etc.).>
<language: find catch-all module files: util, helpers, common, misc.>
<language: find index/entry-point files with non-trivial logic (type/function definitions, not just re-exports).>
<language: search for overly generic manager/handler struct names (Manager, Handler, Helper, Util, Misc).>
<language: list source files by line count to surface likely dumping-ground modules (> 150 lines as a proxy -- deliberately lower than god-files' 300: this smells at name-vs-content mismatch, not size itself).>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Framework lifecycle methods.** Methods like `build`, `update`, or `init`
  defined by a framework interface are not vague names -- they are the framework's
  API surface. Do not flag.
- **Index files in tiny modules.** A module with one or two items may legitimately
  define them directly in the index file rather than a named child. Flag only when
  the module is non-trivial (more than ~30 lines of logic).
- **Trait method stubs.** A trait method named `handle` or `update` on a concrete
  type implementing a narrow interface is not a findability smell -- the trait name
  carries the context.
- **Test helpers in test-only blocks.** Test-only utilities with generic names
  are scoped and invisible to production readers; do not flag them.
- **`common` modules that are truly common.** If a module named `common` holds only
  newtype wrappers or re-exports shared across the whole codebase, and its contents
  are genuinely cross-cutting, the name is defensible. Check the size and contents
  before flagging.

## How to quantify

<language: count catch-all module files (util, helpers, common, misc); count functions
with vague names; record both as: `catch-all files: N; vague-name fns: M`. There is
no automated precision metric for findability; the quantitative pass surfaces candidates
and the reader applies judgment.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
