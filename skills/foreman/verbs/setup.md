# `setup [<root>]` — register Foreman's route

Resolve `<root>` and `.spaces`. Run package-local `scripts/foreman-door.sh check` first.
If the route is current, report a no-op. Otherwise preview the exact bounded span and run `apply`
after authorization.

When `AGENTS.md` is absent, explain that setup can create a minimal front door containing only the
Foreman span and pass `--allow-create` only after the user explicitly accepts that file creation.
A `CLAUDE.md`-only project or malformed delimiters refuse for manual reconciliation.

Setup never creates `.spaces/foreman/operations/`, doctrine, a catalog snapshot, or a
project copy of the bundled templates. Inside this library, exercise setup only against a disposable
fixture; never register Foreman in grimoire's real front door.
