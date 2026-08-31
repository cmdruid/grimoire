---
name: workspace
description: "Validate an agent workspace's owner-first skill/kind layout without changing it. Use when the user runs `/workspace` or `/workspace check`, asks whether an agent workspace is structurally valid, or needs invalid owner/kind paths diagnosed."
---

# workspace — owner-first layout guard

`/workspace` and `/workspace check` perform the same read-only operation. Resolve the project root;
the workspace is its fixed `.spaces` directory. Then run:

```text
scripts/workspace-check.sh --root <root>
```

Resolve the script from this skill's own directory. Report its facts and evidence; do not fix
paths or create directories. A missing workspace is valid and reports `state=absent`.

## Contract

Managed paths have the shape `.spaces/<owner>/<kind>/...`. Owners match
`[a-z0-9-]+` and are open-ended. Kinds are closed:

- `doctrine`, `drafts`, and `templates`: nested Markdown trees.
- `hooks` and `operations`: direct Markdown files.
- `scripts`: direct executable shell files.

Direct files under `.spaces` or an owner, unknown kinds, symlinked owners/kinds/content, and
the retired top-level kind directories fail. Every recognized owner tree receives full
validation; records and tracker entries belong only in their separate fixed homes.

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
