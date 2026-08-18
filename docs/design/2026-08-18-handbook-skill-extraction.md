---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `handbook` — the doctrine-layer format authority — Spec

`stream/feat` **feature 3**. Argued from the 2026-08-18 brainstorm draft, **re-grounded against
feature 2's landed outcome** (`main` @ `ce7e758` + `11ef5d8`). Every open question the draft
carried is resolved in the Decision log; nothing below is left to inference.

> **Read the Decision log before re-deriving anything.** Three of the draft's positions were
> superseded by feature 2 and one of its three justifying problems is dead. What replaced it is
> larger than what it replaced.

## Problem

The doctrine layer has no owning authority. `.handbook/` is defined nowhere citable — its format,
load rules, station model, and deployed loader are embedded in the pack face's `seed/`. The records
layer got a format authority (`journal`); the doctrine layer never did. That asymmetry has three
consequences — one of which feature 2 created and deliberately left for this feature.

1. **No lifecycle.** `clankshop/SKILL.md:23` and `verbs/setup.md:19` both promise that upgrades
   are "a judgment-assisted diff against the current seed, anchored by the README stamp line."
   **No verb performs it.** `journal` has `done` + `curate`; the doctrine layer has no drift
   detection, no stale-chapter pass, and no upgrade path beyond the prose promise. Verified: `check`
   validates conformance (load sets, stamp, slots, links) but never diffs against the seed.

2. **The face carries layer mechanics.** `seed/` (16 files), `scripts/seed.sh`, and
   `seed/scripts/context.sh` sit in the pack face alongside genuine orchestration (`setup`,
   `migrate`, `check`, the door, the manifest). The face is the assembler; it should not also be
   the doctrine layer's implementation.

3. **Nothing declares the doctrine home, so feature 2's resolvers miss a deployed workshop.**
   Feature 2 shipped `agent-doctrine:` (front-door variable, default `<agent-records>/doctrine`)
   and flipped five consumers onto it. **Six skills now read that variable; zero skills write it**
   — verified: `auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96`, and
   `skills-lint.sh:632` read it; no writer exists anywhere in `skills/`. On a deployed workshop the
   door therefore never declares `.handbook`, every consumer resolves the *default*
   `<agent-records>/doctrine` (`.records/doctrine/`), finds nothing, and — correctly, per feature
   2's two-level rule — **degrades instead of summoning the station.** `DOCTRINE.md:228` uses
   `agent-doctrine: .handbook` as *the* canonical override example, and `DOCTRINE.md:236` concedes
   the variance case is currently "**prospective**." This feature is what makes it real.

   This is a designed hand-off, not a discovered defect: feature 2's spec scoped `handbook` out with
   the words *"It creates `.handbook`, migrates existing doctrine into it, **and declares the
   variable**."* The honest cost is a window — between feature 2's ship and this one's, deployed
   workshops lose station context silently. grimoire is patient-zero and has no deployed workshop,
   so the blast radius is other installs only.

## Goal

`handbook` becomes the **doctrine-layer format authority**, symmetric to `journal`'s records-layer
authority: it owns the chapter model, the load rule, the stamp format, the deployed `context.sh`,
and the layer's lifecycle. `clankshop` narrows to the **assembler** — it composes the two layers,
writes the door (now including the doctrine-home declaration), validates the assembly, and carries
the manifest. Done means a deployed workshop declares the home its own consumers resolve.

## Approach — full symmetry

**Moves to `handbook`:** `seed/`, `scripts/seed.sh`, `seed/scripts/context.sh`, the `seed-test.sh`
harness, and two verbs — `setup` (the delegated doctrine seam) and `curate` (which finally
*implements* the promised seed-diff).

**Stays on the clankshop face:** `persona`, `check`, `migrate`, `setup`'s orchestration, the
`AGENTS.md` door, `PACK.md`, `migrate-scan.sh`.

**Tier:** `required:`, alongside `journal`. Pack tier and framework dependency are distinct claims
and both hold: installing the pack installs handbook and `/clankshop setup` hard-stops without it
(a workshop cannot stand up doctrine-less), while the `agent-doctrine` rule still resolves with no
handbook installed at all. `journal` is the exact precedent — `required:` in the manifest, yet
`1707ede` made record-writers work without its floor.

**Name:** `handbook` — the word the library already uses in 40+ places. It collapses the
skill-name/artifact-name distinction that `journal`/`.records` and `notepad`/`notes` keep; that
cost was weighed and accepted against translating a settled term of art. The collision risk this
creates is a routing question, gated by a probe (S8).

