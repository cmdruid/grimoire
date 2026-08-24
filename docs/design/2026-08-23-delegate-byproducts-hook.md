---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Delegate byproducts hook — return-contract overlay — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Kinds (land first):
`docs/design/2026-08-23-workspace-kinds.md` — hook **folders**,
staged scripts, named seams.

Prior split:
`docs/design/2026-08-23-backlog-living-trackers.md` still carries
delegate consumer requirements inherited from the pre-split draft.
This spec hard-cuts that overlap: S1 deletes every delegate
requirement, verification row, and `skills/delegate/**` path from the
living-trackers spec, then owns the delegate contract completely. The
living-trackers spec owns backlog only. This spec publishes the hook
file and fills it at workshop birth.

Lineage this amends, not replaces:
`docs/design/2026-08-20-project-hooks.md` (file-shaped
`hooks/<skill>.md`; workstream first consumer; **out of scope:
hooks for any skill other than workstream**). The workspace spec
replaces the file shape with `hooks/<skill>/<seam>.md`.

Settled 2026-08-23 in conversation (grill + split). Every branch
below is resolved.

## Problem

`delegate`’s return contract needs a third part — leftovers from a
dead cheap context that are not the deliverable. That generic contract
is portable; the host-specific classification, routing, and persistence
policy is host opinion. Live
`skills/delegate/SKILL.md:170–180` hard-codes a kinds list and names
`/backlog debrief` as the workshop drain. That is a leaf naming a
collaborator and a closed taxonomy that will rot when the host’s
trackers change.

The project-hooks convention already exists so glue lives in the
workspace, inspectable and overwritable. Workstream is the first
consumer (extra **command** at a seam). Delegate was excluded
because it is not a multi-step loop. The exclusion left the
byproducts definition in `SKILL.md`.

Running `/backlog debrief` on every `/delegate` return is the wrong
grain: debrief gathers git status, a merge-base diff, and the
conversation, then files and commits. Workstream fires that at
feature completion. Delegate returns per dispatch. The live skill
already says stash byproducts so the **host** sweep needs no special
handling — then contradicts itself with the `/backlog debrief`
sentence.

## Goal

After this feature:

- Delegate publishes
  `<agent-workspace>/hooks/delegate/byproducts.md` (default
  `.dev/hooks/delegate/byproducts.md`) from the exact package skeleton
  `skills/delegate/templates/hooks/byproducts.md`. Missing or empty
  body = no host overlay; the generic Byproducts return part remains.
- `SKILL.md` always requires three compact parts: Deliverable, Status,
  and generic Byproducts (leftovers outside the deliverable; compact;
  empty is valid). It defines no kinds. A filled hook augments only the
  Byproducts instructions.
- The project hook is read **once per dispatch**, before the prompt is
  sent. That one snapshot governs both the delegate prompt and return
  handling. A host overwrite takes effect on the next `/delegate`.
- Clankshop copies the skeleton if absent and fills an **empty**
  `byproducts.md` with stash-only pack prose (not `/backlog debrief`,
  not a stem list). Non-empty body is incumbent.
- Named-seam doctrine and `skill-builder/verbs/new.md` changes land in
  workspace S2. This spec never edits either surface.
- The agent reads the one known file directly. No runtime parser,
  staged delegate entrypoint, compatibility shim, or fallback path.
  Do not glob and do not shell `workstream`’s `hooks.sh`.
- Hard-cut every legacy taxonomy and `/backlog` return-contract
  reference across the delegate package, including
  `references/codex.md`; do not leave dual prose.
- Remove the delegate consumer from the living-trackers spec's Goal,
  Approach, Mechanism table, Verification, and S3 slice. There is one
  owner and no sequencing dependency between those two features.
- Lint `fails=0`. Delegate and clankshop harnesses green.

## Approach

**Chosen: an always-three-part portable return contract plus one
optional host-policy overlay; read once per dispatch; pack fills empty;
host overwrites.**

Same folder convention as the workspace spec. Interpretation is
skill-specific: workstream empty seam file = no extra glue
*command*; delegate empty `byproducts.md` = no extra host-policy
*overlay*. The portable Byproducts contract remains in the skill. The
non-empty project bytes are inspectable host policy appended to it.

**Rejected: make the third return part conditional on the hook.** A
bare install would lose the dead-context leftovers the skill exists to
carry back. The pack enriches; it is not a functional floor.

**Rejected: keep the kinds list in `SKILL.md`.** Not inspectable, not
overwritable, names a tracker taxonomy.

**Rejected: `/backlog debrief` as the filled body / as a per-return
command.** Wrong grain. Filing stays workstream `Feature completion`
(pack already fills that with `/backlog debrief`).

