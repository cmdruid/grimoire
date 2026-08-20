---
name: agent-council
description: "Use when the user runs `/agent-council`, asks for a multi-model or cross-vendor review panel, or wants independent Claude, Grok, and Codex opinions on a skill, spec, or named path. Keywords: council, panel, convene, multi-model review, cross-vendor review."
---

# agent-council — a three-family review panel

Convene isolated Claude, Grok, and Codex reviewers against a named
target, cluster their claims, let them update or rescind, and show one
list ranked by how many seats support each claim. You are the
orchestrator. You never sit on the panel.

Scratch-only: ballots live under `${TMPDIR:-/tmp}`. No durable home, no `init`.

## When to use

- Explicit `/agent-council [path] [brief]`
- A request for a multi-model / cross-vendor / council / panel review
  of a skill, a spec, or another named path

**Do not use** for a one-line tweak, a mechanical lint pass, a scored
rubric audit, a source-tree code review, or when fewer than two seats
exist.

## Target

`/agent-council [target] [brief]`:

1. A readable file or directory (relative paths resolve from cwd).
2. A bare slug → `<git-toplevel>/skills/<slug>/` if that directory
   contains `SKILL.md`.
3. Missing or unreadable → ask. Do not guess a brief as the target.
   The first argument is always the target.

`[brief]` is optional. Present → a readable file that is not a
directory and not a skill package (a directory containing
`SKILL.md`). Unreadable or wrong kind → ask. Do not fall back
silently.

## Brief

Named `[brief]` wins. Otherwise run `scripts/classify-brief.sh`
`<target>` (facts: `brief=skill|spec|generic` or empty). Empty →
ask; do not pick `generic` yourself. Otherwise open the bundled
file for that token:

| Token | File |
|---|---|
| `generic` | `briefs/generic.md` |
| `skill` | `briefs/skill-review.md` |
| `spec` | `briefs/spec.md` |

The classifier is mechanical. Do not replace it with a judgment
about “what this really is.”

## Loop

1. Resolve the target (*Target*). Unreadable → ask.
2. Resolve the brief (*Brief*). Pass its absolute path to every seat.
   Seat cwd is the classifier `workdir` (the directory target, or the
   file’s parent; a `SKILL.md` file retargets to its parent).
3. Run `scripts/probe-seats.sh`. A missing CLI drops that seat. Fewer
   than two paths → stop (one reviewer is not a council).
4. Confirm cost. Name the seats and that this is up to six headless
   runs (round 1 + review). Wait for a yes. A previous session's yes
   does not count. A no leaves no scratch and no dispatches.
5. Open `${TMPDIR:-/tmp}/agent-council-<YYYYMMDDTHHMMSS>-<pid>/`. Print the
   path once. You write every file in it. Layout: `round1/<seat>.md`,
   `review/<seat>.md`, `clusters.md`, `RESULT.md`, plus prompt files.
   Below, `<scratch>` is that absolute directory.
6. **Round 1.** One isolated, read-only, headless process per present
   seat, **in parallel**, per `references/spawn.md`. cwd is the
   workdir from step 2. Each prompt (a file in scratch) tells the seat:
   - You are one isolated reviewer. You do not see other reviewers.
   - Read the brief at `<absolute brief path>`.
   - Emit opinions on stdout in the shape of `<absolute templates/ballot.md>`.
   - Do not edit files. Do not rank. Do not self-tag seats.
   Capture: Claude/Grok → stdout into `<scratch>/round1/<seat>.md`. Codex →
   `-o <scratch>/round1/<seat>.md` **is** the ballot (do not also expect
   stdout; seats do not write scratch themselves).
7. **Cluster** (rules below). Write `<scratch>/clusters.md` with ids `C1`,
   `C2`, … and support tags. No ranks, no “strongest / weakest” frame.
   Shape (seats parse this file; keep it exact):
   ```
   ## C1
   claim: …
   evidence: …
   action: …
   severity: high|mid|low
   support: c,g,x
   ```
   Fewer than two successful ballots (missing file, or zero extracted
   `## Opinion` blocks) → stop, say why, do not invent a ranked list.
8. **Review.** Only seats that produced a successful round-1 ballot, in
   parallel, read-only. Each prompt points at **absolute** paths:
   `<scratch>/clusters.md`, `<scratch>/round1/<seat>.md`, and this
   package's `<absolute templates/review.md>`. Seat cwd is still the
   **target workdir**, so a relative `templates/review.md` would open the
   *target's* file (or miss). A no-show, crash, or unparseable reply
   **holds** that seat's round-1 support and is noted. Silence is not a
   rescind. Capture the same way as round 1, into
   `<scratch>/review/<seat>.md`.
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
`Brief:` is `skill` / `spec` / `generic` for a bundled brief, or the
caller file’s basename without `.md`. A consumer can extract live
ranked opinions with `scripts/read-result.sh` (rescinded claims under
`## Rescinded` are not live).

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

## Project templates

none — `ballot.md` and `review.md` are package-only.

## Edges

Scratch-only. The ranked report is a `review` baton (`RESULT.md`).

<!-- edges:agent-council -->
- produces: review, review-brief — ranked council report (shown + scratch RESULT.md); bundled briefs
- handoff: review — RESULT.md is the baton (ballot / reply / report contract unchanged)
- consumes: review-brief — optional named brief; else classifier token
<!-- /edges:agent-council -->
