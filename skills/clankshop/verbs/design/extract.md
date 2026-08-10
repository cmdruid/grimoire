# `/clankshop design extract` — recover a provisional design draft from code

Hat: `roles/architect.md` — read the hat first; you operate this verb wearing that hat.

The brownfield onramp: for a codebase with **no design layer**, recover a first draft of the design
*from the code itself*. See `docs/DESIGN-DOCTRINE.md` § Extraction — the brownfield onramp for the method,
and § Sufficiency, and its circularity for why this draft is a starting point, not a source of truth.

## Read this framing before you write anything

`extract` is **descriptive, not prescriptive.** What it produces is a *map of what the code appears
to do* — not a proven, binding seed. This is not a limitation to work around; it is the
**circularity trap** stated in `docs/DESIGN-DOCTRINE.md` § Sufficiency: a spec reverse-engineered
from code proves only reverse-engineering skill, never that the *standing seed says enough on its
own*. A draft that looks complete because it was traced off working code is exactly the failure
the discipline exists to catch.

Three hard rules follow, and they govern every step below:

1. **The draft is provisional.** Every file `extract` writes is stamped
   `status: extracted — sufficiency-unproven`. Nothing it emits is binding until a human editorial
   pass and the fresh-agent read-test have hardened it (Step 6).
2. **`extract` writes ONLY to `.records/design/draft/`.** It **never** writes into
   `.handbook/design/`. The seed home stays pure — mutated only by the curated path
   (`seed`/`distill`/human editorial). `extract` produces a *deliverable*, not a seed; see
   `docs/DESIGN-DOCTRINE.md` § Deliverables in `.records/`, seed in `.handbook/design/`.
3. **`extract` never writes executable code.** Standing architect discipline: it reads `src/` to
   inventory and infer, and authors design prose only.

This verb writes the deployed layout (`.records/design/draft/`). On an unstamped root — no
installation block — report what is missing, point at `/clankshop setup` / `migrate`, and write
nothing; the inventory-and-judge half (Steps 1–3's reading) runs anywhere.

## 1. Preconditions — resolve root + date, confirm the onramp applies

- Resolve the repo root (the directory the code lives under) and today's date (`YYYY-MM-DD`,
  `date +%F`) — the draft's provisional stamps carry this date so drift against the code is legible
  later.
- Confirm the draft home: `.records/design/draft/` under the repo root. Create it if absent. If a
  previous `extract` draft already sits there, treat this as a re-run — supersede it in place and say
  so in the report rather than silently layering a second draft on top.

## 2. When to use — and when not to

`extract` is for a codebase with **no design layer**: no `.handbook/design/` seed, and nothing for
`seed` migrate-mode to fold (no `DESIGN.md`, no per-subsystem docs directory). It is the step
*before* a seed exists — it manufactures the raw material a human then hardens into one.

Redirect in two cases:

- **A seed already exists** (`.handbook/design/` is present) → this is not an onramp; it is a
  drift question. Point the user to `/clankshop design reconcile` (compare the code against the standing
  seed) instead. Re-extracting over a live seed would just relaunder the code's current shape back
  over curated design.
- **Design docs exist but no seed** (a `DESIGN.md`, a `docs/design/*` directory) → that is
  `seed` migrate-mode's job, not `extract`'s. There is already curated material to fold; don't
  reverse-engineer what a human already wrote down.

## 3. Inventory the code

Reuse `seed` greenfield's code-inventory shape (see `verbs/design/seed.md` Step 3, "Greenfield mode"):
partition the codebase into systems informed by its **actual module boundaries** — one candidate
system per identifiable code unit — and build the seam graph from **cross-references** between them
(an import, call, or shared type from one system into another is a seam-graph edge). Record, per
system: the code unit(s) it covers, and the neighbors it touches. This inventory is what Step 4
drafts against and what the gap report (Step 5) reasons over.

## 4. Draft the seed shape (descriptive) — under `.records/design/draft/`

Mirror the seed's shape so the draft is *foldable* later, but write it all under
`.records/design/draft/`, **never** `.handbook/design/`. Every file carries the provisional stamp.