**Rejected: pack fill lists `tasks` / `issues` / `feedback`.**
Pre-sorting is debrief’s job (compiled modules). This fill says what
to collect and that filing is not this return.

**Rejected: snapshot once for the session the way workstream snapshots
at create.** An overwrite must take effect on the next call. Also
rejected: re-read during return handling, which can split one dispatch
across two contracts. Snapshot once **per dispatch** and retain those
bytes until that return is handled.

**Rejected: a runtime reader or staged `scripts/delegate/` entrypoint.**
The front door is already loaded and an agent can read one known
Markdown file directly. A helper, materializer, shim, or alternate
path adds machinery without adding a fact the agent cannot obtain.

**Rejected: shared `skill-builder` hooks parser.** Floor (BL-6).
Second consumer copies the format from doctrine. Clankshop fill does
not shell `workstream/scripts/hooks.sh`. Extend the existing
face-local `hooks-glue.sh` with the explicit delegate modes below; do
not add a second helper or invent a generic hooks engine.

**Rejected: a generic before/after on every delegate mechanism.**
One named seam: the return contract.

## Mechanism

### Convention

Consume the hook-folder and named-seam contract after workspace S2.
This spec only **adds** the `byproducts` seam for `delegate`. Do not
re-edit two-roots, `skills/skill-builder/docs/DOCTRINE.md`, or
`skills/skill-builder/verbs/new.md`.

### Path and tree

| File | Owner | Lives |
|---|---|---|
| `skills/delegate/templates/hooks/byproducts.md` | `delegate` | package-only empty skeleton |
| `<agent-workspace>/hooks/delegate/byproducts.md` | the project | tracked config |

Skeleton: an empty file. No comment, sibling name, taxonomy, or
`/backlog` token.

Narrow mkdir: workspace kinds. The pack assembler materializes the
project copy during setup / migrate when this member is present; it
never overwrites a present file. Bare `delegate` has no setup and needs
no project copy to retain its generic return contract.

### `delegate` consumer

**Known seam:** `byproducts.md`.

**When:** every `/delegate` dispatch, before the prompt is sent. Read
the **project** file, not the bundled skeleton, exactly once. Retain
the stripped body as that dispatch's `byproducts_overlay`; inline the
same bytes into the prompt and use the same bytes when handling and
stashing the return. Do not touch the file again until the next
dispatch.

**Read:** resolve `<agent-workspace>` from the first line-start
`agent-workspace:` in `AGENTS.md`, then `CLAUDE.md`, else `.dev`.
The front door is already loaded; no resolver script runs. Read only
`<agent-workspace>/hooks/delegate/byproducts.md`. Missing or empty
after surrounding-whitespace strip → `byproducts_overlay` is empty.
Non-empty → retain and inline the exact stripped body. No H2 grammar,
runtime helper, staged script, alternate path, or glob.

**Skill prose** (`skills/delegate/SKILL.md` return-contract section):

> Every delegation returns **three** compact things:
>
> 1. **Deliverable** — …
> 2. **Status** — DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
>    (unchanged).
> 3. **Byproducts** — leftovers from this dispatch that are not part
>    of the deliverable. Compact list; empty is valid. Append the
>    dispatch-scoped `byproducts_overlay` instructions when non-empty.

Delete the live kinds bullet list and the `/backlog debrief` sentence
(`SKILL.md` return-contract L170–180) if the sibling living-trackers
spec has not already (idempotent). Hard-cut every other contract echo
in `SKILL.md`: Overview, isolated-worktree brief shape, status routing,
stash rule, weak-detector note, fallback logging, Quick reference, and
Done when. Each block below is the **complete replacement span**, not a
substring to add alongside incumbent prose. For the harness, a
normalized span trims outer whitespace and joins Markdown continuation
lines with one ASCII space. Each span occurs exactly once and must equal
these bytes after normalization; extra text inside the span fails.

- Overview `byproducts` bullet:

  ```markdown
  - the **byproducts** — leftovers outside the deliverable — returned compactly because the delegate's context is discarded.
  ```

- Isolated-worktree brief paragraph:

  ```markdown
  The brief shape that has carried judgment-heavy sweeps cleanly is a **narrow, list-shaped brief** (the exact sites, the exact transform) with an explicit scope boundary. Same-pattern sites outside the brief return as Byproducts; never silently expand scope.
  ```

- `NEEDS_CONTEXT` status-routing bullet:

  ```markdown
  - **NEEDS_CONTEXT** → record the missing prompt context as a Byproduct, then re-dispatch with the gap filled.
  ```

- Stash paragraph:

  ```markdown
  **Stash returned Byproducts immediately** so they survive context compaction to the host's close-the-books sweep.
  ```

