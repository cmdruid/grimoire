# `setup [<root>]` — deploy active Architect templates

Run package-local `scripts/architect-setup.sh <root>` standalone, or add `--write-only` inside an
announced configuration sweep. It preflights and immediately rechecks every write, then deploys
`adr.md` and `specs.md` absent-only beneath `.spaces/architect/templates/`. Valid
incumbents win; recognized legacy copies refuse with `/architect migrate <source-path>`.

`founding.md`, `draft.md`, and `spikes.md` are package-only and are never deployed. Setup also never
creates `.spaces/architect/drafts/` or `.records/spikes/`; those appear only on an
authorized save or completed spike. Neither are schemas, record shells, or sibling files. Standalone setup makes one pathspec-scoped commit over exactly its reported writes; sweep mode
leaves commit custody with its caller, and a no-op rerun makes no commit.

Done when both active templates are present and valid and no package-only or foreign path changed.
