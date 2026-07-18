# `/architect reconcile` — the deep semantic seed↔code drift check

`check`'s deep counterpart. Where `check` runs cheaply and often to catch *structural* rot
(missing spine, missing contract, pointer-drift, stale baselines) mechanically, `reconcile` is the
**expensive, occasional, semantic** read: it holds the seed's binding contracts against the
**actual code** and finds where the two have *diverged in meaning* — not just where a pointer rotted.
See `docs/DOCTRINE.md` § Cheap `check`, deep `reconcile` for the split, and § Deliverables in
`.records/`, seed in `.agents/architect/` for the write-boundary this verb obeys.

## Read this framing before you write anything

`reconcile` **detects and adjudicates; it never applies.** Two hard rules govern every step below:

1. **It never patches the seed and never touches code.** A seed edit — even one `reconcile` is
   certain of — is the human's or `distill`'s to make *on reconcile's recommendation*. A code fix is
   the caller's. `reconcile` states which side is authoritative and what should change; enacting it is
   someone else's turn.
2. **It writes ONLY to `.records/`.** Its whole output is one drift report under `.records/reports/`.
   It **never** writes into `.agents/architect/`. The report is a *deliverable* — analysis about the
   design — not the design itself; a write-path from an analysis verb into the seed would relaunder
   the code's current shape back over curated design, the exact inversion the seed exists to prevent
   (`docs/DOCTRINE.md` § Deliverables in `.records/`). `reconcile` also **never writes executable
   code** — standing architect discipline: it reads `src/` to compare, and authors prose only.

`reconcile` is deep and expensive — a per-system semantic read is not a per-change tax. Run it
occasionally (a milestone, a suspected drift, before trusting the seed for a rebuild), the way you
run the fresh-agent read-test — not on every commit the way you run `check`.

## 1. Preconditions — resolve root + date, confirm a seed exists

- Resolve the repo root (where `src/…:NN` reference-arch pointers resolve) and today's date
  (`YYYY-MM-DD`, `date +%F`) — the report's filename and header carry this date so the drift it
  records is legible against a known point in time.
- Confirm `.agents/architect/` exists. **No seed → this is not reconcile's job.** If the codebase has
  no design layer at all, point the user to `/architect extract` (recover a first draft from code)
  instead — there is nothing to reconcile the code *against* yet.
- Confirm the report home: `.records/reports/` under the repo root. Create it if absent.

## 2. Scope from `check` first — don't re-derive its structural facts

Run (or read a recent run of) `check`'s fact script and let it aim the expensive read:

```bash
bash <skill-dir>/scripts/architect-check.sh <project>/.agents/architect [<repo-root>]
```

`reconcile` **builds on** these facts rather than re-computing them — the script already establishes
the structural ground truth mechanically, and duplicating that in an expensive semantic pass wastes
the budget the semantic pass is *for*. Use the facts as a suspect list:

- **`drift:<sys>=<pointer>`** — a reference-arch pointer whose target moved or shrank. Structural
  drift is the loudest signal that a system's *semantics* moved too; start the semantic read here.
- **Stale `baseline_date:<sys>`** relative to the project's current ADRs/commits — the further a
  system's snapshot is from HEAD, the more code has changed under a spec that didn't move. High-churn,
  stale-baseline systems are the next tier of suspects.
- **`acceptance_placeholder:<sys>=true`** — a system with no concrete gate can't be conformance-tested,
  so its contract is especially likely to have drifted unnoticed.

Start with the systems these signals flag; **widen to the rest as the session budget allows.** A
system `check` reports clean is not proven semantically conformant (that's the whole reason
`reconcile` exists — see § The one thing `check` cannot tell you in `verbs/check.md`), so a full pass
reads every system; a budget-limited pass reads the suspects and says in the report which systems it
did **not** reach.

## 3. Per-system semantic read — contract vs. actual code

