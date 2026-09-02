---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# CLI boundary scanner confuses symlink inspection with creation

## Reproduction

`RUSTC_WRAPPER= cargo test -p skill-grimoire --test boundary` fails
`adapter_and_core_ownership_boundaries_are_explicit`. The scanner reports
`crates/grimoire/src/runtime.rs` for the rule `adapter creates managed links`.

## Root cause

The new static boundary rule searches for the unqualified substring `symlink(`. That substring is
also the suffix of the read-only metadata predicate `is_symlink()`, so the scanner conflates
inspection with link creation.

## Evidence

The only match in app production source is
`metadata.file_type().is_symlink()` in `verify_bare_cache`. The surrounding function reads Git
cache metadata and rejects symlink entries; it does not call a filesystem mutation API. The other
managed-write rules qualify their APIs (`fs::write`, `File::create`, `OpenOptions::new`), which is
the working pattern this one rule failed to follow. The controlled scanner arm passes separately,
showing that the scan mechanism is live and the defect is isolated to this needle.

## Fix + verification

Qualified the link-creation needle as `fs::symlink(` while retaining the boundary test as the red
reproduction. The boundary, confirmation, exit, and grammar tests pass, and the original hard-cut
search returns no matches.

## Findings

#### qualify-static-api-needles — Qualify mutation API needles in static boundary tests

Static source checks for mutating APIs should include enough namespace or call-site syntax to avoid
matching read-only predicates whose names merely end with the same substring.
