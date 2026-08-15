# `agent-council` — a three-family review panel

**Status:** proposed (2026-08-15). Settled in conversation; not yet scaffolded. A new
**standalone** library member — outside the `clankshop` pack, scratch-only, one invocation.

## Why this is a skill

A single model reviewing a skill package has systematic blind spots. Claude, Grok, and Codex
miss different classes of problem; a tagged synthesis is more useful than three unread essays.
Nothing in this library convenes independent reviewers from distinct vendor families, clusters
their claims, or lets them update or rescind before a ranked result is shown.

Neighbors that this is **not**:

- `skill-builder check` is a mechanical lint + boundary audit. The council judges substance.
- `auditor` is a rubric-scored pass over project code. The council is a judgment panel.
- A same-family trio of subagents with different personas is a weaker, different skill.

## Decision summary (settled with the human, 2026-08-15)

- **Protocol + briefs.** The skill owns one council loop. What to look *for* lives in a brief
  file. V1 ships `briefs/skill-review.md`. A later `briefs/feature.md` (or a user-typed question)
  plugs into the same loop without rewriting it.
- **V1 target is a skill package.** Generic enough to review anything later; v1 only accepts a
  directory that contains `SKILL.md`.
- **Agreement is strength.** The final list sorts by how many seats support the claim. Shared
  opinions rise; uniques sink. `[c,g,x]` marks who is on each claim. Severity is displayed, not
  sorted on.
- **Review round does not show the ranking.** Independent first pass; cluster; show clusters
  without ranks; seats confirm / refine / rescind / add; re-cluster; then rank for the human.
  Showing the ranked synthesis in the review round would herd the panel.
- **The orchestrator is never a panelist.** Even when the orchestrator *is* Grok, the Grok seat
  is a fresh `grok -p` process. Same-family stand-ins are forbidden.
- **Degrade, don't stall.** A missing CLI, timeout, crash, or empty ballot drops that seat.
  Fewer than two successful round-1 ballots → stop. A review-round no-show **holds** that
  seat's round-1 support.
- **Scratch-only.** Ballots and the result live in a throwaway temp directory. No `init`, no
  front-door registration, no records-layer drain.
- **Confirm cost once** before the headless runs (quota/availability the orchestrator cannot
  see). Then proceed.

## 1. Shape and placement

- Path: `skills/agent-council/`.
- Invocation: `/agent-council [path]`. No verb table until a second verb exists.
- `[path]` is a skill directory (contains `SKILL.md`). Relative paths resolve from cwd. A bare
  slug may resolve to `<git-toplevel>/skills/<slug>/` when that directory exists and contains
  `SKILL.md`. Missing or unresolvable path → ask. Do not guess a different brief.
- Standalone. Not a `clankshop` member. Absent from `PACK.md`. No workshop detection.
- Tier: **scratch-only**. No private home, no `init`, no registration.
- Inventory: one row in the library README (lint check 4). `install.sh` discovers the new
  directory the same way it discovers every other skill.

**Description** (routing surface — trigger only, no protocol summary):

> Use when the user runs `/agent-council`, asks for a multi-model or cross-vendor review panel,
> or wants independent Claude, Grok, and Codex opinions on a skill package. Keywords: council,
> panel, convene, multi-model review, cross-vendor review.

**Edges**

```
produces: review — ranked council report (shown to the user + scratch RESULT.md)
handoff:  — (the report ends the pass)
consumes: — (a path the user names, not another skill's typed artifact)
```

**When not to use:** a one-line tweak; a mechanical lint pass; a scored rubric audit; fewer
than two seats available.

## 2. Package layout

```
skills/agent-council/
  SKILL.md                 # trigger, loop, degrade rules, report shape, edges
  briefs/skill-review.md          # v1 panelist brief (substance, not lint)
  templates/ballot.md      # round-1 output contract
  templates/review.md      # review-round output contract
  references/spawn.md      # CLI invocations (flags drift; re-read --help per session)
  scripts/probe-seats.sh   # prints which of claude/grok/codex exist (facts, not a verdict)
```

