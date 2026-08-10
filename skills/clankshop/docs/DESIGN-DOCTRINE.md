# The `/clankshop design` doctrine — the `.handbook/design/` seed methodology

This is the portable methodology the `design` verbs link to. It states the seed method as durable
doctrine; project-specific content (a project's actual `.handbook/design/` folder) never lives
here.

## Two temporal kinds of doc

Every design document is one of two temporally-distinct kinds — conflating them is the disease
this system exists to cure:

| | **Change records** | **Standing specs** |
|---|---|---|
| Tense | past ("we decided to change X→Y") | present ("this is how it **is**") |
| Good for | building *forward*, incrementally | knowing how it *is* — whole, scar-free |
| Failure mode | superseding-chains → scar debt | — |
| Home | `.records/` (ADRs, plans) — operational | `.handbook/design/` — the seed |

**The ADR-smear disease:** a project's authoritative present-tense truth ends up smeared across a
stack of past-tense decisions — to know how a system works *today*, an agent has to read ADR N
**+** ADR N-1 **+** ADR N-2 **+** … as a superseding chain. Reading the chain means inheriting the
*scars*: every dead end, reversal, and partial correction the system ever passed through, plus the
incremental bias those scars encode. A standing spec has no chain — it reads as though the system
were designed whole, present-tense, today. Change records are essential (they are how forward,
incremental work stays cheap and reviewable) but they are never the source of truth for "how does
this work now" — that job belongs to the seed.

## The durability gradient

The seed is organized along a durability gradient, encoded in directory depth: shallow is durable,
deep is disposable.

```
MOST DURABLE   .handbook/design/VISION.md        — what the product IS (north star)
   ▲           .handbook/design/PHILOSOPHY.md    — core ideals ("seeds are sacred")
   │           .handbook/design/GLOSSARY.md      — shared vocabulary
   │           .handbook/design/MAP.md           — system index + seam graph
   │           (the four above: the required spine, presence-checked by `design health`)
   │           .handbook/design/src/<system>.md  · CONTRACT tier — binding invariants, behavior, seams
   ▼                                             · REFERENCE-ARCH — current shape, DISPOSABLE (a snapshot)
LEAST DURABLE
```

- **Spine at `.handbook/design/` root** is the "constitution" that governs everything below it
  (like a repo's README/LICENSE/config), and it is **required, not optional** — `/clankshop design
  health` fails if `VISION`, `PHILOSOPHY`, `GLOSSARY`, or `MAP` is missing. The spine is what
  makes radical change *safe*: you can rewrite everything about one system without renegotiating a
  durable tenet like "seeds are sacred."
- **`.handbook/design/src/`** holds the per-system specs, roughly 1:1 with code units:
  `.handbook/design/src/<system>.md` is the standing statement of what `src/<code>` must be — the
  spec is the durable truth the code is held to.
- Depth tracks durability because it tracks *how much a single revision can invalidate*. A change
  to `VISION.md` reshapes everything below it; a change to one `src/<system>.md` reference-arch
  paragraph invalidates nothing else.

## The two-tier system spec

Each `.handbook/design/src/<system>.md` carries two tiers with different authority:

- **CONTRACT (binding).** Purpose, invariants, interfaces/seams, behavior, acceptance criteria,
  and the *why* behind hard constraints. This is law: an implementer reads the contract —
  including its seams — as a binding requirement. **Seams live in the contract tier, not
  reference-arch** — this closes the leak where "disposable" architecture would otherwise smuggle
  old design into new work. Nothing an implementation is *required* to honor lives in the
  disposable tier.
- **REFERENCE-ARCHITECTURE (disposable).** The current shape of the implementation — explicitly
  stamped "current best guess — not binding." Kept **pointer-heavy** (`src/…:line`, never pasted
  code) so it rots gracefully instead of silently, and a validator (`/clankshop design health`)
  can catch drift between the pointers and the code they point at. Baseline-stamped
  (`distilled_through_adr`, `distilled_through_commit`, `distilled_through_date`) so `distill` can
  work incrementally and `health` can compute distill-debt from clean, machine-parseable facts.

A contracts-only seed (no reference architecture) was considered and rejected: it under-specifies,
and agents re-litigate settled architecture on every change. The two-tier seed gives new work an
orienting snapshot (the reference-arch, a starting hint) while keeping every binding constraint —
seams included — in the contract tier, where an implementer cannot accidentally skip it.

## The seam — altitude, not medium

> `/clankshop design` owns the *seed-altitude standing design*; `/feature` owns *feature-scope
> change + execution*.

The seam is **altitude**, not "docs vs. code" — `/feature design`/`plan` already produce documents
too, so docs-vs-code was never the real line. `/clankshop design` reasons about and edits the
*durable seed* — the standing specs and the spine — and hands `/feature` **plans to execute**.
`/feature` takes a plan and runs its ordinary `plan`+`build` cycle to change code.

**"Code-blind" is a derived property, not the definition.** It falls out of the altitude split:
`/clankshop design` never writes executable code, but that is a *consequence* of authoring
seed-altitude plans, not the reason the verb family exists. Don't define `/clankshop design` by
what it refuses to touch — define it by the altitude it operates at.

**The altitude discriminator** (the one collision risk — `/feature` also has `brainstorm`/`plan`):

> `/feature brainstorm|plan` mutate **code** (a change you build against the seed). `/clankshop
> design brainstorm|plan` mutate **the seed itself** (the foundation code is built against).
> *Changing the foundation → `/clankshop design`. Building on it → `/feature`.*

`/clankshop design`'s own non-seed wiring (for example, updating a host's doc tooling when a
folder moves) is a **handoff to `/clankshop route` or `/feature`**, not done by `/clankshop
design` itself — that is code/operational work, not seed authoring.

## Sufficiency, and its circularity

"Does this spec say enough?" has no cheap proof. The structural checks (`health`) can prove a
contract present and its pointers live — they cannot prove the contract *says enough to act on*.
The semantic gate is the **fresh-agent read-test**: hand an agent *only* the spec — no ADR access,
no chat history, no author-remembers context — and confirm it can act on it correctly, without
guessing. Run it occasionally, the way you run `reconcile`; it is the expensive proof the cheap
checks cannot substitute for.

There is a trap to respect: a spec traced off working code *looks* sufficient because the code
answered every question — but **observation is not decided intent**. A draft recovered from code
(§ Extraction) proves reverse-engineering skill, never that the standing spec says enough on its
own. Only a human deciding what the design *should* guarantee breaks that circle; every place a
code-traced draft would have to guess is a sufficiency gap to resolve, never a blank to fill from
the implementation.

## Cheap `health`, deep `reconcile`

Validating the seed against reality is two jobs at two costs, and conflating them wastes one or
starves the other — the same shape as the cheap-check / expensive-read-test split in §
Sufficiency:

| | **`health`** | **`reconcile`** |
|---|---|---|
| Cost | cheap, run often (every commit) | expensive, run occasionally (milestone / suspected drift) |
| Depth | **structural** — mechanically checkable | **semantic** — requires reading and judgment |
| Catches | missing spine/contract, pointer-drift, stale baselines, MAP gaps | contract and code diverged in *meaning* |
| How | a read-only fact script (`design-check.sh`) | an agent reads each contract against the code it points at |
| Writes | nothing (facts to stdout) | one drift report to `.records/reports/` |

`health` is necessary but not sufficient (§ The one thing this script cannot tell you,
`verbs/design/health.md`): a contract can be present, concrete, and driftless while the code it
governs has quietly grown a new guarantee, lost an old invariant, or moved a named seam. That gap
— *does the binding contract still mean what the code does?* — is only closeable by reading, and
reading every system's contract against its code is too expensive to run on every commit. So it is
its own occasional verb, `reconcile`, aimed by `health`'s cheap facts: the `drift:<sys>` and
stale-baseline signals point the expensive semantic read at the systems most likely to have
diverged first.

**`reconcile` detects and adjudicates; it never applies.** For each divergence it decides which
side is authoritative — **seed stale** (the code is the intended reality → recommend a seed
update, or `/clankshop design distill` when the drift is accreted-ADR smear) vs **code drifted**
(the code strayed from the intended design → a defect for the caller to fix) — and *recommends*,
human-in-the-loop. It **never patches the seed and never touches code**: a seed edit is the
human's or `distill`'s to make on the recommendation, a code fix is the caller's. And it **writes
only `.records/`** — the drift report is a deliverable *about* the design, never the design itself
(§ Deliverables in `.records/`, seed in `.handbook/design/`). This is distinct from `/auditor`,
which judges code *quality*; `reconcile` judges design *conformance* — whether code and seed still
agree.

## Extraction — the brownfield onramp

Greenfield projects grow a seed as they grow code. A brownfield codebase with **no design layer**
has the opposite problem: working code and nothing that says what it is *supposed* to do.
`extract` is the onramp — it recovers a first *draft* of the design from the code. But the draft
it produces is **descriptive, never prescriptive**, and keeping that distinction sharp is the
whole point:

- **Descriptive** — a *map of what the code appears to do*. Contracts phrased as observation ("the
  code enforces X", "callers appear to rely on Y"), not as law.
- **Prescriptive** — a binding seed that *dictates* what an implementation must guarantee. This
  is what `.handbook/design/` holds, and `extract` **cannot** produce it directly.

The reason is the **circularity trap** (§ Sufficiency, and its circularity): a spec
reverse-engineered from code proves only reverse-engineering skill — never that the *standing seed
says enough on its own*. An extracted draft that looks complete looks that way *because* it was
traced off working code; that resemblance is exactly the false confidence the sufficiency
discipline exists to break. So `extract`'s output is honest about its own status:

- Every drafted file is **stamped provisional** (`status: extracted — sufficiency-unproven`).
- A **sufficiency-gap report** ships alongside it — the ledger of invariants the code implies but
  never explains, acceptance criteria that can't be inferred, and everything an agent acting on
  the spec would have to guess. Each entry is a known place the draft is *not* self-sufficient,
  not a to-do afterthought.

A draft becomes a seed only through a **hardening** step `extract` hands off and does not perform:
a human editorial pass (deciding intended design, resolving the gap report) **then** the
fresh-agent read-test (§ Sufficiency) — and only then a fold into `.handbook/design/` via
`/clankshop design seed` migrate-mode. The human deciding what the design *should* guarantee is
what breaks the circle; the code deciding what it *happens* to do is what keeps a raw extraction
circular.

## Deliverables in `.records/`, seed in `.handbook/design/`

There are two homes, and the write-boundary between them is a hard rule, not a convention:

| | **The seed** | **Deliverables** |
|---|---|---|
| Home | `.handbook/design/` | `.records/` (e.g. `.records/design/draft/`) |
| Status | curated, present-tense, binding | provisional analysis / working artifacts |
| Mutated by | `seed`, `distill`, human editorial **only** | `extract`, `reconcile` (and other analysis verbs) |

**`extract` and `reconcile` write only `.records/`.** They produce analysis *about* the design — a
recovered draft, a drift report — which is a deliverable, not the design itself. Letting an
analysis verb write into `.handbook/design/` would relaunder the code's current shape back over
curated design, reintroducing exactly the "code is the source of truth" inversion the seed exists
to invert (§ Two temporal kinds of doc; the durability gradient). The seed is mutated only by the
curated path: `seed` (compile/migrate), `distill` (collapse change-records), and direct human
editorial. This is the same source-vs-record split `/auditor` and the foreman hat run — the
rubric/seed is durable and curated; the findings/deliverables accumulate in `.records/`.
