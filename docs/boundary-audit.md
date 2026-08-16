# Boundary audit — grimoire's own record

**Status:** Implemented (2026-07-19, Phase 7 of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md`). The workflow this file used to carry
in full — the violation rubric, the audit steps, the routing-probe gate, the mechanical backstop —
now lives in the portable **`skill-builder`** skill:
`skills/skill-builder/docs/BOUNDARY-AUDIT.md` (the workflow) + `skills/skill-builder/verbs/check.md`
(the verb that runs it, alias `/skill-builder audit`). Read those for *how* to run the audit; this
file keeps only **grimoire's own results**, since those are a fact about this library's current
skills, not portable doctrine.

## Routing-probe run log

**2026-08-11 (`bootstrap` added)** — 7 probes against `bootstrap` + its 4 closest neighbors
(`clankshop`, `feature`, `workstream`, `skill-builder`), **7/7** routed correctly (fresh sub-agent,
descriptions only). The pair that needed checking is `bootstrap`/`clankshop`: `clankshop setup` is
self-described as the *"greenfield bootstrap"*, so the two collide on the library's most overloaded
word. Both adversarial decoys held — "bootstrap the development system" and the verbatim "do a
greenfield bootstrap" routed to `clankshop`, with `bootstrap` only as runner-up. The probe named the
real discriminator unprompted: **whether a repository already exists**. That clause was then folded
into `bootstrap`'s description ("...and no repository exists yet") to sharpen the closest case rather
than leave it to inference.

| prompt | expects |
|---|---|
| "I've got an idea for a new CLI tool. Help me think it through, then get me a repo." | `bootstrap` |
| "set up the agent framework on this existing repo" | `clankshop` |
| "let's brainstorm the next feature for this codebase" | `feature` |
| "bootstrap the development system for this project" | `clankshop` |
| "I want to start a new project from scratch. Grill me on the design first." | `bootstrap` |
| "do a greenfield bootstrap" | `clankshop` |
| "write me a roadmap and architecture doc for the new thing — there's no repo yet" | `bootstrap` |

**2026-07-23 (`debugger` added)** — 8 probes against `debugger`, `auditor`, `chiropractor`, and
`skill-builder`, **8/8** routed correctly (fresh sub-agent, descriptions only). The sharpest case —
"I tried two fixes and neither worked, what now?" — correctly stayed with `debugger` rather than
drifting to `auditor` on the word "quality."

| prompt | expects |
|---|---|
| "this test just started failing and I don't know why" | `debugger` |
| "audit my repo for code quality problems" | `auditor` |
| "my docs are a mess and hard to navigate" | `chiropractor` |
| "lint my skills directory before I commit" | `skill-builder` |
| "the build is broken, can you fix it?" | `debugger` |
| "score this codebase against our quality rubric" | `auditor` |
| "I tried two fixes for this bug and neither worked, what now?" | `debugger` |
| "scaffold a new skill for me" | `skill-builder` |

**2026-07-19 (`skill-builder` added, Phase 7)** — 7 probes against `skill-builder` + its 5 closest
neighbors (`auditor`, `chiropractor`, `architect`, `backlog`, `foreman`), **7/7** routed correctly
(fresh sub-agent, descriptions only, no runbook/reasoning in context). The pairs that most needed
checking — `skill-builder`/`auditor` (both "audit") and `skill-builder`/`architect`+`backlog` (both
"scaffold/stand up") — all disambiguated on self-scope.

| prompt | expects |
|---|---|
| "audit my repo for code quality problems" | `auditor` |
| "my docs are a mess and hard to navigate" | `chiropractor` |
| "add a new skill to this library — scaffold it" | `skill-builder` |
| "check whether my skill descriptions are self-scoped" | `skill-builder` |
| "set up the design seed for this project" | `architect` |
| "file this as a task for later" | `backlog` |
| "lint my skills directory before I commit" | `skill-builder` |

**2026-07-18** — 12 probes, **12/12** routed correctly against the thinned descriptions alone (fresh
sub-agent, no runbook/reasoning in context). The auditor/chiropractor, foreman/backlog,
architect/feature, and handoff/workstream pairs all disambiguated on self-scope without a
cross-reference.

| prompt | expects |
|---|---|
| "audit my repo for quality problems" | `auditor` |
| "my docs are a mess / hard to navigate" | `chiropractor` |
| "where does this change start?" | `foreman` |
| "file this follow-up so we don't lose it" | `backlog` |
| "hand this grunt work to a cheaper model" | `delegate` |
| "design the foundational architecture" | `architect` |

Re-run (`/skill-builder check`, Pass 2) after any `description:` change.

**2026-08-15** — checkpoint description rewritten self-scoped (no sibling named; 698 chars), unit 2
of the rev stream, plan `docs/design/2026-08-15-checkpoint-refinement-plan.md`. 13-case battery
(fresh cold-router sub-agent, descriptions only, environment facts supplied inline): **13/13 with
the new description**, including the two stream cases — (2) stream context in prompt and (3) the
OBSERVED 2026-08-14 misroute shape (root cwd, in-place stream, no stream mention in conversation)
— plus the new collision cases: "remember this for later" → `backlog`, "sweep follow-ups / close
the books" → `backlog` vs "CHECKPOINT.md's work landed, close it out" → `checkpoint`, explicit-path
save, mailbox scratch-file decoy, context-pressure phrasing, and the legacy "write a handoff doc"
decoy. **Control (old contrast-bearing description): also 13/13** — no regression from dropping
the contrast. **De-scoped control (scoping sentence removed entirely): stream cases STILL routed
to `workstream`** — its own description (post-a63ee5e save-synonym strengthening) now carries
them alone, so the routing of cases 2/3 is over-determined and this battery validates
no-regression rather than sole-cause; checkpoint's scoping sentence is retained as accurate
self-description and defense in depth, not as the deciding router signal. The plan's contingency
(restore the contrast clause under a documented exception) was NOT needed. Battery red-capability:
not demonstrated for the stream cases (over-determination); the companion S4 ownership scenario
probe did go red against the pre-fix text (compacted-self misjudged foreign), so the fresh-agent
probe machinery itself is proven discriminating.

| probe case (abridged) | expects | new | old | de-scoped |
|---|---|---|---|---|
| "save a checkpoint", plain repo | `checkpoint` | ✓ | ✓ | ✓ |
| "save a checkpoint", stream in context | `workstream` | ✓ | ✓ | ✓ (via workstream's side) |
| "save a checkpoint", root cwd + in-place stream (observed misroute) | `workstream` | ✓ | ✓ | ✓ (via workstream's side) |
| resume post-compaction / snapshot / load / remember-later / close-books / done / explicit path / mailbox decoy / context pressure / handoff decoy | per plan §S5 | ✓ all | ✓ all | — |

Re-run (`/skill-builder check`, Pass 2) after any `description:` change.

**2026-08-16** — **full v2-roster refresh** (rev stream unit 3): one cold-router probe over all
**14** current descriptions (agent-council included), 26 cases — per-skill core triggers plus
every known collision pair: clankshop setup/migrate/persona vs journal setup; the journal/backlog
Phase-6 split (format/contract/closure vs capture/ticket/debrief); "remember this for later" →
`backlog`; the checkpoint/workstream stream cases; auditor vs debugger; delegate vs mailbox;
blueprint verbs vs bootstrap-from-scratch; scheduler; skill-builder new/check; agent-council's
panel summons. **26/26 routed correctly** — no description changes needed, no follow-up probes.
This entry is the **current baseline**; the entries above that speak v1 names
(foreman/architect/handoff/feature-era batteries) are retained as dated history only and are
superseded by this roster.

Re-run (`/skill-builder check`, Pass 2) after any `description:` change.
