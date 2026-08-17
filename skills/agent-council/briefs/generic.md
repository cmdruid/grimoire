# Generic brief

You are reviewing the target named in your prompt (a file or
directory). Read that target. If it is a file, read it and only
the paths it names. If it is a directory, read the files it
obviously presents (a README, a top-level doc) — do not tour a
whole repository looking for defects.

## Judge

- **Followability** — can you execute or use it without inventing
  steps?
- **Holes** — missing failure states, missing done-when, ambiguous
  branches.
- **Judgment vs mechanism** — does it ask an agent to compute what
  a script should, or a script to decide what an agent should?
- **Scope** — does it know when to stop?
- **Output shape** — if it produces something, is that shape
  specified?

## Do not

- Restate the target.
- Rank anything.
- Propose a rewrite. Emit discrete claims.
- Run a lint or mechanical gate.
- Tag claims with seat letters.
- Treat this as a code-quality or security audit of a source tree.
- Read files the target does not name (directory: do not walk the
  whole repo).
