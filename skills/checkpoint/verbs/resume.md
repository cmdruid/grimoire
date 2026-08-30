# `resume` — explicitly read and claim the root checkpoint

`resume` accepts no argument. The generic **Resume discipline** in `references/disciplines.md` is
read-only; Checkpoint's explicit invocation authorizes its identity-only custody claim.

1. Resolve the root and run `scripts/checkpoint-file.sh inspect <root>`. The helper refuses before
   body disclosure unless the target is the exact untracked, ignored, regular non-symlink root file
   with a valid title and token. Only `checkpoint_valid=true` admits the emitted body. Retain its
   token and opaque fingerprint.
2. Load the body in full and reconcile it against durable evidence. Report staleness or
   already-landed work neutrally and retain the single suggested first action. Invocation authorizes
   the identity-only claim; there is no second confirmation turn.
3. Call
   `scripts/checkpoint-file.sh claim <root> <read-token> <read-fingerprint>`. This transaction
   requires the file to be unchanged, rotates only its token, and emits the new stable handle. A
   changed file refuses and requires Resume to restart.
4. After a successful claim, report the new handle and reconciled next action, then continue when
   the action is KNOWN. If two live continuations remain plausible, ask only after the new stable
   handle exists. A later content refresh is a separate Save. Already-landed work remains enrolled
   and does not infer or suggest closure.

**Done when:** the validated body was reconciled, the identity-only claim rotated the token, and the
new handle and action were reported—or the process refused without taking custody.
