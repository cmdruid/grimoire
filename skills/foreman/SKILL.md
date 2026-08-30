---
name: foreman
description: "Discover, author, verify, compose, and curate project operations; ingest brownfield procedures; learn reusable doctrine from an attended session; and compile operation closures into goal runbooks. Use when the user invokes `/foreman`, asks how a project performs recurring work, wants to capture or migrate a procedure, needs an operation checked or run, or wants a durable operation-driven goal."
---

# foreman — curate and drive project operations

Foreman turns project know-how into small, discoverable operations and composes those operations
into attended runs or durable goal runbooks. Operations remain ordinary Markdown, directly usable by
their publisher. Foreman is a curator and compiler, not a workflow runtime.

## Dispatch

Read only the selected verb file, then follow it.

| Invocation | Read | Outcome |
|---|---|---|
| `/foreman inventory [query]` | `verbs/inventory.md` | List, search, and inspect operation health. |
| `/foreman tune <tracker>` | `verbs/tune.md` | Curate one bounded tracker batch into operation proposals. |
| `/foreman run <owner/stem>` | `verbs/run.md` | Follow one named operation in the current attended context. |
| `/foreman setup [<root>]` | `verbs/setup.md` | Register Foreman's bounded project route. |
| `/foreman create [procedure\|workflow]` | `verbs/create.md` | Curate one new Foreman-owned draft. |
| `/foreman import <source>` | `verbs/import.md` | Adopt a native source by reference. |
| `/foreman migrate <file-or-directory>` | `verbs/migrate.md` | Preview and accept brownfield operation candidates. |
| `/foreman activate <owner/stem>` or `deprecate` | `verbs/lifecycle.md` | Request an evidence-bound lifecycle transition. |
| `/foreman project` | `verbs/project.md` | Check or repair Foreman's route projection. |
| `/foreman debrief [scope]` | `verbs/debrief.md` | Curate reusable knowledge from the visible attended session. |
| `/foreman verify <owner/stem>` | `verbs/verify.md` | Run the declared check and bind compact evidence to its digest. |
| `/foreman compose` | `verbs/compose.md` | Extract shared procedures and build ordered workflows by reference. |
| `/foreman goal ...` | `verbs/goal.md` | Compile, pursue, resume, inspect, or close an immutable goal runbook. |

Unknown slash verbs and a bare `/foreman` with no inferable intent require one short clarification.
Natural-language requests may route directly when the intended outcome is clear.

## Shared contract

- Resolve the project root; workspace content lives only under its fixed `.spaces` directory.
- Operations are direct files at
  `.spaces/<owner>/operations/<stem>.md`; identity is `<owner>/<stem>`.
- Foreman may read every owner's conforming operations. It writes operations and doctrine only under
  `.spaces/foreman/` and owns only its `skill:foreman` front-door span.
- Run package scripts from this skill's own `scripts/` directory. Scripts compute facts; the agent
  chooses candidates, interprets evidence, and asks for acceptance.
- Missing workspace content is an empty catalog, not an installation failure. Setup creates no empty
  store; an accepted write creates only the needed Foreman-owned kind.
- The bundled `templates/operation.md` is package-only. Never deploy it as a project template.
- Goal records use `foreman/goal@1` under `.records/goals/`. Missing `records.sh` is not an
  error and records standup is never a precondition.
- A tracker consumer uses the fixed `.trackers` layer and its advertised `tracker@1` API. Missing
  provider state degrades to rows supplied directly
  by the caller; it is not a setup requirement.

## Project templates

None. The operation and goal templates are package-only schemas for mechanical writers.

## Edges
<!-- edges:foreman -->
- produces: operation, doctrine, goal
- handoff: goal-pursuit — an accepted immutable runbook ready for the current runtime owner
- consumes: operation, session-evidence, tracker — project instructions, selected attended evidence, and bounded provider batches
<!-- /edges:foreman -->
