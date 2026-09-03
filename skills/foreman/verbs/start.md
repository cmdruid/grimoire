# `start [--as <stem>] <objective>` — publish first use in one acceptance

Use this route when the objective needs a new Foreman operation and a durable goal. It combines
publication only; execution still belongs to the harness and its ordinary runtime-state owner.
`/foreman setup` is optional and only registers the discovery route; it is not a publication floor.

1. Search project operations first. If a same-purpose operation exists, offer its normal goal path.
   Otherwise follow `verbs/create.md` through metadata-only global suggestions, explicit template
   selection or the bundled scaffold, and full project-specific curation. A selected global body is
   inert input and is never named in the resulting operation.
2. If `--as` is absent, derive a lowercase hyphenated stem from the objective. Ask only when an
   identity choice or an incumbent conflict would change the artifact. Otherwise include
   `foreman/<stem>` in the joint preview; do not spend a separate confirmation on the derived name.
3. Put the complete draft operation in ephemeral storage. It must omit `verified-against`. Run
   package-local `scripts/goal-start.sh render` with that candidate, the resolved identity, and the
   exact objective. The helper chooses the dated goal destination once and emits an exact draft
   goal, four-line manifest, and `sha256:` preview digest without writing the project.
4. Show one publication preview containing the complete resolved operation and destination, exact
   goal record destination and content, exact manifest, and preview digest. One explicit acceptance
   authorizes only this bundle. Pass only that accepted digest to `goal-start.sh apply`; never
   regenerate the date, identity, operation, goal, or manifest after acceptance.
5. Confirm that both durable files exist with the accepted bytes. Only then invoke the harness goal
   with exactly:
   `Pursue the published runbook at <goal-record>. Resume with /foreman goal resume <goal-record>.`
   If the harness has no goal feature, return that exact ready-to-submit objective and do not claim
   pursuit began. Do not create `CHECKPOINT.md`; the harness and `/checkpoint` retain lazy runtime
   ownership.

After the attended run, review compact verification evidence. If the provisional root is still a
draft, preview the exact evidence, canonical operation digest, raw operation and evidence hashes,
and the single `draft` to `active` replacement. A separate explicit acceptance authorizes
`scripts/operation-write.sh promote`. The helper binds verification, evidence, and status in one atomic replacement.
Once the root is active, do not offer promotion again; goal close performs only
its ordinary runtime and records cleanup.
