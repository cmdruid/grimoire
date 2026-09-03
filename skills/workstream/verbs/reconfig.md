# `reconfig [<stream>]` — adopt current Workstream configuration

Resolve the stream without entering a foreign session. Inside a stream, the omitted name means the
current stream; from the root, require the name. Invoke `workstream.sh` with the canonical primary
root and `reconfig <stream>`, optionally followed by `--mode`, `--landing`, or `--ship-cadence`.
Repeat `--inherit mode|landing|ship-cadence` to return an explicit value to project or bundled
defaults. Supplying an explicit value and `--inherit` for the same field refuses.

Reconfig requires clean tracked work, stable Git custody, and no running hook. It validates the
current project `CONFIG.md`, refuses an isolation change, previews the old and new contract hashes,
and replaces only the compiled policy and hook spans. The runbook's purpose, coordinates,
orientation, operator note, and project prose remain unchanged. Existing receipts retain their
original hook fingerprints; only identities that haven't started use the new body.

The helper uses a pending contract hash to recover either side of an interrupted two-file update.
On a refusal, don't edit `workstream.tsv`; rerun `reconfig` after resolving the reported config,
custody, or worktree condition.

Done when the helper reports `applied` or `unchanged` and ordinary `read` admits the stream.
