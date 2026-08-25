---
name: workspace
description: "Validate an agent workspace's owner-first skill/kind layout without changing it. Use when the user runs `/workspace` or `/workspace check`, asks whether an agent workspace is structurally valid, or needs invalid owner/kind paths diagnosed."
---

# workspace — owner-first layout guard

`/workspace` and `/workspace check` perform the same read-only operation. Resolve the project
root, `<agent-workspace>` (first line-start `agent-workspace:` in `AGENTS.md`, then
`CLAUDE.md`, else `.spaces`), and `<agent-records>` (first `agent-records:` or `records-root:`,
else `.records`). Then run:

```text
scripts/workspace-check.sh --root <root> --workspace <W> --records-root <R>
```

Resolve the script from this skill's own directory. Report its facts and evidence; do not fix
paths or create directories. A missing workspace is valid and reports `state=absent`.

## Contract

Managed paths have the shape `<agent-workspace>/<owner>/<kind>/...`. Owners match
`[a-z0-9-]+` and are open-ended. Kinds are closed:

- `doctrine` and `templates`: nested Markdown trees.
- `hooks` and `flows`: direct Markdown files.
- `scripts`: direct executable shell files.
- `trackers`: direct safe-named regular files; the owning engine defines their schema.

Direct files under the workspace or owner, unknown kinds, symlinked owners/kinds/content, and
the retired top-level kind directories fail. When workspace and records roots coincide,
record stores and `history.tsv` may coexist: entries without recognized kind children warn as
`coincident-unknown`; recognized owner trees receive full validation.

This skill is an in-place steward over a host layout. It owns no durable home, has no setup
verb, and writes nothing.

## Edges

<!-- edges:workspace -->
- produces: — (check facts are conversational output)
- handoff: — (none)
- consumes: — (the host layout is inspected in place, not consumed as an artifact)
<!-- /edges:workspace -->

## Done when

The check reports `fails=0`, or every failure is shown with its repo-relative path and reason.
