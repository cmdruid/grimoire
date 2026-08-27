# `run <owner/stem>` — follow one operation

This is an attended walk in the calling context. It creates no runtime state.

1. Require one exact identity. If the request is topical, use `inventory` first and resolve one
   operation before reading a body.
2. Run package-local `scripts/operation-check.sh --root <root> --workspace <relative> --operation
   <owner/stem>`. Refuse malformed, missing, or cyclic operations.
3. Surface imported-source drift and stale verification. A named draft may run only after a concise
   warning. A deprecated operation requires explicit confirmation.
4. Read the selected operation in full. For a procedure, follow its Procedure in order. For a
   workflow, resolve each referenced identity in written order and recurse through the same check.
5. Respect each operation's Preconditions, Verification, and Recovery. Stop for user authority or a
   genuine decision; an operation is instruction, not tool permission.
6. Return the completed work, evidence, and exact next action. Do not write a Foreman progress file.
