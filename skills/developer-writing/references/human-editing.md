# Human editing for change-oriented prose

Read this reference for explanations, PR descriptions, and release notes. Use the transformations
as judgment patterns, not templates. Preserve necessary technical terms, risks, limitations, and
scope boundaries.

## Explain the change, not the proof process

Review-system framing makes the author's validation process the subject:

> This change deliberately does not claim that every runtime mutation is validated. The exact
> invariant established here is startup validation only.

Maintainer framing puts the behavior first:

> The service now validates configuration at startup. Runtime mutations still use the existing
> validation path.

Keep explicit proof language when the proof itself matters, such as a security argument or protocol
guarantee. Otherwise state the behavior and its practical boundary directly.

## Replace exhaustive classification with a useful overview

Don't reproduce a file-by-file audit or a scope table merely to demonstrate completeness. Group
changes by the reason a reader cares about them:

> The new resolver is used by both startup and reload paths, so configuration errors now produce the
> same diagnostic in either case. The command reference and migration guide were updated to describe
> that behavior.

Keep a table when it makes an exact mapping or comparison easier to understand than prose.

## Put a limitation beside the affected behavior

Don't repeat the same caveat in an overview, a scope section, and a verification section. State it
once where it changes the reader's interpretation:

> Reloads preserve existing connections; only new connections use the updated timeout.

An explicit out-of-scope section is useful when it resolves a likely misunderstanding across the
whole document. It isn't a default container for everything unchanged.

## Compress without erasing decisions

Remove headings with one short paragraph, repeated source links, exhaustive inventories, and
bookkeeping about how the work was checked. Preserve surprising changes, tradeoffs, rationale,
compatibility effects, operational risks, and information a reviewer needs to make a decision.