For each system in scope, read its `## Contract (BINDING)` and its `## Reference Architecture`
against the code the reference-arch tier points at (`src/…:NN`). You are not checking that the
pointers *resolve* (that's `check`); you are checking that the code's actual behavior and the
contract's claims still **mean the same thing**. Hunt three kinds of divergence:

- **Code guarantees something the contract omits.** The code enforces an invariant, ordering, or
  error-handling that the binding contract never states — a real guarantee callers may rely on, living
  only in the implementation.
- **Contract claims behavior the code lost.** The contract states an invariant or behavior the code no
  longer honors — a binding requirement the implementation quietly dropped or changed.
- **A named seam the code moved or dropped.** The contract names an interface/seam (seams are binding —
  `docs/DOCTRINE.md`) that the code has relocated to a different boundary, merged away, or deleted.

Record each divergence concretely — which contract clause, which code location (`src/…:NN`), and what
the two disagree about — so the adjudication in Step 4 and the caller acting on it both have evidence,
not a vibe.

## 4. Adjudicate each divergence — decide the authoritative side, recommend, do not apply

A divergence is not automatically a bug and not automatically stale seed — it is a *disagreement*,
and the judgment `reconcile` exists to make is **which side is authoritative.** For each one, decide:

- **Seed stale — the code is the intended reality.** The implementation is where the design actually
  went; the contract simply didn't keep up. → **Recommend a seed update** that folds the code's real
  behavior into the contract. If the divergence is the accumulation of decisions made across ADRs/plans
  that were never folded back (an ADR-smear, `docs/DOCTRINE.md` § Two temporal kinds of doc), recommend
  **`/architect distill`** for that system rather than a hand-patch — distill is the verb that collapses
  accreted change-records into a clean present-tense spec.
- **Code drifted — the code diverged from the intended design.** The contract is right; the
  implementation strayed from it. → **Flag it as a defect for the caller to fix** in code. This is a
  conformance failure, not a spec-staleness problem.

State the recommendation explicitly on each divergence — *which* side wins and *what* should change —
but **do not enact it.** `reconcile` never patches the seed (that's the human's or `distill`'s turn on
this recommendation) and never touches code (that's the caller's). When the authoritative side is
genuinely unclear, say so and hand the human the decision with the evidence; a confident-wrong verdict
is worse than an honest "you decide."

## 5. Write the report to `.records/` — never the seed

Write one report: `.records/reports/reconcile-<YYYY-MM-DD>.md` (today's date from Step 1). If one
already exists for today (a re-run), supersede it in place and say so, rather than layering a second.
Structure it so the human can act on it and the next reader can trust its provenance:

- **Header** — the date, the repo HEAD short SHA reconciled against, and the `check` baseline it
  scoped from (Step 2). This stamps *what the report was built against* so its age is legible later.
- **Scope** — which systems were read semantically, and (for a budget-limited pass) which were **not**
  reached, so a clean absence isn't mistaken for a clean verdict.
- **Per-system divergences** — each divergence from Step 3 (contract clause ↔ code `src/…:NN` ↔ the
  disagreement), its Step 4 adjudication (seed-stale vs code-drifted), and the concrete recommendation
  (seed update / `/architect distill` / code defect to fix / human decides).

**Never write `.agents/architect/`.** The seed edits the report *recommends* are made later, by the
human or `distill` — not by `reconcile`.

## 6. Report + commit

Close `reconcile` with a chat summary: systems reconciled (and any left unread), the headline
divergences, the seed-stale vs code-drifted split, and the explicit next steps (which recommendations
go to a human editorial pass or `/architect distill`, which are code defects for the caller). Make the
recommend-not-apply boundary unmissable — nothing here was applied.

Commit only the report path written this run, scoped and pathspec-atomic, no `Co-Authored-By` trailer.

## The seams around this verb

- **vs `check`** — `check` is the cheap, frequent, *structural* gate (does a pointer resolve, is a
  contract present); `reconcile` is the deep, occasional, *semantic* read (does the contract still
  *mean* what the code does). `reconcile` consumes `check`'s facts to aim itself; it does not replace
  them.
- **vs `distill`** — `distill` folds accreted *change-records* (ADRs, plans) into the spec; it reads
  code only to catch decisions that never got an ADR. `reconcile` is a direct *contract-vs-code*
  comparison and enacts nothing — when it finds an ADR-smear, it **recommends** `distill`, it doesn't
  perform the fold.
- **vs `/auditor`** — `/auditor` judges code *quality* against a rubric; `reconcile` judges design
  *conformance* — whether the code and the binding seed still agree. Different question, different home
  for the finding.

## Discipline this verb carries

- **Never patch the seed; never touch code** (framing rule 1) — detect and adjudicate; recommend, the
  human or `distill` or the caller enacts.
- **Never write executable code** (framing rule 2) — read `src/` to compare; author prose only.
- **Write only `.records/`** (framing rule 2) — the report is a deliverable; the seed stays pure,
  mutated only by the curated path (`init`/`distill`/human editorial).
- **A snapshot must not pose as authoritative** (`docs/DOCTRINE.md`) — the report is stamped with the
  HEAD and `check` baseline it was built against, and names the systems it did not reach.
