# The doctrine home — how this project works

Doctrine for the workshop: policy and procedure — always *how we work*, never *what we are
building* (that lives in the design spec, `.records/specs/`). Readable by humans and agents
alike. This README is the entry point and orientation; it is **not** part of any station's load
set, so nothing pays for it twice.

## The line

The workshop is a line of four **stations**. Work moves through them in lifecycle order; each is
a standing area of work with its own doctrine:

| station | covers |
|---|---|
| `design` | design and specification — the spec the code is measured against |
| `build` | planning and development — workflows, worktrees, development resources |
| `test` | testing and gating prior to release — fixtures, CI/CD, diagnostics |
| `review` | upkeep after each cycle — records, doctrine, door, improvement loop |

**The flow of a change:** work enters at the door (`AGENTS.md` routes it); `core/ROUTING.md`
classifies it; **design** shapes anything with a design decision at stake; **build** plans and
lands it through a workflow lane; **test** gates it before it ships; **review** sweeps up after —
debriefs recorded, records curated, doctrine corrected where practice diverged. Small work skips
straight to its lane; the stations it doesn't need cost nothing.

## Load rule

> To work station X, read `core/*` plus `<station>/POLICY.md`. Procedures are not
> loaded until one is selected; `core/ROUTING.md` still selects a classification-lane
> path under `<agent-workspace>/flows/`.

Policy is always-on; procedures are pay-per-use. `scripts/context.sh <station>` renders a
station's load set on demand (`--list` for the reading list, `--check` for the contract test).

## Layout

```
.dev/               # the default agent-workspace; a declared `agent-workspace:` moves it
  doctrine/         # how we work
    README.md       # this file — orientation; outside every load set
    core/           # every station loads this — the shared floor
      POLICY.md     #   workshop-wide standing judgments
      INVARIANTS.md #   hard rules, never overridden
      GOTCHAS.md    #   project traps: working-as-coded but surprising
      ROUTING.md    #   how work is classified and dispatched
    design/         # the design station
      POLICY.md     #   station policy + chores
    build/          # the build station                    (same shape)
    test/           # the test station                     (same shape)
    review/         # the review station                   (same shape)
    scripts/        # deployed tooling: context.sh (records tooling lives with the records)
  flows/            # host procedures (sibling of doctrine/; not loaded until one is selected)
```

## Precedence

`core/` is the floor. A station's `POLICY.md` may *refine* core but never restate or contradict
it — a restatement is a bug the review station fixes. Shared doctrine lives once, in core, and is
linked.

## Records

Work products accumulate in `.records/` — the stores, the front-matter contract, and
`records.sh` (query, lifecycle, the history ledger) are the records layer's own domain; see
`.records/README.md`.

---

_Seeded from clankshop v<version> on <date>._