The loop stays in `SKILL.md`. Spawn flags live in `references/spawn.md` so CLI drift does not
rot the driver. Briefs are what panelists read; they must not name the ranking rule or the
other seats' identities.

## 3. The loop

The skill is a thin driver. It never reviews the target itself.

1. **Resolve the target** — §1. Must contain `SKILL.md` (v1).
2. **Pick the brief** — v1 always `briefs/skill-review.md`. Later a flag, a target-shape guess, or a
   user-supplied question can swap it. The loop does not change.
3. **Probe seats** — run `scripts/probe-seats.sh`. It prints `key=value` facts
   (`claude=/path` or `claude=`). A missing CLI drops that seat. Fewer than two seats → stop
   (one reviewer is not a council).
4. **Confirm cost** — tell the user which seats will run and that this is up to six headless
   invocations (three round-1 + three review). Wait for a yes. Confirmed for this convene
   only; do not treat a previous session's yes as standing permission. A no leaves no
   scratch and no dispatches.
5. **Open scratch** — `$TMPDIR/agent-council-<YYYYMMDDTHHMMSS>-<pid>/`. Not inside the
   project; no `.gitignore` edit. Print the path once. Layout:
   `round1/<seat>.md`, `review/<seat>.md`, `clusters.md`, `RESULT.md`, plus the prompt files
   fed to each seat. The orchestrator writes these files; seats do not.
6. **Round 1** — one isolated, read-only, headless process per present seat, dispatched
   **in parallel**. Each gets the target path, the brief, and the ballot template. Each
   emits its ballot on stdout. The orchestrator captures that stream into
   `round1/<seat>.md`. No sibling ballots. No ranking instruction.
7. **Cluster** — §5. Write `clusters.md` with stable ids `C1`, `C2`, … and support tags.
   Do **not** include ranks or a sort in this file (it is what the review round sees).
   Fewer than two successful ballots → stop here, report the reason, do **not** invent a
   ranked list.
8. **Review round** — only seats that produced a successful round-1 ballot, in parallel,
   read-only. Each gets `clusters.md`, its own round-1 ballot path, and the review
   template. A no-show, crash, or unparseable reply **holds** that seat's round-1
   support and is noted.
9. **Re-cluster and rank** — apply confirms / refines / rescinds / news (§5). Sort by
   support count. Write `RESULT.md`. Show it to the user.

## 4. Opinion contract

An opinion is one discrete claim, not an essay. Round-1 ballots fill `templates/ballot.md`:

| Field | Required | What it is |
|---|---|---|
| `claim` | yes | One sentence |
| `evidence` | yes | Path + quote or `file:line` |
| `action` | yes | What to change |
| `severity` | no | `high` / `mid` / `low`. Omitted → `mid`. Do not upgrade an omitted severity to `high` |

Panelists do **not** self-tag `[c,g,x]`. Support is assigned from which seat's file the claim
came from.

Review-round replies fill `templates/review.md`: for each cluster id, one of `confirm` /
`refine` / `rescind`, plus any `new` claims in the same ballot shape. A **refine** carries
replacement `claim` / `evidence` / `action` / `severity` — without those fields the
cluster text cannot update, and the edit is treated as a confirm.

**Malformed input.** Extract every block that matches the template; ignore wrapping prose.
Zero extracted claims → empty ballot → that seat drops for the round (round 1) or is a
no-show (review).

## 5. Clustering and review-round edits

Two ballots join only when **both** are true:

1. **Same artifact** — same path or the same named surface (`SKILL.md` description, verb
   `new`, script `foo.sh`).
2. **Same assertion** — the same change would fix both.

Same section, same severity, or “both about independence” is not enough. Unsure → split.
Never inflate agreement.

Stable ids (`C1`, `C2`, …) are assigned at first cluster and kept through the review round.
New claims in the review round get the next unused id.

