# PIPELINE — CI/CD, from push to shipped

<!-- spine-doc v1
kind: testing
doctrine: clankshop
doctrine-version: 1
refs: .handbook/**
-->

The continuous-integration and delivery story: what runs where, on which trigger, and what a
failure at each stage means. This seed is a skeleton; the verification steward fills and tends it.
A project with no CI leaves the stages table at its one local row — that is a valid fill, not a
gap.

## Stages

| stage | trigger | runs | on red |
|---|---|---|---|
| local gate | before every commit | `<gate>` | fix before committing (INV-1) |
| `<CI stage — e.g. PR checks>` | `<push / PR>` | `<command / workflow>` | `<who looks, where the logs are>` |
| `<delivery stage — e.g. release, deploy>` | `<tag / merge to trunk>` | `<command / workflow>` | `<rollback story>` |

## Artifacts and environments

`<what the pipeline produces (packages, images, site builds), where they land, and which
environments exist. Empty until filled.>`

## Local ↔ CI parity

`<what CI runs that the local gate does not (and why), so a green local run's residual risk is a
known quantity. Ideally: nothing.>`