- Weak-detector paragraph:

  ```markdown
  **Weak model = weak detector.** A cheap delegate spots fewer Byproducts than you would. Byproduct-rich work is a reason to route UP, not down.
  ```

- Fallback paragraph:

  ```markdown
  **Log every fallback as a Byproduct** (route X failed → fell back to Y). It signals that the confirmed route may need re-confirming.
  ```

- Quick-reference row:

  ```markdown
  | return | Deliverable + Status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED) + Byproducts (leftovers outside the deliverable; empty OK; append overlay when present); stash now |
  ```

- Done-when paragraph:

  ```markdown
  Mechanism picked; route confirmed or pre-confirmed; Deliverable + Status + Byproducts received; trust re-established from evidence; Byproducts stashed. If the route failed: fallback or floor named.
  ```

- `references/codex.md` prompt paragraph:

  ```markdown
  In the prompt: name exactly what's in scope (the task, or the file list), point at the plan file by path, and state what's out of scope (no drive-by refactors, no dependency bumps, no submodule pointer changes). Tell Codex **not to commit** and not to run stack/network verifications (see gotcha). Ask it to report the files it touched, any gate output, and leftovers not part of the deliverable, following the supplied Byproducts instructions.
  ```

The canonical item 3 is exactly the quoted three sentences above; it
ends before the unindented status-routing paragraph. There is no
compatibility paragraph, old-vocabulary registry, or dual contract.

**Compile:** there is no hand-off or session snapshot. “Compiled”
means the one dispatch-scoped stripped body is appended to the generic
Byproducts instructions when non-empty. The compiled bytes remain
immutable for that dispatch and are discarded after its return.

### Clankshop glue

Presence: sibling `skills/delegate/templates/hooks/byproducts.md`
resolvable from the clankshop skill dir. Missing member → skip this
fill; no check finding.

`$HOOKS_DELEGATE=<root>/<agent-workspace>/hooks/delegate/byproducts.md`
(absolute).

`hooks-glue.sh` gains exactly two face-local modes:

- `delegate-fill --file <abs> --skeleton <abs>` — skeleton absent →
  `status=noop`; destination absent → copy the skeleton, then fill;
  destination empty after surrounding-whitespace strip → write the
  pack fill below; destination non-empty → `status=skipped`, byte
  identity preserved.
- `delegate-check --file <abs> --skeleton <abs>` — skeleton absent →
  `finding=false`; project file missing or empty after strip →
  `finding=true`, `name=/clankshop setup`; non-empty →
  `finding=false`. Read-only in every branch.

No `delegate-presence` mode, second helper, publisher registry, or
generic hook engine. The two modes test the exact skeleton path they
receive.

On `setup` / `migrate` (same numbered hooks **step** as workstream,
not a new walk number), invoke `delegate-fill` with
`--file "$HOOKS_DELEGATE"` and the exact package skeleton. `check`
invokes `delegate-check` with those same paths. Same mkdir convention
as the workstream hook folder.

Unfinished predicate: skeleton exists AND (project file missing OR
project file empty). `delegate-check` reports it; it never writes.

Do not bump setup’s 1–7 range (living-trackers owns apply as
step 6). This fill rides the **existing hooks step**.

**Pack fill** (face may name members; this fill does not name
`/backlog debrief` and does not list stems):

```markdown
Do not file Byproducts during this return. Stash them for the host
close-the-books sweep. Anything that would change a skill goes to the
skills' home feedback channel, tagged by skill — not the project
follow-up lane.
```

Host overwrite of `.dev/hooks/delegate/byproducts.md` is the point.
A host may later put `/backlog file …` or stem names in **their**
copy. The bundled skeleton and this first fill must not.

`hooks-glue.sh` (after the workspace spec’s folder migration) fills
known **files**. Add `hooks/delegate/byproducts.md` as a known seam
to fill when empty. Do not glob `hooks/`. Do not shell
`workstream`’s parser.

PACK.md seam note (content-only, no `version:` bump in **this**
spec):

> **Seam — `delegate` / host close-the-books:** `delegate` publishes
> `<agent-workspace>/hooks/delegate/byproducts.md` from its own
> package skeleton. `setup` / `migrate` copy that file if absent
> and fill an empty body with stash-only prose. `check` reports
> empty pack glue only when that skeleton is installed; it does not
> write. Leaves do not name each other. Filing leftovers is
> `hooks/workstream/feature-completion.md` (already filled with
> `/backlog debrief` when that member is installed).

### Independence

- `delegate` `description:` still names no sibling.
- Bundled skeleton names no sibling and no `/backlog`.
- Face fill may name the close-the-books *idea*; this fill does not
  put a backticked `/backlog` token in the default body.
- There is no runtime parser, runtime file under
  `skills/delegate/scripts/`, staged delegate entrypoint, shim, or
  alternate project-hook path. The agent reads the one known file.

