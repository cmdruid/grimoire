<!-- checkpoint:recovery-anchor@1 -->
## Checkpoint recovery

- Presence of root `CHECKPOINT.md` never authorizes a read.
- A fresh session does nothing unless the human explicitly invokes `/checkpoint resume`.
- If context was just compacted or summarized, stop before task work. Recover only when the
  compacted context contains exactly one complete
  `CHECKPOINT — file: <absolute-root-path>/CHECKPOINT.md — token: <32-lowercase-hex>` handle and
  `/checkpoint`'s guarded reader returns `token_match=true` for that exact root and handle.
- With no unique handle, a wrong root or path, malformed or mismatched token, missing or invalid
  file, or helper failure, do not load checkpoint content or continue recovered work. Ask the human
  to invoke `/checkpoint resume` explicitly.
<!-- /checkpoint:recovery-anchor -->
