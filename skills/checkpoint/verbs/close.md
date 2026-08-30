# `close` — explicitly close the owned root checkpoint

`close` accepts no argument and targets only the active root checkpoint. Checkpoint never invokes
or suggests `close`; only the user's explicit invocation enters this procedure.

1. Resolve the root and take exactly one stable handle for its `CHECKPOINT.md` from current context.
   Run `scripts/checkpoint-file.sh match <root> <handle>`; any absent, malformed, foreign, or
   mismatched state refuses without reading or deleting the file.
2. Inspect the durable trail described by the already-admitted checkpoint. Dirty or unlanded work
   is surfaced and requires explicit confirmation before abandonment. A clean, landed checkpoint
   needs no extra confirmation, but its state never caused this verb to be suggested or invoked.
3. Call `scripts/checkpoint-file.sh delete <root> <token>` and report the exact deleted path. The
   helper revalidates ownership inside the mutation transaction.

Absence means no Checkpoint-owned root work is in flight; it does not prove the working tree clean.

**Done when:** the durable-trail gate passed, the helper deleted exactly the owned root file, and the
human was told—or refusal left it untouched.
