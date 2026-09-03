# Kind: implementation

## Discriminator

All of:

- an explicit completed code-change target: a named diff, range, worktree, or commit;
- the target does not match any bundled or project document kind;
- the governing spec, plan, or runbook is resolved when named or discoverable from the change
  context.

Implementation is tried only after every document kind. A source file named as a document artifact
does not become an implementation review merely because it contains code.

## Soundness axes

- behavior matches the governing design and acceptance criteria;
- control and data flow are correct at boundaries and failure paths;
- control-flow complexity is proportionate to the required behavior: changed code does not add
  avoidable decision paths, interacting modes, or branches whose distinct outcomes are untested;
- the change is cohesive and contains no compatibility substrate forbidden by the design;
- tests exercise the real behavior, including required red-proofs;
- no unrelated mutation or unresolved conflict marker remains.

## Groundedness extras

- inspect the full diff and load-bearing surrounding code;
- run relevant targeted and host gates, or explain a concrete inability;
- verify claimed deletions and absence assertions over the correct population;
- inspect call sites and configuration affected by changed interfaces;
- ask which passing test could still encode the wrong implementation.

Inspect changed authored functions qualitatively for avoidable branch multiplication. Treat
generated code, exhaustive dispatch, table-driven logic, parsers, explicit state machines, and
sequential test setup as possible false positives; judge whether each path represents required
behavior and is independently verifiable. Keep test code outside the numeric population unless
effective project instructions deliberately include test maintainability; otherwise exclude it or
report it separately.

If effective project instructions name a complexity analyzer identity, version, configuration,
population, and exclusions, it may provide supporting delta evidence. Compare materialized before
and after endpoints. Use the same analyzer identity and version, configuration, population, and
exclusions. Added or deleted functions use `--` for the absent endpoint. Analyze endpoints
read-only; never apply the diff or mutate the reviewed tree to construct one. If either required
endpoint cannot be materialized safely, record `endpoint-unavailable` and continue qualitatively.
Do not install, configure, or discover an analyzer during review. When numeric comparison is
available, report the analyzer identity, version, configuration, population, and exclusions. For
each numeric delta, report
the function or method identity, repo-relative source location, and value at each endpoint. Then
identify newly introduced hotspots. When numeric comparison is not available, include the
limitation as a confidence note when it matters.

A raw value or threshold crossing is evidence, not an automatic finding. Report complexity only
when the changed behavior creates a material maintainability or verification problem, and explain
the concrete branch burden or missing path coverage. Analyzer absence, failure, or an unavailable
endpoint is not itself a finding and does not prevent a verdict.

Use the shared exact verdict mapping. The verdict is conversation-only.

## Review continuation

revision-after-review: unavailable

## Revision legal locations

None. Implementation never enters document `revise` or `refine`, writes status or stage, or
publishes. The review phase never amends code. After a material implementation verdict,
`verbs/review.md` owns a separate plain-text action close with a numbered scope, `A`/`I` execution,
and `R`/`N` afterward modifiers. An unresolved destination may retain only pending scope; a complete
confirmed selection may use an eligible inline or isolated route and optional full same-base
re-review. That action is neither automatic from the verdict nor a revision legal location. A clean
`approve` has no action surface and resumes the caller automatically.
