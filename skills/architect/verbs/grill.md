# `grill [doc]` — the interview primitive

Focused questioning until the **material design decisions are sufficient** for
the requested outcome. Standalone by design: point it at a draft design, a spec
— or nothing (it grills the current conversation's proposal). `grill` writes
no artifact of its own; it drives decisions into whichever doc it was aimed at
(or leaves them in context for the calling verb).

If `[doc]` is named, classify it (SKILL.md *Founding-shaped*) **before** the
steps below. Founding-shaped → fill the six map H2s in place under that
branch; do not run the feature-spec reshape. Refuse the otherwise-case.
They never scan cwd for a founding file.

Founding `grill` still does not mint a record.

## Procedure

1. **Find material branches** — read the doc or conversation and identify only
   choices whose answers change scope, externally visible behavior, system
   boundaries, safety, compatibility, or acceptance. Do not turn every vague word
   or implementation detail into a design interview.
2. **Ask in short rounds** — number a few related questions. Recommend an answer
   when evidence supports one and explain the important trade-off. Use
   multiple-choice only when it makes answering easier.
3. **Chase material consequences** — follow an answer only while it can change the
   design. Stop when the artifact is sufficient for its purpose. Preserve a real
   non-blocking uncertainty as a labeled open question instead of forcing a
   premature decision.
4. **Write the decisions back** — into the target doc's argued sections, or
   hand the resolved list to the calling verb. Record *who settled it and when*
   for the load-bearing ones. Founding-shaped: who/when notes go **inside**
   the mapped section as a whole line in this exact form (roman, not italic):
   `Settled: YYYY-MM-DD.`

Output: a doc or context with its material decisions settled and any remaining
non-blocking questions visible. Return to the calling verb or the human.

## Done when

No unresolved material decision blocks the target doc or conversation's purpose.
Founding-shaped: the six map H2s were filled in place; no `specs/` mint; no
`published` write; `founding` tag and H2 set unchanged.