**The precedent is explicit.** `setup.md` step 3 delegates records standup to `/journal setup` and
forbids inlining its walk; as of `1707ede` it delegates the records **tool layer** specifically.
Extracting `handbook` is the same move for the other half. The resulting symmetry is near-exact:

| layer | authority | deployed tool | mechanical check | judgment hygiene | face delegates at |
|---|---|---|---|---|---|
| records | `journal` | `records.sh` | `records.sh check` | `/journal curate` | `setup` 3, `check` 5 |
| doctrine | `handbook` | `context.sh` | `context.sh --check` | `/handbook curate` | `setup` 2, `check` 1 |

### Why not the alternatives

- **Thin extraction** (assets move, no lifecycle verbs) — a file move dressed as an architecture
  change. The six consumers already cite `context.sh` fine today, so citability alone is thin
  payoff, and it leaves the seed-diff gap unowned. What makes `journal` worth being a skill is not
  that it holds `records.sh`; it is that the layer has a lifecycle.
- **Authority without extraction** (a doctrine-contract section in `clankshop/SKILL.md`, mirroring
  journal's record contract) — zero risk, zero move cost, and it neither thins the face nor closes
  the lifecycle gap. Rejected, but preferred over thin extraction if the extraction were dropped.
- **Declaring the home without extracting anything** (a one-line fix to `setup.md` step 4 closing
  Problem 3 alone) — genuinely tempting, and it is the whole of this feature's *urgent* value. It is
  rejected as the *only* action because it leaves Problems 1 and 2 standing and re-opens this same
  design in a month. It is, however, the correct **fallback** if the extraction must be abandoned
  mid-flight: S5 alone is shippable and independently valuable.

## Mechanism

### M1 — the package move

`git mv` (history survives), yielding `skills/handbook/`:

    skills/clankshop/seed/                  → skills/handbook/seed/
    skills/clankshop/scripts/seed.sh        → skills/handbook/scripts/seed.sh
    skills/clankshop/scripts/tests/seed-test.sh → skills/handbook/scripts/tests/seed-test.sh

`seed-test.sh` moves because it tests exactly the two moving assets (`seed.sh` projects; the
deployed `context.sh` serves and self-checks). `face-test.sh`, `migrate-scan-test.sh`,
`setup-journal-test.sh`, and `lib.sh` stay with clankshop. Both skills get a `scripts/tests/run.sh`
entrypoint; clankshop's drops `seed-test.sh` from its list, handbook's gains it. `lib.sh` is
duplicated into handbook's test dir — **the established pattern**, verified: six skills carry six
own copies (`analyst`, `checkpoint`, `clankshop`, `journal`, `scheduler`, `skill-builder`) and no
test sources another skill's lib. A cross-skill source would violate package independence.

`seed.sh` resolves its seed as `$(dirname $0)/../seed` — unchanged by the move, since the relative
layout is preserved.

### M2 — `skills/handbook/SKILL.md`, the authority document

States, in its own package (never delegating the bytes elsewhere): the layer's shape (`core/` +
four station dirs + lazy `workflows/`), the load rule (`core/*` in `POLICY, INVARIANTS, GOTCHAS,
ROUTING` order, then `<station>/POLICY.md`), the persona aliases (architect→design, foreman→build,
guardian→test, admin→review), the stamp format (`Seeded from clankshop vX.Y on DATE`, provenance
only), and the deployed tool contract. Two verbs, below. `description:` is written to route against
`clankshop` (S8).

### M3 — `/handbook setup`

`setup <root> --gate '<cmd>' --trunk '<branch>'`. Projects the **full seed** — chapters *and*
loader — not a tool layer only. The asymmetry with `/journal setup` (which deploys `records.sh` +
ledger + README and **no** stores) is deliberate and principled: **records are minted, doctrine is
seeded.** Journal's stores are empty containers whose content other skills mint later, so creating
an empty `design/` helps nobody. The doctrine layer's chapter text *is* the deliverable; an empty
`.handbook/core/POLICY.md` is worthless.

**handbook never interviews.** `<gate>` and `<trunk>` are gathered by the face's step-1 interview
and passed as arguments — exactly as the face passes the resolved agent-records home to `/journal
setup`. **handbook never writes the door**; the face owns `AGENTS.md`.

Mechanics are today's `seed.sh` unchanged: copy, fill slots, write the stamp, self-check. It still
refuses an existing `.handbook` (upgrade is a diff, not a re-seed).

### M4 — `/handbook curate`, the promised seed-diff

