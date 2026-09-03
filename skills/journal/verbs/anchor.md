# `anchor` — point the project front door at the records layer

Add one optional, project-owned discovery section to repository-root `AGENTS.md`. Anchor is the only
Journal operation that writes a front-door pointer; setup, repair, migration, runtime, and curation
never install or require it.

1. Resolve `<root>` as the exact Git top level. For standalone custody, require
   `git status --porcelain=v1 -- AGENTS.md` to be empty; otherwise stop with
   `reason=commit-custody-required detail=AGENTS.md`. An announced sweep may proceed only when
   `AGENTS.md` is already an approved destination.
2. Run `scripts/records-anchor.sh preview --root <root>`. It derives readiness only from the public
   layer: safe ledger, exact executable provider, and current managed README block. It never
   inspects `.agents/skilldata`. Show the complete proposed `## Project records` section and obtain explicit
   confirmation. A literal `.records/README.md` mention is already satisfied; a conflicting heading
   or unsafe target refuses.
3. Run `scripts/records-anchor.sh apply --root <root> --confirmed`. Apply repeats preflight and
   refuses concurrent project edits. It creates or appends the marker-free section without changing
   existing bytes; the result becomes project-owned.
4. If the helper reports `wrote=AGENTS.md`, commit exactly that path with
   `scripts/scoped-commit.sh <root> "Add records layer pointer" AGENTS.md`, or return it to an
   announced sweep. A no-op makes no commit.

## Done when

The fixed guide was already named or the exact approved section was added; the records layer stayed
unchanged and standalone custody committed only `AGENTS.md`.
