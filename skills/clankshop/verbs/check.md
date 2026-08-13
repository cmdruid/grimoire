# `check` — assembly validation

Validate a deployed workshop: layout shape, required files, resolvable links, record
conformance. Facts come from the deployed scripts; this verb reads them and reports — it fixes
nothing silently.

**Guard:** resolve the project root (conversation → cwd → ask). No `<root>/.handbook` → not a
workshop; report that and point at `setup` / `migrate` — nothing to check.

## The walk

1. **Load sets** — `<root>/.handbook/scripts/context.sh --check`. Exit 2 lists exactly which
   station's load set is broken.
2. **Stamp** — the install stamp line (`Seeded from clankshop …`) is present in
   `.handbook/README.md`. Missing stamp = a hand-built or half-seeded handbook; report it.
3. **Slots** — no unfilled `<gate>` / `<trunk>` placeholders left in `.handbook/` (grep). A
   deliberate placeholder confirmed at setup is fine when the doc says so; a forgotten one is
   a finding.
4. **Links** — every relative `.md` link inside `.handbook/` resolves, and the door
   (`AGENTS.md`) exists and points at `.handbook/README.md`.
5. **Records** — where the records layer is deployed (`records.sh` under the records root's
   `scripts/`), run `records.sh check`: front-matter conformance and status↔ledger coherence
   are its facts. No records layer → report it as absent (setup's step 3 unfinished), not as
   a pass.
6. **Report** — one list: green items as one line, each finding as location + what's wrong.
   Fixes are ordinary routed work, not part of the check.
