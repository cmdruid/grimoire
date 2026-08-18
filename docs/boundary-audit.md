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
This entry is the historical **full-roster** baseline; genesis routing is
superseded by the 2026-08-17 genesis battery below. The entries above that speak v1 names
(foreman/architect/handoff/feature-era batteries) are retained as dated history only and are
superseded by this roster.

**2026-08-16 (`mailbox` rescoped, rev unit 4)** — description rewritten per council finding 14
(council record: `.scratch/mailbox/RESULT.md`, root checkout): the bare `git apply` keyword and
the backticked `/delegate` sibling name dropped (doctrine: no sibling names in descriptions —
the lint's standing mailbox/delegate exception retires with it); the HOW-not-WHETHER self-scope
retained without naming the sibling. 9-case battery (fresh cold-router sub-agent, descriptions
only), new text plus an old-text control:

| probe case (abridged) | expects | new | old control |
|---|---|---|---|
| sub-agent's patch back without it touching the tree | `mailbox` | ✓ | ✓ |
| "hand this grunt work to a cheaper model" | `delegate` | ✓ | ✓ |
| farm out this refactor, or inline? | `delegate` | ✓ | ✓ |
| "apply its patch slot from .mailbox and clean up" | `mailbox` | ✓ | ✓ |
| dispatch a sub-agent → scratch file + handle | see exception | `delegate` | `mailbox` |
| "apply this patch file a colleague sent me" | none (keyword-drop control) | ✓ | ✓ |
| "save a checkpoint of my session state" | `checkpoint` | ✓ | ✓ |
| route work to a different model, keep context lean | `delegate` | ✓ | ✓ |
| pick a model tier per build phase | — | none | none (unchanged) |

**Recorded exception (case 5):** the mixed prompt — a dispatch verb wrapped around a
slot-mechanism description — now lands on the front-door `delegate` instead of `mailbox`.
Accepted per the unit's scope directive: the sibling name is NOT restored to win the case back.
Behaviorally safe: `delegate`'s own description names the "mailbox slot" mechanism, so the
front-door still reaches the transport; purely transport-shaped prompts (cases 1, 4) still route
to `mailbox` directly. Case 9 routes `none` under both texts — a pre-existing fact about
`delegate`'s surface, untouched by this change and left as is.

**2026-08-16 (`delegate` claims phase→tier, rev unit 5)** — drains the OPEN `[delegate]`
FEEDBACK.md entry (filed by unit 4's case 9): the description now claims per-phase model-tier
selection — trigger clause "when choosing a model tier per build phase" + keyword
`phase-to-tier` (732 chars; the body's model-routing table was always the claim's substance).
8-case battery (fresh cold-router sub-agent, descriptions only, full 14-skill roster), new text
plus an old-text control:

| probe case (abridged) | expects | new | old control |
|---|---|---|---|
| pick which model tier should handle each phase of this build | `delegate` | ✓ (cites the new clause) | `delegate` (see note) |
| hand this grunt work to a cheaper model | `delegate` | ✓ | ✓ |
| sub-agent's patch back without touching my worktree | `mailbox` | ✓ | ✓ |
| save a checkpoint of my session state | `checkpoint` | ✓ | ✓ |
| farm out this refactor, or inline? | `delegate` | ✓ | ✓ |
| which model should my app call for summarization? | none (over-claim control) | ✓ | ✓ |
| route work to a different model, keep context lean | `delegate` | ✓ | ✓ |
| recurring nightly test-suite run | `scheduler` | ✓ | ✓ |

**Note (honest non-reproduction):** the old-text control routed case 1 to `delegate` this run —
unit 4's observed `none` did not reproduce, so the old text's miss was FLAKY (router-dependent
semantic stretch), not deterministic. The revision's value is converting that flaky stretch into
an explicit textual claim the router cites verbatim; no none→delegate flip is claimed. All
no-steal and over-claim controls hold under the new text.

Re-run (`/skill-builder check`, Pass 2) after any `description:` change.

**2026-08-16 (`contractor` added, grok stream Task 3)** — 14-case battery for the
blueprint/contractor split (fresh cold-router sub-agent, descriptions only, 15-skill
roster including the new `contractor` description and the rewritten `blueprint`
spec-spine description). **14/14 routed as expected.** No description changes.
`blueprint` holds bare `/blueprint`, brainstorm/grill/spec/review-spec, and the
one-phase "spec is enough, just implement" case (does not leak to `contractor`).
Bare `/contractor` is `none` (no default verb; the skill asks). Job artifacts
(plan / roadmap / runbook / execute / review-a-plan) go to `contractor`. Ship →
`workstream`; cheaper-model slice → `delegate`. Sibling-in-description WARN on
either leaf: none.

| prompt | expects | pick |
|---|---|---|
| `/blueprint` (bare) | `blueprint` (brainstorm) | `blueprint` |
| brainstorm this feature | `blueprint` | `blueprint` |
| grill the spec until the forks close | `blueprint` | `blueprint` |
| write the specification for this design | `blueprint` | `blueprint` |
| review this spec for soundness | `blueprint` | `blueprint` |
| `/contractor` (bare) | none — must not steal; ask for a verb | none |
| one-phase feature: spec is enough, just implement | `blueprint` (not `contractor`) | `blueprint` |
| write an implementation plan | `contractor` | `contractor` |
| draft a roadmap of phases | `contractor` | `contractor` |
| compile a runbook from this plan | `contractor` | `contractor` |
| execute the implementation plan | `contractor` | `contractor` |
| review this tracer-bullet plan | `contractor` | `contractor` |
| ship this stream to main | `workstream` | `workstream` |
| hand this slice to a cheaper model | `delegate` | `delegate` |

**2026-08-17 (genesis on blueprint, grok stream)** — new genesis battery (descriptions
only; fresh cold-router sub-agent; 14-skill roster, `bootstrap` already deleted).
**5/5 routed as expected.** Live genesis baseline: genesis prompts expect
`blueprint`; workshop-setup prompts expect `clankshop`. Dated tables above are
history; do not re-run the 26-case roster expecting the old skill. One expected
genesis winner (`blueprint`).

| prompt | expects | pick |
|---|---|---|
| idea → think it through → get a repo | `blueprint` | `blueprint` |
| start a new project from scratch; grill the design | `blueprint` | `blueprint` |
| deploy this spec (founding file in cwd) | `blueprint` | `blueprint` |
| deploy the workshop / set up the agent framework on this existing repo | `clankshop` | `clankshop` |
| stand up the development system on this project | `clankshop` | `clankshop` |

**2026-08-18 (analyst joins the pack, feat stream)** — new-skill routing battery
(descriptions only; fresh cold-router sub-agent; 15-skill roster). **12/12 routed
as expected, zero misroutes.** The boundary this battery exists to test is
`analyst` vs `auditor` — informing vs judging — and it held in both directions:
"how good is the code, score it" → `auditor`, "is this project healthy?" →
`analyst`. The router named `analyst`'s "renders no quality score" clause as what
tipped the vaguer health prompt, so that clause is load-bearing — do not trim it.
Two mediums flag genuine prompt vagueness ("healthy", "what's blocked"), not
description defects.

| prompt | expects | pick |
|---|---|---|
| catch me up after two weeks away | `analyst` | `analyst` |
| how good is the code in this repo? score it | `auditor` | `auditor` |
| give me a report on the auth subsystem | `analyst` | `analyst` |
| the test suite is failing — figure out why | `debugger` | `debugger` |
| what's the state of things right now? what's blocked? | `analyst` | `analyst` (medium; runner-up `backlog`) |
| walk me through how the plugin system works | `analyst` | `analyst` |
| is this project healthy? | `analyst` | `analyst` (medium; runner-up `auditor`) |
| close this plan record and log it | `journal` | `journal` |
| write down that we should refactor the parser later | `backlog` | `backlog` |
| audit the codebase for quality issues and file findings | `auditor` | `auditor` |
| summarize what shipped last month | `analyst` | `analyst` |
| explain how OAuth works (general concept) | none | none |
