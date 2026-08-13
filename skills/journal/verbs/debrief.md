# `debrief` — sweep a finished body of work

Fires when a body of context worth routing is about to be lost — a feature done, a session
about to reset, an investigation wrapped. The sweep routes **every byproduct** to its durable
home; capture broadly and honestly, let the loop sift meaning later.

1. Resolve the records root (SKILL.md discipline); stand the layer up lazily if missing.
2. **Gather the candidates** — facts first, memory second:
   - `git -C <root> status --porcelain` — uncommitted record/doc writes already made;
   - `git -C <root> diff <base>` (or the work's commit range) — newly added `TODO`/`FIXME`
     markers;
   - the conversation — follow-ups spoken but never filed, surprises, gotchas, dev-experience
     friction, facts worth persisting, open questions for the human.
3. **Route each item by kind, write-only** — apply the matching capture verb's procedure
   (`task`/`bug`/`issue`/`feedback`/`note`/`ticket`) with its commit step **skipped**; the
   sweep commits once. Skip what is already recorded; a duplicate line is curation debt.
4. **Close what completed**: records this work finished get `/journal done` (right
   disposition, note); tracker line-items get their `[x]` flip + `touch`.
5. **One atomic commit** over every file touched:
   `scripts/scoped-commit.sh <root> "Journal: debrief — <what finished>" <paths…>`, then the
   host's cheap doc gate if it has one.
6. **Report the sweep** in one short list: what was filed where, what was closed, what needs
   the human (open tickets).

**Workstream exception** (SKILL.md discipline): inside an active workstream worktree, write
and commit on the **stream's branch** (`git -C <worktree>` + the same pathspec scoping); the
stream's ship lands it. A shipped stream unit whose story warrants narrative also gets a
`reports/` record tagged `debrief` — one page, findings first.
