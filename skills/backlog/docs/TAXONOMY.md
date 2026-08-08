# Capture taxonomy — a pointer, not a schema

The record schema — the five capture kinds and their classifiers, the typed-ID namespace, the
per-store wire formats, the done log, the ticket schema with its escalation layer, and the report
wire contract — is stated **once**, in the pack doctrine's
`skills/clankshop/doctrine/rules/RECORDS.md`, and deployed to every installation as
`.handbook/rules/RECORDS.md` (the stamped projection this skill's
`scripts/records-projection.sh` writes — backlog is the sole schema-facing writer).

**The authority chain:** the doctrine states the schema → backlog executes it (capture, `done`,
tickets, curation) → `.handbook/rules/RECORDS.md` projects it into the installation. Nothing else restates
the schema; this file exists only so older citations of `docs/TAXONOMY.md` still resolve
somewhere that points at the real thing.

Read the schema in a deployed project at `.handbook/rules/RECORDS.md`; in this library, at
`skills/clankshop/doctrine/rules/RECORDS.md`.
