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
     layer, unfinished hooks would `finding=false`, unfinished copy would
     `finding=false`, and when `$SKILL/flows` is present face
     `scripts/flows-door.sh check` is green) → already seeded. Stop.
     Unfinished hooks (`scripts/hooks-glue.sh check` would `finding=true`)
     means **not** seeded. Unfinished copy (`scripts/flows-copy.sh check`
     would `finding=true`) means **not** seeded. A missing, malformed, or
     wrong-path flows pointer when `$SKILL/flows` is present means **not**
     seeded. An upgrade the human asked for is a
     judgment-assisted diff against the current seed, anchored by the README
     stamp line — not a re-seed, not this walk.
   - Present but `check` would not be green (missing stamp, leftover `<gate>` /
     `<trunk>`, no door pointer, records layer absent, unfinished hooks, unfinished
     copy, missing/malformed/wrong-path flows pointer) → **resume**. Start at the
     first unfinished *walk* step (1–6). Do not re-run `seed.sh` (it refuses). Do
     not treat this as "already seeded." Empty `$HOOKS` with stamp/door/records
     present hits **this** arm. A present doctrine pointer + complete copy +
     missing flows pointer (or complete doctrine + missing dest stems) hits
     **this** arm, not STOP, not a dead branch. Resume: skip `seed.sh` if
     doctrine is present; **still run** the copy arm and/or door `apply` when
     those predicates fire.

## The walk

1. **Gather the two facts the seed needs.**
   - `<trunk>`: the project's trunk branch — `git -C <root> branch --show-current` on a fresh
     repo, or the default branch where a remote exists.
   - `<gate>`: the project's one gate command. Propose it from inspection (test runner, build
     manifest, CI config); confirm with the human. A brand-new project with no gate yet gets a
     placeholder confirmed as such — the test station fills it when one exists.
2. **Project payload** (two arms; still this numbered step). Resolve `<agent-workspace>` from
   the door first (default `.dev`) and pass it in — the scripts never scan the front door.
   1. **Doctrine.** `scripts/seed.sh <root> --workspace '<agent-workspace>' --gate '<gate>'
      --trunk '<trunk>'` — copies the template doctrine to
      `<root>/<agent-workspace>/doctrine`, fills the slots, writes the one install stamp
      (`Seeded from clankshop vX.Y on DATE` in `<agent-workspace>/doctrine/README.md`), and
      self-checks the load sets. It refuses an existing doctrine home **and** a legacy
      `.handbook/`. Omit `--workspace` for the default. Present doctrine home → do not
      re-run (`seed.sh` refuses).
   2. **Flows copy.** `scripts/flows-copy.sh copy --root <abs> --workspace '<agent-workspace>'`
      (`SRC=$SKILL/flows`, `DST=$root/$ws/flows`). If `$SRC` is absent, skip. `mkdir` `$DST`
      only when `<ws>` already exists (arm 1 just created it, or it already existed) or the
      home is the derived default `.dev`. For each `$SRC/*.md`, copy **if the dest file is
      absent**; never overwrite an incumbent; do not delete extras already in `$DST`. Resume
      still runs this arm when dest stems are missing.
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
   - a delimited flows **pointer** via `scripts/flows-door.sh apply --root <abs>
     --workspace '<agent-workspace>'` (creates `AGENTS.md` only because this walk is
     already writing the door; the script itself never creates the file). Body is one
     line locating `<ws>/flows/`; not loaded until one is selected. No stem table. Do
     not compile dispatch rows from `core/ROUTING.md`. Classification walk stays in
     `core/ROUTING.md`. Unfinished (this step): `$SRC` present AND the pointer is
     missing, malformed, or its body does not contain the resolved `<ws>/flows/` path
     as a literal;
   - `agent-records: <rel>` at line start only when the records home is not
     `.records/` (omit the line for the default). `records-root:` remains
     accepted on already-declared hosts.
   - `agent-workspace: <rel>` at line start only when the workspace is not `.dev`
     (omit the line for the default — that is the point of the default, and a line
     restating it is a no-op the lint flags).

   Do not invent a third location. Do not rewrite unrelated existing content.
5. **Hooks.** Set `HOOKS=<root>/<agent-workspace>/hooks/workstream.md` (absolute).
   `mkdir` the parent of `$HOOKS` only when (a) `<root>/<agent-workspace>` already
   exists as a directory, or (b) the home is the derived default `.dev` and the
   mkdir is `hooks/` only. Then run `scripts/hooks-glue.sh fill --file "$HOOKS"
   --skeleton <skill-base>/../workstream/templates/hooks.md` (skill-base like
   `seed.sh`). Presence false (no sibling skeleton) → fill is noop. Do not
   invoke `skills/workstream/scripts/hooks.sh`.
6. **Validate**: run the `check` verb. Setup is complete only when it comes back green.

## Notes

- The doctrine home is the **project's** document from this moment: project specifics accrete
  below the seeded preambles; upgrades diff against the current seed rather than re-projecting.
- Nothing here writes outside `<root>`; commits (if the human wants them) are scoped to the
  paths written (`<agent-workspace>/doctrine/`, `<agent-workspace>/flows/`,
  `.records/`, `AGENTS.md`, `<agent-workspace>/hooks/`).
