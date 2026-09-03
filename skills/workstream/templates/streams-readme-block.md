<!-- workstream:control@1 -->
# Workstream control surface

`CONFIG.md` defines defaults and lifecycle hooks for streams created after configuration. The
executable `workstream.sh` exclusively validates and mutates ignored per-stream runtime state.
`history.tsv` is the concise landed-unit ledger. Immediate child directories are ignored registered
stream worktrees; do not copy or nest them. Landing follows each stream's compiled policy and
synchronizes the clean primary checkout through the runtime helper's repository lease.
<!-- /workstream:control@1 -->
