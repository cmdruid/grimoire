---
name: code-humanizer
description: "Use: durable app/service/library/CLI or maintained tests; humanize/format/indent/mark/map/walk. Never infrastructure/deployment/CI/build. No auto-use for repo scripts, throwaway/generated/vendor code, fixtures/snapshots."
---

# code-humanizer — keep durable source fit for human ownership

Keep agent-written code safe for a human to understand, change, and verify.
One skill, three verbs, one reading of the tree: entry points, file roles,
density, landmarks.

Disposition: **in-place steward of source** — no project home, no setup, no
front-door registration. Map snapshots, when asked, are records under
`.records/maps/`. Missing `records.sh` is not an error. Journal standup
is never a precondition.

This `SKILL.md` is a **thin router**. The write-time standard lives here because
it must fire while source is being written. Each verb's procedure lives in
`verbs/<verb>.md` — **read it and follow it**; do not reconstruct it from
memory. Landmark grammar is `references/landmarks.md`.

## Applicability

Classify the target by its role and intended lifecycle, never by extension or
path alone. First apply the hard boundary: infrastructure-as-code, deployment
manifests, and CI/build infrastructure are outside this skill. Even when the
invocation is explicit, report that boundary and stop before dispatch, file
listing, or editing.

Implicit write-time application is for durable application, service, library,
shipped CLI, and maintained test source. Repository automation, release,
maintenance, and operational scripts; spikes, scratch files, prototypes, and
other throwaway code; fixtures and snapshots; and generated or vendored code do
not activate it. A shipped CLI is durable product source even when executable;
a repository script remains excluded unless the request is explicit. If the
role is ambiguous, skip the implicit write-time standard and continue the
underlying task normally.

Explicit invocation bypasses the automatic exclusions for supported
non-infrastructure code, including scripts and disposable programs. For a
vendored or machine-generated artifact, prefer its generator or template;
edit the artifact itself only when the user explicitly asks and the project
permits it.

## Write-time standard

After the applicability gate passes, apply this only to code the session
introduces or materially reshapes, plus the immediate formatting context needed
to make that code fit. Merely touching a legacy file does not authorize headers,
docstrings, banners, helpers, or formatting elsewhere in it. Do not start a
second sweep of the tree or perform unrelated cleanup. No extra confirmation.

Use this hierarchy, in order:

1. **Correctness and task constraints come first.** Preserve requested behavior,
   security, performance, compatibility, and public contracts.
2. **Fit the project.** Follow repository instructions, formatter configuration,
   established architecture, and nearby idioms.
3. **Prefer the simplest cohesive implementation.** Keep invariants, failure
   behavior, resource ownership, and edge cases explicit; use restrained
   abstraction and create no unnecessary public surface.
4. **Make it scannable.** Visually scannable code uses deliberate names, control
   flow, indentation, grouping, line breaks, and useful landmarks.
5. **Verify the work.** Run the host's applicable tests, diagnostics, and
   formatting before handoff; visual polish is not evidence of correctness.

A function is small enough when its responsibility and control flow are
understandable together. A file is cohesive when its contents change for the
same reason. There is no line, screen, or file-count target. Extract a helper or
split a new file only when the authorized coding task already permits that
structure and it clarifies a real responsibility; do not refactor existing code
to satisfy this standard. Prefer direct code over speculative layers, one-caller
generic helpers, or clever compression.

File-purpose comments and public docstrings are conditional: add them when they
help navigation or explain a non-obvious contract, not when a file, signature,
getter, test helper, or conventional entry point already says enough. Put hidden
constraints and trade-offs in comments only when code or types cannot express
them clearly. Read [`references/landmarks.md`](references/landmarks.md) when the
form is unclear.

## Formatting and indentation

Use formatting authority in this order:

1. The repository's documented formatting command and checked-in configuration.
2. An established language formatter already used by the project.
3. The conventions in the surrounding file when no formatter is available.

Run a formatter on the narrowest supported touched scope and inspect its diff.
Canonical token changes from a project-prescribed formatter are allowed. Do not
install a formatter, add or alter formatter configuration, or silently run a
repository-wide reformat. If the only available formatter has broad effects,
run it only when host instructions explicitly require that command; otherwise
preserve local style and report that no narrow formatter was available.

When formatting manually, preserve the local tabs-versus-spaces choice,
indentation depth, continuation alignment, brace placement, and wrapping
convention. Use indentation to expose nesting, blank lines to group one thought,
and line breaks to reveal control flow or data shape. Do not mechanically expand
idiomatic compact code or compress several decisions into a dense one-liner.

In an indentation-sensitive language, apply a trusted formatter to parseable
code or adjust continuation whitespace that cannot change block nesting. This
skill must not guess at ambiguous nesting or manually reindent code in a way
that may change control flow; that requires an implementation request.

Formatting and verification already completed by the underlying coding task
satisfy this standard; do not repeat it solely because code-humanizer loaded.
Report unavailable checks and failures honestly.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| writing or editing applicable durable source (no verb) | (this file, *Write-time standard*) | quality and scanability on introduced or materially reshaped code |
| bare `/code-humanizer`, or `mark [<path>]` | `verbs/mark.md` | approved landmarks, grouping, formatting, and safe indentation |
| `map [<path>]` | `verbs/map.md` | conversational navigation snapshot; save only if asked |
| `walk [<path>]` | `verbs/walk.md` | conversational tour of one path |

`mark` is the default verb for an explicit invocation. Free-text "make this
readable", "add comments", "add docstrings", "humanize this", "format this",
or "fix the indentation" is `mark`.
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
the human asks. Then mint under fixed `.records/maps/`. Front-matter keys: `doctype`, `status`,
`schema`, `tags`; schema
`code-humanizer/map@1`; live `draft` / `published`; closed `archived` (ledger
`--as` is `done` / `dropped` / `superseded` / `consumed` when the tool exists).
File-mode close changes only status. Ordinary edits stamp no generic date or
revision. Filenames are `YYYY-MM-DD-<slug>.md`; record links are
`→ <store>/<file>.md`. Optional `stage` is non-empty if present. Use
`.records/records.sh new maps
--schema code-humanizer/map@1 --title "…"` when that tool is executable;
otherwise write the same four-key shape in file mode. Never write
`history.tsv` by hand.

## Not v1

Review, debugging, audit, and broad refactoring are outside this skill. Do not
stretch `mark` into identifier or API changes, helper extraction, file splits,
dependency changes, or behavioral repair.

## Project templates

none

## Edges

<!-- edges:code-humanizer -->
- produces: record — an optional stamped map snapshot under maps/ when the human asks to save
- handoff: — (none; mark edits source in place; map and walk inform)
- consumes: — (the repository working tree and git change are direct input, not a typed artifact)
<!-- /edges:code-humanizer -->

## Done when

For write-time, the authorized changed code follows the hierarchy, formatting
was handled or accounted for, applicable verification was completed or reported,
and no unrelated source was swept. For a named verb, that verb file's Done when.
