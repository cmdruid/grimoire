# `setup` — greenfield bootstrap

Stand up the workshop on a project that has none: project the seed doctrine, stand up the
records layer (via `journal`), write the door, validate. Facts come from scripts and
inspection; the few real decisions are confirmed with the human, once.

**Guard:** resolve the project root first — a project directory the conversation
references, else the working directory, else ask. Then classify *before any write*:

a. **Journal present?** If `/journal setup` is not available, stop: say so and do
   not improvise a records layer. Write nothing.
b. **Inventory.** `scripts/migrate-scan.sh <root>` (facts). If both `workspace=absent`
   and `handbook=absent`, and any of `docroot=`, `tracker-shaped=`, `records=present`
   fire, prefer `migrate` — show the human those keys and stop unless they confirm
   greenfield anyway.
c. **Existing doctrine home?** Test the resolved `<agent-workspace>/doctrine`, **and**
   legacy `.handbook/` — the scan can only probe the default workspace, so a host that
   declared a non-default one reports `workspace=absent` regardless. A present
   `.handbook/` is a **pre-relocation** workshop: it is assembled, so this is not
   greenfield. Do not seed beside it (`seed.sh` refuses); the move is
   `git mv .handbook <agent-workspace>/doctrine`, then resume at the first unfinished
   walk step.
   - Both absent → continue the walk.
   - Present, and a `check` would be green (stamp, slots, door pointer, records
     layer) → already seeded. Stop. An upgrade the human asked for is a
     judgment-assisted diff against the current seed, anchored by the README
     stamp line — not a re-seed, not this walk.
   - Present but `check` would not be green (missing stamp, leftover `<gate>` /
     `<trunk>`, no door pointer, records layer absent) → **resume**. Start at the
     first unfinished *walk* step (1–5). Do not re-run `seed.sh` (it refuses). Do
     not treat this as "already seeded."

## The walk

1. **Gather the two facts the seed needs.**
   - `<trunk>`: the project's trunk branch — `git -C <root> branch --show-current` on a fresh
     repo, or the default branch where a remote exists.
   - `<gate>`: the project's one gate command. Propose it from inspection (test runner, build
     manifest, CI config); confirm with the human. A brand-new project with no gate yet gets a
     placeholder confirmed as such — the guardian fills it when one exists.
2. **Project the seed** (mechanics are scripted). Resolve `<agent-workspace>` from the door
   first (default `.dev`) and pass it in — the script never scans the front door:
   `scripts/seed.sh <root> --workspace '<agent-workspace>' --gate '<gate>' --trunk '<trunk>'`
   — copies the template doctrine to `<root>/<agent-workspace>/doctrine`, fills the slots,
   writes the one install stamp (`Seeded from clankshop vX.Y on DATE` in
   `<agent-workspace>/doctrine/README.md`), and self-checks the load sets. It refuses an
   existing doctrine home **and** a legacy `.handbook/`. Omit `--workspace` for the default.
3. **Stand up the records tool layer — `/journal setup`** (a required pack member; the
   records layer is its domain). Run `/journal setup` for `<root>`: `records.sh`,
   the empty history ledger, and the records README are its deployed assets, not
   this skill's. Do not `mkdir` store directories or templates to "help." Do not
   inline journal's walk. If `journal` is not available, say so and stop — the
   Guard should have caught this; write nothing further.
4. **Write the door.** Integrate into `<root>/AGENTS.md` (create it if absent; integrate,
   never clobber — existing content stays). Minimum bytes — not a template:

   - a pointer that names `<agent-workspace>/doctrine/README.md` (the workshop's doctrine
     lives in `<agent-workspace>/doctrine/`, by default `.dev/doctrine/`; start there);
   - a thin routing table compiled from `core/ROUTING.md`'s dispatch rows (kind of
     work → lane). Detail stays in the doctrine home; the door only routes;
   - `agent-records: <rel>` at line start only when the records home is not
     `.records/` (omit the line for the default). `records-root:` remains
     accepted on already-declared hosts.
   - `agent-workspace: <rel>` at line start only when the workspace is not `.dev`
     (omit the line for the default — that is the point of the default, and a line
     restating it is a no-op the lint flags).

   Do not invent a third location. Do not rewrite unrelated existing content.
5. **Validate**: run the `check` verb. Setup is complete only when it comes back green.

## Notes

- The doctrine home is the **project's** document from this moment: project specifics accrete
  below the seeded preambles; upgrades diff against the current seed rather than re-projecting.
- Nothing here writes outside `<root>`; commits (if the human wants them) are scoped to the
  paths written (`<agent-workspace>/doctrine/`, `.records/`, `AGENTS.md`).
