# `setup` — greenfield bootstrap

Stand up the workshop on a project that has none: project the seed handbook, stand up the
records layer (via `journal`), write the door, validate. Facts come from scripts and
inspection; the few real decisions are confirmed with the human, once.

**Guard:** resolve the project root first — a project directory the conversation
references, else the working directory, else ask. Then classify *before any write*:

a. **Journal present?** If `/journal setup` is not available, stop: say so and do
   not improvise a records layer. Write nothing.
b. **Inventory.** `scripts/migrate-scan.sh <root>` (facts). If `handbook=absent` and
   any of `docroot=`, `tracker-shaped=`, `records=present` fire, prefer `migrate` —
   show the human those keys and stop unless they confirm greenfield anyway.
c. **Existing `.handbook`?**
   - Absent → continue the walk.
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
2. **Project the seed** (mechanics are scripted):
   `scripts/seed.sh <root> --gate '<gate>' --trunk '<trunk>'`
   — copies the template handbook to `<root>/.handbook`, fills the slots, writes the one
   install stamp (`Seeded from clankshop vX.Y on DATE` in `.handbook/README.md`), and
   self-checks the load sets. It refuses an existing `.handbook`.
3. **Stand up the records layer — `/journal setup`** (a required pack member; the records
   layer is its domain). Run `/journal setup` for `<root>`: the `.records/` stores,
   templates, `records.sh`, and the history ledger are its deployed assets, not this
   skill's. Do not inline journal's walk. If `journal` is not available, say so and
   stop — the Guard should have caught this; write nothing further.
4. **Write the door.** Integrate into `<root>/AGENTS.md` (create it if absent; integrate,
   never clobber — existing content stays):
   - a pointer: the workshop's doctrine lives in `.handbook/` — start at
     `.handbook/README.md`;
   - a thin routing table compiled from `core/ROUTING.md`'s dispatch rows (kind of work →
     station or workflow). Detail stays in the handbook; the door only routes.
5. **Validate**: run the `check` verb. Setup is complete only when it comes back green.

## Notes

- The handbook is the **project's** document from this moment: project specifics accrete below
  the seeded preambles; upgrades diff against the current seed rather than re-projecting.
- Nothing here writes outside `<root>`; commits (if the human wants them) are scoped to the
  paths written (`.handbook/`, `.records/`, `AGENTS.md`).