### Out of scope

- Living-trackers TSV / debrief modules / clankshop step 6 apply
  (sibling spec).
- `/backlog debrief` on each return.
- Stem list in the default fill.
- Shared skill-builder hooks runtime.
- Runtime delegate hooks parser or staged delegate script.
- Hooks for mailbox, auditor, or any third publisher.
- Re-parse policy for workstream (still snapshot at create).
- Door skill-route blocks.
- Two-roots, `skills/skill-builder/docs/DOCTRINE.md`, and
  `skills/skill-builder/verbs/new.md` (workspace S2 owns them).

## Verification

**Mechanical**

- New `skills/delegate/scripts/tests/run.sh` is a skill-doc harness,
  not a runtime reader. It asserts the always-three-part contract,
  exact project-hook and package-skeleton paths, an exactly zero-byte
  package skeleton, the once-per-dispatch snapshot rule, and the absence
  of a runtime script directly under `skills/delegate/scripts/`.
- The same harness extracts the structural units named above. Within
  `The return contract`, it requires exactly the ordered labels
  `Deliverable`, `Status`, `Byproducts` and exact normalized item-3
  bytes. Each other named span must occur once and equal its canonical
  normalized bytes; a required substring beside extra incumbent prose
  is a failure. There is no registry of former labels in the harness.
- The complete live delegate prose population (`SKILL.md` +
  `references/*.md`) has zero literal `/backlog`. This is the one
  negative prose assertion: it enforces the leaf/composer boundary,
  not a historical vocabulary.
- Clankshop: (a) no delegate skeleton → no
  `hooks/delegate/byproducts.md`, no check finding; (b) skeleton
  present, file absent → setup creates + fills the exact fenced pack
  body above, including one terminating newline;
  (c) file present, non-empty → body unchanged. Check never writes
  (checksum). Exercise the exact `delegate-fill` / `delegate-check`
  modes; unknown delegate modes exit 2.
- `skills/skill-builder/scripts/skills-lint.sh` clean for `delegate`.

**Absence**

- Delegate live prose (`skills/delegate/SKILL.md` and
  `skills/delegate/references/*.md`) has zero `/backlog`.
- No runtime `*.sh` lives directly under `skills/delegate/scripts/`;
  only `scripts/tests/run.sh` is added.

Red-proof the positive contract in a temp fixture: append arbitrary
extra prose inside item 3 and inside each exact replacement span;
each mutation must make the harness fail. Append one byte to the empty
skeleton and alter one byte of the expected pack fill; each must fail.
Plant literal `/backlog` in `SKILL.md` and a runtime script directly
under `skills/delegate/scripts/`; each must fail. Restore and confirm
byte identity after every mutation. A zero-replacement mutation is a
test failure, not a red proof.

**Procedure**

- Dispatch with empty/missing hook: return contract still contains
  Deliverable + Status + generic Byproducts; no host overlay and no
  kinds list.
- Dispatch with the pack fill: prompt inlines the stash-only prose;
  the delegate is not told to run `/backlog debrief`.
- Change the project file while a dispatch is running: current return
  uses the original snapshot; the next dispatch sees the new body.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | Always-three-part core contract + optional once-per-dispatch overlay; exact empty skeleton; hard-cut old taxonomy and `/backlog` across all delegate prose; delete every delegate requirement / verification / path from living-trackers so this spec is the sole owner; skill-doc tests only (no runtime reader) | exact canonical-span mutations + exact empty-skeleton mutation + boundary-absence red-proofs | `skills/delegate/templates/hooks/byproducts.md`, `skills/delegate/SKILL.md`, `skills/delegate/references/codex.md`, `skills/delegate/scripts/tests/run.sh`, `docs/design/2026-08-23-backlog-living-trackers.md` |
| S2 | Add exact face-local `delegate-fill` / `delegate-check` modes; copy-if-absent + empty-file fill + read-only unfinished predicate; PACK seam; tests | clankshop harness | `skills/clankshop/scripts/hooks-glue.sh`, `skills/clankshop/verbs/setup.md`, `skills/clankshop/verbs/migrate.md`, `skills/clankshop/verbs/check.md`, `skills/clankshop/PACK.md`, `skills/clankshop/scripts/tests/**` |

Land order S1 → S2. Land **after workspace S2**, which already
requires workspace S3. There is no living-trackers ordering
dependency: S1 removes delegate from that spec's change surface, so a
later backlog build cannot overwrite this contract. No compatibility
period. S2 must not bump setup’s walk range. This fill attaches to the
hooks step. This spec never edits the workspace-owned doctrine or
`new.md` surfaces.

## Review history

None yet on this split file. Caller publishes after a passing host
review they accept.
