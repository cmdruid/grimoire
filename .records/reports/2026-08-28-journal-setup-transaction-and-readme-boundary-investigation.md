---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: [journal, setup, repair]
---

# Journal setup transaction and README boundary investigation

## Reproduction

Two throwaway-project reproducers exercised the reviewed implementation at its actual boundaries:

1. A copied `standup.sh` exited immediately after each provider, ledger, README, or legacy-path
   destination commit and before post-write bookkeeping. On resume, the changed path was absent from
   the transaction's `wrote:` union.
2. An initialized records README ended with unowned `TAIL_CANARY` bytes and no final newline. After
   the managed block was made stale, `/journal repair` refreshed the block and changed the final byte
   from `Y` (`89`) to newline (`10`).

## Root cause

Setup changed each destination before atomically recording its path, leaving an unavoidable crash
window between two independently durable files. The README renderer reconstructed every line through
`awk`, whose `print` supplied a newline after an unowned final record that originally had none.

## Evidence

The commit-point reproducer left a valid adjacent provider but no corresponding completed entry;
the unmodified resume reported only the later ledger and README paths. The README reproducer's byte
probe measured `89` before refresh and `10` afterward. Existing tests stopped only after bookkeeping
and checked unowned prose by content rather than byte equality, so both defects survived otherwise
green suites.

## Fix + verification

The setup intent now holds exactly one empty-or-path `pending=` field. Setup checkpoints the pending
path before a destination commit, promotes it to `completed=` only after the postcondition holds, and
reports only completed paths. Resume can therefore promote a finished commit or execute an unfinished
one without losing custody or falsely reporting a pending path on refusal.

README reconciliation now removes only the newline synthesized after an unowned final record; both
managed-block refresh and exact legacy-pointer replacement have byte-level EOF regressions. Counted
marker-parser mutations also prove the duplicate, nested, reversed, and unmatched refusal fixtures.

Verification passed: Journal's `standup`, transaction, repair, contract, and records suites; the
consuming Clankshop configuration test; repository integration; every affected owner suite;
Skill-builder lint (`fails=0`, four known orphan-edge warnings); system skill validation; ShellCheck
for `standup.sh`; and `git diff --check`.

## Findings

#### setup-transaction-custody — Destination commits require durable pending state

Post-write bookkeeping cannot close the crash window between independently durable destination and
intent files. A single pending step in the intent supplies write-ahead custody without broadening the
setup write set. Consumed by the Journal durable-setup spec, implementation plan, helper, and
commit-point regression matrix.

#### readme-unowned-eof — Line renderers must preserve the unowned EOF byte

Content-presence assertions do not prove a managed-span renderer preserved project-owned bytes. The
managed-block and legacy-pointer fixtures now retain a recognizable suffix without a final newline
and compare its bytes after reconciliation. Consumed by the shared README renderer and its setup and
repair regressions.
