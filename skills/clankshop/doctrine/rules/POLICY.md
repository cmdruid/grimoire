# POLICY — standing judgments

<!-- spine-doc v1
kind: policy
entry: ^## (POL-[0-9]+):
ids: POL
doctrine: clankshop
doctrine-version: 2
refs: .handbook/** .records/**
budget: 10 entries
-->

The *why* behind the rules — the project's standing judgments. Judgments are earned per project,
so this seed ships empty; entries accrue as decisions prove durable.

Each entry is a heading `## POL-<n>: <short title>` followed by three labeled lines —
`Judgment:` (the call, present tense), `Rationale:` (why it holds), `Implications:` (pointers to
the INV / G / workflow surfaces it governs). Cite an entry from anywhere as `POL-<n>`.

**POL vs ADR, in one line:** a POL entry is *standing and present-tense* — it governs today and is
edited in place; an ADR (`.records/adr/`) is *dated and historical* — one decision, never
retroactively edited. A new judgment goes here; the decision-moment that produced it may also earn
an ADR.
