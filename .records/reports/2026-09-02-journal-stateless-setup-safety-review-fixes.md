---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: [debugger, journal]
---

# Journal stateless setup safety review fixes

## Reproduction

Two disposable-project probes reproduced the review findings against `2cb02d4`:

- make `.records/locked/` unreadable while it contains an archived record and leave
  `history.tsv` absent; `records-layer-status.sh setup` reported `recovery_state=uninitialized`,
  and runtime stderr contained both a raw `find` error and its supposedly exact recovery route;
- use `JOURNAL_SETUP_TEST_AFTER_PREFLIGHT` to create or change `.records/README.md`; setup and
  repair exited successfully after replacing the concurrent project bytes.

## Root cause

The state classifier consumed `find` through process substitution, whose exit status is not the
status of the surrounding loop, and treated every failed record parse as a simple non-witness. The
reconciler rendered README output from preflight state but rechecked only the destination's file
kind before `mv`, not whether the absent/incumbent bytes it had inspected were still current.

## Evidence

Before the fix, the unreadable fixture returned exit 0 with `archived_witness=absent` while `find`
printed `Permission denied`. The two README fixtures returned exit 0, and the planted
`PROJECT_CONCURRENT_CANARY` was absent afterward. All three focused suites failed red before the
implementation changed.

## Fix + verification

The classifier now performs the setup-only archived crawl through a captured candidate file,
classifies traversal or read failure as unsafe, and skips that crawl for runtime and repair. The
reconciler snapshots README absence or bytes at preflight and repeats that proof immediately before
replacement, preserving concurrent changes with a deterministic refusal. Mutation fixtures now
red-prove the three ledger-loss branches, README-after-ledger ordering, and ledger/README custody.
The obsolete Skill Builder exception for retired Journal declarations was removed.

Verification: focused regressions, the complete Journal harness, ShellCheck, Bash syntax, Skill
Builder lint, Skill Creator validation, and the repository integration suite all passed.

## Findings

#### fail-closed-crawl — Absence requires a complete readable population

A negative recovery witness is trustworthy only when traversal and every candidate read complete
successfully. Process-substitution loops do not propagate the producer's exit status.

#### revalidate-owned-write — Preserve project bytes across preflight-to-write races

File-kind safety does not prove ownership or freshness. A reconciler that renders from an incumbent
must compare the same absent/byte snapshot immediately before replacement and refuse drift.

#### mutation-proof-safety-guards — Green guards need a demonstrated failing arm

Safety assertions around absence, ordering, and custody can remain green while production takes the
wrong branch. Mutating each load-bearing guard made the corresponding fixture observably fail.