- **Per system**, draft `.records/design/draft/src/<system>.md` on the two-tier
  `templates/design/system-spec.md` shape, but read the tiers *descriptively*:
  - **Contract (apparent, not binding):** the purpose, invariants, seams, and behavior the code
    *appears* to guarantee — phrased as observation ("the code enforces…", "callers appear to rely
    on…"), never as law. Seams still go in the contract tier (`docs/DESIGN-DOCTRINE.md`). Where an invariant
    is visible in the code but its *reason* is not, say so — that unexplained-why is a gap for Step 5,
    not a blank to fill by guessing.
  - **Reference Architecture (pointer-heavy):** `src/…:NN` pointers into the code the contract was
    read from. This tier comes *for free* here — the draft is traced off the live code — so make it
    dense and accurate; it is the evidence trail a human hardening the draft will re-walk.
  - **Acceptance:** leave the template's `<...>` placeholder unless the code carries a genuine,
    inferable gate (an existing test suite, a determinism check). Do **not** invent acceptance
    criteria from the implementation — fabricated acceptance is worse than an honest gap, and an
    un-inferable gate is a Step 5 finding.
- **The spine**, inferred from code into `.records/design/draft/`:
  - `VISION.md` — the product's apparent north star, inferred from what the code as a whole does.
    This is the weakest inference (code shows *what*, rarely *why*) — flag it loudly as provisional.
  - `PHILOSOPHY.md` — cross-cutting patterns that recur across **≥2 systems** in the inventory (the
    same candidate-signal bar `PHILOSOPHY.md` and `distill` use). A pattern in one system is a local
    detail, not a tenet.
  - `GLOSSARY.md` — domain terms mined from names in the code (types, modules, key identifiers).
  - `MAP.md` — one row per inventoried system, plus the seam graph from Step 3's cross-references.
- **Stamp every file** with frontmatter `status: extracted — sufficiency-unproven` and the
  resolution date from Step 1. The provisional stamp is not decoration — it is what stops a later
  reader (human or agent) from mistaking a traced-off-code draft for a curated seed.

## 5. Sufficiency-gap report — the honest deliverable

Alongside the draft, write `.records/design/draft/SUFFICIENCY-GAPS.md`: the record of *what
hardening must resolve* before this draft can become a seed. This is the part that keeps `extract`
honest — the draft says "here is what exists"; the gap report says "here is what an agent acting on
this spec would have to guess." For each system, list:

- **Systems found** and their **apparent contracts** (one line each, cross-referencing the draft).
- **Invariants implied but unexplained** — the code enforces it, but nothing says *why*, so a later
  implementer can't know whether it is sacred or incidental.
- **Un-inferable acceptance criteria** — where behavior has no existing test/gate to read, so the
  "does the implementation pass?" question has no answer yet.
- **Anything an implementer would guess** — magic constants without rationale, ordering the code
  depends on but never states, error-handling that may be deliberate or may be an accident.

Frame this list as the sufficiency-failure ledger, not a to-do afterthought: per `docs/DESIGN-DOCTRINE.md`
§ Sufficiency, every gap here is a place the extracted draft is *known* not to be self-sufficient.

## 6. Hand off to hardening — extract stops here

`extract` produces the draft and the gap report; it does **not** produce a seed. The path from draft
to real `.handbook/design/` seed runs through two steps `extract` explicitly hands off:

1. **Human editorial pass** over `.records/design/draft/` — resolving the gap report's findings,
   replacing "appears to" observations with decided intent, filling or accepting each placeholder
   acceptance. This is the step that breaks the circularity: a human deciding what the design *should*
   guarantee, not the code dictating what it *happens* to do.
2. **The fresh-agent read-test** (`docs/DESIGN-DOCTRINE.md` § Sufficiency; `verbs/design/health.md`): hand a fresh
   agent *only* the hardened draft and confirm it can act on it without guessing. This is the
   semantic sufficiency proof no script can substitute for.

Only after both does the hardened draft fold into the seed — via `/clankshop design seed` in **migrate
mode**, with `.records/design/draft/` as the source material `seed` reshapes into `.handbook/design/`.
State this path in the report; do not run it — `extract` stops at the draft + gap report.

## 7. Report + commit

Close `extract` with: the systems inventoried, the apparent contracts drafted, the spine files
stamped (with `VISION`'s inference flagged as weakest), the headline entries of the gap report, and
the explicit next step (human editorial → read-test → `/clankshop design seed` migrate-mode). Make the
provisional nature unmissable: this is a draft to harden, not a seed to build against.

Commit the draft outputs scoped and pathspec-atomic (only the `.records/design/draft/` paths written
this run), no `Co-Authored-By` trailer.

## Discipline this verb carries

- **Never write executable code** (Step framing rule 3) — read `src/` to inventory; author prose only.
- **Respect the durability gradient** (`docs/DESIGN-DOCTRINE.md`): the draft mirrors it (spine shallow,
  reference-arch deep and pointer-heavy) so it folds cleanly, but nothing is durable until hardened.
- **Portable methodology stays in this package; project content stays in the project** — the draft is
  project content and lives in the project's `.records/`, never in this skill.
