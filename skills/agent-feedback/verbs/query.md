# `query` — inspect global feedback without mutation

Pass only the provider's declared filters through to package-local `scripts/feedback.sh query`:
`--origin agent|human`, `--subject-type skill|agent|harness|tool|workflow`, `--subject <slug>`,
`--status open|closed`, `--limit 1..100`, `--order newest|oldest`, and `--format human|tsv`.
The provider defaults to the 20 newest open rows. Do not add defaults, parse the TSV directly, or add
a count trailer.

Pass `--include-project-ref` only when the caller explicitly requests it together with
`--format tsv`; ordinary human and TSV output omit project provenance.

Done when the provider's validated bounded page or single diagnostic was returned unchanged and no
mutation occurred.
