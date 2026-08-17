# `/skill-builder review` — substance judgment of a skill package

Judge a skill package on the **skill** `review-brief` (trigger,
followability, holes, independence, judgment vs mechanism, scope,
output shape). Pass 1 is lint facts. Pass 2 is same-session judgment
or consumption of a `review` baton. This verb never convenes a
panel, never writes `RESULT.md`, and never grows `check`.

Read the resolved brief for the axes. Do not copy them here.

## When to use

- The user runs `/skill-builder review <skill>`
- A request to review a skill’s substance (followability, holes,
  trigger quality) — not a lint-only pass (`check`) and not a
  spec/design-doc review

**Do not use** for a one-line tweak, a mechanical lint pass alone,
or a target that is not a skill package.

## Resolve the target

`<skill>`:

1. A directory that contains `SKILL.md` → that package.
2. A relative path → resolve from cwd, then apply (1).
3. A file whose basename is `SKILL.md` → its parent directory.
4. A bare slug → `<git-toplevel>/skills/<slug>/` if that
   directory contains `SKILL.md`.
5. Missing or not a skill package → ask or refuse. Do not
   classify a non-skill into this verb.

Optional `[<path>]`, by content, not flag:

- File whose first heading is `# Council:` → a `review` baton.
  Consume it (Pass 2 — baton).
- Else a readable file that is not a skill package → a
  `review-brief`. Same-session judgment against it.
- Else → ask.

## Depth

| Situation | What to do |
|---|---|
| Default (no panel asked, no baton) | Pass 1, then same-session judgment against the skill brief |
| Baton supplied | Pass 1, then consume the baton (do not re-judge from scratch) |
| User asked to convene / panel / council, no baton | Pass 1, then **stop**. A `review` baton is required. Do not convene. Do not judge. |
| High-stake, no baton, no panel ask | Same as default, plus a note that a panel is warranted. High-stake = user-nominated, or the target directory contains `PACK.md` |

Never dispatch seats, write scratch, cluster, or run a brief
classifier.

## Locate the skill brief

1. Caller passed a brief file → use it.
2. Else find the target’s **library root**: walk up from the
   skill directory until a parent contains a `skills/` directory
   that itself contains the target. Scan
   `<library-root>/skills/*/SKILL.md` for an edge block that
   declares `produces: review-brief`. For each hit, if
   `<that-dir>/briefs/skill-review.md` exists, collect it.
3. Exactly one distinct file → use it. Zero → refuse
   same-session judgment (a baton or an explicit brief path is
   required). Several distinct files → ask.

## Pass 1 — facts

If a library root exists, run this skill’s
`scripts/skills-lint.sh` against it. Report the
**target-relevant** `FAIL:` / `WARN:` lines as facts, not
verdicts. If no library root, note `Facts: lint skipped (no
library root)`.

Do **not** run `check` Pass 2 (`docs/BOUNDARY-AUDIT.md`). Do not
edit `verbs/check.md`.

## Pass 2 — same-session judgment

Read the resolved brief in full. Judge only on the axes it
names. Follow its read rule (`SKILL.md`, then only the verbs /
scripts / docs / templates it names). Emit discrete findings:
claim, evidence (path + quote or `file:line`), action, severity
`high` / `mid` / `low`.

Do not restate the skill. Do not run a second lint. Do not copy
the brief’s axis list into this file.

Independence findings that `check` Pass 2 already owns: point at
`check`, do not re-walk `docs/BOUNDARY-AUDIT.md`. A brief-axis
hit that is also a lint `WARN:` cites the lint line as evidence.

## Pass 2 — consume a baton

For each live ranked opinion (skip `## Rescinded`):

1. Re-check the claim against the actual skill (path + quote).
2. Verified → keep. Class `must-fix` if severity is `high`, else
   `nice-to-have`, unless the action is a rewrite of the whole
   package (nice-to-have regardless of seat count).
3. Unverified → keep only as `unverified` with the failed check
   stated; do not fold later.
4. Do not re-cluster. Do not invent support tags.

Then add only those same-session findings that Pass 1 facts
support and the baton did not already claim.

A fixture reader for the baton shape (if present next to the
brief producer) may extract `n=` and `claim=` lines; you may
also parse `RESULT.md` by the contract: `# Council:`, `Brief:`,
`## Ranked opinions` / `### N. [seats] severity — claim`,
`## Rescinded` is not live.

## Receiving discipline (before any fold)

1. Feedback is a claim, not a decision — re-check before
   implementing.
2. No performative agreement.
3. One unclear item holds the whole batch.
4. Grep before generalizing.
5. Push back with evidence when the claim is wrong.

Do not write findings back into the target skill.

## Report (in context; no file)

```
# Review: <skill>
Depth: same-session | baton | stopped-for-baton
Brief: <path or `skill`>
Facts: lint fails=N warns=N (target-relevant listed)

## Verdict
approve | approve-with-changes | needs-rework

## Findings
### 1. high — <claim>
Location: <path>
Why: …
Fix: …
Class: must-fix | nice-to-have
Source: same-session | baton (verified) | baton (unverified)

## Notes
```

Verdict: any verified `must-fix` → `needs-rework`; only
`nice-to-have` → `approve-with-changes`; no findings →
`approve`. Unverified baton claims do not by themselves block.

## Done when

Target resolved (or refused); Pass 1 facts reported; Pass 2 ran
or the verb stopped for a missing baton; the report above is
shown. The target tree is unchanged by this verb.
