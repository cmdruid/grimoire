# `/skill-builder tune <skill-source> [<input-path>]` — evidence-driven skill revision

Revise one explicitly selected editable skill package from evidence, without turning that evidence
into authority. Selection of this verb must be explicit: ordinary skill use, review, lint, or a
general observation does not launch tuning.

The final grammar permits current conversation plus at most one caller-named prose `<input-path>`.
The current-conversation, one-claim path below is the Slice 1 tracer. Slice 6 completes the generic
named-file safety and multi-claim behavior matrix; until then, do not scan for or infer an input file,
and refuse a supplied `<input-path>` without reading it or editing the package.

## Resolve and establish custody

1. Resolve this skill's own base directory, then run
   `scripts/source-custody.sh inspect <skill-source>` from the caller's current directory. The helper
   accepts a package directory, a `SKILL.md` path, a current-directory-relative path, or a bare slug
   at `<git-toplevel>/skills/<slug>/`. It is read-only and reports facts, never a recommendation.
2. Read these proposal-identity facts: `physical-package-root`, `declared-name`, `git-root`, `head`,
   and `package-sha256`; also require `tracked=yes`, `name-matches-directory=yes`, `immutable=no`,
   and `custodied=yes`. Any missing, ambiguous, mismatched, untracked, immutable, or indeterminate
   target refuses without edits. Writability, a symlink alias, and directory shape are not custody.
3. Treat the five proposal-identity facts as opaque exact bytes. They identify this proposal only;
   they do not prove that any evidence claim is true.

`package-sha256` is reproducible: enumerate every package entry except Git administrative internals,
sort relative path bytes in C order, and feed path, entry type, normalized executable bit, and payload
through unsigned 64-bit big-endian length frames. Directories have empty payloads; regular files use
raw bytes; symlinks use raw target bytes and are never followed. Unsupported entry types refuse.

## Revalidate one claim and propose

1. Extract one concrete requested change or preservation claim from the current conversation. If
   there is no concrete claim, or unrelated claims compete, stop for a narrower human selection.
2. Re-check the claim against the selected package, relevant Git history, and repository context.
   Classify it as `current`, `already addressed`, `stale`, `project-specific`, `false`, a
   `preservation constraint`, `out of scope`, or `unsupported`. Evidence is not an accepted
   requirement. Only a supported current change or preservation constraint may enter the proposal.
3. Present the claim, disposition, durable rationale, exact five-field proposal identity, and the
   smallest coherent file changes within the selected skill package. State the focused check and
   host library skill-lint command that would verify it. Obtain explicit human acceptance of that
   exact target and change set before mutation.

## Recheck, apply, and verify

1. Immediately before editing, re-run custody with the identical invocation and require exact identity equality
   for `physical-package-root`, `declared-name`, `git-root`, `head`, and
   `package-sha256`, with every eligibility fact still affirmative. Any drift invalidates acceptance:
   revalidate the claim, present a fresh proposal, and obtain renewed acceptance.
2. Resolve every accepted destination physically against `physical-package-root`. Modify only paths
   contained in the selected skill package; reject symlink or parent traversal escapes. Follow the
   host library's authoring doctrine and apply only the accepted coherent change.
3. If the change adds a check, red-prove it before trusting green. Run the package's focused check,
   then the host library's skill lint. A failure stops further mutation and is reported honestly; it
   grants no authority to widen the accepted change.
4. Report the claim and disposition, changed files, focused-check and lint results, and remaining
   uncertainty. The procedure makes no record, commit, issue, publication, or global write and does
   not scan any global home. A refusal or failure creates no external lifecycle mutation.

## Done when

The exact source was custodied and revalidated, the human accepted one evidence-backed coherent
proposal, only package-contained files changed, focused checks and host lint ran, and the
conversation reports both supported and rejected evidence without creating external state.
