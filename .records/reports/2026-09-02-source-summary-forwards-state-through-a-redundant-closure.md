---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# Source summary forwards state through a redundant closure

## Reproduction

`RUSTC_WRAPPER= cargo clippy --workspace --all-targets -- -D warnings` fails with
`clippy::redundant-closure` at `crates/grimoire-core/src/source/query.rs:186`.

## Root cause

`Option::and_then` receives a closure whose sole operation is calling `state_receipt` with the same
borrowed `SourceState`. The closure adds no conversion, capture, or ownership behavior, so clippy
correctly rejects it under the repository's warnings-denied policy.

## Evidence

The full expression is `candidate.and_then(|state| state_receipt(state))`; `candidate` is
`Option<&SourceState>` and `state_receipt` accepts `&SourceState`, so their signatures align
directly. Working analogs in the same crate pass method/function items such as `Path::parent` and
`Item::as_str` straight to `and_then`. Git blame traces the closure to Phase 5 Slice 2 rather than
an unrelated pre-existing line.

## Fix + verification

Replaced the forwarding closure with `candidate.and_then(state_receipt)`. The Phase 5 source and
trust adapter tests pass, and the complete warnings-denied workspace clippy gate is green.

## Findings

#### direct-option-function — Prefer direct function items for exact Option adapters

When an `Option` combinator's input type already matches a helper function, pass the helper
directly so the warnings-denied gate does not reject a behavior-free forwarding closure.
