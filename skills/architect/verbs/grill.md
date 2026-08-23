# `grill [doc]` — the interview primitive

Relentless questioning until **every decision branch resolves**. Standalone by
design: point it at a draft design, a spec — or nothing (it grills the current
conversation's proposal). A job artifact with open decision branches means the
**spec** is not settled — grill the spec, not the job artifact. `grill` writes
no artifact of its own; it drives decisions into whichever doc it was aimed at
(or leaves them in context for the calling verb).

If `[doc]` is named, classify it (SKILL.md *Founding-shaped*) **before** the
steps below. Founding-shaped → fill the six map H2s in place under that
branch; do not run the feature-spec reshape. Refuse the otherwise-case.
They never scan cwd for a founding file.

Summon the design station per SKILL.md *One environment probe* (founding
`grill` is still a design-station read; it does not mint a record).

## Procedure

1. **Build the decision tree** — read the doc/conversation and enumerate every
   open branch: unstated assumptions, either/or forks, vague quantities
   ("fast", "some"), unowned risks, undefined terms. Each becomes a question.
2. **Ask in rounds** — numbered questions, a few per round, **each with a
   recommended answer and why** (the human confirms or overrides in one word).
   Multiple-choice when the options are enumerable; open only when they aren't.
   Never a wall of questions covering the whole tree at once — later rounds
   depend on earlier answers.
3. **Chase the consequences** — every answer can open new branches; keep going
   until a full round surfaces nothing new. Resolved ≠ mentioned: a decision is
   resolved when its consequence is stated and the human has confirmed it.
4. **Write the decisions back** — into the target doc's argued sections, or
   hand the resolved list to the calling verb. Record *who settled it and when*
   for the load-bearing ones. Founding-shaped: who/when notes go **inside**
   the mapped section as a whole line in this exact form (roman, not italic):
   `Settled: YYYY-MM-DD.`

Output: a doc (or context) with no unresolved decision branches. Terminal step:
return to the calling verb (`spec`) or the human.

## Done when

No unresolved decision branch remains in the target doc or conversation.
Founding-shaped: the six map H2s were filled in place; no `specs/` mint; no
`published` write; `founding` tag and H2 set unchanged.
