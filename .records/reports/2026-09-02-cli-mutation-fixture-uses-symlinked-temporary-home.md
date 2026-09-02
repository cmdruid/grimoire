---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# CLI mutation fixture uses symlinked temporary home

## Reproduction

`RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_mutations
install_update_frozen_and_uninstall_share_the_transaction_path -- --nocapture` fails reliably at
the first pack install with `plan is stale: store snapshot for fixture changed`.

## Root cause

The new CLI test passes `tempfile::TempDir::path()` directly as `HOME`. On macOS that spelling is
under `/var/folders/...`, where `/var` is a symlink to `/private/var`. Materialization succeeds at
that lexical path, but the subsequent immutable-store scan uses `HeldDirectoryReader`, whose
descriptor-relative boundary deliberately rejects symlinked ancestors. The store is therefore
classified as corrupt and stale-plan protection stops the transaction.

## Evidence

A temporary diagnostic at the store-validation boundary reported
`expected=Absent required=Valid observed=Corrupt`; a second probe exposed the underlying scan error
as `I/O failure at /var: Not a directory (os error 20)`. Both probes were removed. The established
working analog in `crates/grimoire-core/tests/apply_matrix.rs` canonicalizes the temporary root
before deriving project, home, and source paths, producing `/private/var/...` and passing the same
materialize-then-scan sequence.

## Fix + verification

The existing failing CLI test now canonicalizes the temporary fixture root before deriving its
`home`, `project`, and `source` paths. Descriptor-relative store traversal and the product contract
remain unchanged. The test advanced beyond initial pack installation; after the separate update
planner defect was corrected, the full scenario, Slice 4's exact core/app tests, and the workspace
check all passed.

## Findings

#### canonical-temp-root — Canonicalize macOS temporary roots in held-directory fixtures

Fixtures that exercise descriptor-relative source or store readers must canonicalize macOS
temporary roots before constructing application paths; otherwise `/var` introduces a symlinked
ancestor that the security boundary correctly rejects.
