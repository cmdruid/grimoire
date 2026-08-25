# `migrate <source-path>` — upgrade Contractor artifacts

The argument selects one source file or directory tree; canonical records remain in
`<agent-records>/plans/` and active templates in `<agent-workspace>/contractor/templates/`.

Inventory stably and own only a `doctype: plans` record with exactly one writer-kind tag (`plan`,
`roadmap`, or `runbook`) or active `plan.md`/`roadmap.md` templates. Preserve optional non-empty
`stage` and all legal extra metadata. Map the kind to `contractor/plan@1`,
`contractor/roadmap@1`, or `contractor/runbook@1`; an unknown declared schema refuses. A schema-less
legacy record must have `created` equal to its filename date before that key and all other retired
generic history keys are removed. Preserve authored body bytes.

Recognize previous-home and registered flat template locations only through this verb. Strip a
legacy record shell, move active templates to the canonical workspace home, and retire generic
`plans.md`: stock content may be removed after preview; customized content refuses until the caller
maps it explicitly to `plan.md` or `roadmap.md`. Runbooks have no project template.

Use the shared migration transaction: reject symlinks/out-of-project paths, preview every source,
kind, schema, destination and change, confirm writes, stage and validate the entire batch, then
write `.contractor-migrate-manifest` with ordered components, before/staged checksums, and phase.
Resume forward before requiring the source; `absent` is the completed deletion state, any third
byte state refuses, and a selected directory is never removed. Identity moves go through staged
Journal `records.sh relocate` so ledger rows and internal links follow; external exact references
block. Re-inventory and report `changes=0`; an ordinary rerun must do the same without confirmation.

## Done when

Every selected owned artifact validates under its Contractor schema, active templates are canonical,
no foreign record changed, no manifest remains, and replay reports `changes=0`.
