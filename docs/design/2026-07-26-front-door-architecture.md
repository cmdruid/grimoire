# Front-door architecture — read-cost tiers + the compiled routing table

**Status:** Designed (2026-07-26); not yet implemented. Rollout surfaces are listed in §7; none have
been touched.

**Goal:** Bound what a session pays to discover its instructions. An agent's path from "I need to do
X" to "the chunk of instructions for X" is a sequence of reads; this doc fixes the architecture that
makes that path short (few actions) and cheap (few irrelevant tokens per action), and names the
machinery that keeps it that way. It governs what `foreman init` stamps into every consuming
project's front door, so it is library doctrine, not one project's layout note.

**References:**
- `packs/clankshop.md` — the runbook that owns the glue content this doc shapes (door profile, seams).
- `docs/design/2026-07-18-skill-boundaries-and-glue-ownership.md` — birth/growth split (`clankshop`
  births, `foreman` stamps + grows) this doc extends to the routing table.
- `skills/chiropractor/RUBRIC.md` — the entry-door checks + facts (`always_loaded_bytes`,
  `max_depth`, `doc_sizes`) that become this doc's measures.
- The design conversation this doc records (2026-07-26 session).

---

## 1. The problem — reads are the unit of cost

Every instruction an agent can follow lives somewhere in a hierarchy: the always-loaded front door
(`AGENTS.md` + its `@`-imports + skill descriptions), the docs it links, the skills it names, their
verb files. Discovery cost has two axes:

- **Depth** — how many actions (file reads or skill invocations) from session start to the chunk.
- **Payload** — how many tokens each action loads, and what fraction of them serve the task at hand.

The waste to eliminate is precise on both axes: a read whose only content is *which read to do next*
(pure depth waste), and a read that loads N workflows to perform one (pure payload waste).

## 2. The tier model

- **Tier 0 — always loaded.** `AGENTS.md` + `@`-imports + skill descriptions. Paid every session;
  free at decision time.
- **Tier 1 — one action away.** A doc linked from the door; a `SKILL.md` reached by invocation.
- **Tier 2 — two actions away.** Verb files; deep procedure docs; deployed templates.

**Hard rules** (mechanically checkable, harness-independent):

1. **Decisions at tier 0.** Anything needed *to choose the next action* — the routing table, the
   gate command, where the map is — is always-loaded.
2. **Procedure within two actions.** Every executable workflow instruction is reachable from tier 0
   in ≤ 2 actions.
3. **No menu-only reads.** No document whose sole content is which document to read next. A hub
   either fits in the door or carries real procedure.
4. **One job per payload.** A tier-1/2 document carries the instructions for one task, not a family
   of them.

**One soft budget:** an `always_loaded_bytes` target, judged against project maturity — overage is
drift to report, not a hard failure (a monorepo's legitimate door differs from a library's).

**The duality that reconciles rules 3 and 4:** menus are only legal at tier 0, where they are free;
payloads are only legal at tier 1+, where they are deferred. A menu at tier 1 is a wasted read; a
payload at tier 0 taxes every session. Every piece of content has exactly one right altitude —
*deciding* content floats to the door, *doing* content sinks to a single-job leaf.