Diffs the deployed `<root>/.handbook/` against the **current bundled seed** and reports every
divergent hunk for judgment. It classifies nothing automatically and writes nothing silently.

**Why not a three-way diff:** separating "deliberate project accretion" from "untaken seed upgrade"
needs the *historical* seed at the stamped version, which a consuming project does not have — it has
today's bundle and nothing else. Reaching into the installed skill's git history would work only for
clone installs and degrade silently for tarball/vendored ones, a floor this library has avoided. So
the stamp is **provenance in the report**, not a differ input:

    /handbook curate
      seeded: v2.4.0 (2026-08-18)      ← stamp, provenance only
      bundle: v2.5.0
      core/GOTCHAS.md      +14 -0   → judge
      build/POLICY.md       +2 -2   → judge
      test/workflows/…    ABSENT    → judge
      3 divergences. None auto-classified.

Output is a report plus proposals; applying a hunk is the operator's call. Mirrors `/journal
curate`, which likewise proposes prunes rather than taking them.

### M5 — `context.sh --check` widens to the whole doctrine layer

Today `--check` verifies load sets only. It grows to cover every **doctrine-internal** fact:

| arm | asserts |
|---|---|
| load sets | every station's load set resolves *(existing)* |
| stamp | `Seeded from clankshop` present in `.handbook/README.md` |
| slots | no unfilled `<gate>` / `<trunk>` remains under `.handbook/` |
| links | every relative `.md` link **inside** `.handbook/` resolves |

Contract change: the documented *"Exit 2 lists exactly which station's load set is broken"* widens
to *"lists exactly what is wrong"* — one finding per line on stderr, **exit 2 for any**
doctrine-internal failure. No new exit codes; the caller already reports findings as location +
what's wrong.

The seam is drawn by **scope, not by mechanism**: `--check` owns what is *inside* `.handbook/`; the
face owns the *wiring between* layers. So `clankshop check` becomes:

    1–3, 4a  → delegate to context.sh --check     (doctrine-internal)
    4b       → door exists, names .handbook/README.md,
               AND declares `agent-doctrine: .handbook`   (assembly — face)
    5        → delegate to records.sh check        (records-internal, unchanged)

### M6 — the doctrine-home declaration (closes Problem 3)

The face writes `agent-doctrine: .handbook` at line start into `<root>/AGENTS.md`, in **`setup` step
4** and **`migrate` step 4** (the two door writers).

**Asymmetry with `agent-records:`, stated because it is easy to get wrong:** `agent-records:` is
written *only when the home is not the default* `.records/`. `agent-doctrine: .handbook` is written
**always** on a workshop, because `.handbook` is *never* the default (`<agent-records>/doctrine`
is). A workshop that omits the line is misconfigured, which is why `check` step 4b asserts it.

### M7 — clankshop narrows

- `setup.md` — Guard (a) tests handbook availability exactly as it tests journal ("If `/handbook
  setup` is not available, stop"); step 2 becomes `/handbook setup <root> --gate … --trunk …` with
  the same do-not-inline language step 3 carries for journal; Guard (c)'s "do not re-run `seed.sh`"
  becomes "do not re-run `/handbook setup`"; step 4 gains M6's line.
- `migrate.md` — step 3's direct `scripts/seed.sh` call becomes `/handbook setup`, symmetric with
  the adjacent `/journal setup`. **The single confirmed mapping table (step 2) and the step-4
  judgment merges stay on the face** — the face keeps one table. Step 4's door write gains M6's line.
- `check.md` — restructured per M5.
- `persona.md` — the no-workshop fallback (`:14`) is **dropped**: it reaches into clankshop's
  *bundled* `seed/scripts/context.sh`, which after the move is another skill's bundle. `/clankshop
  <persona>` on an unseeded project reports that no workshop is deployed and points at `setup`. The
  cost is one degraded edge case, and `persona.md` already concedes its worth — *"the voice is the
  generic seed persona — the project's own accrued judgments don't exist yet."* A queued `personify`
  skill (feature 4) would restore it properly.
- `SKILL.md` — the face is described as the assembler; `seed/` and `context.sh` drop from its
  self-description.

### M8 — manifest, roster, doctrine folds

- `PACK.md`: `required: journal, handbook`; **version 2.4.0 → 2.5.0** (member-set change → minor
  bump); a roster row. **The version line is ID-bearing** — two streams have already claimed the
  same number with no textual conflict — so re-verify siblings immediately before writing it.
- `README.md`: a row for `handbook`. *(A new skill needs a row here **and** in `PACK.md` — two
  separate edits.)*
- `install.sh`: **no change** — verified, not assumed. It reads `required:`/`optional:` from
  frontmatter (`:96-98`, comma-split) and errors only when `required:` is absent; members outside
  `optional:` get `"required": true` in the lock (`:151`).
- `DOCTRINE.md:234-241`: the note conceding the doctrine home's variance case is "**prospective**"
  becomes false when M6 ships — a deployed workshop is now the concrete, live case. Update it
  ("fix the doctrine, not just the tool", `DOCTRINE.md:61`).

### M9 — routing probe

Per `docs/boundary-audit.md`'s established format: ~8 prompts against `handbook` + its nearest
neighbors (`clankshop`, `journal`, `skill-builder`), judged by a **fresh read-only sub-agent given
descriptions only**, logged to that file's run log. The sharp pair is `/handbook setup` vs
`/clankshop setup` — both "set up doctrine." The prose discriminator to fold into `handbook`'s
description if the probe drifts: **handbook stands up one layer and is normally invoked *by* the
assembler; clankshop assembles the whole workshop.** `journal` coexisting with `clankshop` today is
only weak evidence — "handbook" is far more generic than "journal."

## Verification

**The governing discipline: no check is trusted until it FAILs on deliberately-broken input.** A
verification grep is not evidence.

**Each new `--check` arm gets its own independent red-proof.** This is feature 2's S1 lesson,
paid for once already: a `check`-only proof **passes against a partial fix** (demonstrated in that
review — `stores()` patched, `resolve()` broken, `check` returned OK while `show` still worked). So
three new arms (stamp, slots, links) = three separate break-then-observe proofs, each breaking only
its own arm and confirming the other two still pass.

| what | how |
|---|---|
| move preserves history | `git log --follow skills/handbook/scripts/seed.sh` reaches pre-move commits |
| seed still projects | `skills/handbook/scripts/tests/run.sh` green (moved `seed-test.sh`) |
| clankshop suite still green | `skills/clankshop/scripts/tests/run.sh` green minus the moved suite |
| `--check` stamp arm | delete the stamp line from a fixture handbook → exit 2 naming the stamp; other arms still pass |
| `--check` slots arm | reintroduce a literal `<gate>` → exit 2 naming the file; other arms still pass |
| `--check` links arm | point an intra-handbook link at a deleted file → exit 2 naming the link; other arms still pass |
| `--check` load-set arm | delete `core/ROUTING.md` → exit 2 (existing proof, must not regress) |
| **M6 declaration** | seed a fixture via the full `setup` walk → `grep '^agent-doctrine: .handbook' AGENTS.md` |
| **M6 is load-bearing** | on that fixture, a consumer's resolver returns `.handbook`; delete the line → returns `.records/doctrine` |
| `check` 4b asserts it | delete the declaration from a green fixture → `check` reports it |
| lint gate | `skills-lint.sh` `fails=0`, warns ≤ 22 (current baseline) |
| routing | S8's probe, ≥ 7/8 correct, logged |

The **M6-is-load-bearing** row is the one that proves the feature's headline claim rather than its
mechanism: it demonstrates a consumer actually resolving to `.handbook` *because* of the declaration,
which is the whole of Problem 3.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| **S1** | Package move + both test entrypoints | both `run.sh` green; `git log --follow` reaches pre-move | `skills/handbook/**`, `skills/clankshop/scripts/**` |
| **S2** | `handbook/SKILL.md` — the authority doc | `skills-lint.sh` `fails=0` | `skills/handbook/SKILL.md` |
| **S3** | `/handbook setup` verb | `seed-test.sh` green via the verb's documented call | `skills/handbook/verbs/setup.md` |
| **S4** | `context.sh --check` widened + 3 red-proofs | the four `--check` rows above | `skills/handbook/seed/scripts/context.sh`, `…/tests/seed-test.sh` |
| **S5** | **M6 — the doctrine-home declaration** (independently shippable) | the two M6 rows + `check` 4b row | `skills/clankshop/verbs/{setup,migrate,check}.md` |
| **S6** | `/handbook curate` verb | fixture with a hand-edited chapter → reported, unclassified | `skills/handbook/verbs/curate.md` |
| **S7** | clankshop narrowing (M7) + manifest/roster/doctrine folds (M8) | `clankshop` suite green; lint `fails=0`; version verified against siblings | `skills/clankshop/{SKILL.md,PACK.md,verbs/*}`, `README.md`, `DOCTRINE.md` |
| **S8** | Routing probe (M9) | ≥ 7/8, logged | `docs/boundary-audit.md`, possibly `handbook/SKILL.md` description |

**S5 is deliberately ordered before the cosmetic slices and is independently valuable** — it closes
Problem 3 on its own. If the extraction stalls, S5 still ships.

**Two slices touch `check.md`, deliberately and without conflict:** S5 adds the 4b declaration
assertion; S7 restructures steps 1–3 into the M5 delegation. Different steps of the same file, and
S7 depends on S4 having widened `--check` first. Order: S4 → S5 → S7.

**Scope note, stated honestly:** eight slices is at the upper bound for one feature — larger than
feature 2's six. It is one coherent architectural move (a layer gains an authority), so it is not
decomposable along its seams without leaving the face half-narrowed. But S5 is genuinely separable,
and if the loop needs a landing point mid-feature, **after S5 is the natural one**.

## Greenfield check

_Which mechanisms here exist only because of substrate we could delete instead? Named explicitly,
because a grounded review — which refutes claims against `HEAD` — structurally cannot raise them._

- **`.handbook` as a hardcoded path vs. seeding to the default home.** M6 exists *entirely* because
  the doctrine seed lands at `.handbook/` while `<agent-doctrine>` defaults to
  `<agent-records>/doctrine`. Delete that mismatch — have `/handbook setup` seed to the default home
  — and **M6 evaporates**: no declaration to write, no `check` 4b assertion, no asymmetry to explain,
  Problem 3 solved by construction rather than by a line of configuration.

  **Verdict: design around it, pay M6's cost.** `.handbook` is a term of art in 40+ places; the door
  pointer names it, all four clankshop verbs reference it, `DOCTRINE.md:228` cites it as the
  canonical override example, and **workshops already deployed in the field have the directory on
  disk** — a rename is a migration for every existing install, to save one declaration line. The
  variable was designed precisely so a project can centralize doctrine somewhere conventional; a
  workshop *is* that case. M6 is the mechanism working as intended, not debt.

  Worth recording that this is the *only* thing keeping `.handbook` special. If the term of art were
  ever retired, M6 and `check` 4b retire with it.

- **`seed.sh`'s refuse-on-existing.** Could be deleted in favor of an idempotent re-seed, which would
  simplify Guard (c) and `/handbook setup` both. **Pay the debt:** upgrade-as-diff is a deliberate
  safety property (a re-seed would silently clobber accreted project doctrine), and `curate` is the
  verb that finally honors it. Deleting the refusal would delete the reason `curate` exists.

- **The install stamp.** Already adjudicated upstream by feature 2 and rule 8 — it has legitimate
  *policy* consumers, and this spec touches it not at all. Named here only so a reader does not
  re-open it.

## Decision log

Settled by the human 2026-08-18 unless noted. **Do not re-litigate.**

1. **Scope: full symmetry**, not thin extraction — `seed/`, `seed.sh`, `context.sh`, plus `setup`
   and `curate` verbs.
2. **Tier `required:`**, alongside journal; `/clankshop setup` hard-stops without it, extending
   Guard (a). *(Settled after a brief revision to `optional:`.)*
3. **Name `handbook`**, accepting the skill-name/artifact-name collapse.
4. **Validation seam: grow `context.sh --check`**; no second deployed tool. Doctrine-internal facts
   to the loader, cross-layer assembly facts to the face, judgment to `curate`.
5. **`/handbook setup` deploys the full projection** (chapters + loader), not a tool layer only —
   because records are minted but doctrine is seeded.
6. **Guard (c) stays on the face**; handbook supplies the facts. Mirrors Guard (a) testing journal's
   availability without owning journal.
7. **`migrate` delegates the seed call only**; the mapping table and step-4 judgment merges stay on
   the face.
8. **`curate` diffs deployed vs current bundle**; the stamp is provenance in the report, never a
   differ input. No git-history reach.
9. **`install.sh` needs no change** *(resolved by verification, not by asking)*.
10. **The doctrine-home declaration is in scope and first-class** *(agent, from re-grounding)* — the
    face writes `agent-doctrine: .handbook` **always**, in `setup` 4 and `migrate` 4, asserted by
    `check` 4b.
11. **A routing probe runs at build time** with an authorized sub-agent dispatch — this feature's
    only delegation.

## Superseded framings

Recorded so they are not resurrected.

- **"Consumers probe a prose string to predict a tool"** *(the draft's Problem 3)* — **dead.**
  Feature 2 dissolved every *location* probe. Zero consumers now grep the stamp to find doctrine.
- **"The install stamp — split its two jobs"** — **superseded, and now doctrine-violating.** Its
  Job 1 proposed deleting the boolean probe in favor of an existence test of
  `.handbook/scripts/context.sh`. The 3 probes that survive feature 2 (`debugger:39`,
  `workstream/SKILL.md:101`, `workstream/verbs/create.md:119`) are **policy** probes — *is a
  workshop assembled, may its lanes run* — and a loader-existence test cannot answer a policy
  question. Rule 8 as shipped (`11ef5d8`) names those consumers and forbids exactly this cleanup:
  *"do not 'finish the migration' by deleting them."* **The stamp is entirely out of scope.**
  Job 2 (version anchor as provenance) survives untouched and needs no work.
- **"Required fold: rule 8's wording must change with the mechanism"** — **already shipped** in
  feature 2 + `11ef5d8`.
- **"Probe conversion touches six consumer skills"** *(the draft's largest risk)* — **dead** with
  the stamp work. This feature touches **zero** consumer skills, which is a strict risk reduction.
- **"`personify` is feature 3"** — stale numbering; it is **feature 4**.
- **Live stamp-site count** — the draft's "ten live sites across six skills" is now **8 live sites,
  3 of them probes across 2 skills**. Re-verify before citing.

## Grounding

Built against `main` @ `ce7e758` + branch `11ef5d8`. Verified at spec time, not assumed:

- No skill or directory named `handbook` exists; `skills/` holds 16 skills.
- `seed/` is 16 files; `seed.sh`, `context.sh`, `persona.md:14`'s fallback all intact and untouched
  by the `grok` landing.
- `context.sh --check` today checks **load sets only** (`check_all()`); exit codes 0/1/2 as
  documented.
- `setup.md` Guard (a) tests journal availability; step 3 delegates the records **tool** layer and
  forbids inlining — the precedent, verbatim.
- `setup.md` step 4 writes `agent-records:` **conditionally** and no `agent-doctrine:` line at all.
- `check.md` step 5 already delegates to `records.sh check` — the delegation precedent for M5.
- `migrate.md:50` calls `seed.sh` directly while `:52` delegates to `/journal setup` — the exact
  asymmetry S7 removes.
- **6 readers of `agent-doctrine:`, 0 writers**, repo-wide.
- `install.sh:96-98,151` parses `required:`/`optional:` as claimed.
- `PACK.md` at `2.4.0`, `required: journal`.
- `skills-lint.sh` baseline `fails=0 warns=22`.

## Status: PARKED (2026-08-18)

**Parked behind the path-consolidation feature.** This spec's central unresolved question — *where
does the seed land* — turned out to be downstream of a larger one: the front door carries three
path variables (`agent-records`, `agent-templates`, `agent-doctrine`) where two have no independent
variance case, and `.records/` hosts three directories it must explicitly exclude
(`records.sh:64,82`). Consolidating to two homes (a records file-cabinet + one "everything else"
home) changes this feature's answer, so it is specced first and this one resumes behind it.

**The findings below are path-independent** — they apply to the extraction whatever the doctrine
home ends up being. Do not re-derive them on resume.

## Review history

### 2026-08-18 — needs-rework (×3: soundness, groundedness, skeptic)

Three independent lenses, three different attack angles, unanimous verdict. Consolidated and
deduplicated; the reviewer that found each is noted where it matters.

**MUST-FIX — feasibility (proven, not argued)**

1. **`seed.sh` breaks on the move.** `seed.sh:54` reads the stamp version from `$SKILL/PACK.md`,
   and `PACK.md` stays on the face. Groundedness performed the move in a scratch copy: `seed.sh`
   exits 2 and leaves `_Seeded from clankshop v<version> on <date>._` unfilled. M1's "unchanged by
   the move" is true of one of the script's two sibling resolutions and silent about the one that
   breaks. **This hides an unmade decision:** once handbook owns the seed and the stamp format,
   where does the version come from? Reaching `../clankshop/PACK.md` is the cross-package reach M1
   forbids elsewhere; giving handbook its own version changes the string rule 8's three policy
   probes grep. Recommended: the face passes `--version` alongside `--gate`/`--trunk`.
   *(Consequence: "this spec touches the stamp not at all" is **false** — it breaks the stamp's
   production path. Rule 8 governs stamp consumers; nobody has adjudicated stamp ownership.)*
2. **Two more clankshop suites go red.** `face-test.sh:27,33,37-43` (script list, bundled-seed
   `--check`, v1-vocabulary scan) and `setup-journal-test.sh:22` all exercise the moving assets.
   "Clankshop suite green minus the moved suite" is unachievable as written. `setup-journal-test.sh`
   should resolve a `HANDBOOK=` sibling exactly as it already resolves `JOURNAL=` at `:10`.
3. **The moved `seed-test.sh` cannot be green unedited** — `:37` reads `$SKILL/PACK.md` the same
   way; same root cause as #1.

**MUST-FIX — verification that cannot do its job**

4. **The links arm has no world in which it can be green.** `grep -rn "](" seed/` returns **zero** —
   the seed contains no markdown links. So there is nothing to repoint for the red-proof, and the
   "other arms still pass" anti-partial-fix device is *vacuous* for that arm: a scanner flagging
   every link it finds would pass all four verification rows. Needs a green control (inject a valid
   link, assert it is not reported) before a red-proof means anything. The arm is also syntactically
   undefined — inline vs reference-style, anchors, out-of-handbook targets.
5. **"M6 is load-bearing" has no executable subject.** There is no runnable `agent-doctrine`
   resolver anywhere in `skills/`; `resolve_agent_doctrine()` exists only as a reference snippet at
   `DOCTRINE.md:275-285`, `skills-lint.sh:632` greps skill *prose*, and all consumers are prose
   rules. The row the spec calls its headline proof degrades to the grep its own Verification
   section forbids. The S1 lesson was applied to the `--check` arms and only nominally to the
   cross-layer claim.
6. **The new arms make the bundled seed un-self-checkable.** The seed legitimately carries ~20
   literal `<gate>`/`<trunk>` placeholders and an unfilled stamp; `context.sh --check` running green
   *against `seed/` itself* is a contracted property (`face-test.sh:32-34`, `README.md:94`). A slots
   arm destroys it. Also: `seed.sh`'s slot args are **optional** and its last line self-checks, so
   `seed.sh <root>` with no flags would exit 2 on a successful seed. And the stamp arm as specified
   passes on the *unfilled* template, so it is weaker than it reads.
7. **Widening a *deployed* `context.sh` silently degrades existing installs.** `context.sh` is a
   per-project copy frozen at seed time. Delegating `check` steps 2–4 to it means an older copy
   returns `load sets: OK` and the stamp/slots/links coverage vanishes with **no error** — `check`
   reports green on a workshop it no longer validated. Needs a capability probe with prose fallback.

**MUST-FIX — design decisions left unmade**

8. **`handbook` will not be a pack face, and loses exemptions that currently cover this content.**
   `skills-lint.sh:118-123` derives `is_pack_face()` from the presence of `PACK.md`. Check 15
   (`:641-679`) FAILs unconditionally on `` `.handbook/test/ ``-style literals, exempting only
   `skill-builder` and faces — its own header says *"clankshop legitimately owns the handbook."*
   After extraction the skill that legitimately owns it is `handbook`, which has no `PACK.md`.
   Check 14 would also require the doctrine authority to carry a resolution literal it never uses.
   M8's "`install.sh`: no change — verified" checked one machine surface and missed this one.
9. **`/handbook setup` vs Doctrine-touching rule 3.** Rule 3 permits creating the home *"only when
   the home is the derived default"* and *"never create an explicitly declared home that is
   absent."* Creating `.handbook` is neither. The doctrine authority appears to violate the portable
   doctrine on day one. *(Dissolves if the home becomes the derived default — see PARKED note.)*
10. **`curate` is not implementable as written.** How does a deployed project locate "the current
    bundled seed"? What is the diff unit, given accreted content below seeded preambles is
    *expected*, so nearly every file diverges on a healthy install? `ABSENT` is directionless — it
    reads identically for an untaken upgrade and for healthy project accretion.
11. **The seeded-vs-foreign boundary is undefined.** `auditor:108-109` writes its rubric to
    `<agent-doctrine>/test/workflows/audit/` and wires `core/ROUTING.md` + `test/POLICY.md` — it
    deposits *into* the station tree by design. `curate` would report every foreign artifact as
    drift forever. Needs journal's reserved-entries rule applied to doctrine. **Path-independent:
    true wherever the tree lives.**
12. **M6 had no idempotency or conflict rule**, and `check` 4b asserting the literal `.handbook`
    converts a front-door *variable* into a constant. *(Moot if M6 is deleted.)*

**Scope — both non-soundness reviewers converged independently**

13. **This should be two features.** The atomic core (move + SKILL.md + setup verb + narrowing +
    routing gate) genuinely cannot be split. But S5 (declaration), S4 (`--check` widening), and S6
    (`curate`) are independent additions bolted onto it — each would work on the face unmoved. The
    honest split: **(1) lifecycle + wiring**, closing both problems with demonstrated consequences,
    ~3 slices; **(2) the extraction**, closing the one problem with no stated cost.
14. **Problem 2 has no stated cost.** *"The face is the assembler; it should not also be the
    doctrine layer's implementation"* is asserted with no consequence attached, and no package-size
    or one-job principle in `DOCTRINE.md` grounds it. On the repo's evidence it is aesthetic.
15. **The strongest counter-alternative is missing:** *add `curate` to the face and skip the move
    entirely.* That closes Problems 1 and 3 at near-zero risk. The "Authority without extraction"
    bullet rejects a documentation-only strawman, not this.

**Problem 3 was under-stated, not over-stated** *(skeptic tried to refute it and failed)*

16. `/auditor setup` on a deployed workshop does not merely fail to find doctrine — per
    Doctrine-touching rule 3 it will **create a second doctrine tree** at `.records/doctrine/`
    beside the real one and wire routing into files the handbook's `check` never reads. That is
    active layout fragmentation, not graceful degradation. Concretely lost today on every seeded
    project: design-station summon (`blueprint:38`), build-station summon (`contractor:29`),
    `workstream`'s feature lane (`flow.md:56`), `debugger`'s diagnostics playbook (`SKILL.md:31`).

**Corrections to this spec's own Grounding**

17. **"6 readers" is 5 consumer skills + the lint gate** — `skills-lint.sh:632` greps prose, it does
    not resolve the variable. "0 writers of the declaration" **verified TRUE** by exhaustive grep.
18. **`1707ede` is misattributed twice** — it is *"docs: close records-layer init spec (shipped)"*,
    touching only a design doc, zero changes under `skills/`. Both substantive claims are true
    (`setup.md:39-44`; rule 4 at `DOCTRINE.md:316-318`); the SHA is wrong.
19. **The `.handbook`-vs-default-home verdict was right for the wrong reason.** The migration-burden
    argument rested on an unenumerated population — confirmed by the human as **one deployed
    workshop, theirs**. The real argument the section failed to make: `.handbook/README.md` is baked
    into the stamp probe contract at four sites (`DOCTRINE.md:337` + the three policy probes).
20. **`warns ≤ 22` fails by construction** — lint check 4 warns per-skill for not being wired into
    `~/.claude/skills` and not appearing in `README.md`'s inventory, so a new skill adds ≥1 warn
    (2 between S2 and S7). Budget the expected warns or scope the row to `fails=0`.
21. **M8's fold list is incomplete** — also stale on landing: `README.md:30,50,94`, `AGENTS.md:12`,
    `PACK.md:27`, `migrate.md:77`, `clankshop/SKILL.md:23`, `lint-exemption-test.sh`.

**Substrate the greenfield check missed** *(the biggest one, and the seed of the parking decision)*

22. **The copy-projection seed model itself.** `curate` exists *entirely* because 16 chapter files
    are **copied** into the project at setup. A design that kept bundled doctrine in the installed
    skill and had `context.sh` compose bundled chapters with a project-local delta would have no
    drift, no seed-diff, no `curate`, no stamp version, and no unfulfilled upgrade promise —
    Problem 1 would dissolve rather than earn a verb. Probably still "pay it" (the seed is meant to
    be edited in place), but the spec never named it.
23. **Slot substitution** — the permanent slots arm guards a substrate choice (string-substituting
    two facts into 16 files at copy time) the spec never questions.
24. **Name-based lint exemptions** — `is_pack_face` is a proxy for "owns the doctrine layer," and
    the extraction is precisely the event that breaks the proxy.

**Verified TRUE and not to be re-checked on resume:** all five consumer `agent-doctrine` readers;
0 writers repo-wide; `setup.md` Guard (a) / step 3 / step 4 behavior; `check.md:21-28` records
delegation; `migrate.md:50` vs `:52`; `context.sh --check` load-sets-only; `install.sh:96-98,151`
parsing (Decision 9 holds); `PACK.md` 2.4.0; `persona.md:14`; `DOCTRINE.md:228,236,61` and rule 8
verbatim; the 8/3/2 stamp census; `seed/` = 16 files; six per-skill `lib.sh` copies; lint baseline
`fails=0 warns=22`; clankshop suite currently all-green.
