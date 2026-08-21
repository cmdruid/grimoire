# `check` — assembly validation

Validate a deployed workshop: layout shape, required files, resolvable links, record
conformance. Facts come from the deployed scripts; this verb reads them and reports — it fixes
nothing silently.

**Guard:** resolve the project root (conversation → cwd → ask), then resolve
`<agent-workspace>` from the door (first line-start `agent-workspace:` in `<root>/AGENTS.md`
then `<root>/CLAUDE.md`, else `.dev`). No `<root>/<agent-workspace>/doctrine` → not a
workshop; report that and point at `setup` / `migrate` — nothing to check. **If a legacy
`<root>/.handbook/` is present instead, say so specifically:** that is a pre-relocation
workshop, and the fix is `git mv .handbook <agent-workspace>/doctrine`, not `setup`.

## The walk

1. **Load sets** — `<root>/<agent-workspace>/doctrine/scripts/context.sh --check`. Exit 2
   lists exactly which station's load set is broken.
2. **Stamp** — the install stamp line (`Seeded from clankshop …`) is present in
   `<agent-workspace>/doctrine/README.md`. Missing stamp = a hand-built or half-seeded
   doctrine home; report it.
3. **Slots** — no unfilled `<gate>` / `<trunk>` placeholders left in
   `<agent-workspace>/doctrine/` (grep). A deliberate placeholder confirmed at setup is fine
   when the doc says so; a forgotten one is a finding.
4. **Links** — every relative `.md` link inside `<agent-workspace>/doctrine/` resolves, and
   the door (`AGENTS.md`) exists and names `<agent-workspace>/doctrine/README.md`.
   **Declaration coherence:** if the workspace is not `.dev`, the door must carry
   `agent-workspace: <rel>` at line start; if it *is* `.dev`, a line declaring it is a no-op
   — report it as a finding, because a host meaning to declare an undotted `dev` and typing
   `.dev` degrades silently.
5. **Records** — resolve the agent-records home: the first line-start
   `agent-records:` or `records-root:` in `<root>/AGENTS.md` or
   `<root>/CLAUDE.md`, else `.records/`. A host that only declared
   `agent-records:` must not be told the layer is absent at default
   `.records/`. Where `<agent-records>/scripts/records.sh` exists, run
   it `check`: front-matter conformance and status↔ledger coherence are
   its facts. Missing → report the records layer as absent (setup's
   step 3 unfinished), not as a pass.
6. **Hooks** — run `scripts/hooks-glue.sh check --file "$HOOKS" --presence
   true|false` (absolute `$HOOKS=<root>/<agent-workspace>/hooks/workstream.md`;
   presence from `scripts/hooks-glue.sh presence --clankshop-dir <skill-base>`).
   Report-only: `finding=true` names `/clankshop setup`. Do not write the file.
   Missing known H2 is not a finding.
7. **Report** — one list: green items as one line, each finding as location + what's wrong.
   Fixes are ordinary routed work, not part of the check.
