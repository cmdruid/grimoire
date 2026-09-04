# `create <stream> [<source-or-brief>] [policy options]` — create and enter a stream

Run this only from a session that isn't already driving a stream. Resolve the canonical primary
root and its current integration-target branch. A plan or roadmap source must be a tracked regular
file at `HEAD`; pass its kind and root-relative path as `--source-kind plan|roadmap --cursor PATH`.
Otherwise treat the argument as a bounded inline brief. If the user explicitly asks
for the package's debug or design intake, read only `templates/debug.md` or
`templates/design.md` and reduce its durable mission and pointers to the bounded brief. Omission
means an ad hoc intake whose first unit is not yet defined.

Accept explicit `--mode` and `--landing` choices. Pass only choices the user supplied; they
override project defaults, which override bundled defaults. Invoke the effective helper:

```text
workstream.sh CHECKOUT runtime-init STREAM TARGET BRIEF [--source-kind KIND --cursor PATH] [POLICY OPTIONS]
```

The helper validates configuration, secure instance entropy, exclusions, target ancestry, branch
absence, and the exact `.streams/STREAM` worktree coordinate before creating anything. Every
successful stream is registered there on `stream/STREAM`. Entropy or admission failure leaves no
ref, worktree, path, or runtime byte. A retry of the same admitted instance returns `existing` and
preserves its ID.

Call `read STREAM`. If `next_action=define-unit`, determine one coherent unit from the source or ask
only when the brief is genuinely ambiguous. Start it with `unit-begin STREAM SLUG SUMMARY`, then
continue the runtime loop. The explicit create invocation already authorizes this first known
action; don't ask for redundant confirmation.

For an explicit request to seed a stream for another session, stop after creation and return
`/workstream load STREAM`. Never seed a tangent or enter a second stream yourself.

Done when the new session has one admitted stream and one known action, or the seed-only handoff is
returned.
