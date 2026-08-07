# GOTCHAS — traps that cost time

<!-- spine-doc v1
kind: gotchas
entry: ^## (G-[0-9]+):
ids: G
doctrine: clankshop
doctrine-version: 1
refs: .handbook/** .records/**
budget: 20 entries
exclude: archive/**
-->

The running list of this project's traps — behavior that is working-as-coded but surprising, a
tool's sharp edge, a sequence that silently corrupts. Traps are **project-specific by nature**, so
this seed ships empty: entries accrue as the project surfaces them (a bug investigation that ends
"working as coded" captures a note; the improvement loop lands it here).

Each entry is a heading `## G-<n>: <short title>` followed by three labeled lines —
`Symptom:` (what you observe), `Cause:` (why it happens), `Avoid:` (the rule that sidesteps it) —
and an optional `(seen: <date>, <ref>)` trailer citing where it last bit. Cite an entry from
anywhere as `G-<n>`. Retiring an entry (root cause fixed) is improvement-loop work, recorded in
the run log — never a silent deletion.
