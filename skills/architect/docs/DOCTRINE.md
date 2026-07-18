# The `/architect` doctrine — the `.agents/architect/` seed methodology

This is the portable methodology every verb links to. It encodes the founding
design spec as durable doctrine;
project-specific content (a project's actual `.agents/architect/` folder) never lives here.

## Two temporal kinds of doc

Every design document is one of two temporally-distinct kinds — conflating them is the disease
this system exists to cure:

| | **Change records** | **Standing specs** |
|---|---|---|
| Tense | past ("we decided to change X→Y") | present ("this is how it **is**") |
| Good for | building *forward*, incrementally | *regenerating* from a clean seed |
| Failure mode | superseding-chains → scar debt | — |
| Home | `.records/` (ADRs, plans) — operational | `.agents/architect/` — the seed |

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
MOST DURABLE   .agents/architect/VISION.md        — what the product IS (north star)
   ▲           .agents/architect/PHILOSOPHY.md    — core ideals ("seeds are sacred")     required spine
   │           .agents/architect/GLOSSARY.md      — shared vocabulary                    (presence-checked
   │           .agents/architect/MAP.md           — system index + seam graph             by /architect check)
   │           .agents/architect/src/<system>.md  · CONTRACT tier    — binding invariants, behavior, seams
   ▼                                    · REFERENCE-ARCH  — current shape, DISPOSABLE (a snapshot)
LEAST DURABLE
```

- **Spine at `.agents/architect/` root** is the "constitution" that *governs* the compile (like a repo's
  README/LICENSE/config). It is not itself compiled to code, and it is **required, not
  optional** — `/architect check` fails if `VISION`, `PHILOSOPHY`, `GLOSSARY`, or `MAP` is missing.
  The spine is what makes radical change *safe*: you can rewrite everything about one system
  without renegotiating a durable tenet like "seeds are sacred."
- **`.agents/architect/src/`** holds the compilable source specs, roughly 1:1 with code units. The compile
  metaphor is exact: `.agents/architect/src/<system>.md` is to `src/<code>` as a source file is to its build
  artifact — the spec is the durable input, the code is the disposable output regenerated from it.
- Depth tracks durability because it tracks *how much a single revision can invalidate*. A change
  to `VISION.md` reshapes everything below it; a change to one `src/<system>.md` reference-arch
  paragraph invalidates nothing else.

## The two-tier system spec

Each `.agents/architect/src/<system>.md` carries two tiers with different authority:

- **CONTRACT (binding).** Purpose, invariants, interfaces/seams, behavior, acceptance criteria,
  and the *why* behind hard constraints. This is law: a rebuild reads the contract — including its
  seams — as a binding requirement. **Seams live in the contract tier, not reference-arch** —
  this closes the leak where "disposable" architecture would otherwise smuggle old design into a
  rebuild. Nothing a rebuild is *required* to honor lives in the disposable tier.
- **REFERENCE-ARCHITECTURE (disposable).** The current shape of the implementation — explicitly
  stamped "current best guess; a rebuild MAY discard this." Kept **pointer-heavy**
  (`src/…:line`, never pasted code) so it rots gracefully instead of silently, and a validator
  (`/architect check`) can catch drift between the pointers and the code they point at.
  Baseline-stamped (`distilled_through_adr`, `distilled_through_commit`, `distilled_through_date`)
  so `distill` can work incrementally and `check` can compute distill-debt from clean,
  machine-parseable facts.

A contracts-only seed (no reference architecture) was considered and rejected: it under-specifies,
and agents re-litigate settled architecture on every rebuild. The two-tier seed gives a rebuild an
orienting snapshot (the reference-arch, a starting hint) while keeping every binding constraint —
seams included — in the contract tier, where a rebuild cannot accidentally skip it.

## The keystone: deletion is the context-hygiene mechanism

> You do not need a special "rebuild mode" or a fresh-context discipline to escape rotten code's
> incremental bias — if the rotten code is *gone*, there is nothing to inherit. The magic is not
> in the build; it is in the *prep that precedes it*. Code is the disposable **build output** of
> `.agents/architect/`.

This is made **structural**, not a rule to police, by running the clear and the build as **two
independent `/feature` executions**:

- A **clear run** (`/feature plan`+`build` executing a `/architect prep` brief) removes the retired
  code and/or exposes the new boundary. This is the *only* run that ever sees the retired code —
  it must, in order to remove it.
- A **build run** (`/feature plan`+`build` executing the feature design plan) rebuilds against the
  seed and the already-cleared tree. Its context holds only the feature design plan and the
  current tree — it has no path to the retired code, which lived only in the clear run's now-
  discarded context and in git history.

Because the two runs are separate invocations, "deletion is context hygiene" is not something an
agent has to remember to uphold — it *falls out* of running two independent executions instead of
one folded reasoning pass. That separation is a hard requirement on `/feature`'s execution
(never fold clear+build into one pass); `/architect`'s job ends once the prep brief exists. (Forward
reference: this is the mechanism `/architect prep`, Plan B, hands to `/feature`.)

## The seam — altitude, not medium

> `/architect` owns the *seed-altitude standing design*; `/feature` owns *feature-scope change +
> execution*.

The seam is **altitude**, not "docs vs. code" — `/feature design`/`plan` already produce documents
too, so docs-vs-code was never the real line. `/architect` reasons about and edits the *durable
seed* — the standing specs and the spine — and hands `/feature` **plans to execute**. `/feature`
takes a plan and runs its ordinary `plan`+`build` cycle to change code.

**"Code-blind" is a derived property, not the definition.** It falls out of the altitude split:
`/architect` never writes executable code, but that is a *consequence* of authoring seed-altitude
plans, not the reason the skill exists. Don't define `/architect` by what it refuses to touch —
define it by the altitude it operates at.

**The altitude discriminator** (the one collision risk — `/feature` also has `brainstorm`/`plan`):

> `/feature brainstorm|plan` mutate **code** (a change you build against the seed).
> `/architect brainstorm|plan` mutate **the seed itself** (the foundation you later regenerate code
> from). *Changing the foundation → `/architect`. Building on it → `/feature`.*

`/architect`'s own non-seed wiring (for example, updating a host's doc-linter when a folder moves) is
a **handoff to `/foreman` or `/feature`**, not done by `/architect` itself — that is code/operational
work, not seed authoring.

## Sufficiency, and its circularity

"Is this spec enough to rebuild from?" has no cheap proof. There is a trap: if `prep` reads the
old code and *patches* the spec to close gaps it finds, a successful rebuild afterward proves
*reverse-engineering skill*, not that the **standing seed** was sufficient on its own. The test is
only valid under discipline that breaks the circle:

1. **Freeze the seed** before prep runs — no further edits once the sufficiency test starts.
2. **Every gap `prep` finds is a sufficiency failure**, tracked as a metric — not silently patched
   and forgotten. A spec that needed reverse-engineering to complete was, by definition, not yet
   sufficient.
3. Run an **adversarial sufficiency review** of the frozen seed before trusting it.
4. The **build run gets fresh context** (the keystone's second, independent `/feature` run), and
   its **acceptance tests are authored independently of the prep pass** — never derived from the
   same reverse-engineering that produced the prep brief.

Only a rebuild that clears *independent* acceptance tests from a *frozen* seed, via the two-run
structural separation above, is evidence of sufficiency. This is the empirical test that Plan B
(`prep` + a clear run + a fresh-context build run) exists to run, and it is a hard gate before
adopting the rebuild workflow on any real project — not a routine check `/architect check` can
substitute for.

## Cheap `check`, deep `reconcile`

Validating the seed against reality is two jobs at two costs, and conflating them wastes one or
starves the other — the same shape as the cheap-check / expensive-read-test split in § Sufficiency:

| | **`check`** | **`reconcile`** |
|---|---|---|
| Cost | cheap, run often (every commit) | expensive, run occasionally (milestone / suspected drift) |
| Depth | **structural** — mechanically checkable | **semantic** — requires reading and judgment |
| Catches | missing spine/contract, pointer-drift, stale baselines, MAP gaps | contract and code diverged in *meaning* |
| How | a read-only fact script (`architect-check.sh`) | an agent reads each contract against the code it points at |
| Writes | nothing (facts to stdout) | one drift report to `.records/reports/` |

`check` is necessary but not sufficient (§ The one thing this script cannot tell you, `verbs/check.md`):
a contract can be present, concrete, and driftless while the code it governs has quietly grown a new
guarantee, lost an old invariant, or moved a named seam. That gap — *does the binding contract still
mean what the code does?* — is only closeable by reading, and reading every system's contract against
its code is too expensive to run on every commit. So it is its own occasional verb, `reconcile`,
aimed by `check`'s cheap facts: the `drift:<sys>` and stale-baseline signals point the expensive
semantic read at the systems most likely to have diverged first.

**`reconcile` detects and adjudicates; it never applies.** For each divergence it decides which side
is authoritative — **seed stale** (the code is the intended reality → recommend a seed update, or
`/architect distill` when the drift is accreted-ADR smear) vs **code drifted** (the code strayed from
the intended design → a defect for the caller to fix) — and *recommends*, human-in-the-loop. It
**never patches the seed and never touches code**: a seed edit is the human's or `distill`'s to make
on the recommendation, a code fix is the caller's. And it **writes only `.records/`** — the drift
report is a deliverable *about* the design, never the design itself (§ Deliverables in `.records/`,
seed in `.agents/architect/`). This is distinct from `/auditor`, which judges code *quality*;
`reconcile` judges design *conformance* — whether code and seed still agree.

## Extraction — the brownfield onramp

Greenfield projects grow a seed as they grow code. A brownfield codebase with **no design layer**
has the opposite problem: working code and nothing that says what it is *supposed* to do. `extract`
is the onramp — it recovers a first *draft* of the design from the code. But the draft it produces
is **descriptive, never prescriptive**, and keeping that distinction sharp is the whole point:

- **Descriptive** — a *map of what the code appears to do*. Contracts phrased as observation ("the
  code enforces X", "callers appear to rely on Y"), not as law.
- **Prescriptive** — a binding seed that *dictates* what a rebuild must guarantee. This is what
  `.agents/architect/` holds, and `extract` **cannot** produce it directly.

The reason is the **circularity trap** (§ Sufficiency, and its circularity): a seed reverse-engineered
from code and then used to regenerate that code proves only reverse-engineering skill — never that
the *standing seed was sufficient on its own*. An extracted draft that looks complete looks that way
*because* it was traced off working code; that resemblance is exactly the false confidence the
sufficiency discipline exists to break. So `extract`'s output is honest about its own status:

- Every drafted file is **stamped provisional** (`status: extracted — sufficiency-unproven`).
- A **sufficiency-gap report** ships alongside it — the ledger of invariants the code implies but
  never explains, acceptance criteria that can't be inferred, and everything a rebuild would have to
  guess. Each entry is a known place the draft is *not* self-sufficient, not a to-do afterthought.

A draft becomes a seed only through a **hardening** step `extract` hands off and does not perform: a
human editorial pass (deciding intended design, resolving the gap report) **then** the fresh-agent
read-test (§ Sufficiency) — and only then a fold into `.agents/architect/` via `/architect init`
migrate-mode. The human deciding what the design *should* guarantee is what breaks the circle; the
code deciding what it *happens* to do is what keeps a raw extraction circular.

## Deliverables in `.records/`, seed in `.agents/architect/`

There are two homes, and the write-boundary between them is a hard rule, not a convention:

| | **The seed** | **Deliverables** |
|---|---|---|
| Home | `.agents/architect/` | `.records/` (e.g. `.records/design-draft/`) |
| Status | curated, present-tense, binding | provisional analysis / working artifacts |
| Mutated by | `init`, `distill`, human editorial **only** | `extract`, `reconcile` (and other analysis verbs) |

**`extract` and `reconcile` write only `.records/`.** They produce analysis *about* the design — a
recovered draft, a drift report — which is a deliverable, not the design itself. Letting an analysis
verb write into `.agents/architect/` would relaunder the code's current shape back over curated
design, reintroducing exactly the "code is the source of truth" inversion the seed exists to invert
(§ Two temporal kinds of doc; the durability gradient). The seed is mutated only by the curated path:
`init` (compile/migrate), `distill` (collapse change-records), and direct human editorial. This is
the same source-vs-record split `auditor` and `foreman` run — the rubric/seed is durable and curated;
the findings/deliverables accumulate in `.records/`.
