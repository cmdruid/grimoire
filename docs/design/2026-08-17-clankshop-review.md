---
doctype: design
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [spec]
---

# clankshop review — Spec

Accepted 2026-08-17 on stream `grok`. Same-session `/skill-builder review
clankshop` against `skills/agent-council/briefs/skill-review.md`. Verdict:
**needs-rework**. The human approved the recommended subset; this file is the
governing spec for that fold. It is the review report plus the receiving
locks — not a restatement of the skill.

Target (unchanged by the review verb):
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/clankshop/`

Brief:
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/agent-council/briefs/skill-review.md`

High-stake: `skills/clankshop/PACK.md` is present. A panel was warranted;
none was asked for; none was convened.

## Facts (Pass 1)

lint fails=0 warns=20 (target-relevant: 1)

- `WARN: clankshop: ~/.claude/skills/clankshop resolves to /Users/cscott/Repos/grimoire/skills/clankshop, not this clone`

Expected worktree-vs-clone note. Not a finding. The other 19 WARNs are
sibling symlink notes and orphan edge types (`founding-documents`,
`git-repository`, `plan`, `roadmap`, `runbook`).

## Findings (the requirements)

### 1. high — A half-finished `setup` cannot be resumed
Location: `skills/clankshop/verbs/setup.md` (Guard + walk step 2 then 3);
`skills/clankshop/verbs/migrate.md` (Guard)
Class: must-fix
Disposition: **fold**

The guard stops on any `<root>/.handbook`. The walk then writes that
directory in step 2 (`scripts/seed.sh`) *before* the journal standup it
can abort on. `migrate` uses the same existence guard. After a
journal-missing stop (or any later red `check`), both onramps refuse,
and the body only names upgrades as “a judgment-assisted diff against
the current seed” — no resume walk. Pack-format §6 (named from
`SKILL.md`) requires “a complete system or a clean refusal, never a
partial projection.”

### 2. mid — “Run its standup” is not an executable step
Location: `skills/clankshop/verbs/setup.md` (step 3);
`skills/clankshop/verbs/migrate.md` (step 3)
Class: nice-to-have
Disposition: **drop as a standalone item**

Journal’s own description and dispatch table already name `/journal
setup` as “the workshop’s delegated records seam.” Doctrine: do not
restate a sibling’s verb roster. A one-word pointer is free while
rewriting step 3 for finding 1; it is not its own remediation.

### 3. mid — The door’s required shape is unspecified
Location: `skills/clankshop/verbs/setup.md` (step 4);
`skills/clankshop/verbs/migrate.md` (step 2);
`skills/clankshop/verbs/check.md` (steps 4–5)
Class: nice-to-have
Disposition: **fold**

Setup asks for “a pointer” plus “a thin routing table compiled from
`core/ROUTING.md`’s dispatch rows.” No example block, no required keys.
`records-root:` appears only in migrate (legacy root). Check then
requires that `AGENTS.md` “points at `.handbook/README.md`” and that
`records.sh` lives “under the records root’s `scripts/`” without saying
how to resolve that root.

### 4. mid — `check` says facts come from scripts, then has the agent invent most of them
Location: `skills/clankshop/verbs/check.md`
Class: nice-to-have
Disposition: **defer the script; fold records-root into finding 3**

Stamp and leftover-slot checks are already named greps. A link-walker
script would match “scripts compute facts” but is new surface plus
tests. The only mechanical hole that lands this pass is records-root
resolution, which finding 3 already covers.

### 5. mid — Description lead “operate” plus the station inventory over-triggers
Location: `skills/clankshop/SKILL.md` (frontmatter `description:`)
Class: nice-to-have
Disposition: **fold**

The Use-when is tight. The lead sentence is “Set up and **operate** an
agentic workshop” and then names design / build / test / review. After
deploy, operating the workshop is the handbook’s job. “build (the
foreman)” and “review (the admin)” also match ordinary build and review
requests. Current description is 721 characters.

### 6. mid — Setup’s migrate-prefer branch has no test
Location: `skills/clankshop/verbs/setup.md` (Guard)
Class: nice-to-have
Disposition: **fold into finding 1**

“If the project has organic structure worth adopting… prefer
`migrate`.” No command, no threshold. `migrate-scan.sh` already emits
`docroot=`, `tracker-shaped=`, `records=present`.

## Receiving locks (do not fold past these)

Applied 2026-08-17 before planning. Feedback is a claim; these are the
approved pushbacks.

1. **Finding 2 is not its own item.** At most name `/journal setup`
   while rewriting setup/migrate step 3. Do not inline journal’s
   procedure.
2. **Finding 4’s facts script is deferred.** Records-root resolution
   lands in finding 3 / `check` prose only. Do not add a
   `check-facts` script (or extend `context.sh --check`) this pass.
3. **Door contract is minimum bytes, not a full `AGENTS.md` template.**
   Integrate, never clobber. Required: a pointer that names
   `.handbook/README.md`. Optional: a line-start `records-root: <rel>`
   (omit when the default `.records/` holds). Thin table compiled from
   `seed/core/ROUTING.md`’s dispatch rows. Do not paste a whole door.
4. **Do not bump `PACK.md` `version:`.** Member set is unchanged.
5. **Do not run `/clankshop setup` or `/clankshop migrate` in this
   library.** Patient-zero. Verify with lint + grep, not a live
   onramp.
6. **Do not edit `seed/`, `scripts/`, or `tests/`** unless a comment
   is now false. No new scripts. Walk steps stay numbered 1–5
   (gather, seed, journal, door, check). Classify / journal-probe /
   migrate-prefer / resume live in the Guard, before the walk.
7. **Independence walk stays on `check`.** Do not run or paste
   `docs/BOUNDARY-AUDIT.md` into this fold.
8. **Sibling `feat` does not own clankshop.** Do not drive it. Root
   checkout dirt (blueprint + mailbox scripts + two untracked design
   docs) is disjoint — do not sweep it into stream commits.
9. **Finding 5 must keep** `setup`, `migrate`, `check`, persona
   summons, and the Use-when clause. Drop “operate” and the
   four-station inventory (`design` / `build` / `test` / `review` as
   station names). Description is 721 characters today; stay under
   1024, prefer ≤750.
10. **Resume is `setup`’s job.** `migrate` does not grow a resume
    walk. If `.handbook` exists, migrate stops and points at `setup`
    (resume when `check` would be red; upgrade-as-diff when the human
    asked and `check` is green).

## Out of scope this pass

- A `check` facts script / link walker (finding 4 remainder).
- A named `upgrade` verb.
- Seed workflow or persona edits.
- Convening a panel.
