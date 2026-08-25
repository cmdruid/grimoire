# `setup` — deploy Backlog explicitly

1. Resolve `<root>` and repo-relative `<workspace>` per `SKILL.md`.
2. Run bundled `scripts/backlog-setup.sh <root> --workspace <workspace> --list`; present the
   builtin suggestions and ask which to enable unless the invocation already names stems.
3. Run `scripts/backlog-setup.sh <root> --workspace <workspace> --apply <builtin-stems...>
   [--custom <custom-stems...>]`. Builtins use their suggestions; custom names receive stubs for
   the caller to author before commit.
4. Parse every unique `wrote=` / `removed=` path. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; empty → no commit.

Done when the staged engine is current, every selected builtin has both components, Backlog's
route block is present when a tracker exists, and one scoped commit contains every changed path.
