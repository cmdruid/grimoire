# Specification brief

You are reviewing the specification or design document that is
your target. Read that file, then only the paths it cites.

## Judge

- **Soundness** — internally consistent; mechanism implementable
  as written; every requirement unambiguous; scope is one
  artifact.
- **Groundedness** — claims match the files they cite (path
  exists; quote or `file:line` is the code or prose claimed).
- **Holes** — open decision branches presented as settled;
  missing failure states; verification that cannot go red.
- **Scope** — a spec, not a sequenced plan or multi-phase
  conductor.
- **Output shape** — if it specifies an output or baton, is that
  shape frozen enough to implement from?

If the document carries a `founding` tag, also: mapped sections
that are empty vs leftover headings that do not belong.

## Do not

- Restate the spec.
- Rank anything.
- Propose a rewrite of the whole document. Emit discrete claims.
- Run a lint or mechanical gate.
- Tag claims with seat letters.
- Review a diff or a source tree this document is not.
