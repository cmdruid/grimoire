# `setup` — reconcile the global data home

Run package-local `scripts/feedback.sh init`. This is the only setup operation: do not inspect or
write global instructions, projects, installed bytes, predecessor feedback or routes, or sibling
skilldata directories.

On `status=ready`, stop. On refusal, pass through the provider's single recovery diagnostic rather
than repairing malformed data or guessing ownership.

Done when the owned directory and TSV are valid with restrictive permissions, or an unsafe or
ambiguous incumbent was left unchanged with an actionable diagnostic.
