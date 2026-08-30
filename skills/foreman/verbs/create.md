# `create [procedure|workflow]` — author one operation

Create is a short curation walk, not a form wizard.

1. Resolve the intended use, shape, identity stem, areas, and tags. Default the shape from the
   work: one ordered walk is a procedure; an ordered composition of existing identities is a
   workflow. Ask only when the resulting artifact would differ.
2. Draft the complete `foreman/operation@1` file from package-only
   `templates/operation.md`. Status is `draft`; omit `verified-against`. A workflow uses Steps and
   exact identity references instead of Procedure.
3. Preview the destination `.spaces/foreman/operations/<stem>.md` and complete body.
   Explicit acceptance is required; a goal feature does not authorize inferred instruction.
4. Put the accepted candidate in ephemeral storage and run package-local
   `scripts/operation-write.sh put --root <root> --identity
   foreman/<stem> --candidate <file>`.

The writer validates reference closure and owner custody, preserves an identical incumbent, and
refuses a conflict. Create no doctrine, route, runtime state, or catalog snapshot.
