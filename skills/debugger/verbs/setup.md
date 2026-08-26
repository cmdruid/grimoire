# `setup [<root>]` — deploy active Debugger project assets

Run package-local `scripts/debugger-setup.sh <root>` for standalone setup, or add `--write-only`
when the caller has announced a larger configuration sweep. It deploys absent-only:

- `templates/bugs.md`
- `templates/investigation.md`
- `flows/diagnostics.md`

The deployer preflights the complete owned set and immediately rechecks parents before every write.
Valid incumbents stay byte-for-byte; the flow retains its `title` and `use-when` crawl keys.
Recognized legacy templates refuse and name `/debugger migrate <source-path>`. Standalone setup makes
one pathspec-scoped commit over exactly its reported writes; sweep mode is write-only and a no-op
rerun makes no commit. Never deploy schemas, record shells, package-only assets, or another owner.

Done when all three assets are present and valid and commit custody matches the invocation mode.
