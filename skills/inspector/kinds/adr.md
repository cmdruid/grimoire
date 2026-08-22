# Kind: adr

## Discriminator

Any of:

- `tags:` contains `adr`
- `doctype:` is `adr`
- shape: structural H2 set is Context / Decision / Alternatives
  / Consequences (ADR body)

Founding-shaped files do not match here.

## Soundness axes

Shared floor in `verbs/review.md`, plus:

- Decision follows from Context
- Alternatives are honestly weighed (rejected ones named)
- Consequences are stated, including the cost of the choice
- one decision per file

## Groundedness extras

None beyond ground-check + re-read. On a workshop host, check
against `core/` and live ADRs for contradiction.

## Refine legal locations

Context / Decision / Alternatives / Consequences. Do not mint a
successor ADR. A new decision that is not this ADR's subject →
**park**. A finding aimed at a feature spec's Mechanism or at
a job artifact → `push-back` (wrong owner).
