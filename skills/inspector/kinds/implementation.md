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
- the change is cohesive and contains no compatibility substrate forbidden by the design;
- tests exercise the real behavior, including required red-proofs;
- no unrelated mutation or unresolved conflict marker remains.

## Groundedness extras

- inspect the full diff and load-bearing surrounding code;
- run relevant targeted and host gates, or explain a concrete inability;
- verify claimed deletions and absence assertions over the correct population;
- inspect call sites and configuration affected by changed interfaces;
- ask which passing test could still encode the wrong implementation.

Use the shared exact verdict mapping. The verdict is conversation-only.

## Refine legal locations

None. Implementation review never amends code, writes status, publishes, offers refine, or enters
automatic remediation.