**The merge/split test** (so sharding doesn't overshoot): **split** a doc when its sections serve
different tasks — an agent doing task A shouldn't pay for task B's instructions. **Merge** docs that
are always read together — two chunks that only ever co-load are one job paying two action
overheads. The floor is "a complete job per read," not "smallest possible files."

The skill channel already obeys this shape — a thin `SKILL.md` router dispatching to per-verb files
read on demand *is* rule 4. This doc's contribution is stating the same law for the deployed doc
tree, so both channels are one architecture.

## 3. The compiler model — foreman's API for routing

The routing knowledge exists in exactly one authoritative place and is *projected*, not duplicated:

| role | artifact | owning verb |
|---|---|---|
| **Source** | `.agents/foreman/docs/ROUTING.md` decision-walk — project policy, tunable. (Renamed from `DEVELOPMENT.md` as part of this rollout: the old name said nothing; the new one names the content — classification rules + where each class goes — and pairs with the compiled table and `/foreman route`.) | `/foreman calibrate` edits it |
| **Compiled projection** | the `AGENTS.md` routing table — trigger → lane entry, ~10–15 lines | `init` stamps; `calibrate` regrows |
| **Interpreter (slow path)** | `/foreman route` — classification for inputs the table doesn't decide | `route` |
| **Drift gate** | projection ↔ source ↔ installed-skills consistency | `/foreman check` (via `foreman-health.sh check-projection`) |

**The agent's contract at the table:** dispatch **directly** — invoke the lane's entry point (or
follow the by-hand fallback when no skill runner is available). `/foreman route` is the *exception
handler*, reached only from the table's own "unsure / mixed altitude" row — never a mandatory front
gate, which would cost 2–3 reads per classification (§8, alternative A).

**The table never re-documents a lane.** Rows carry a trigger and an entry point; each entry point
is a self-describing skill (its own `description:` takes over). Verb rosters or lane protocol in the
table is the enumerated-roster rot the boundary doctrine already forbids in skill bodies.

## 4. The door profile (what `foreman init` stamps)

Ordered tier-0 content — the shape `clankshop.md` specifies and `init` stamps on greenfield:

1. **what-this-is** — 1–2 lines.
2. **build / run / gate commands.**
3. **routing table + fallback line** — verb-first rows; one shared line beneath: *"no skill runner?
   follow `.agents/foreman/docs/ROUTING.md` by hand."*
4. **repo map** — links, one hop.
5. **pointers** — conventions, gotchas, ownership index.

Reference table shape (illustrative, not a template a project must copy verbatim):

```
| you're about to…            | go                                    |
|-----------------------------|---------------------------------------|
| fix a reproducible bug      | `/debugger` (file it: `/backlog bug`) |
| land a one-line patch       | trunk, no ceremony                    |
| build a feature             | `/feature`                            |
| change a tenet/contract/seam| `/architect`                          |
| capture a follow-up         | `/backlog`                            |
| unsure / mixed altitude     | `/foreman`                            |
```

## 5. The audit seam — affordance vs. fidelity

Two auditors render different verdicts on the same door, and neither crosses:

- **`chiropractor` scores form** — routing *affordance* (a cold agent can tell where work starts),
  depth (rule 2), payload precision (rule 4), the soft byte budget. Portable: judged in any repo,
  phrased generically, no knowledge of the composition.
- **`/foreman check` scores fidelity** — the compiled table matches the decision-walk and the
  installed skills. Deployed projects only; requires the composition knowledge only foreman has.

This sharpens the existing `foreman ↔ chiropractor` seam row (specify → stamp → audit) with the
affordance/fidelity wording.

## 6. Steward framing (context this doc assumes, not new scope)

`foreman` is the steward of the **operational layer**: workflow routes and their descriptions, plus
project memory (`.agents/foreman/` MEMORY / GOTCHAS / durable notes) — `migrate` as the brownfield
onramp, `calibrate` as the feedback drain. `architect` is the same grammar over the **design
layer**: principles, specs, and ADR distillation. Two precision notes: ADRs are *written* by the
feature lane into `.records/adr/` and *distilled* into the seed by architect (steward of the seed,
not owner of the store); and architect currently has **no feedback-drain verb** — design-flavored
signal reaches the seed only through foreman's over-broad calibrate. Completing that steward grammar
(per-layer calibrate verbs consuming `tracker-entry` by type, foreman's calibrate classifying and
dispatching the slices) is **future work**, deliberately outside this doc.

## 7. Rollout — the four surfaces

1. **`packs/clankshop.md`** — the recipe owns glue content: add the door profile spec (§4) and the
   routing-table shape; sharpen the `foreman ↔ chiropractor` seam row with §5's wording; name the
   routing table as a compiled projection in the layout narrative.
2. **`foreman`** — `verbs/init.md` stamps the §4 profile; `verbs/calibrate.md` regrows the table
   when policy or installed skills change; `verbs/check.md` / `foreman-health.sh check-projection`
   confirmed (or extended) to compare table ↔ decision-walk ↔ installed skills; `verbs/route.md`
   gains one line naming route the slow path behind the door's table. Two doc-tree changes ride
   along: **rename `docs/DEVELOPMENT.md` → `docs/ROUTING.md`** (blast radius: `BOOTSTRAP.md`, the
   verb files, `foreman-health.sh` if it greps the name, `packs/clankshop.md`; deployed projects
   pick the rename up via `migrate`/`calibrate`), and **dissolve `docs/WORKFLOWS.md`** — the
   deployed tree's own "index of common how-tos (pointers, not restatements)" is a menu-only
   tier-1 doc that rule 3 forbids; its lane-entry rows fold into the door's routing table, the
   rest into the ownership-index pointers.
3. **`chiropractor`** — rubric only; the scanner already emits the needed facts. Entry-Door Audit
   gains **Check 5: Routing Affordance** (a routing affordance exists, rows dispatch directly, a
   no-runner fallback is present — form only, never route correctness). The Read-Path dimension
   absorbs rule 2; the token-economy dimension absorbs rule 4's split-candidate judgment over
   `doc_sizes`. All additions phrased generically — chiropractor names no skill and assumes no
   grimoire deployment.
4. **`AGENTS.md` (grimoire's own)** — at most a one-line pointer to this doc from the design-
   philosophy section, per the patient-zero caveat (no self-registration accretion in the library's
   own front door).

Gate for the rollout: `scripts/skills-lint.sh` stays `fails=0`; a routing-probe pass on any
description that gains routing-flavored language (a prompt like "check my AGENTS.md routes" must
still land on foreman, not chiropractor).

## 8. Alternatives considered

- **A. Route-first** — no table; `/foreman route` is the canonical entry for every change.
  Rejected: 2–3 reads (SKILL.md + verb file + decision-walk) per classification, paid on every
  change — the exact waste being optimized. Route survives as the slow path.
- **B. `WORKFLOWS.md` hub doc** — a tier-1 doc listing the workflows. Rejected: a menu-only read
  (rule 3); either its table is small enough for the door or its categories are wrong. (Foreman's
  deployed tree already ships exactly this doc — `docs/WORKFLOWS.md` — so rejecting the shape
  dissolves that file too; see §7.)
- **C. Dual-dispatch rows** — every table row carries both a skill verb and a doc anchor. Rejected:
  roughly doubles the table's byte cost and gives every row two things to rot; the single shared
  fallback line serves the bare-agent case at one hop.

## 9. Measures

All measurable with existing chiropractor facts: `always_loaded_bytes` against the soft budget;
`max_depth` ≤ 2 to any workflow instruction (rule 2); `doc_sizes` outliers triaged as one-big-job
vs. bundled-jobs (rule 4); the entry-door checks (plus new Check 5) all `solid`. Fidelity is
`/foreman check` green on a deployed project.
