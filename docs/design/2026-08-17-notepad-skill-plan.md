---
doctype: plans
status: open
created: 2026-08-17
updated: 2026-08-17
tags: [plan]
---

# notepad — Implementation Plan

Tracer-bullet: slice 1 is minting a contract-conformant `notes/` record
**without** `records.sh` (the newest path). Later slices add the
opportunistic `records.sh` branch, the skill prose, then the backlog
cutover.

Spec: `docs/design/2026-08-17-notepad-skill.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Invariants:** notes are journal's store; notepad is a client. Do not
  give notepad ownership of the contract. Do not write `history.tsv` by
  hand. Do not register against this library's real `AGENTS.md`.
- **Live-API gotchas:** `records.sh` `cmd_new` slug + collision is
  `skills/journal/scripts/records.sh:171-181`. Template slots are
  `<title>` and `<date>` (`fill` at lines 136–155). Front-matter is five
  keys (`skills/journal/SKILL.md` *The record contract*). Commit-tree
  probe is `skills/journal/SKILL.md:94-103` (already copied onto
  backlog). Description names no sibling. `description:` ≤ ~700 chars
  (hard cap 1024).
- **Coexisting work:** stream `grok` (`stream/grok`) holds this branch;
  unshipped `8506acd` is the backlog review fold. Sibling stream `feat`
  is a different brief — do not drive it. Root checkout may still hold
  unrelated dirt (mailbox scripts + untracked design docs) — do not
  sweep it into stream commits.
- **CI-safety / scope:** `skills/skill-builder/scripts/skills-lint.sh`
  must stay `fails=0`. Markdown-only slices need no host full gate.
  Slice 1–2 tests use `mktemp` fixtures only; they must not write
  `.records/` in this repo.
- **Pack version:** adding the member bumps `skills/clankshop/PACK.md`
  `version:` 2.2.0 → 2.3.0 (member-set rule in that file).
- Every slice's requirements implicitly include this section and the spec.

## File map

| Path | Responsibility |
|---|---|
| `skills/notepad/scripts/note-mint.sh` | Resolve root; mint or stamp; print facts + path |
| `skills/notepad/scripts/tests/note-mint-test.sh` | PATH-isolated / fixture smoke |
| `skills/notepad/scripts/tests/run.sh` | Test entrypoint |
| `skills/notepad/templates/notes.md` | Owner-carried notes template (moved) |
| `skills/notepad/scripts/scoped-commit.sh` | Copy of backlog's pathspec-atomic commit |
| `skills/notepad/SKILL.md` | Trigger, dispatch, shared discipline, edges |
| `skills/notepad/verbs/write.md` | Find-or-update, else mint |
| `skills/notepad/verbs/find.md` | List / retrieve |
| `skills/notepad/verbs/supersede.md` | Close old, mint replacement |
| `skills/backlog/SKILL.md` | Drop note row + notes lazy-deploy |
| `skills/backlog/verbs/debrief.md` | Route facts through notepad `write` |
| `skills/backlog/verbs/issue.md` | Substantial analysis via notepad `write` |
| `skills/clankshop/PACK.md` | optional member + 2.3.0 + roster row |
| `README.md` | Inventory row + helpers list |

---

## Slices

- [ ] **Slice 1: mint without records.sh (the tracer)** <requires: —>

  - Files:
    - Create: `skills/notepad/templates/notes.md` (copy of
      `skills/backlog/templates/notes.md` — leave the backlog copy
      until slice 4)
    - Create: `skills/notepad/scripts/note-mint.sh`
    - Create: `skills/notepad/scripts/tests/note-mint-test.sh`
    - Create: `skills/notepad/scripts/tests/run.sh`
  - Change: `note-mint.sh` is the no-`records.sh` minter. Usage:

    ```
    note-mint.sh mint  <records-root> <title>
    note-mint.sh stamp <abs-path> [--status <status>]
    ```

    `mint`: create `<records-root>/notes/` if needed; refuse an empty
    slug; write `<records-root>/notes/YYYY-MM-DD-<slug>.md` from
    `../templates/notes.md` using the same slot fill and the same slug
    / collision rules as `records.sh` `cmd_new`; print:

    ```
    records-root=<abs>
    path=<abs>
    rel=notes/YYYY-MM-DD-<slug>.md
    mode=file
    ```

    `stamp`: rewrite `updated:` (and optionally `status:`) in the
    front-matter block only — same semantics as `records.sh` `stamp`.
    Print `path=` / `mode=stamp`. Never create `history.tsv`,
    `scripts/`, or any store other than `notes/`. Never decide
    update-vs-mint.

    Resolve the script's own directory for the bundled template
    (`$(cd "$(dirname "$0")/.." && pwd)/templates/notes.md`).
    `<records-root>` is an argument (the caller resolves
    `records-root:`); the script does not scan `AGENTS.md` in this
    slice.

  - Verify: write `skills/notepad/scripts/tests/note-mint-test.sh` as a
    `mktemp` fixture (nothing touches this repo's tree except reading
    the script). Cases:
    1. `mint` on a fresh root creates `notes/YYYY-MM-DD-alpha-fact.md`
       with `doctype: notes`, `status: open`, `created:`/`updated:`
       equal to today, and `# Alpha fact` after fill.
    2. Second `mint` of the same title the same day writes
       `...-alpha-fact-2.md` (collision).
    3. Empty title / punctuation-only title exits non-zero and writes
       nothing.
    4. `stamp --status superseded` changes `status:` and `updated:`,
       leaves `created:` alone.
    5. After `mint`, `<records-root>` contains only `notes/` — no
       `history.tsv`, no `scripts/`, no `templates/`.

    `scripts/tests/run.sh` runs that test. Expected: `note-mint-test:
    N passed, 0 failed` and exit 0.

    Run: `cd <worktree> && /bin/bash skills/notepad/scripts/tests/run.sh`

