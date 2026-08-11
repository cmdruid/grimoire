# `/clankshop design seed` — bootstrap or migrate the `.handbook/design/` seed

Hat: `roles/architect.md` — read the hat first; you operate this verb wearing that hat.

Stands up a project's `.handbook/design/` seed (see `docs/DESIGN-DOCTRINE.md` for the durability gradient and the
two-tier system-spec this verb populates). Two modes, one procedure with a fork at Step 3:

- **Greenfield** — compile a loose `PROJECT.md` vision brief into the seed. There is little or no
  scattered design material to fold in; the brief is the only real input besides whatever code
  already exists.
- **Migrate** — an existing project has design material spread across a root `PROJECT.md`/
  `DESIGN.md` and a per-subsystem docs directory (e.g. `docs/design/*`). `seed` folds that
  material into the seed's shape rather than writing it fresh.

Both modes end the same way: `seed` is not done until `/clankshop design health` reports a complete spine
(and every migrated system has a contract).

This verb writes the deployed layout (`.handbook/design/`). On an unstamped root — no
installation block — report what is missing, point at `/clankshop setup` / `migrate`, and write
nothing: the face owns bootstrap, and there is no pre-stamp write license here. Judgment
(mode detection, advice on the material found) runs anywhere.

## 1. Detect mode

Look for existing design material in the project root:

| signal | present | absent |
|---|---|---|
| `DESIGN.md` (or an equivalently-named principles doc) | → **migrate** | — |
| a per-subsystem docs directory (e.g. `docs/design/`) with more than a couple of files | → **migrate** | — |
| `.records/design/draft/` (an `/clankshop design extract` handoff — see `verbs/design/extract.md`) | → **migrate**, seed-shaped source (Step 3) | — |
| only a `PROJECT.md` (or similarly-named vision brief), nothing above | → **greenfield**, using it as the compile input | — |
| nothing at all | → **greenfield**, but stop and ask the human for a short vision brief first — `VISION.md` cannot be stamped from nothing | |

Reconciling the brief's literal signal list (`PROJECT.md`, `DESIGN.md`, `docs/design/` all "→
migrate"): a bare `PROJECT.md` alone, with no `DESIGN.md` and no subsystem-docs directory, *is*
the greenfield case — it is exactly the "loose vision brief" `seed` is meant to compile. Treat
`DESIGN.md` or a real subsystem-docs directory as the actual migrate signal; `PROJECT.md`'s role
differs by what else is present, not by its own existence.

**`.records/design/draft/` is a distinct migrate source, not a subsystem-docs directory.** It is the
deliverable `/clankshop design extract` writes when hardening a brownfield onramp — already **seed-shaped**
(the same spine + `src/<system>.md` layout `.handbook/design/` uses) rather than prose to reshape from
scratch, but every file in it is stamped `status: extracted — sufficiency-unproven` and its
`SUFFICIENCY-GAPS.md` lists what a hardening pass must still resolve. Fold it per Step 3's "seed-shaped
source" case, not the generic subsystem-docs reshape.

Report the detected mode before proceeding — this governs every step below.

## 2. Stamp the spine

Populate the four required root files (`templates/design/VISION.md`, `PHILOSOPHY.md`, `GLOSSARY.md`,
`MAP.md`) from whatever source material mode detection found. This step is the same shape in both
modes — greenfield just has thinner sources.

- **`VISION.md`** ← the vision brief, or `PROJECT.md`'s vision + pillars sections. Fill
  "North star" from the vision prose and "Design
  pillars" from the pillars list; carry a "Non-goals" section across verbatim if the source has one.
- **`PHILOSOPHY.md`** ← the project's existing principles doc (`DESIGN.md`, or equivalent). Each
  of its cross-cutting patterns becomes one tenet line. Don't invent tenets that aren't already
  load-bearing in the source — `PHILOSOPHY.md`'s own doctrine (recurrence across ≥2 systems is a
  *candidate* signal, not an automatic promotion) applies here too.
- **`GLOSSARY.md`** ← seeded empty, then filled two ways: (a) if the brief/`PROJECT.md` already
  carries its own glossary section, fold it in directly; (b) mine
  domain terms out of each subsystem doc as you migrate it in Step 3. Don't leave this seeded-only
  in migrate mode — every migrated system should have contributed at least the terms its contract
  depends on.
- **`MAP.md`** ← seeded empty, then filled from the **system inventory**: one row per system being
  migrated (Step 3), or, in greenfield with existing code but no design docs, one row per
  identifiable code module. Fill the seam graph from cross-references between systems as they turn
  up (an "Interfaces/seams" bullet in one system's contract that names a neighbor is a seam-graph
  edge).

