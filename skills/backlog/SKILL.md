---
name: backlog
description: "Manage project-owned living follow-up trackers under the agent workspace. Verbs: setup stages the TSV engine and selected tracker modules; tracker add|remove|list manages extensible lists; file appends one item; debrief routes finished-work leftovers through the project cookbook; curate completes, drops, updates, or reorders items. Use for `/backlog ...`, filing follow-ups, grooming living lists, or sweeping work before context loss."
---

# backlog — living follow-up trackers

Backlog owns mutable project queues, not records. Its complete project surface is
`<agent-workspace>/backlog/{hooks,scripts,trackers}/`; the staged `trackers.sh` is the sole TSV
writer and the project-authored `hooks/debrief.md` is the routing cookbook.

## Verb dispatch

| Invocation | Read | Does |
|---|---|---|
| `/backlog setup` | `verbs/setup.md` | Stage the engine and enable selected builtin or custom trackers |
| `/backlog tracker add\|remove\|list` | `verbs/tracker.md` | Manage or inspect tracker components |
| `/backlog file <stem> [text]` | `verbs/file.md` | Append one open item to a known tracker |
| `/backlog debrief` | `verbs/debrief.md` | Compile project routing and sweep finished-work leftovers once |
| `/backlog curate [<stem>]` | `verbs/curate.md` | Complete, update, drop, or reorder through the writer |

Bare `/backlog` asks which verb. Unknown verbs refuse; there are no taxonomy aliases.

## Shared discipline

- Resolve `<root>` as the project checkout and `<workspace>` from line-start `agent-workspace:`
  in `AGENTS.md`, then `CLAUDE.md`, else `.dev`. It must be repo-relative with no `..` segment.
- Except for setup, invoke only the executable staged engine at
  `<root>/<workspace>/backlog/scripts/trackers.sh`, always beginning with
  `--root <root> --workspace <workspace>`. Missing or non-executable refuses with
  `reason=setup-required` and points to `/backlog setup`; never run the bundled engine.
- Never read or edit TSV bytes directly. Use `list` and `compile` for reads and writer commands
  for every mutation. Tracker stems match `[a-z0-9][a-z0-9-]*`.
- Operations that can change tracker population preflight `scripts/register-route.sh` before
  data writes, then reconcile Backlog's delimited root-`AGENTS.md` block afterward.
- Standalone setup, tracker, file, and curate calls make one scoped commit over every reported
  `wrote=` / `removed=` path via `scripts/scoped-commit.sh`. Inside debrief, nested calls are
  write-only and the sweep commits once. No changed paths means no commit.
- Resolve the commit tree before committing: detached HEAD or an unheld `stream/*` /
  `feature/*` branch stops; a matching workstream handoff commits in that worktree; otherwise
  commit in the current project checkout. Never stage broadly.

## Project state and suggestions

`suggestions/{tasks,issues,feedback}.md` are setup choices, not defaults. Setup copies their
H2 modules only when selected. Custom stems receive a stub for the project to author. Each TSV
and H2 is an independent incumbent: a rerun repairs a missing counterpart and never overwrites
the present one.

## Edges

<!-- edges:backlog -->
- produces: tracker — living skill-owned follow-up rows
- consumes: — (debrief reads the caller's finished-work context, not a typed artifact)
<!-- /edges:backlog -->

## Scope boundary

Backlog stores and routes follow-ups. It does not diagnose defects, perform queued work, mint
records, publish another skill's hook, or define another skill's return contract. Portable
consumers name the host's follow-up or bug-filing lane; they do not require Backlog.
