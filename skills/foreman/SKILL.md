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
| `/foreman start [--as <stem>] <objective>` | `verbs/start.md` | Publish a first-use operation and provisional goal with one acceptance. |
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

- Resolve the project root; project support lives only under its fixed `.agents/skilldata` directory.
- Operations are direct files at
  `.agents/skilldata/<owner>/operations/<stem>.md`; identity is `<owner>/<stem>`.
- Foreman may read every owner's conforming operations. It writes operations and doctrine only under
  `.agents/skilldata/foreman/`; its doctrine resolves beneath
  `.agents/skilldata/foreman/doctrine/`. Foreman owns only its `skill:foreman` front-door span.
- Run package scripts from this skill's own `scripts/` directory. Scripts compute facts; the agent
  chooses candidates, interprets evidence, and asks for acceptance.
- Missing skilldata content is an empty catalog, not an installation failure. Setup creates no empty
  store; an accepted write creates only the needed Foreman-owned kind.
- The bundled `templates/operation.md` is package-only. Never deploy it as a project template.
- Before authoring a replacement, prefer an existing same-purpose project operation. Otherwise
  inspect the optional global template catalog through `scripts/operation-template-index.sh`;
  catalog output is metadata-only and semantic fit remains agent judgment.
- Goal records use `foreman/goal@1` under `.records/goals/`. Missing `records.sh` is not an
  error and records standup is never a precondition.
- A first-use start binds one resolved draft operation and its exact provisional goal record to a
  digest-backed publication acceptance. It starts no runtime until both durable artifacts exist.
- A tracker consumer uses the fixed `.trackers` layer and its advertised `tracker@2` API. Missing
  provider state degrades to rows supplied directly
  by the caller; it is not a setup requirement.

## Global skilldata

- Scope: user-global, optional authoring input only.
- Path: `~/.agents/skilldata/foreman/templates/operations/`.
- Access: read-only; Foreman has no global setup, write, synchronization, or migration command.
- Safety: unsafe roots disable suggestions, malformed entries are excluded without exposing their
  bodies, and an explicitly selected invalid template refuses without fallback.
- Justification: generic operation shapes need to survive package replacement and be available
  across projects, so neither project storage nor installed package bytes are suitable.
- Precedence and materialization: an existing same-purpose project operation wins. A global body is
  read only after explicit selection, treated as inert input, and curated into a complete previewed
  project operation; its path is never persisted or reread by execution.

## Project templates

None. The operation and goal templates are package-only schemas for mechanical writers.

## Edges
<!-- edges:foreman -->
- produces: operation, doctrine, goal
- handoff: goal-pursuit — an accepted immutable runbook ready for the current runtime owner
- consumes: operation, session-evidence, tracker — project instructions, selected attended evidence, and bounded provider batches
<!-- /edges:foreman -->
