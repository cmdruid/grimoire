# GOTCHAS — traps that cost time

The running list of this project's traps — behavior that is working-as-coded but surprising, a
tool's sharp edge, a sequence that silently corrupts. Traps are **project-specific by nature**,
so this seed ships empty: entries accrue as the project surfaces them (a bug investigation that
ends "working as coded" captures a note; the review station lands it here).

Each entry is a heading `## G-<n>: <short title>` followed by three labeled lines —
`Symptom:` (what you observe), `Cause:` (why it happens), `Avoid:` (the rule that sidesteps it) —
and an optional `(seen: <date>, <ref>)` trailer citing where it last bit. Cite an entry from
anywhere as `G-<n>`. Retiring an entry (root cause fixed) is review-station work with a ledger
trace — never a silent deletion.
