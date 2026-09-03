# `setup` — reconcile the global data home

Run package-local `scripts/feedback.sh init`. It is the only setup operation: do not inspect or
write global instructions, projects, installed package bytes, legacy feedback files, or sibling
skilldata directories.

On `status=ready`, stop. On refusal, pass through the provider's single recovery diagnostic rather
than repairing malformed data or guessing ownership.

Done when the owned directory and TSV are valid with restrictive permissions, or the unsafe or
ambiguous incumbent was left unchanged with an actionable diagnostic.
