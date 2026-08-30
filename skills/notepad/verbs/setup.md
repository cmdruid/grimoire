# `setup [<root>]` — deploy the active notes template

1. Resolve `<root>` from the argument, else the current Git top level. Templates live only at
   `.spaces/notepad/templates/`; `.records` is consulted only for recognized legacy templates.
2. For a standalone invocation, run package-local `scripts/notepad-setup.sh <root>`. It preflights
   the complete owned write set, immediately rechecks parents, deploys only
   `.spaces/notepad/templates/notes.md` when absent, and makes one pathspec-scoped commit
   over exactly that reported write. A valid incumbent is preserved byte-for-byte; a no-op rerun
   makes no commit.
3. When the caller has announced a larger configuration sweep, run
   `scripts/notepad-setup.sh --write-only <root>`. Do not commit; return the script's owner-specific
   report so the caller can derive one approved aggregate path set from Git.
4. A recognized legacy copy refuses and names `/notepad migrate <source-path>`. Never deploy a
   schema, package-only file, sibling namespace, or records-layer artifact.

Done when `notes.md` was deployed and committed alone, was deployed write-only for its caller, or a
valid incumbent was preserved with zero writes and zero commits.
