---
doctype: design
status: open
created: 2026-08-20
updated: 2026-08-21
tags: [spec]
---

# Project hooks — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here, on `stream/skills` until ship. It doubles as the implementation
plan.

Subject: a project-resident hooks convention (`skill-builder` doctrine)
with `workstream` as the first consumer and `clankshop` as the first
glue author. Brief: glue skills together in the project, not in the
leaves — visible hook points, a parse/compile snapshot, no
`<debrief>` socket, no stamp→`/backlog debrief` probe.

Settled 2026-08-20 on stream `skills` from the clankshop walk; F1
amended the same day from `needs-rework`:

1. Define the reusable convention now (`skill-builder` / `DOCTRINE.md`).
   `workstream` is the first consumer, not the only imagined one.
2. This feature replaces only the debrief fill. `/backlog task` in
   workstream Scope and `/backlog issue` in `sync.md` stay for a later
   walk.
3. **Two materializers, workstream's own skeleton, never overwrite.**
   `workstream` holds `skills/workstream/templates/hooks.md` (package-
   only). `create` copies it to the project if absent. `clankshop
   setup` copies that same file if absent **and** fills empty
   sections. Neither overwrites a present file. There is **no**
   generic `hooks.md` template, **no** `skill-builder new` scaffold of
   one, and **no** `<agent-workspace>/templates/hooks.md`.
4. **Hooks walk step is numbered.** `setup` step 5 (check becomes 6)
   and `migrate` before check. Unfinished = sibling skeleton present
   AND (`$HOOKS` missing OR a **known H2 is present with empty
   body**). A missing heading is not unfinished. HEAD setup Guard
   (all three arms, range **1–6**) is edited so already-seeded /
   resume actually run this step. `check` uses the same presence
   test and the same unfinished predicate (no finding when
   `workstream` is not installed; no finding for a missing H2).
5. **`save` preserves the compiled snapshot.** `## Hooks (compiled)`
   and `hooks-compiled:` are Coordinates-class. Every hooks path is
   absolute `<root>/<agent-workspace>/hooks/workstream.md`.

## Problem

Cross-skill glue today is authored **inside the leaf**. `workstream`
probes `Seeded from clankshop` and writes `/backlog debrief` into each
stream's hand-off (`verbs/create.md` step 6, `SKILL.md` *Host layout*,
`templates/workstream-handoff.md` `<debrief>`). Standalone hosts get a
carved "project's own close-the-books sweep" sentence that exists only
because the workshop fill exists.

That has three failures:

1. **The leaf names a collaborator.** `backlog` may not be installed.
   The portable `<debrief>` token is a socket for a skill `workstream`
   should not know about.
2. **The glue is invisible in the project.** An agent looking at the
   repo cannot see that the loop is extensible, and cannot add their
   own extra step without editing the skill package.
3. **The same pattern will recur.** Any later "run X before workstream
   Y" will either rot into another stamp probe or revive a registrar
   skill (retired `foreman` / `register-route`).

v2 already said glue is pack content, leaves instruct generically, and
compilation of doctrine is a view never an artifact. There is no
project file that is the glue surface, no format, and no first
consumer.

## Goal

After this feature:

- **Convention.** `skill-builder`'s `DOCTRINE.md` names project hooks:
  `<agent-workspace>/hooks/<skill>.md` (default `.dev/hooks/<skill>.md`).
  A skill with a named-seam loop may publish empty hook ids there. Any
  agent, and a pack face, may fill those sections. Leaves do not name
  glue authors or sibling commands in the skeleton. The two-roots
  workspace holds-column and the doctrine-touching destination test
  both list `hooks/`. Format reference lives in doctrine (optional
  `skill-builder/docs/` example). Not a lock-in template. Not
  `<agent-workspace>/templates/hooks.md`. Not a `new` scaffold.
- **First consumer.** `/workstream create` (and `recycle`) materializes
  the bundled empty skeleton if the project file is absent, parses it,
  and compiles a snapshot into Coordinates `this hand-off:` (not a
  guessed `<worktree>/WORKSTREAM.md`). Empty sections mean no extra
  *glue command*. Later *edits to a filled body* apply at the next
  `create`/`recycle`, not mid-stream.
- **First glue.** Numbered `setup` / `migrate` step copies
  `skills/workstream/templates/hooks.md` if the project file is
  absent (member installed), then fills empty `Feature completion`
  and `After eventful ship` with `/backlog debrief`. Primary path
  and already-seeded / migrate paths all fill before `check`.
  `check` **reports** empty pack glue only when that skeleton is
  present; it does not write.
- **Stamp probe for debrief is gone.** `workstream` no longer keys
  `<debrief>` on `Seeded from clankshop`. Tracker-line permission on the
  stamp (queue items as Backlog lines) is unchanged — Host layout's
  stamp now governs **that one thing**.

Standalone `workstream` still functions: empty hooks, bundled `flow.md`,
no `/backlog`. Lint `fails=0`. New parser tests green. Existing
clankshop harnesses green.

## Approach

**Chosen: a project file per skill, parse/compile at instantiate,
convention in doctrine, one consumer implemented.** Hook ids are that
skill's own lifecycle seams. The file is the editor surface. The
instance artifact (for workstream: Coordinates `this hand-off:`) is
the snapshot the loop actually follows.

**Chosen (F1, was rejected 3B): `setup` materializes-if-absent and
fills.** Two materializers sharing `workstream`'s bundled skeleton is
not two authors of the API. Both refuse overwrite, so the first writer
wins the empty headings; `setup` then fills empty *bodies*. That is
what makes `setup → first create → ship` compile pack glue. 3A (face
never creates the file) plus snapshot-at-instantiate plus no re-parse
on `load` made pack glue **never** for a plan/roadmap stream. Review
2026-08-20. Do not restore the stamp fill.

**Rejected: a named `<debrief>` slot in `workstream`.** Carves a
collaborator. Confusing when `backlog` is absent. Human, this walk.

**Rejected: 3A (`setup` never creates the file; glue may be late).**
Late is never: `create` snapshots `(empty)`, `load`/`save` must not
recompile, plan/roadmap streams do not `recycle`. Regression vs
`create.md` 119–123. Human had chosen 3A for unique creator;
overwrite-refusal already gives a unique creator of *bytes*.