**Support tags** always list present seats in canonical order: `c`, then `g`, then `x`.
Missing seats are omitted. Examples: `[c,g,x]`, `[c,x]`, `[g]`. Never `[x,c]`.

**Severity of a cluster** is the highest severity among current supporters. **Evidence**
keeps every distinct evidence line. **Action:** if supporters agree on the assertion but
word the action differently, prefer the more specific wording; if the actions conflict,
list both.

**Review-round edits**

| Seat says | Effect |
|---|---|
| **confirm** | Support stays on that cluster |
| **refine** | Same assertion, tighter wording or better evidence. Cluster text updates. Support stays. If the “refine” actually changes the assertion, it becomes a **new** cluster and that seat's support *moves* |
| **rescind** | That seat drops off the cluster |
| **new** | New cluster, that seat only (unless another seat filed the same claim this round) |

Conflicting refines that still share an assertion: keep one wording, prefer the more
specific evidence. Conflicting refines that diverge: split, assign support to the claim
each seat actually endorsed. A **confirm** stays on the original.

A cluster with no remaining support leaves the ranked list and goes under **Rescinded**.
A review-round no-show holds round-1 support — silence is not a rescind.

## 6. Spawn

`references/spawn.md` is the one place CLI flags live. Re-read each binary's `--help` once
per session; do not trust a memorized flag surface.

| Seat | Letter | Probe key | Invocation (intent) |
|---|---|---|---|
| Claude | `c` | `claude` | `claude -p --bare` with write tools disallowed |
| Grok | `g` | `grok` | `grok -p` (or `--prompt-file`) with write tools disallowed |
| Codex | `x` | `codex` | `codex exec --sandbox read-only -c approval_policy="never" -o <ballot>` |

Shared rules:

- cwd is the **target skill directory**, so evidence paths are `SKILL.md`, `verbs/new.md`,
  and the seat is not invited to tour the rest of the repo. Claude may need `--add-dir`
  (or the session equivalent) pointing at that directory if the process starts elsewhere;
  prefer starting in the target.
- The prompt is a file in scratch, not a huge argv. Seats read it; they do not write it.
- Each seat emits the ballot (or review reply) on **stdout**. The orchestrator captures
  that into `round1/<seat>.md` or `review/<seat>.md`. Codex's `-o` is the parent CLI
  writing the final message — same idea. Seats do not need write access to scratch.
- No model pin unless the user named one for this convene.
- Read-only. A seat must not edit the target or the project tree.
- The orchestrator's own context is not a seat, even when it shares a family with one.

**Degrade.** Missing CLI / non-zero exit / timeout / process death / empty ballot → drop
that seat for the round and note it. Do not retry the identical dispatch (a failed review
is not a transient blip to bounce). Do not substitute a same-family subagent. Need two
successful round-1 ballots or stop after round 1 and say so.

**Timeouts.** Do not invent a short skill-level deadline that kills a live review. If the
user aborts, or the process dies, that seat drops. Harness defaults stand.

`scripts/probe-seats.sh` prints facts only:

```
claude=/Users/…/claude
grok=/Users/…/grok
codex=
```

It does not recommend whether to convene.

## 7. The skill brief (v1)

`briefs/skill-review.md` is what each panelist reads. It is not a restatement of a mechanical
lint or boundary gate. Lint stays lint. The brief file itself names no sibling skill.

- **Target** is the skill directory. Read `SKILL.md`, then only the verbs / scripts / docs /
  templates it actually names. Do not tour the rest of the repo.
- **Judge:** trigger quality (fires on the right jobs, skips the wrong ones); followability
  (can you execute without inventing steps); holes (missing failure states, missing
  done-when, ambiguous branches); independence (assumes a sibling, a pack, or a host layout
  that is not guaranteed); judgment-vs-mechanism (agent computing what a script should, or
  a script deciding what an agent should); scope (knows when to stop); output shape (if it
  produces something, is that shape specified).
- **Do not** restate the skill, rank anything, propose a rewrite, run a lint gate, or
  self-tag `[c,g,x]`. Emit discrete claims in the ballot contract.
