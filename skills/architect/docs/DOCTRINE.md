# The `/architect` doctrine — the `.agents/design/` seed methodology

This is the portable methodology every verb links to. It encodes the founding
design spec as durable doctrine;
project-specific content (a project's actual `.agents/design/` folder) never lives here.

## Two temporal kinds of doc

Every design document is one of two temporally-distinct kinds — conflating them is the disease
this system exists to cure:

| | **Change records** | **Standing specs** |
|---|---|---|
| Tense | past ("we decided to change X→Y") | present ("this is how it **is**") |
| Good for | building *forward*, incrementally | *regenerating* from a clean seed |
| Failure mode | superseding-chains → scar debt | — |
| Home | `.agents/dev/` (ADRs, plans) — operational | `.agents/design/` — the seed |

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
MOST DURABLE   .agents/design/VISION.md        — what the product IS (north star)
   ▲           .agents/design/PHILOSOPHY.md    — core ideals ("seeds are sacred")     required spine
   │           .agents/design/GLOSSARY.md      — shared vocabulary                    (presence-checked
   │           .agents/design/MAP.md           — system index + seam graph             by /architect check)
   │           .agents/design/src/<system>.md  · CONTRACT tier    — binding invariants, behavior, seams
   ▼                                    · REFERENCE-ARCH  — current shape, DISPOSABLE (a snapshot)
LEAST DURABLE
```

- **Spine at `.agents/design/` root** is the "constitution" that *governs* the compile (like a repo's
  README/LICENSE/config). It is not itself compiled to code, and it is **required, not
  optional** — `/architect check` fails if `VISION`, `PHILOSOPHY`, `GLOSSARY`, or `MAP` is missing.
  The spine is what makes radical change *safe*: you can rewrite everything about one system
  without renegotiating a durable tenet like "seeds are sacred."
- **`.agents/design/src/`** holds the compilable source specs, roughly 1:1 with code units. The compile
  metaphor is exact: `.agents/design/src/<system>.md` is to `src/<code>` as a source file is to its build
  artifact — the spec is the durable input, the code is the disposable output regenerated from it.
- Depth tracks durability because it tracks *how much a single revision can invalidate*. A change
  to `VISION.md` reshapes everything below it; a change to one `src/<system>.md` reference-arch
  paragraph invalidates nothing else.

## The two-tier system spec

Each `.agents/design/src/<system>.md` carries two tiers with different authority:

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
> `.agents/design/`.

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
