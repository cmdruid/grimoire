# `resume` — explicitly read and claim the root checkpoint

`resume` accepts no argument. The generic **Resume discipline** in `references/disciplines.md` is
read-only; Checkpoint adds a separate identity-only claim after human confirmation.

1. Resolve the root and run `scripts/checkpoint-file.sh inspect <root>`. The helper refuses before
   body disclosure unless the target is the exact untracked, ignored, regular non-symlink root file
   with a valid title and token. Only `checkpoint_valid=true` admits the emitted body. Retain its
   token and opaque fingerprint.
2. Load the body in full, reconcile it against durable evidence, report staleness or already-landed
   work, and echo at most its one suggested first action. Do not emit an ownership handle yet. Wait
   for human confirmation.
3. On confirmation, call
   `scripts/checkpoint-file.sh claim <root> <read-token> <read-fingerprint>`. This transaction
   requires the file to be unchanged, rotates only its token, and emits the new stable handle. A
   changed file refuses and requires Resume to restart. Rejection leaves the file unchanged.
4. After a successful claim, continue from the reconciled action. A later content refresh is a
   separate `save`; already-landed work routes to `done` instead of ghost continuation.

**Done when:** the validated body was reconciled, the human confirmed, the identity-only claim
rotated the token, and the new handle was reported—or the process refused without taking custody.
