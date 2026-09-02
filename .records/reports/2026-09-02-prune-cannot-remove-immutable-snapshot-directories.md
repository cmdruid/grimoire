---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# Prune cannot remove immutable snapshot directories

## Reproduction

`RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_workflows` completes init, source review,
install, cached update, explicit fetch/update, uninstall, source removal, and trust revocation, then
reliably fails confirmed `store prune` with permission denied at the old snapshot's `SKILL.md`.

## Root cause

Materialization deliberately changes every snapshot directory to mode `0555`. Prune opens the
snapshot and its descendants descriptor-relatively, but `remove_tree_contents` never grants the
held directory owner-write permission before calling `unlinkat`. Removing a read-only file needs
write permission on its parent directory, so the first file removal fails even though the process
owns the immutable snapshot.

## Evidence

The failing path is a successfully materialized store snapshot and the error is `Permission denied
(os error 13)`. `store::assemble_contents` explicitly applies `0555` to every directory.
`prune::remove_tree_contents` opens and identity-checks each directory, then directly calls
`unlinkat` without changing that mode. Store repair's cleanup is the working semantic analog: it
first makes owned immutable directories removable, though prune must retain its stronger held-fd
and no-follow implementation.

## Fix + verification

After opening and identity-checking each owned snapshot directory, prune now uses descriptor-
relative `fchmod` to grant mode `0700` before recursively unlinking its contents. It does the same
for each verified child without following links or switching to path-recursive deletion. The core
fixture now makes its isolated snapshot tree immutable. The original CLI workflow, prune
race/security tests, the complete Slice 6 suite, and the workspace check all pass.

## Findings

#### held-directory-write-mode — Make verified immutable directories writable through held fds

Secure deletion of an owned immutable tree needs temporary write permission on every parent
directory. Apply that permission to the already-open, identity-checked descriptor so the existing
race and symlink guarantees remain intact.
