# `query` — inspect global feedback without mutation

Accept an optional exact skill slug, `--status open|resolved`, and `--limit N` from 1 through 100.
Default to the 20 newest open rows. Invoke package-local `scripts/feedback.sh query` with
`--order newest --format human`; do not parse or read the TSV directly.

Use TSV output only when the caller explicitly requests machine-readable rows. Include
`project_ref` only when that same request explicitly authorizes both `--format tsv` and
`--include-project-ref`; never expose it in ordinary human output.

Done when one validated bounded page or one provider diagnostic was returned without mutation.