**Rejected: compile into the bundled `workstream-handoff.md`.** That is
the skill package. Only the instance hand-off is filled.

**Rejected: re-parse on every `load`.** The instance is the loop for
that stream. Live edits to a *filled* body must not rewrite an
in-flight ship ritual. Stamp the snapshot (`hooks-compiled:` path +
hash). Empty snapshot is still a snapshot of empty; after 3B the
workshop file is filled *before* first `create`.

**Rejected: a shared runtime parser in `skill-builder` that every skill
calls.** Floor (BL-6). Each consumer bundles its own parser against the
doctrine format. No drift check until a second copy exists.
`clankshop` fill does **not** shell `workstream/scripts/hooks.sh`
(same floor). It tests the two known H2s itself.

**Rejected: a generic before/after on every verb, conditions, or
ordering.** Plugin bus. Extra steps attach only at seams the skill's
flow already names.

**Rejected: `hooks/` as a copy of `flow.md`.** Two writers on the loop
prose. Glue-only sections under empty H2s.

**Rejected: putting this under `workflow/`.** Lanes are host procedures
that work by hand. Hooks are overlays on a skill loop. `workflows/`
plural rename stays deferred (BL-36 / this walk).

**Rejected: stripping every `/backlog` mention from `workstream`.**
Scope and `sync.md` issue capture are different seams. Later walk.

**Rejected: minting this spec into `.records/`.** Patient-zero.

**Rejected: a new `foreman` / AGENTS.md registrar.** Already walked;
hooks are not door blocks.

**Rejected: attended `check` writes glue in the same walk.**
`check.md:39` — fixes are ordinary routed work, not part of the check.
Empty pack glue is a finding that names `/clankshop setup` (which now
has a numbered unfinished step, so resume actually fills). Unattended
and attended: report only.

**Rejected: a generic `hooks.md` template / `new` scaffold /
`<agent-workspace>/templates/hooks.md`.** The project artifact is
`<agent-workspace>/hooks/<skill>.md` (config). Workstream may hold
*its own* package skeleton. A later consumer may generate headings
from `--known` or bundle its own file. `skill-builder` documents the
format; it does not mint a lock-in template into the project.

## Mechanism

### Convention (doctrine)

Add a **Project hooks** section to
`skills/skill-builder/docs/DOCTRINE.md`, next to doctrine-touching /
record-writing (a fourth landing class, not a front-door variable):

> **Hooks** are skill-keyed overlay steps on a skill's own loop →
> `<agent-workspace>/hooks/<skill>.md`. Default `.dev/hooks/<skill>.md`.
> The `<skill>` stem matches that skill's frontmatter `name:`.

Amend the doctrine-touching **Which home** boxed test from three
destinations to four. Add `hooks/` to
`docs/design/2026-08-19-two-roots-simple-spec.md` workspace
holds-column (`doctrine/`, `spec/`, `workflow/`, `templates/`,
`scripts/`, `hooks/`). That is a content-only layout line, not BL-36
(un-nest / `spec/` station work stays parked).

Rules:

1. **Who publishes.** A skill that owns a multi-step loop with named
   seams *may* publish hooks. Not every skill. Not mailbox, delegate,
   or a one-shot verb. The convention does **not** require a bundled
   `templates/hooks.md`. `workstream` holds one because it copies a
   skeleton; another skill may generate empty H2s from `--known`.
   `skill-builder new` asks (do not guess): *does this skill have a
   named-seam loop the pack or a later agent might extend?* Yes → a
   sentence in `SKILL.md` plus known ids on the parse line. **No**
   generic scaffold. **No** project-templates lock-in file.
2. **Who materializes.** The **publisher** copies *its* bundled
   skeleton to `<root>/<agent-workspace>/hooks/<skill>.md` **if
   absent**, or generates empty H2s from `--known` if it has no
   skeleton file. Never overwrite a present file (structure or
   bodies). Paths are always that absolute root path — never
   cwd-relative `hooks/<skill>.md`. Workstream's skeleton is
   `skills/workstream/templates/hooks.md`; `create` / `recycle` copy
   it. The pack face's numbered hooks step copies **that same
   workstream file** (first glue; face may name members). If the
   member is not installed (no sibling `templates/hooks.md`), skip.
   `mkdir` `hooks/` only:
   - when `<agent-workspace>` **already exists**, or
   - when the home is the derived default `.dev` and the mkdir is
     `hooks/` only (creates `.dev` as a container for `hooks/`,
     **never** `doctrine/`).
   Declared `agent-workspace:` that is absent → do not create; treat
   hooks as empty. Amend doctrine-touching rule 3 with that **narrow**
   hooks mkdir (leaf is not the workspace assembler; it must not seed
   `doctrine/`).
3. **Who fills.** Any agent. A pack face may fill **empty** sections
   for members it names. Non-empty body is incumbent — never clobber.
   `setup` may create the file only as a copy of the publisher's
   skeleton (rule 2), then fill empty bodies.
4. **What the skeleton may say.** Hook ids are that skill's lifecycle
   events (`Feature completion`), never collaborator names
   (`<debrief>`, `/backlog`). No sibling slash-commands in the bundled
   skeleton.
5. **Format (normative, parseable).**

   ```markdown
   # <skill> hooks

   <one-line purpose. Empty section = no extra glue command.>

   ## <Hook id>

   ## <Hook id>
   ```

   - Structural H2s (`^##[ \t]+\S`, not inside a fence) are hook ids.
   - Body = bytes after the heading until the next structural H2 or
     EOF. Strip surrounding whitespace. Then empty → no glue.
   - Duplicate H2 → parse fails (exit 2).
   - Extra H2 not in the skill's known set → fact `unknown=`
     (comma-separated if several), not compiled, not a fail.
   - Known H2 missing from an existing file → that hook is empty.
     Do not edit the file to add headings.
   - No front-matter required. H1 is chrome.
   - No conditions, flags, or before/after tables.
6. **When it runs.** Parse + compile at instantiate (workstream:
   `create` / `recycle`). Snapshot into Coordinates `this hand-off:`.
   Do not re-parse on resume. Stamp `hooks-compiled: <rel-path> @
   <sha256-12>` (`hash=none` when the file is missing).
