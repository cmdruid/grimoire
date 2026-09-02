---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# Absent project world omits shared trust precondition

## Reproduction

`RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_reports` initializes global state, grants
global trust, then reliably fails `grimoire init` for a new project with
`plan is stale: trust appeared`.

## Root cause

`load_world` returns an absent `WorldState` before reading the user-global `trust.json`. The
initialization plan consequently records an absent trust precondition even when shared trust
already exists. Apply correctly observes the file and rejects the stale plan.

## Evidence

The failure occurs at project initialization immediately after the global trust grant. In
`world.rs`, the `(manifest=None, lock=None)` branch returns before the later trust read; in
`plan.rs`, `initialization_preconditions` derives trust directly from `world.trust_bytes`; and
`apply.rs` validates that precondition for every non-prune plan. Initialized project worlds are the
working analog: they read and validate the same shared trust file before planning.

## Fix + verification

`load_world` now reads and validates shared trust before the absent-scope branch and attaches those
exact bytes to the absent world. Initialization copies their hash into its trust precondition. The
new absent-world core regression, the original CLI workflow, Slice 5's exact suites, and the
workspace check all pass.

## Findings

#### shared-state-before-scope-return — Observe shared preconditions before absent-scope return

An absent manifest/lock pair does not imply shared trust is absent. Initialization must carry the
same trust observation and stale-plan protection as every other scope mutation.
