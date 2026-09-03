---
name: skill-feedback
description: "Capture concrete, change-worthy feedback about an installed agent skill into a private global queue; inspect that queue without touching a project; optionally install its global route. Use for `/skill-feedback`, a skill-named capture, setup, query, tune, or anchor requests."
---

# skill-feedback — global skill-use observations

Capture one actionable observation from a real skill invocation without interrupting the user. The
package owns a private global TSV at `~/.agents/skilldata/skill-feedback/feedback.tsv`; it never
stores feedback in a project or writes through an installed skill directory.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| `/skill-feedback`, `/skill-feedback <skill>` | `verbs/capture.md` | Capture at most one observation from recent context |
| `/skill-feedback capture [<skill>] [<observation>]` | `verbs/capture.md` | Use the explicit capture form |
| `/skill-feedback setup` | `verbs/setup.md` | Initialize or validate only the owned global data home |
| `/skill-feedback query [<skill>] [--status open\|resolved] [--limit N]` | `verbs/query.md` | Read a bounded page without mutation |
| `/skill-feedback tune <skill> [--limit N] [--source <path>]` | `verbs/tune.md` | Revalidate and disposition one bounded batch |
| `/skill-feedback anchor [--remove]` | `verbs/anchor.md` | Preview and, after confirmation, change only the owned global route block |

Bare invocation is capture, not a request to choose a verb. A first token other than `capture`,
`setup`, `query`, `tune`, or `anchor` is the target skill for capture. Unknown option-shaped input
refuses.

## Shared discipline

- Invoke only package-local `scripts/feedback.sh` for TSV initialization, capture, query, and
  resolution. Never edit the TSV directly.
- Capture asks no follow-up questions. A weak or ambiguous observation returns the documented
  `skipped=` result and leaves the store unchanged after any absent-only initialization.
- De-identify before invoking the provider. Never store secrets, raw prompts, environment values,
  absolute project paths, proprietary identifiers, or unnecessary source excerpts.
- Data operations are local-only and never inspect or modify `~/.agents/AGENTS.md`; only the
  explicit anchor verb may access that file.
- This is a global durable-data owner, not a project-home or records writer. It owns only the
  `skill-feedback/` child beneath `~/.agents/skilldata/`.

## Global skilldata

- Scope: user-global, private feedback rows and their lifecycle state; writes no project data.
- Path: `~/.agents/skilldata/skill-feedback/feedback.tsv` beneath the package-owned directory.
- Access: read-write; capture initializes absent state and setup explicitly reconciles it.
- Safety: reject unsafe or malformed incumbents, use `0700`/`0600`, de-identify before storage, and
  make no claim that local permissions turn feedback into a secret store.
- Justification: observations must aggregate across projects and survive replacement of installed
  package bytes without dirtying a linked source checkout.

## Edges

<!-- edges:skill-feedback -->
- produces: skill-observation — private global observations about reusable skill behavior
- handoff: — (rows remain open until a later explicit lifecycle workflow)
- consumes: skill-observation — tune reviews and dispositions captured observations
<!-- /edges:skill-feedback -->

## Project templates

None. Setup owns only the fixed global data directory and does not deploy project files.

## Done when

The selected verb used its guarded helper, made no project or network write, and returned its
documented terse result.