- **Do not** tell the panelist the agreement-is-strength rule or show them sibling ballots.

A later `briefs/feature.md` swaps this file. That file is out of scope for v1.

## 8. The report

One ranked list, shown to the user and written to `RESULT.md` in the scratch directory. No
orchestrator essay that re-argues the claims.

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

### 2. [c,g] mid — <claim>
…

### 3. [x] low — <claim>
…

## Rescinded
- [was c,g] — <claim> (c rescinded, g rescinded)

## Seat notes
- x review no-show; round-1 support held

Scratch: <absolute path>
```

Sort key is support count only (`[c,g,x]` before `[c,x]` before `[x]`). Ties keep
cluster-id order (`C1` before `C2`). Status is `held` / `refined` / `new` as of the
final cluster. Rescinded clusters are not numbered in the ranked list.

`clusters.md` (review-round input) is the same claims **without** the numeric ranking
and without a “strongest / weakest” frame.

## 9. Done when

- Seats probed; cost confirmed; scratch opened.
- At least two successful round-1 ballots, or a stop with the reason.
- Cluster → review (or attempted) → re-cluster.
- Ranked report shown and written to `RESULT.md`.
- Every dropped, empty, or silent seat is in Seat notes.

## 10. Non-goals (v1)

- A `briefs/feature.md` or ad-hoc user question as a brief swap.
- Draining the report into the records layer (`reports` / trackers).
- Front-door registration or a durable `.council/` in the project.
- Scoring, rubrics, or a numeric quality grade for the target.
- Same-family fallback when a CLI is missing.
- The orchestrator contributing an opinion.
- Retrying a failed seat with a different model or prompt.
- A verb table (`convene`, `brief`, …).

## 11. Rejected alternatives

| considered | rejected because |
|---|---|
| Rank by severity × evidence; agreement is only a tag | Owner chose option A: agreement is the sort key |
| Two lists (“panel agrees” then “unique / dissent”) | Same choice: one list, shared rise, uniques sink |
| Show the ranked synthesis in the review round | Herds the panel toward the top items; Delphi failure mode |
| Fully generic, no briefs — user writes the question every time | Weaker default for skill review; re-teaches the brief each run |
| Skill-only loop, generalize later | Bakes skill-review assumptions into the driver; “review anything” becomes a rewrite |
| Orchestrator plays the seat that matches its family | Contaminates that ballot with the synthesizer's context |
| Same-family subagents when a CLI is missing | A different, weaker skill; would silently ship a false council |
| Durable `.council/` in the project + `.gitignore` edit | Scratch-only; a project ignore is a host mutation this skill does not own |
| Drain to `journal` reports on a workshop host | V1 ends at the ranked report; records drain is a later brief/consumer |
| Make it a `clankshop` / review-station verb | The panel is not workshop-admin work; it must install and run bare |

## 12. Gate and tests

- `skills/skill-builder/scripts/skills-lint.sh` → `fails=0` (frontmatter, bundled refs,
  script syntax, edges, README mention).
- `scripts/probe-seats.sh`: `bash -n` (covered by the lint) plus a smoke that it prints
  exactly the three keys `claude`, `grok`, `codex` and never a verdict.
- No live convene in CI. Six authenticated headless runs are not a unit test.

## Residual assumptions

1. `claude`, `grok`, and `codex` are the v1 seat set. Adding a fourth family is a new
   letter and a new probe key, not a config surface.
2. V1 refuses a target that is not a skill package. That refusal lives in the target
   resolver (`SKILL.md` must exist). The loop is already generic; a later brief adds a
   new accepted target shape, not a new driver.
3. Cost confirmation is per convene, interactive. This skill is not designed to run
   inside an unattended workstream loop in v1.
4. Patient-zero does not apply: this is a library skill, not a deployed workshop
   mechanism, and it is exercised by convening against other skills (or a fixture
   package), never by writing into grimoire's own `AGENTS.md`.