- [ ] **Slice 2: opportunistic records.sh** <requires: 1>

  - Files:
    - Modify: `skills/notepad/scripts/note-mint.sh`
    - Modify: `skills/notepad/scripts/tests/note-mint-test.sh`
  - Change: add a third subcommand (or a flag on `mint`):

    ```
    note-mint.sh mint <records-root> <title>
    ```

    After resolving `<records-root>`, if
    `<records-root>/scripts/records.sh` is executable:
    - if `<records-root>/templates/notes.md` is absent, copy the
      bundled template there
    - run `"$RR/scripts/records.sh" new notes --title "<title>"`
    - print `mode=records` and `path=` / `rel=` from that tool's
      stdout
    Else keep slice 1's file mint (`mode=file`).

    `stamp` likewise: if `records.sh` exists and the path is under that
    root, call `records.sh touch` (and `done --as <status>` only when
    the caller asked for a *closing* status — `superseded` /
    `dropped` / `done` / `consumed`). Closing through `done` is how
    the ledger line gets written. File-mode `stamp --status
    superseded` stays a front-matter rewrite (spec: no hand-written
    ledger).

    Do not implement find/update judgment here.

  - Verify: extend the fixture.
    1. Root *without* `scripts/records.sh` → `mode=file` (slice 1
       still green).
    2. Root *with* a copy of `skills/journal/scripts/records.sh` plus
       `templates/notes.md` already in place → `mode=records`, path
       exists, `records.sh check` on that fixture exits 0 for the new
       note.
    3. Root with `records.sh` but *no* `templates/notes.md` → script
       copies the bundled template, then `new` succeeds.

    Run: `cd <worktree> && /bin/bash skills/notepad/scripts/tests/run.sh`
    Expected: all previous plus the three new cases pass.

- [ ] **Slice 3: skill package (write / find / supersede)** <requires: 2>

  - Files:
    - Create: `skills/notepad/SKILL.md`
    - Create: `skills/notepad/verbs/write.md`
    - Create: `skills/notepad/verbs/find.md`
    - Create: `skills/notepad/verbs/supersede.md`
    - Create: `skills/notepad/scripts/scoped-commit.sh` (byte-copy of
      `skills/backlog/scripts/scoped-commit.sh`)
  - Change: thin router + three verbs, following the spec §§1, 3, 4.
    Description is the spec's trigger text (tune only if lint length
    fails). Edges block as specified. Shared discipline: records-root
    resolver (scan `AGENTS.md` / `CLAUDE.md` for `^records-root:`,
    else `.records`), commit-tree probe (cite journal's wording; do
    not invent a third variant), capture-commit policy, write-only
    mode for a sweep.

    `write.md`: find-or-update then mint; call `note-mint.sh`; one
    fact per note; Done when as spec §6.

    `find.md`: `records.sh list --type notes` when present, else
    scan `notes/*.md`; print paths + titles; no mint.

    `supersede.md`: mint or confirm successor, then close old
    (`note-mint.sh stamp` / `records.sh done --as superseded`).

    No `/backlog` / `/journal` names in the description. A body
    pointer at the contract section is allowed (`journal` SKILL.md
    *The record contract*) — cite, do not restate.

  - Verify:
    - `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh <worktree>`
      Expected: `fails=0`. Target-relevant new WARNs at most the
      worktree-vs-clone symlink note for `notepad`.
    - Grep the new description for sibling slugs (`backlog`,
      `journal`, `debugger`) — expected: no matches.
    - Read `SKILL.md` + the three verb files against spec §§4 and 6;
      every failure row has a matching Done-when / STOP.

- [ ] **Slice 4: cutover + pack wiring** <requires: 3>

  - Files:
    - Delete: `skills/backlog/verbs/note.md`
    - Delete: `skills/backlog/templates/notes.md`
    - Modify: `skills/backlog/SKILL.md` (drop the note dispatch row;
      drop `notes` from the lazy-deploy list)
    - Modify: `skills/backlog/verbs/debrief.md` step 3: facts →
      notepad `write` write-only; keep
      `task`/`bug`/`issue`/`feedback`/`ticket`
    - Modify: `skills/backlog/verbs/issue.md`: substantial analysis
      that needs a dated note goes through notepad `write` write-only,
      then link
    - Modify: `skills/clankshop/PACK.md`: `version: 2.3.0`; add
      `notepad` to `optional:`; add a helper roster row
    - Modify: `README.md`: helpers list + inventory table row
      (alphabetically near `mailbox` / `journal`)
  - Change: implement spec §5 exactly. No alias. `install.sh` needs
    no edit (directory discovery).
  - Verify:
    - `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh <worktree>`
      Expected: `fails=0`.
    - `rg -n '/backlog note|verbs/note\\.md|templates/notes\\.md' skills/backlog`
      Expected: no remaining mint path (debrief/issue may mention
      notepad `write`).
    - `rg -n 'notepad' skills/clankshop/PACK.md README.md` — pack
      `optional:` line contains `notepad`; README table has a row.
    - Confirm `PACK.md` frontmatter `version: 2.3.0`.

## Done when

- `skills/notepad/` exists with the layout in the spec; lint
  `fails=0`.
- A fixture mint without `records.sh` produces a contract-conformant
  note and no other records-layer files.
- A fixture mint with `records.sh` uses it (`mode=records`) and
  `records.sh check` accepts the note.
- `/backlog note` is gone; debrief/issue route facts through notepad
  `write`.
- Pack manifest is 2.3.0 and lists `notepad` as optional.

_On completion (before landing), run the host's close-the-books sweep
(this host has no records layer: conversational debrief only)._