7. **Scripts.** Facts, not verdicts. A consumer's parse script prints
   compact facts + bodies; `compile` is a deterministic subcommand in
   the same script. No shared `skill-builder` runtime. Second consumer
   copies the format from doctrine, not a sibling script.
8. **Independence.** Leaves resolve `<agent-workspace>` and the
   `hooks/<own-name>.md` path. They do not name the pack face or the
   glue command. `PACK.md` records the seam.

Update the doctrine **Glue is content vs. mechanism** bullet: the
retired `foreman` oven is not the glue surface. Project hooks files
are. Pack/runbook still authors *what* the glue says; there is no
composer skill to invoke.

Update the stamp-consumers sentence: `workstream` no longer gates
`<debrief>` on the stamp. It still gates Backlog tracker-line
permission. `debugger` Phase 4 is unchanged. **This sentence lands
with the `create.md` fill deletion, not before.**

`skill-builder new` step: the hooks question is orthogonal to tier and
to record-writer. On yes: SKILL.md sentence + known ids. Do **not**
scaffold `templates/hooks.md`. Do not add a lint check that requires
the file. Optional reference: a `docs/` example of the format, never
`templates/hooks.md`, never copied to a project.

No new `skills-lint.sh` number in this feature. Parser tests carry the
format. A lint for "skeleton contains `/sibling`" is a later check if
a second consumer appears.

### Path and tree

