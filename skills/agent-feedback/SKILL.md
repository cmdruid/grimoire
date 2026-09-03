---
name: agent-feedback
description: "Capture concrete feedback about reusable agent-facing skills, agents, harnesses, tools, and workflows in a private global queue; query or close that queue without touching a project; optionally install its global route. Use for `/agent-feedback`, explicit capture, query, close, setup, or anchor requests, and after qualifying agent work."
---

# agent-feedback — reusable agent-system observations

Preserve one actionable observation about a reusable agent-facing subject without turning feedback
capture into remediation. The package owns a private global TSV at
`~/.agents/skilldata/agent-feedback/feedback.tsv`; it never stores feedback in a project, changes the
subject, or writes through installed package bytes.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| agent-selected qualifying use | `verbs/capture.md` | Capture at most one agent-authored observation from current context |
| `/agent-feedback capture <subject-type> <subject> [<message>]` | `verbs/capture.md` | Preserve one explicit human submission |
| `/agent-feedback query [filters]` | `verbs/query.md` | Read one bounded validated page without mutation |
| `/agent-feedback close <id> --as <disposition> --reason <text> [--result-ref <ref>]` | `verbs/close.md` | Close one row without performing remediation |
| `/agent-feedback setup` | `verbs/setup.md` | Initialize or validate only the owned global data home |
| `/agent-feedback anchor [--remove]` | `verbs/anchor.md` | Preview and confirmation-gate only the owned global route block |

Human capture requires the slash command and `capture` verb. Bare or natural selection is the
agent-originated path. `capture`, `query`, `close`, `setup`, and `anchor` are reserved first tokens;
unknown option-shaped input refuses. There is no tune, migration, remediation, or project-setup verb.

## Shared discipline

- Invoke only package-local `scripts/feedback.sh` for initialization, capture, query, and close.
  Never parse or edit the TSV directly.
- Set `origin` from custody of the observation: `human` only for explicit human capture, `agent` for
  observations the agent authors during ordinary work. The provider validates but never infers it.
- De-identify before invoking the provider. Never store secrets, raw prompts, environment values,
  absolute project paths, proprietary identifiers, person/project names, or unnecessary excerpts.
- Agent-selected capture is rare, silent when skipped, and at most once after qualifying work.
  Explicit human capture preserves one requested submission and may ask one concise ambiguity question.
- Setup, capture, query, and close are local-only and never inspect or modify
  `~/.agents/AGENTS.md`; only the explicit anchor verb may access that file.
- The predecessor's store and route are outside this package's ownership. Never inspect, import,
  migrate, alter, or delete them.

## Global skilldata

- Scope: user-global private feedback rows and lifecycle state; writes no project data.
- Path: `~/.agents/skilldata/agent-feedback/feedback.tsv`.
- Access: read-write; capture initializes absent state and setup explicitly reconciles it.
- Safety: reject unsafe or malformed incumbents, retain `0700`/`0600`, and make no claim that local
  permissions turn feedback into a secret store.
- Justification: observations aggregate across projects and survive replacement of installed bytes
  without dirtying a linked source checkout.

## Edges

<!-- edges:agent-feedback -->
- produces: feedback-observation — private global observations about reusable agent-facing behavior
- handoff: —
- consumes: feedback-observation — query and close operate on this package's own observations
<!-- /edges:agent-feedback -->

## Project templates

None. Setup owns only the fixed global data directory and does not deploy project files.

## Done when

The selected procedure used its guarded helper, made no project or network write, performed no
remediation, and returned its documented terse result.
