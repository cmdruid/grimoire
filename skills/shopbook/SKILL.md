---
name: shopbook
description: "Find or create a project procedure under <agent-workspace>/<owner>/flows/ (workflow, playbook, host routine). Query, list, or search by title and use-when; when asked to run a host routine (start the environment, publish a release), resolve one file and follow it in the calling context. When asked to create, add, or author a workflow, routine, procedure, or playbook, mint a host stub for a named owner (create). Use when asked to use the shopbook, query or create a project procedure, list host workflows, repair the procedures pointer in AGENTS.md, or fill missing title/use-when (upkeep)."
---

# shopbook — find or create a host procedure

**Experimental.** Finder and host-stub creator over `<agent-workspace>/*/flows/`
(default `.spaces/*/flows/`). Script-only search; the **calling** agent reads the
one file and follows it, or authors the body of a new stub. No durable home,
no `init`, no front-door registration, no records, no hooks. In-place
steward: it maintains host procedure files that already live in the project
tree. An explicit create requires an owner and may create only that
`<owner>/flows/` path after safe-parent checks. It does not assemble the
workspace and does not copy another skill's bundled files.

This `SKILL.md` is a **thin router**. Dispatch applies to **every**
invocation (slash, unknown slash, NL, and bare). When a verb is selected,
**read its file and follow it**; do not reconstruct a procedure from memory.
Enter `verbs/create.md` only after this table chose `create`. Enter
`verbs/query.md` only after this table chose `query` (including the `list` /
`search` / `find` aliases). Slash tokens match **Invocation only**; Trigger
is NL-only.

Scripts compute facts (`scripts/flows-index.sh`, `scripts/flows-create.sh`,
`scripts/flows-door.sh`, `scripts/flows-upkeep.sh`); the calling agent
decides. Resolve them from **this skill's own base directory**.

## Verb dispatch (read the file, then follow it)

Authoring verbs (NL only) = {create, add, author}. A type noun (workflow /
routine / procedure / playbook) without those verbs does not select the
`create` walk. Slash mint is only `/shopbook create`. Slash `add` /
`author` are unknown → **ask**.

| Invocation | Verb file | Trigger |
|---|---|---|
| `/shopbook query` (alias `list` / `search` / `find`; with or without a topic; no topic = list) | `verbs/query.md` | list / search / run / follow a host procedure; "how do we handle X"; start the env; publish a release (NL, no slash verb) |
| `/shopbook create` (with or without a stem) | `verbs/create.md` | create / add / author a workflow, routine, procedure, or playbook (NL, no slash verb; `add`+procedure wins over list) |
| `/shopbook sync` | `verbs/sync.md` | repair the procedures pointer in AGENTS.md (NL, no slash verb) |
| `/shopbook upkeep` | `verbs/upkeep.md` | fill missing title/use-when (NL, no slash verb) |
| unknown slash token (`/shopbook foobar`, `/shopbook bug`, `/shopbook new bug`, `/shopbook add`, `/shopbook author`, bare `/shopbook`); NL "use the shopbook" with no further intent | — | **ask** which of query / create / sync / upkeep |

## Shared discipline (every verb relies on this — stated here once)

- **Resolve the project root** (a directory the conversation references, else
  cwd, else ask). Resolve `<agent-workspace>` from the door (first
  line-start `agent-workspace:` in `AGENTS.md` then `CLAUDE.md`, else
  `.spaces`). Pass `--root` and `--workspace` into every script; the scripts
  do not scan the door.
- **Scripts compute facts; the verb prose decides.** Never push a pick
  among several matches into a script. Never invent a procedure when
  `matches=0`.
- **Owner-first creation** (`create` only): require a valid named owner and
  create only `<root>/<agent-workspace>/<owner>/flows/`. A declared absent
  workspace is allowed for this explicit write. Recheck every parent and
  refuse symlinked or non-directory parents before writing.

## Edges

<!-- edges:shopbook -->
- produces: — (none; host stubs and pointer repairs are in-place files, not a typed record)
- handoff: — (none; the caller follows or authors in the calling context)
- consumes: — (none)
<!-- /edges:shopbook -->

## Done when

- **No recognized verb / unknown slash / bare / NL with no further intent:**
  asked which of query / create / sync / upkeep; did not mint.
- **A verb ran:** that verb file's Done when.
