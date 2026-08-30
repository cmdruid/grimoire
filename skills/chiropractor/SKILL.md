---
name: chiropractor
description: "Audit and repair a repository's agent-facing documentation spine: start at AGENTS.md and trace task routes through READMEs, docs, runbooks, workflows, and helper scripts. Use for documentation discoverability, agent onboarding, broken or stale knowledge routes, duplicate authorities, overloaded front doors, CLAUDE.md/AGENTS.md reconciliation, or questions such as ‘where would an agent learn how to do X?’ Adjustments are documentation-only and require confirmation."
---

# chiropractor — documentation-spine steward

Make important project knowledge discoverable from the root `AGENTS.md`. A technically valid link is
not enough: its surrounding instruction must tell an agent when to follow it, and the destination
must be the authoritative procedure or runnable entry point.

This is an **in-place steward**. It has no project home, setup, templates, registration block,
persistent report, or dependency on another skill. Its scanner computes repository facts; the agent
classifies importance, authority, routing quality, and the smallest useful correction.

## Modes

| Invocation | Read and follow | Result |
|---|---|---|
| bare invocation or `audit [<root>]` | `verbs/audit.md` | read-only five-part audit, then an offer to adjust |
| `adjust [<root>]`, or a request to fix/restructure the spine | `verbs/adjust.md` | the same audit, an exact temporary patch, and a confirmation stop before writes |

Resolve `<root>` from an explicit argument, otherwise use the enclosing Git top level. If neither is
available, ask for the directory. Resolve `verbs/` and `docs/RUBRIC.md` relative to this installed
skill, never relative to the target repository. The package-local scanner is the sole deterministic
entry point:

```text
scripts/spine-scan.sh <root> [--candidates]
```

The scanner is read-only and never executes discovered commands. A broken script, workflow,
manifest, or program is evidence for the audit, not an authorization to edit it.

## Front-door invariant

The established spine requires a readable, regular, non-symlink root `AGENTS.md`. Bad content is an
audit finding; it does not make a regular door incompatible. A missing door permits a repository
census and a grounded door proposal, but no full Reach score or ordinary route adjustment. An
incompatible door is reported and left for a maintainer decision.

Shared instructions belong in `AGENTS.md`. A root `CLAUDE.md` may import it with `@AGENTS.md` and
retain only genuinely Claude-specific content. Creating or reconciling either door is itself a
confirmation-gated adjustment; rescan from the established AGENTS door before proposing later route
repairs.

## Patient-zero caveat

When this package is developed inside a skills library whose real `AGENTS.md` is authored library
doctrine, never exercise migration or adjustment against that live door. Use throwaway fixtures.

## Edges

<!-- edges:chiropractor -->
- produces: — (conversational audit plus in-place documentation fixes, not a typed artifact)
- handoff: — (the verified adjustment ends the pass)
- consumes: — (the repository working tree is direct input, not a typed artifact)
<!-- /edges:chiropractor -->

## Done when

For `audit`, every scanner candidate and discovered semantic surface is reconciled, every important
surface has an explained route, and the five-part report ends without a patch. For `adjust`, the
approved documentation subset is applied against unchanged preimages, affected routes are rescanned,
and the incremental diff is separated from pre-existing work.
