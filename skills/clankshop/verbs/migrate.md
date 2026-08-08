# `/clankshop migrate` — the brownfield onramp

Bring a project with pre-existing content — documents, tracker-like files, record stores, prior
agent scaffolding of **any** convention — onto the pack. **Format-agnostic by design**: this verb
names no legacy formats and enumerates none; it inventories whatever exists, classifies each
artifact **by its content** into the taxonomy, and executes one confirmed mapping pass. A stamped
root is never re-migrated; an empty root belongs to `setup`.

Patient-zero note: in the grimoire library itself this verb is exercised only against throwaway
temp-dir fixtures — never against the library's own tree.

## Preconditions — facts first, then judgment

Run `scripts/migrate-preflight.sh <root>` and judge its facts:

- **`stamped=1` → refuse.** The root is already an installation; drift is `check`'s and the
  improvement loop's business, not a re-migration.
- **`tree_clean=0` → stop.** Migration executes as history-rewriting moves; a dirty tree makes
  rollback ambiguous. Have the human land or stash first.
- **Active workstreams → stop.** Both kinds block: `linked_worktrees` (a stream's worktree holds
  branch state the moves would strand) **and** `inplace_streams` (an in-place stream holds custody
  of the shared tree — the worktree check alone cannot see it).
- **`dup_ids` non-empty → resolve in the table.** Two artifacts claiming one identifier cannot
  both keep it as an alias; the mapping table must resolve every collision row before execution.
- **Unclassifiable artifacts → triage.** Anything the classification below cannot place is
  surfaced to the human as its own mapping-table row — never guessed, never dropped.

A declared `records-root` (a live front-door variable, not a legacy format) is **respected in
place**: the same walk runs against it, and nothing is bulk-moved to `.records/` just to satisfy
the default path.

## Step 1 — generic inventory

Walk the root (tracked files; the preflight's facts anchor the git shape) and list every artifact
that carries process content: docs, trackers of any shape, record stores, scaffolding, config-like
process files. The inventory is complete before anything is classified — classification quality
depends on seeing the whole set.

## Step 2 — content classification

Classify each artifact **by what its content is**, into the taxonomy the doctrine deploys:

| the content is… | it becomes |
|---|---|
| a load-bearing rule | an INVARIANTS entry |
| a procedure / how-to | its lane file (or a testing chapter doc) |
| a standing judgment | a POLICY entry |
| a trap / surprising behavior | a GOTCHAS entry |
| a work item (todo, issue, bug report) | a tracker entry in wire format |
| a decision record | `.records/adr/` |
| completion evidence / changelog-like history | `.records/done/` |
| project-specific tool material | the owning role's seat — "no seat" is a valid outcome |
| an operator override (user-authored config) | stays put, untouched |
| none of the above, or genuinely ambiguous | a triage row for the human |

## Step 3 — one confirmed mapping table

Propose the **complete** table: every inventoried artifact in **exactly one row** — source path →
destination (+ new ID where one is minted) → alias to preserve → note. Collision rows (from
`dup_ids`) and triage rows are resolved here. The human confirms the table **once**; no
incremental re-asks, no post-confirmation additions. The confirmed table is the contract the
execution and the nothing-dropped check both run against.

## Step 4 — execution, in a worktree with rollback

Execute the table in a **dedicated worktree** on a migration branch — never on the live checkout:

- moves and rewrites per the table, one artifact at a time;
- **alias preservation**: every pre-existing identifier survives verbatim on its restamped entry —
  `(alias <old>)` on flat-store lines/headings, a frontmatter `alias:` key on store-dir items
  (the per-store encodings: `.handbook/rules/RECORDS.md`); in-repo citations of the old
  identifier are rewritten to the new ID;
- the **alias map** (old → new, complete) is recorded in the migration's done-record;
- any failure mid-pass → discard the worktree and branch: the live checkout was never touched.

Then run the projection half of the bootstrap exactly as `setup` does (doctrine → `.handbook/`
with provenance stamps, the door table + registration blocks, the stewardship maps, the records
skeleton for stores the table did not populate) — migration is classification **plus** the same
assembly, not a different assembly.

## Step 5 — nothing-dropped check, then stamp

- **Nothing dropped**: every table row's source is accounted for at its destination (or explicitly
  `stays put` / triaged-out with the human's sign-off); the table doubles as the checklist. Assembly
  validation (`check`) must be green on the migrated tree before the merge.
- **Stamp**: write the installation block last (`scripts/install-block.sh write <root> 1
  clankshop <pack-version>`, the pack version from the manifest — this pack's `PACK.md`
  frontmatter `version:`), merge the migration branch, and remove the worktree. The project is
  now stamped — and never re-migrated.

## Done when

The confirmed mapping table is fully executed with nothing dropped; every pre-existing identifier
survives as an alias with citations rewritten and the alias map in the done-record; the handbook,
door, maps, and records stores stand exactly as a fresh `setup` would leave them; `check` is
green; and the root is stamped.
