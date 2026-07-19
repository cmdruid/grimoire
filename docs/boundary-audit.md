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
