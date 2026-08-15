---
name: agent-council
description: "Use when the user runs `/agent-council`, asks for a multi-model or cross-vendor review panel, or wants independent Claude, Grok, and Codex opinions on a skill package. Keywords: council, panel, convene, multi-model review, cross-vendor review."
---

# agent-council — a three-family review panel

Convene isolated Claude, Grok, and Codex reviewers against a skill
package, cluster their claims, let them update or rescind, and show one
list ranked by how many seats support each claim. You are the
orchestrator. You never sit on the panel.

Scratch-only: ballots live under `$TMPDIR`. No durable home, no `init`.

## When to use

- Explicit `/agent-council [path]`
- A request for a multi-model / cross-vendor / council / panel review
  of a skill package

**Do not use** for a one-line tweak, a mechanical lint pass, a scored
rubric audit, or when fewer than two seats exist.

## Target

`/agent-council [path]`:

1. A directory that contains `SKILL.md` → that package.
2. A relative path → resolve from cwd, then apply (1).
3. A bare slug → `<git-toplevel>/skills/<slug>/` if that directory
   contains `SKILL.md`.
4. Missing or unresolvable → ask. Do not guess a different brief.

V1 refuses a target that is not a skill package. The brief is always
`briefs/skill.md`.

## Loop

1. Resolve the target. No `SKILL.md` → stop.
2. Brief is `briefs/skill.md`.
3. Run `scripts/probe-seats.sh`. A missing CLI drops that seat. Fewer
   than two paths → stop (one reviewer is not a council).
4. Confirm cost. Name the seats and that this is up to six headless
   runs (round 1 + review). Wait for a yes. A previous session's yes
   does not count. A no leaves no scratch and no dispatches.
5. Open `$TMPDIR/agent-council-<YYYYMMDDTHHMMSS>-<pid>/`. Print the
   path once. You write every file in it. Layout: `round1/<seat>.md`,
   `review/<seat>.md`, `clusters.md`, `RESULT.md`, plus prompt files.
6. **Round 1.** One isolated, read-only, headless process per present
   seat, **in parallel**, per `references/spawn.md`. cwd is the target
   skill directory. Each prompt (a file in scratch) tells the seat:
   - You are one isolated reviewer. You do not see other reviewers.
   - Read the brief at `<absolute briefs/skill.md>`.
   - Emit opinions on stdout in the shape of `<absolute templates/ballot.md>`.
   - Do not edit files. Do not rank. Do not self-tag seats.
   Capture stdout into `round1/<seat>.md`.
7. **Cluster** (rules below). Write `clusters.md` with ids `C1`, `C2`,
   … and support tags. No ranks, no “strongest / weakest” frame.
   Fewer than two successful ballots (missing file, or zero extracted
   `## Opinion` blocks) → stop, say why, do not invent a ranked list.
8. **Review.** Only seats that produced a successful round-1 ballot, in
   parallel, read-only. Each prompt points at `clusters.md`, that
   seat's `round1/<seat>.md`, and `templates/review.md`. A no-show,
   crash, or unparseable reply **holds** that seat's round-1 support
   and is noted. Silence is not a rescind.
9. Re-cluster. Sort by support count. Write `RESULT.md`. Show it.

## Extracting opinions

From a ballot, take every `## Opinion` block that has `claim`,
`evidence`, and `action`. Ignore wrapping prose. Omitted `severity`
→ `mid`. Do not upgrade an omitted severity to `high`. Zero blocks
→ empty.

From a review reply, take every `## Reply` with `id` and `verdict` in
`confirm` / `refine` / `rescind`. A `refine` without replacement
`claim` / `evidence` / `action` / `severity` is a **confirm**. Then
take any extra `## Opinion` blocks as `new`.

## Clustering

Two claims join only when **both** hold:

1. Same artifact (same path or the same named surface).
2. Same assertion (the same change would fix both).

Unsure → split. Never inflate agreement.

Support tags list present seats in order `c`, `g`, `x` — never
`[x,c]`. Cluster severity is the highest among current supporters.
Keep every distinct evidence line. If actions conflict, list both;
if they agree, keep the more specific wording.

| Seat says | Effect |
|---|---|
| confirm | Support stays |
| refine | Same assertion → update cluster text, support stays. Different assertion → new id, that seat **moves** |
| rescind | That seat drops off |
| new | New id, that seat only (merge if another seat filed the same claim this round) |

Conflicting refines that still share an assertion: one wording, prefer
the more specific evidence. Divergent refines: split. A confirm stays
on the original. A cluster with no remaining support leaves the ranked
list and goes under **Rescinded**.

## Report

Show this, and write it to `RESULT.md`. No essay that re-argues claims.

```
# Council: <target>
Brief: skill
Seats: c=claude  g=grok  x=codex
Round 1: c,g,x ok
Review:  c,g ok; x no-show (held)

## Ranked opinions

### 1. [c,g,x] high — <claim>
Evidence: …
Action: …
Status: held

## Rescinded
- [was c,g] — <claim> (c rescinded, g rescinded)

## Seat notes
- x review no-show; round-1 support held

Scratch: <absolute path>
```

Sort by support count only (`[c,g,x]` before `[c,x]` before `[x]`).
Ties keep cluster-id order. Status is `held` / `refined` / `new`.
Rescinded clusters are not numbered.

## Anti-patterns

- Reviewing the target yourself
- Playing the seat that matches your family
- Substituting same-family subagents for a missing CLI
- Showing ranks (or “strongest”) in `clusters.md`
- Retrying an identical failed dispatch
- Inventing a short skill-level timeout
- Editing the project tree or a `.gitignore`

## Done when

Seats probed and cost confirmed; at least two round-1 ballots (or a
stop with the reason); cluster → review (or attempted) → re-cluster;
ranked report shown and written to `RESULT.md`; every dropped or silent
seat is in Seat notes.

## Edges

Scratch-only. The report ends the pass.

<!-- edges:agent-council -->
- produces: review — ranked council report (shown to the user + scratch RESULT.md)
- handoff: — (the report ends the pass)
- consumes: — (a path the user names, not another skill's typed artifact)
<!-- /edges:agent-council -->
