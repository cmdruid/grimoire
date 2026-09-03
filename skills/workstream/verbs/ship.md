# `ship [--prepare]` — prepare and deliver one shipment

Bare `ship` authorizes reversible preparation and the reported landing. `ship --prepare`
authorizes preparation only.

1. Invoke `workstream.sh ROOT ship-prepare STREAM`. It allocates or resumes one shipment and
   immutable unit batch, syncs as needed, commits one row per unit to `.streams/history.tsv` on the
   stream branch, and proves changed gitlinks. A missing object, conflict, or uncertain receipt
   blocks without target mutation.
2. At `phase=gate`, select the host's documented gate for the final changed paths. Invoke only
   `gate-run --class docs|full --label LABEL -- ARGV...` or
   `gate-run --class semantic --selector --label LABEL -- ARGV...`. Don't invent a command. Failed
   or stale evidence must be remediated and rerun.
3. If preparation reports friction, resolve the `ship-friction` receipt through `hook-start` and
   `hook-complete`. Commit and validate tracked hook effects, then rerun `ship-prepare`; changed
   effects return to the gate under the same shipment and hook identity.
4. When the helper reports `ready-to-land`, stop if `--prepare`. Confirm that the readiness facts
   still match. For bare `ship`, pass the current invocation's ephemeral authority to the helper's
   guarded local advance. For a documented PR path, record `pr-await` only after the authorized
   push/create-or-update and use `pr-verify` after merge. Never force a ref.
5. At postflight, verify the observed destination and invoke `ship-finalize STREAM`, optionally
   with one operator note. Finalization clears the completed transaction atomically and doesn't
   create a tracked commit or hook.

If delivery is partial, retain the shipment. Follow `delivery-classify`; use two-parent
`reconcile-partial` only for its exact verified divergent-tip case, then re-gate and retry. An
uncertain mutation is never replayed on the assumption that it failed.

Done when `--prepare` returns readiness without a ref change, or bare ship reports finalized
delivery.
