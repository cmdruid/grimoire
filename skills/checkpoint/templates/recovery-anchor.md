<!-- checkpoint:recovery-anchor@2 -->
## Checkpoint lifecycle and recovery

- This anchor and the presence of `CHECKPOINT.md` never enroll a session. Enrollment begins only
  through successful explicit `/checkpoint save`, `/checkpoint resume`, or token-matched Recovery.
- An enrolled session refreshes after a human-visible work unit, before a healthy reset, and on a
  context-pressure warning. Each refresh reports the complete handle and next action without
  requesting a response. Never save a polluted context. The lifecycle never infers that work is
  complete or suggests closure. Enrollment ends only through explicit `/checkpoint close`.
- Absent an explicit Checkpoint verb, a fresh or compacted session without a complete stable handle
  for this root receives no Checkpoint behavior and never reads the file.
- After compaction with exactly one complete handle for this root, use Checkpoint's guarded reader.
  On a match, read in full and reconcile using: committed or external systems of record, then current
  files, then checkpoint, then compaction summary. Report the unchanged handle and next action,
  write nothing, and continue when unambiguous.
- On a token or identity mismatch, stop without disclosing checkpoint content and tell the user
  Recovery failed.
<!-- /checkpoint:recovery-anchor -->