## 3. Migrate subsystem docs (migrate mode) / inventory code (greenfield)

**Migrate mode.** For each doc in the existing subsystem-docs directory:

1. Copy the template `templates/design/system-spec.md` to `.handbook/design/src/<system>.md`.
2. Reshape the doc's content into the two tiers — this is a **reshape, not a paste**:
   - **Contract (BINDING):** purpose, invariants (cite `PHILOSOPHY.md` tenets where the doc
     already implies one), **interfaces/seams**, behavior, the *why* behind hard constraints.
     Per `docs/DESIGN-DOCTRINE.md`, **seams belong in the contract tier, never reference-arch** — if the
     source doc describes how a neighbor consumes this system, that description lands here even
     if the source doc filed it under "architecture."
   - **Reference Architecture (DISPOSABLE):** the current implementation shape. Keep it
     **pointer-heavy**: replace the source doc's prose descriptions of modules/algorithms with
     `src/…:NN`-style pointers into the actual code they describe (a file path alone is an
     acceptable pointer when a specific line isn't meaningful; never paste code). If a described
     piece of architecture no longer matches any code you can find, that's drift worth flagging in
     the seed report, not something to paper over by keeping the stale prose.
   - **Acceptance:** carry over any concrete scenarios/gates/determinism checks the source doc
     already names. If the source doc has nothing concrete, leave the template's `<...>`
     placeholder rather than inventing one — `/clankshop design health` will flag it as
     `acceptance_placeholder`, which is correct: a fabricated acceptance bullet is worse than an
     honest gap.
3. Stamp the frontmatter `distilled_through_adr: none`, `distilled_through_commit: none`,
   `distilled_through_date: none` — a migrated spec has not been through a `distill` pass yet, even
   though its content is freshly written today. (This is the three-key form the `system-spec.md`
   template and `design-check.sh` both parse; don't use an older single-key `distilled-through:`
   shape.)
4. **Not every doc under the subsystem-docs directory is a committed system spec.** Some are
   explicitly speculative or forward-looking (e.g. a subsystem doc marked "not committed").
   Use judgment: migrate committed subsystems as normal; for a speculative doc,
   either skip it and note the decision in the seed report for the human to make, or migrate it
   with a contract that's honest about its non-committal status — don't silently launder a
   "maybe someday" doc into a binding contract.

**Migrate mode — seed-shaped source (`.records/design/draft/`, an `extract` handoff).** This source
folds like subsystem docs (same Step 3 procedure — copy the template, reshape into the two tiers,
stamp the three-key `distilled_through_*` frontmatter, consume the source when spent) with one
difference: instead of reshaping loose prose, you are **hardening an already seed-shaped draft**.

1. Map `.records/design/draft/src/<system>.md` → `.handbook/design/src/<system>.md` one-to-one (the
   draft already used `templates/design/system-spec.md`'s two-tier shape) and `.records/design/draft/{VISION,
   PHILOSOPHY,GLOSSARY,MAP}.md` onto the four root files, same as any other source feeds Step 2.
2. **Resolve every entry in `SUFFICIENCY-GAPS.md` — do not fold the draft silently.** Per
   `docs/DESIGN-DOCTRINE.md` § Sufficiency, a draft traced off code is circular until a human decides what the
   design *should* guarantee; folding it unresolved just relaunders that circularity into
   `.handbook/design/`. For each gap: turn an "apparent"/"appears to" observation into decided intent,
   fill or knowingly accept each placeholder acceptance, and state the resolution in the seed report.
3. Drop the `status: extracted — sufficiency-unproven` stamp once resolved — a folded system carries the
   normal `distilled_through_*: none` stamp (Step 3, point 3 above), not the draft's provisional one.
4. `.records/design/draft/` is **transient by contract** — born at `extract`, consumed exactly
   here. After folding, **archive the consumed draft** to `.records/design/draft/archive/`
   (`git mv`; never a silent delete — the draft records what extraction saw), so the live
   `draft/` is empty again; stale live `draft/` content is a check fact.

**Greenfield mode.** If there's a live codebase but no prior design docs, build the same
`.handbook/design/src/<system>.md` files directly from code inspection + the vision brief instead of from a
source doc: partition the codebase into systems (informed by its actual module boundaries), draft
each contract from what the code visibly does, and skip straight to pointer-heavy reference-arch
since there's no prose to reshape. If there's no code either, `src/` starts empty — `MAP.md`
records the intended systems from the brief, and their specs are the first thing a `/clankshop design plan`
pass writes.

**What never gets migrated into `.handbook/design/`:** change-records — ADRs, plans, roadmap deltas — stay
in the project's own operational history (`.records/adr/`, `.records/plans/`, etc.). Per `docs/DESIGN-DOCTRINE.md`,
change-records and standing specs are temporally distinct; folding an ADR chain's *history* into
the seed reintroduces exactly the scar-smear the seed exists to avoid. `distill` is the verb that
later mines those change-records to refresh a spec — `seed` only establishes the baseline stamp
(`none`) that `distill` will work forward from.

## 4. Consume the bootstrap inputs

Once their content lives in the seed, the source material is **spent** — in migrate mode this is
`PROJECT.md`/`DESIGN.md` **and** every per-subsystem doc actually migrated in Step 3 (e.g.
`docs/design/<system>.md` for each system now living at `.handbook/design/src/<system>.md`); in greenfield
mode it's just `PROJECT.md`. Leaving a migrated subsystem doc in place, unlinked, recreates the
two-source-of-truth problem `seed` exists to close — don't stop at the root files. This is a
document edit — `seed` performs it directly:

- Default: replace each with a one-line pointer to `.handbook/design/` (e.g. "Superseded by `.handbook/design/` — see
  `.handbook/design/README.md`." for the root files, or "Superseded by `.handbook/design/src/<system>.md`." for a
  migrated subsystem doc). This is the safer default; deleting a root file a human may still link
  to is more disruptive than leaving a pointer.
- Delete outright only if the project's own conventions call for it (e.g. an "alpha, no dead
  files" policy) — ask, or check the project's own conventions doc, rather than assuming.
- A subsystem doc explicitly skipped in Step 3 (the speculative-doc case) is **not** spent — leave
  it as-is; only a doc actually migrated gets superseded.

## 5. Update project wiring — code-blind: doc edits direct, code edits are a handoff

This step is the one place `seed` must actively watch the altitude seam (`docs/DESIGN-DOCTRINE.md` § The
seam — altitude, not medium). "Update project wiring" covers three kinds of reference that can go
stale once `.handbook/design/` exists and the old docs are gone/moved:

1. **Repo-map docs** (e.g. `AGENTS.md`) that describe where design docs live.
2. **A doc checker or indexer** that enumerates the old design-doc directory.
3. **`related:`-style links** elsewhere that point at the moved files.

For each, ask: *is the thing I'd edit a document, or executable code?*

- **Document** (markdown, a `.ron`/`.yaml` config the linter reads declaratively, a repo-map file
  like `AGENTS.md`) → `seed` edits it directly, in the same pass. This is authoring the seed's
  surroundings, not writing code.
- **Executable code** (a doc checker's source, a build script, a compiled indexer) → `seed`
  does **not** edit it. Emit a short handoff note instead: what
  moved, what the code currently assumes, and what change would make it correct again. Hand that
  note to `/clankshop route` or `/feature` to execute — do not guess at the project's tracker; if the project
  has one (a backlog file, an issue tracker), file it there per that project's convention, and
  otherwise surface the note directly in `seed`'s final report so the human can route it.

This is a direct consequence of the altitude split in `docs/DESIGN-DOCTRINE.md`: `/clankshop design` never writes
executable code, even code as small as a one-line linter glob update. The instinct to "just
fix the one-liner" is exactly the boundary this step exists to hold.

## 6. Run `health` — the completion gate

```bash
bash <skill-dir>/scripts/design-check.sh <project>/.handbook/design [<repo-root>]
```

`seed` is not done until:

- `spine_complete=true`, and
- `contract:<sys>=true` for every system `seed` migrated or inventoried.

Both are `design-check.sh`'s exit-1 conditions (see `verbs/design/health.md`) — a missing spine or a
contract-less system means there's no constitution, or no binding contract, for anything
downstream to build against. If either is still false, that's `seed` unfinished, not `seed` done
with follow-ups: go back and fill the gap.

The remaining facts (`drift`, `acceptance_placeholder`, `map_orphan`/`map_dangling`,
`baseline_date`) are advisory. Don't silently patch them to make the report look cleaner — surface
them in `seed`'s final report exactly as `verbs/design/health.md` prescribes (flag drift and placeholder
acceptance to the human; note orphan/dangling MAP rows as cheap hygiene). A migration that lands
with a handful of honest `acceptance_placeholder`s and a filed handoff note is a correct outcome;
one that fabricates acceptance criteria to clear the check is not.

## Report

Close `seed` with: the detected mode, the spine files stamped, the systems migrated/inventoried
(and any skipped as speculative, per Step 3), what happened to `PROJECT.md`/`DESIGN.md` (pointer
or delete), any handoff note(s) emitted for code-side wiring (Step 5), and the final `health` facts
— pass/fail on the hard blockers plus a list of what's advisory-outstanding.