| File | Owner | Lives |
|---|---|---|
| `skills/workstream/templates/hooks.md` | `workstream` | package-only empty skeleton (this consumer's, not a generic template) |
| `<agent-workspace>/hooks/workstream.md` | the project | tracked **config**, not a template. Never `<agent-workspace>/templates/hooks.md`. |
| instance artifact | the instance | compiled snapshot. Coordinates `this hand-off:` only — `<root>/.workstreams/<stream>/WORKSTREAM.md` (worktree and in-place). Never a guessed `<worktree>/WORKSTREAM.md`. |

The project file is **not** the live hand-off. Do not name it
`WORKSTREAM.md`.

**Root, not worktree.** One hooks file per repo, shared by every
stream. Materialize at `<root>/<agent-workspace>/hooks/workstream.md`
(Coordinates `root checkout:`). Recycle runs in the worktree and must
still write that **root** path (a relative `.dev/hooks/` from the
worktree is the untracked twin this rule forbids). `clankshop setup` /
`check` run on the root and see the same path.

`create` writes the skeleton if absent. Attended: propose a
pathspec-scoped root commit for that path (same root-contention rule
as the gitignore / compaction-anchor). Unattended / `--seed-only`:
write, do not commit, record `hooks: uncommitted` in Pointers.
`--seed-only` still makes **no** root commit (create.md seed-only
contract).

### `workstream` consumer

**Known ids** (exact H2 strings; these are the two debrief *moments*
`flow.md` already has, not a new socket). Each has a slug for
`key=value` facts (H2 may contain spaces; fact keys must not):

| H2 | slug |
|---|---|
| `Feature completion` | `feature-completion` |
| `After eventful ship` | `after-eventful-ship` |

Bundled `skills/workstream/templates/hooks.md` is those two headings,
empty bodies, plus the one-line purpose. No `/backlog`. No `<debrief>`.

**Script** `skills/workstream/scripts/hooks.sh` (skill-base path, like
`workstream-git.sh`):

```
hooks.sh parse  --file <abs> --known <slug>=<H2> [--known <slug>=<H2> ...]
hooks.sh compile --file <abs> --handoff <abs> --known <slug>=<H2> [--known <slug>=<H2> ...]
```

`<abs>` for `--handoff` is Coordinates `this hand-off:`. `--file`
missing → `status=missing`, every known slug `empty`, `hash=none`,
exit 0.

`parse` is read-only. Prints:

```
file=<path>
hash=<sha256-hex>|none
status=missing|ok|fail
hook_<slug>=empty|filled
unknown=<H2>[,<H2>...]
```

and, for each filled hook, the body on following lines in a delimited
block the compile step consumes (exact delimiter in the script header;
tests pin it). Duplicate H2 → `status=fail`, exit 2.

`compile` is deterministic projection into `--handoff` (same class as
`seed.sh`, not a verdict). It does **not** rewrite the bundled
template in the skill package. It writes/replaces `## Hooks (compiled)`
in that hand-off: each known slug with its body or `(empty)`, plus
`hooks-compiled: <rel> @ <hash12>` (`none` when missing).

**`create` / `recycle` (step 6 today):**

Let `HOOKS=<root>/<agent-workspace>/hooks/workstream.md` (absolute;
Coordinates `root checkout:`). Recycle's cwd is the worktree; it
still uses `HOOKS`, never a relative `.dev/hooks/`.

1. Resolve `<agent-workspace>` from the root door.
2. If `$HOOKS` is absent and mkdir is allowed (rule 2): copy
   `skills/workstream/templates/hooks.md` to `$HOOKS`.
3. `parse --file "$HOOKS"`. Fail → STOP (malformed project file).
4. Instantiate the hand-off from the bundled
   `templates/workstream-handoff.md` as today, **except** do not run
   the stamp→`<debrief>` fill. Write only Coordinates `this hand-off:`.
5. `compile --file "$HOOKS" --handoff <this hand-off:>`.
6. Loop routine / phase map / Pointers: replace every `<debrief>`
   **glue-command** token with "the compiled hook **Feature
   completion** (skip the glue command if empty)" / "**After eventful
   ship** (skip the glue command if empty; only when the ship was
   eventful)". Do **not** skip the rest of the feature-completion
   ritual (delegation tally, route-before-loss floor in `flow.md`
   *Event-driven debrief*). Glue is an extra command at the seam, not
   the seam.

`load` does not recompile. `save` does not recompile **and** must
**preserve** `## Hooks (compiled)` and `hooks-compiled:` verbatim
(Coordinates-class) when it regenerates the hand-off from the bundled
shape (`save.md` 18–21 today recopies the template and would wipe
create's snapshot). Write Coordinates `this hand-off:` only. Slice 2
lists `verbs/save.md`. Also fix always-loaded prose that still says
the hand-off IS `<worktree>/WORKSTREAM.md` (`SKILL.md` live-hand-off
bullet, `save.md:18`, `flow.md` Scenario C) — in-place is
`<root>/.workstreams/<stream>/WORKSTREAM.md`.

`recycle` re-applies create step 6 in place (`recycle.md` already
does; it does not restate the old fill). Preserve Coordinates; blank
per-unit sections (TL;DR, Queue state, What's been done, What's next).
`## Hooks (compiled)` is rewritten by compile in that step 6, not
blanked as per-unit. Recycle still STOPs if the write path ≠
`this hand-off:`.

`flow.md` and `close.md` speak of the compiled glue command, not
`<debrief>` and not `/backlog`. `close.md` optional pre-close sweep
is "the compiled Feature completion hook if nonempty."

**`SKILL.md` Host layout.** Delete: filled `<debrief>` is `/backlog
debrief` when stamped. Keep: stamp still gates Backlog tracker-line
permission; still never route to workshop onramps. The stamp now
governs **exactly one** thing (tracker-line permission), not two.
Add: at `create`/`recycle`, read `$HOOKS` (absolute
`<root>/<agent-workspace>/hooks/workstream.md`) when present; empty
or absent → no extra glue command.

Standalone close-the-books is no longer a carved sentence in the
hand-off. Feature-completion remains a seam; extra glue is only what
the hooks file says.

**`SKILL.md` Discipline** root-contention example currently names
`` `/backlog debrief`'s captures ``. Generalize to "debrief / tracker
captures from compiled hooks" — no sibling slash-command.

### `clankshop` glue

Pack face may name `/backlog debrief`.

**Presence test** (same on `setup`, `migrate`, and `check`): sibling
`skills/workstream/templates/hooks.md` resolvable from the clankshop
skill dir (`../workstream/templates/hooks.md`). Missing → skip the
whole hooks step; **no** check finding.

**Unfinished predicate** (same on setup Guard, migrate, and check
finding), `$HOOKS=<root>/<agent-workspace>/hooks/workstream.md`
absolute:

presence test passes AND (`$HOOKS` missing OR a **known H2 is
present and its body is empty** after surrounding-whitespace strip).

A known H2 **absent** from an incumbent file is empty-by-parse (no
extra glue command). It is **not** unfinished. Do not name
`/clankshop setup`. Do not add the heading.

**Hooks walk step** (numbered; unfinished = that predicate):

1. If `$HOOKS` is absent: copy the sibling skeleton there (mkdir per
   convention rule 2).
2. For each of `Feature completion` and `After eventful ship`: if that
   H2 exists and its body is empty, write a single line
   `/backlog debrief`. Non-empty → leave it. Missing H2 → do not add
   it; do not treat as unfinished.

Do **not** invoke `skills/workstream/scripts/hooks.sh` (floor). The
empty-body test is two known H2s **after the same whitespace strip
as `hooks.sh parse`** (a `" \n"` body is empty; otherwise red-proof 8
dies). Duplicate it in a clankshop-local helper. Accepted duplication
until a second consumer exists.

- **`setup`:** this is **step 5**; `check` becomes **step 6**. Edit
  HEAD `verbs/setup.md` **24–31 as three quoted targets**, not only
  the STOP arm:

  1. **STOP / already-seeded** (`Present, and a check would be green
     (stamp, slots, door pointer, records layer)`): extend the green
     list — unfinished hooks (predicate above) means **not** seeded.
     Stop only when check would be green **including** hooks.
  2. **Resume** (`Present but check would not be green (missing
     stamp, leftover <gate>/<trunk>, no door pointer, records layer
     absent)`): add unfinished hooks to that parenthetical. Empty
     `$HOOKS` with stamp/door/records present must hit **this** arm,
     not a dead branch between the two.
  3. **Range:** `first unfinished walk step (1–5)` → **`(1–6)`** so
     resume still runs check after step 5.

  Notes commit pathspec today names doctrine / `.records/` /
  `AGENTS.md`; add `<agent-workspace>/hooks/`.

- **`migrate`:** run the same step after the door is written, before
  `check`. Slice 3 lists `verbs/migrate.md`. If migrate Notes say
  “not installed until step 5 is green,” retarget to the new check
  step (6).
- **`check`:** read-only. Finding only when the unfinished predicate
  is true. Names `/clankshop setup`. No write. `check.md` step 6
  stays "fixes are ordinary routed work, not part of the check."
  Red-proof: check against empty glue leaves the tree
  byte-identical. Missing known H2 → no setup-named finding.

`PACK.md` seam note (content-only, no `version:` bump — member set
unchanged):

> **Seam — `workstream` / `backlog`:** `workstream` publishes
> `<agent-workspace>/hooks/workstream.md` from its own package
> `templates/hooks.md`. `setup` step 5 / `migrate` copy that skeleton
> if absent and fill empty `Feature completion` and `After eventful
> ship` with `/backlog debrief`. `check` reports empty pack glue only
> when that skeleton is installed; it does not write. Leaves do not
> name each other.

### Out of scope

- `workflows/` plural rename; BL-36 layout (`spec/` station un-nest).
  Adding `hooks/` to two-roots' holds-column **is** in scope (F5).
- `/backlog task` / `/backlog issue` in `workstream`.
- `debugger` stamp (Phase 4) and `auditor` "clankshop onramps".
- A generic hooks engine, lint check, or `skill-builder` parse script.
- Hooks for any skill other than `workstream`.
- Re-parse on `load`. Conditions, ordering, before-every-verb.
- Door skill-route blocks / resurrecting `register-route`.
- Attended `check` writing glue.
- A generic `hooks.md` template; `skill-builder new` scaffolding one;
  `<agent-workspace>/templates/hooks.md`.
- Patient-zero: do not write `.dev/hooks/` into this library's own
  tree as a side effect of tests; fixtures only.

## Verification

**Mechanical**

```
cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
  bash skills/workstream/scripts/tests/run.sh && \
  bash skills/clankshop/scripts/tests/run.sh && \
  bash skills/skill-builder/scripts/skills-lint.sh .
```

Expect: new workstream parser suite ALL GREEN; clankshop tests ALL
GREEN; lint `fails=0`.

Grep gate — two commands, both under `skills/workstream/` excluding
`scripts/tests/**`:

1. `rg -n '<debrief>'` → empty. Not allowed: `<debrief>` in the
   hand-off template, `create.md`, `flow.md`, `close.md`.
2. `rg -n 'Seeded from clankshop'` → **exactly one** hit, and that
   hit is the Host-layout tracker-line permission bullet (not a
   debrief fill). Count the hits; fail on 0 or on 2+.

**Red-proofs (do not land a first clean run)**

1. **Empty parse.** Skeleton-only file → both slugs `empty`,
   `hash` nonempty, exit 0. Disable the whitespace-strip, confirm a
   `" \n"` body becomes `filled`, restore.
2. **Filled body.** Plant `/backlog debrief` under `Feature
   completion` → `hook_feature_completion=filled`, compile inlines it
   in `## Hooks (compiled)` of `--handoff`. Empty
   `after-eventful-ship` listed `(empty)`.
3. **Duplicate H2 → exit 2.**
4. **Unknown H2.** Extra `## Other` → `unknown=Other`, compile does
   not fail, known slugs still emit. Two extras → comma-separated.
5. **Create does not overwrite.** File with glue present; run the
   materialize step → bytes unchanged (checksum).
6. **Setup materialize + fill + incumbent.** (a) Tree with no
   `hooks/workstream.md` and workstream skeleton present → setup
   creates the file and both bodies are `/backlog debrief`. (b) File
   present with a non-empty `Feature completion` → that body
   unchanged; empty sibling still filled. (c) Workstream skeleton
   missing → setup does not create the file.
7. **No stamp fill.** `create` given a planted `Seeded from clankshop`
   README and **empty** hooks file must **not** write `/backlog
   debrief` into the hand-off. Disable the deletion of the stamp fill,
   confirm the hand-off gains `/backlog debrief`, restore.
8. **Primary path.** Fixture: run setup (skeleton present), then
   create. Hand-off `## Hooks (compiled)` lists
   `/backlog debrief` for both ids. Compile target is the Coordinates
   `this hand-off:` path, not `<root>/WORKSTREAM.md`.
9. **In-place hand-off.** `--in-place` create compiles into
   `<root>/.workstreams/<stream>/WORKSTREAM.md`. `<root>/WORKSTREAM.md`
   is absent.
10. **Save preserves compiled block.** Create a filled snapshot, run
    save, `## Hooks (compiled)` and `hooks-compiled:` byte-identical
    to pre-save (aside from unrelated TL;DR refresh). Disable the
    preserve, confirm the block becomes the bundled empty
    placeholder, restore.
11. **Already-seeded setup fills.** Doctrine present, stamp present,
    door present, records present, sibling skeleton present. Two
    plantings of the **full** unfinished predicate (not
    missing-file-only):
    (a) `$HOOKS` **absent** → setup does **not** re-seed (`seed.sh`
    still refuses); Guard resume arm matches (not a dead branch,
    not STOP); it runs step 5, creates+fills `$HOOKS`, then step 6
    `check` is green.
    (b) `$HOOKS` **present** with both known H2s and empty bodies
    → same Guard resume (the empty-body arm of the predicate);
    step 5 fills those bodies (does not recreate or overwrite
    structure); step 6 `check` is green.
    Disable the resume-parenthetical edit, confirm setup writes
    nothing (dead branch) on (a), restore. A resume gloss that
    only tests “file missing” greens (a) and misses (b).
12. **Check presence vs write.** (a) No sibling skeleton → check has
    **no** hooks finding; tree checksum unchanged. (b) Skeleton
    present, `$HOOKS` empty headings → one finding naming setup;
    tree checksum unchanged (`check` does not write). (c) Skeleton
    present, file present, `## Feature completion` omitted → **no**
    setup-named finding; checksum unchanged.

**Judgment**

- Bundled `skills/workstream/templates/hooks.md` names no sibling and
  no `<debrief>`. No `<agent-workspace>/templates/hooks.md`. `new.md`
  does not scaffold a generic `hooks.md`.
- `SKILL.md` description still does not name `clankshop` or `backlog`.
- Host layout stamp governs exactly one thing (tracker-line).
- `check.md` still says fixes are not part of the check; empty glue is
  a finding that names setup **only when the skeleton is installed**.
- Doctrine Project-hooks section exists; four destinations; two-roots
  holds-column lists `hooks/`; `new.md` asks the question and does not
  scaffold `templates/hooks.md`; glue bullet no longer names `foreman`
  as the oven.
- `flow.md` skip-if-empty applies to the glue command only.

## Slices

- [ ] **Slice 1: parser + skeleton + create materialize (tracer)**
  <requires: —>
  - Files:
    - Create: `skills/workstream/templates/hooks.md`;
    - Create: `skills/workstream/scripts/hooks.sh`;
    - Create: `skills/workstream/scripts/tests/hooks-test.sh`,
      `skills/workstream/scripts/tests/run.sh`, `lib.sh` if needed
      (new harness; copy the small pattern from journal/clankshop
      `tests/lib.sh` only as needed — do not import a sibling);
    - Modify: `skills/workstream/verbs/create.md` (materialize if
      absent at absolute `$HOOKS=<root>/<agent-workspace>/hooks/workstream.md`;
      parse `--file "$HOOKS"`; no compile-into-loop yet if that keeps
      the tracer small — must at least write the file and refuse
      overwrite).
  - Change: Mechanism *Path and tree* + `hooks.sh parse` + create
    materialize. `recycle` not yet. Do not delete `<debrief>` in this
    slice (hand-off still works). Do not touch clankshop.
  - Verify: red-proofs 1, 3, 4, 5. `run.sh` ALL GREEN.
    `create.md` names the absolute `$HOOKS` path, never a
    cwd-relative `hooks/workstream.md`.

- [ ] **Slice 2: compile snapshot; remove `<debrief>` fill**
  <requires: 1>
  - Files:
    - Modify: `skills/workstream/scripts/hooks.sh` (`compile`);
    - Modify: `skills/workstream/scripts/tests/hooks-test.sh`
      (red-proofs 2, 7, 9, 10);
    - Modify: `skills/workstream/templates/workstream-handoff.md`
      (`## Hooks (compiled)` section; Loop routine / phase map /
      Pointers without `<debrief>` glue tokens);
    - Modify: `skills/workstream/verbs/create.md` (compile to
      `this hand-off:` with `--file "$HOOKS"`; delete stamp→`<debrief>`
      fill; seed-only still no root commit);
    - Modify: `skills/workstream/verbs/save.md` (preserve `## Hooks
      (compiled)` and `hooks-compiled:`; write `this hand-off:` only;
      stop saying the hand-off IS `<worktree>/WORKSTREAM.md`);
    - Modify: `skills/workstream/SKILL.md` (*Host layout* one stamp
      job; Discipline root-commit example; live-hand-off bullet is
      Coordinates `this hand-off:`);
    - Modify: `skills/workstream/flow.md` (glue command vs ritual
      floor; Scenario C reads `this hand-off:`);
    - Modify: `skills/workstream/verbs/close.md`.
    - `recycle.md` needs no fill restatement (it already re-applies
      step 6); confirm `## Hooks (compiled)` is not in the blanked
      per-unit list; confirm `$HOOKS` stays the absolute root path.
  - Change: Mechanism *workstream consumer* compile + Host layout +
    save preserve. Grep gate as specified (two commands).
  - Verify: red-proofs 2, 7, 9, 10. Grep gate. Parser suite still green.

- [ ] **Slice 3: clankshop materialize + fill + PACK seam**
  <requires: 2>
  - Files:
    - Modify: `skills/clankshop/verbs/setup.md` (step 5 = hooks walk;
      check becomes step 6; quote-edit Guard 24–31: STOP green-list,
      resume parenthetical, range **(1–6)**; Notes pathspec includes
      `hooks/`);
    - Modify: `skills/clankshop/verbs/migrate.md` (same step before
      check);
    - Modify: `skills/clankshop/verbs/check.md` (finding only when
      unfinished predicate: skeleton present AND (`$HOOKS` missing OR
      known H2 present with empty body); names setup; no write;
      missing H2 is not a finding);
    - Modify: `skills/clankshop/PACK.md` (seam note; no `version:`
      bump);
    - Modify: `skills/clankshop/scripts/tests/` (red-proofs 6, 8, 11,
      12; new cases in an existing suite or a small
      `hooks-fill-test.sh` wired into `run.sh`).
  - Change: Mechanism *clankshop glue*. Check stays report-only.
    Presence test shared.
  - Verify: red-proofs 6, 8, 11, 12.
    `bash skills/clankshop/scripts/tests/run.sh` ALL GREEN.
    Slice 1–2 tests still green.

- [ ] **Slice 4: doctrine convention** <requires: 2>
  - Files:
    - Modify: `skills/skill-builder/docs/DOCTRINE.md` (Project hooks
      section; four destinations; rule 3 narrow hooks mkdir; glue
      bullet; stamp-consumers sentence — **after** slice 2);
    - Modify: `skills/skill-builder/verbs/new.md` (orthogonal
      question; SKILL.md sentence + known ids; **do not** scaffold
      `templates/hooks.md`);
    - Modify: `docs/design/2026-08-19-two-roots-simple-spec.md`
      (holds-column `hooks/`);
    - Modify: `skills/skill-builder/docs/BOUNDARY-AUDIT.md` only if a
      one-line pointer is needed (glue lives in hooks files, not in
      leaf descriptions).
  - Change: Mechanism *Convention*. No new lint number. Requires 2 so
    the stamp-consumers sentence is not a lie. May run in parallel
    with slice 3.
  - Verify: lint `fails=0`. Doctrine contains
    `<agent-workspace>/hooks/<skill>.md`. Two-roots holds-column lists
    `hooks/`. `new.md` asks the hooks question and does not scaffold
    `templates/hooks.md`. No `foreman` oven in the glue bullet.

## Done when

All four slices checked. Verification block green.

- `setup` then `create` on a fixture: hand-off compiled hooks are
  `/backlog debrief` for both ids, written at `this hand-off:`.
- Already-seeded `setup` (doctrine present) fills `$HOOKS` without
  re-seeding. `migrate` fills before check.
- `create` with a planted stamp and **empty** hooks file: compiled
  hooks stay `(empty)` (no stamp fill).
- Second `create` leaves planted glue intact.
- `setup` / `check` with no workstream skeleton: no file created, no
  finding.
- `check` never writes the file (checksum).
- `save` after create preserves `## Hooks (compiled)`.
- In-place create does not plant `<root>/WORKSTREAM.md`.
- No `<agent-workspace>/templates/hooks.md`. `new.md` does not
  scaffold a generic `hooks.md`.
- Doctrine states the convention; two-roots lists `hooks/`;
  `workstream` is the only implemented consumer.

Close-the-books: `docs/BACKLOG.md` only if this walk surfaces a new
leftover (the remaining `/backlog task` / `issue` mentions are
already scoped out, not a surprise). Do not invoke `/backlog`.
Do not unpark BL-36.

## Review history

### 2026-08-20 — needs-rework

Must-fix (do not sequence until these are folded):

1. **Primary workshop path never compiles pack glue.** Location: Goal / clankshop
   `setup` “first workshop… no-op” / *When it runs* / red-proof 7 / Done when.
   3A (face never creates the file) + snapshot only at `create`/`recycle` + no
   re-parse on `load`/`save` + red-proof 7 (stamp must not fill) means
   `setup → first create → ship` compiles `(empty)` and keeps it for the life
   of a plan/roadmap stream (`recycle` is not their advance). A later `check`
   fill updates the project file, not the in-flight hand-off. That is a
   regression vs `verbs/create.md` 119–123. “Late glue” is never, not late.
   Pick one and rewrite Goal / Rejected / red-proofs: un-reject 3B (`setup`
   materializes skeleton if absent *and* fills; `create` still
   materialize-if-absent for standalone; neither overwrites), or compile at
   the feature-completion seam when the snapshot is still empty *and* still
   materialize at setup so the file exists before that seam. Do not restore
   the stamp fill.

2. **Grep gate cannot pass with the allowed leftover.** Verification
   `rg '<debrief>|Seeded from clankshop'` “must be empty” vs “allowed:
   one Host-layout `Seeded from clankshop` for tracker-line permission.”
   Encode the leftover (split greps / counted assertion). Do not claim both.

3. **Instance path is Coordinates `this hand-off:`, not
   `<worktree>/WORKSTREAM.md`.** In-place writes
   `<root>/.workstreams/<stream>/WORKSTREAM.md` (`create.md` in-place step 6,
   `recycle.md` 35–37). Compiling to `<worktree>/WORKSTREAM.md` when
   `<worktree>` is the root plants a tracked root `WORKSTREAM.md`. Recycle
   already STOPs on mismatch.

4. **Doctrine-touching rule 3 is cited half.** The owner exception says
   every skill other than `clankshop`/`journal` **never `mkdir`** a home.
   Standalone `create` creating `.dev/` is workspace standup by a leaf.
   Amend rule 3 with a narrow hooks mkdir, or stop having `workstream`
   create the workspace (3B).

5. **Fourth landing class vs two current maps.** `DOCTRINE.md` 420–426
   still has three destinations; two-roots (`status: current`) workspace
   holds-column has no `hooks/`. Slice 4 must edit both (two-roots
   holds-column, not BL-36 unpark).

6. **`check` attended fill vs `check.md:39`.** “Fixes are ordinary routed
   work, not part of the check.” Attended in-walk fill is a write inside
   `check`. Rewrite step 6 to name the one attended exception, or keep
   check report-only and route the fill to `setup`.

7. **Slice 4 `<requires: 1>` can land lying doctrine.** The
   stamp-consumers sentence (“workstream no longer gates `<debrief>`”)
   is only true after slice 2. Slice 4 requires 2 for that sentence, or
   move it into slice 2.

Nice-to-have: pin `hooks.sh compile` argv; encode hook ids without spaces
in `key=value` facts; `unknown=` for multiple extras; missing-file
`hash=` / stamp; split flow.md’s remaining #1 ritual (tally,
route-before-loss) from the glue command so “skip if empty” does not
drop the floor; generalize `SKILL.md:168` `` `/backlog debrief`'s
captures ``; say whether clankshop fill shells `workstream`’s parser or
duplicates it; Host layout “governs exactly two things” → one
(tracker-line); seed-only `create` “no root commit” vs attended hooks
commit.

Ground-check: `checked=20` `unresolved_count=4` — all four are
slice-1 create paths (`hooks.sh`, tests, `templates/hooks.md`), not
drift.

Independent skeptic (read-only explore) reached the same primary-path
verdict. Confidence on (1)–(3) high (traced against HEAD); (4)–(6)
high; (7) medium-high.

### 2026-08-20 — revise dispositions

| Id | Action | Disposition |
|---|---|---|
| F1 | keep — un-reject 3B | resolved — setup copies skeleton if absent then fills; create still materialize-if-absent; neither overwrites; Goal/Approach/Mechanism/red-proof 8; 3A now Rejected |
| F2 | keep | resolved — two grep commands; Seeded-from count exactly one Host-layout hit |
| F3 | keep | resolved — instance is Coordinates `this hand-off:`; red-proof 9 |
| F4 | keep | resolved — rule 3 narrow mkdir (`hooks/` only; no `doctrine/`); 3B setup is the assembler path |
| F5 | keep | resolved — four destinations; two-roots holds-column `hooks/` in slice 4 |
| F6 | keep | resolved — check report-only; finding names `/clankshop setup` |
| F7 | keep | resolved — slice 4 `<requires: 2>` |
| n1 compile argv | keep-optional taken | resolved — `parse`/`compile` argv pinned |
| n2 fact-key spaces | keep-optional taken | resolved — slugs `feature-completion` / `after-eventful-ship` |
| n3 unknown= | keep-optional taken | resolved — comma-separated |
| n4 missing hash | keep-optional taken | resolved — `hash=none` |
| n5 glue vs ritual | keep-optional taken | resolved — skip-if-empty is the glue command only |
| n6 SKILL.md:168 | keep-optional taken | resolved — generalize to compiled-hook captures |
| n7 clankshop parser | keep-optional taken | resolved — no shell-out; duplicate empty-H2 test |
| n8 Host layout one | keep-optional taken | resolved — stamp governs exactly one thing |
| n9 seed-only commit | keep-optional taken | resolved — `--seed-only` still no root commit |

### 2026-08-20 — needs-rework (delta re-review)

Prior F1–F7 are in the body, not only the disposition table. Four new
must-fix items from the independent delta pass. Do not sequence.

1. **`check` names `/clankshop setup`; that command does not fill on a
   seeded host (or via `migrate`).** Fill is an unnamed insertion
   between setup steps 4 and 5. HEAD setup: already-green workshop →
   stop, write nothing; resume-at-unfinished skips a done step 4 and
   jumps to 5 (`check`), skipping the insertion. `migrate.md` is not
   in slice 3; it seeds, writes the door, then `check`. After this
   feature, `check` is red on empty glue and points at `setup`, which
   then hits the resume skip. Greenfield `setup → create` still works;
   existing workshop, migrate, and “check finding → run setup” do not.
   Fix: number the fill as its own walk step with an unfinished test
   (file missing **or** a known H2 empty). Run it from `migrate`
   before check. Setup “already seeded” must still run that step (or
   must not treat empty glue as seeded). Slice 3 lists `verbs/migrate.md`.

2. **`check` finding is unconditional; setup skip is not.**
   `workstream` is `optional:` in PACK.md. Member not installed →
   setup skips the whole step; check still findings on missing file
   and names setup, which no-ops. Gate ungreenable. Fix: same
   presence test on both verbs (sibling `templates/hooks.md`). Finding
   only when the skeleton exists and glue is empty.

3. **`save` can wipe the snapshot; no slice names `save.md`.**
   Spec says `load`/`save` do not recompile. HEAD `save.md` 18–21
   regenerates the hand-off from the bundled template in place.
   Feature-completion is debrief #1 then `save`. Create’s compiled
   block is lost; later features compile `(empty)` on the primary
   path. Fix: slice 2 modifies `verbs/save.md` — preserve `## Hooks
   (compiled)` and `hooks-compiled:` verbatim; write Coordinates
   `this hand-off:` only.

4. **Create/recycle step 2 is cwd-relative.** Procedure still says
   “If `hooks/workstream.md` is absent.” Recycle runs in the worktree
   (`recycle.md` line 1) and re-applies create step 6. A relative
   `.dev/hooks/` write is the untracked twin Path-and-tree forbids.
   Fix: every materialize/parse/compile `--file` is absolute
   `<root>/<agent-workspace>/hooks/workstream.md`.

Nice-to-have: SKILL.md 146–149 / `save.md:18` / flow.md Scenario C
still say the hand-off IS `<worktree>/WORKSTREAM.md` (in-place lie);
red-proof that `check` leaves the tree byte-identical.

Ground-check: `checked=21` `unresolved_count=4` — still the four
slice-1 create paths, not drift.

Independent delta reviewer (read-only explore). Confidence high on
(1)–(3) against HEAD setup/save/check; (4) high against recycle cwd
+ relative path.

### 2026-08-20 — revise dispositions (delta + template split)

| Id | Action | Disposition |
|---|---|---|
| D1 numbered step + migrate | keep | resolved — setup step 5 / migrate before check; unfinished = skeleton present AND (missing file OR empty known H2); already-seeded stop includes that test; red-proof 11 |
| D2 optional workstream | keep | resolved — same presence test on setup, migrate, check; no finding when skeleton absent; red-proof 12 |
| D3 save wipes snapshot | keep | resolved — `save.md` preserves `## Hooks (compiled)` and `hooks-compiled:`; slice 2 lists it; red-proof 10; in-place hand-off prose in SKILL.md / save.md / flow.md Scenario C |
| D4 cwd-relative path | keep | resolved — `$HOOKS=<root>/<agent-workspace>/hooks/workstream.md` on create, recycle, setup, migrate, parse, compile |
| T1 no generic / project template | keep | resolved — workstream keeps its own `skills/workstream/templates/hooks.md`; no `new` scaffold; no `<agent-workspace>/templates/hooks.md`; doctrine format is the reference |

### 2026-08-20 — needs-rework (second delta)

Prior F1–F7 and D1–D4/T1 are in the body. Greenfield `setup → create`
compiles `/backlog debrief` (red-proof 8). Save preserve and `$HOOKS`
are specified. Two new must-fix items; do not sequence.

1. **HEAD setup Guard is an exhaustive if/else; the spec only patches
   STOP.** Location: Mechanism *clankshop glue* setup bullet; slice 3
   `setup.md`. HEAD `verbs/setup.md` 24–31: green list → stop;
   not-green parenthetical (missing stamp / leftover slots / no door /
   no records) → resume at unfinished **(1–5)**. Empty `$HOOKS` with
   stamp/slots/door/records matches **neither** arm if those lists
   stay exhaustive → dead branch, write nothing, `check` still
   findings. Even if resume is forced, `(1–5)` with hooks as 5 and
   check as 6 **drops check from resume**. Red-proof 11 does not
   assert post-fill check green. Fix: slice 3 quotes and edits **all
   three** Guard clauses — STOP green-list includes the hooks
   unfinished test; resume parenthetical includes it; range is
   **(1–6)**. Extend red-proof 11: after that setup, step 6 check is
   green and `$HOOKS` is filled.

2. **Missing known H2 vs empty body.** Parse: missing H2 → empty
   (no extra glue). Setup fill: missing H2 → do not add; report.
   Unfinished / check finding: “known H2 empty” names setup. A
   hand-deleted `## Feature completion` makes check name setup, which
   will not restore the heading — gate cannot green (same class as
   D2). Fix: unfinished test and check finding =
   presence ∧ (`$HOOKS` missing ∨ **(known H2 present ∧ body
   empty)**). Missing H2 is not a setup-fill defect; do not name
   setup. Red-proof 12 third case: skeleton present, file present,
   one known H2 omitted → no setup-named finding; checksum unchanged.

Nice-to-have: setup Notes commit pathspec add
`<agent-workspace>/hooks/`; clankshop empty-H2 helper must strip
surrounding whitespace (same as parse) or red-proof 8 dies; Host
layout `$HOOKS` not cwd-relative prose; migrate Notes “step 5 is
green” if check becomes step 6.

Ground-check: `checked=24` `unresolved_count=4` — slice-1 create
paths, not drift.

Independent delta reviewer (read-only explore). Confidence high on
(1) against HEAD setup.md 24–31; high on (2) against the three
rules in this spec.

### 2026-08-20 — revise dispositions (Guard + missing H2)

| Id | Action | Disposition |
|---|---|---|
| G1 setup Guard three arms | keep | resolved — slice 3 quote-edits STOP green-list, resume parenthetical, range (1–6); red-proof 11 asserts post-fill check green and dead-branch if parenthetical unedited |
| G2 missing H2 vs empty body | keep | resolved — unfinished/check = presence ∧ (`$HOOKS` missing ∨ known H2 present with empty body); missing heading is not a setup-named finding; red-proof 12c |
| n10 setup Notes pathspec | keep-optional taken | resolved — `<agent-workspace>/hooks/` on the commit pathspec |
| n11 whitespace strip parity | keep-optional taken | resolved — clankshop empty-H2 helper uses the same strip as parse |
| n12 Host layout $HOOKS | keep-optional taken | resolved — Host layout names absolute `$HOOKS` |
| n13 migrate Notes step | keep-optional taken | resolved — retarget “step 5 is green” to the new check step |

### 2026-08-20 — approve

Delta only: Guard 24–31 three quote-edits and the missing-H2 predicate.
Independent reviewer: implementable against HEAD `setup.md` 23–31.

- Empty `$HOOKS` + stamp/door/records → resume, not STOP, not a dead
  branch (STOP green-list includes unfinished hooks; resume
  parenthetical includes it).
- Resume range `(1–6)` still runs check after step 5.
- Deleted `## Feature completion` does not name setup; check can
  still go green (G2 trade: no pack glue on that heading).

Non-blocking (folded 2026-08-21, cheap): red-proof 11 plants
**absent** `$HOOKS`, not a present file with empty known bodies.
The Guard edit still covers that path if resume uses the **full**
unfinished predicate, not a missing-file-only gloss.

Safe to sequence. Independent delta (read-only explore). Confidence
high on the four hunt questions against HEAD 23–31.

### 2026-08-21 — approve nit folded

| Id | Action | Disposition |
|---|---|---|
| A1 red-proof 11 empty-body already-seeded | keep-optional taken | resolved — red-proof 11 now (a) absent `$HOOKS` and (b) present file, empty known H2 bodies; resume must use the full unfinished predicate |