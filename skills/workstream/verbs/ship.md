# `ship [--prepare]` — prepare and deliver one shipment

Bare `ship` authorizes reversible preparation and the reported landing. `ship --prepare`
authorizes preparation only.

1. Invoke `workstream.sh ROOT ship-prepare STREAM`. It allocates or resumes one shipment and
   immutable unit batch, syncs as needed, commits one row per unit to `.streams/history.tsv` on the
   stream branch, and proves changed gitlinks from that worktree. It never prepares a
   primary-checkout submodule. A missing object, conflict, or uncertain receipt blocks without
   target mutation.
2. At `phase=gate`, select the host's documented gate for the final changed paths. Invoke only
   `gate-run --class docs|full --label LABEL -- ARGV...` or
   `gate-run --class semantic --selector --label LABEL -- ARGV...`. Use `gate-none` only when the
   helper proves there is no build-relevant own path. Don't invent a command. Failed or stale
   evidence must be remediated and rerun.
3. If preparation reports friction, resolve the `ship-friction` receipt through `hook-start` and
   `hook-complete`. Commit and validate tracked hook effects, then rerun `ship-prepare`; changed
   effects return to the gate under the same shipment and hook identity.
4. When the helper reports `ready-to-land`, stop if `--prepare`. Confirm that the readiness facts
   still match. For bare `ship`, pass the current invocation's ephemeral authority to
   `land-advance`. It leases and admits the primary checkout, requires complete cleanliness and no
   interrupted Git operation, transfers changed gitlink objects there, and fast-forwards it once.
   Push then publishes from the stream worktree while retaining that lease. Never force a ref.
5. For a documented PR path, publish/create-or-update from the stream worktree and record
   `pr-await`. After merge, `pr-verify` records only the observed remote target and leaves
   `next_action=postflight`; it does not touch the primary. With authority from the same bare
   `ship`, or fresh explicit authority after context loss, invoke `land-advance` again to lease and
   synchronize that guarded primary endpoint. Mechanical contention does not consume same-session
   authority.
6. At landed postflight, invoke `ship-finalize STREAM`, optionally with one operator note.
   Finalization requires the advanced local-target receipt, clears the completed transaction
   atomically, and doesn't create a tracked commit or hook. Dirty, wrong-branch, interrupted, or
   busy primary admission leaves PR postflight active and cannot finalize.

If delivery is partial, retain the shipment. Follow `delivery-classify`; use two-parent
`reconcile-partial` only for its exact verified divergent-tip case, then re-gate and retry. An
uncertain mutation is never replayed on the assumption that it failed.

Done when `--prepare` returns readiness without a ref change, or bare ship reports finalized
delivery.
