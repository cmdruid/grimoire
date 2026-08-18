---
doctype: design
status: current
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# pack-utilities review — Spec

**Shipped 2026-08-18** on `stream/grok` — subjects: `docs: add
pack-utilities review spec`; `Fold pack-utilities skill-builder
review findings`.

Accepted fold set 2026-08-18 on stream `grok`. Same-session
`/skill-builder review` of `checkpoint`, `mailbox`, `delegate`,
`scheduler`, and `notepad` against
`skills/agent-council/briefs/skill-review.md`. Combined verdict:
**needs-rework** (one must-fix on `delegate`). The human asked to
fold **every numbered finding**. This file is the governing spec
for that fold — the review report plus the receiving locks — not a
restatement of the five skills.

This spec doubles as the plan (Slices). A separate contractor plan
is not required unless a later flip changes a slice boundary.

Targets (unchanged by the review verb), all under
`/Users/cscott/Repos/grimoire/.workstreams/grok/`:

- `skills/checkpoint/`
- `skills/mailbox/`
- `skills/delegate/`
- `skills/scheduler/`
- `skills/notepad/`

Brief:
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/agent-council/briefs/skill-review.md`

High-stake: no target contains `PACK.md`. No panel was warranted;
none was asked for; none was convened.

## Problem

Five remaining pack members (`checkpoint`, `mailbox`, `delegate`,
`scheduler`, `notepad`) were reviewed this series and still carry
the numbered holes: one must-fix (Codex writes a shared worktree)
and twelve nice-to-haves (over-broad triggers, missing done-whens,
an unexecutable isolated-worktree branch, a sibling-cited record
contract, a first-save root that never names git, a silent
scheduler overwrite). Leaving them unfixed means the next session
that follows those skills invents steps or takes the unsafe
executor path.

## Goal

Every numbered finding is folded into the named file. Lint
`fails=0`. No new scripts. No sibling restated past a one-word
pointer. Descriptions stay under 1024 characters (prefer ≤750).

## Approach

**Chosen:** one prose-only fold across the five packages, locked
below so build does not re-open branches. Same shape as the
workstream / clankshop folds: the review report is the
requirements; receiving locks are the remedies.

**Rejected:** five separate specs (the human named one unit).
**Rejected:** a new `save-guard`-style script on `delegate` (the
two file/branch checks already live in prose on `notepad` and in
`checkpoint`’s script; duplicating a script is new surface).
**Rejected:** refusing the isolated-worktree mechanism (folding
the hole means making the named path executable, not deleting
it).

## Facts (Pass 1)

lint fails=0 warns=20 (target-relevant: 5 symlink notes, one per
target). Expected worktree-vs-clone notes. Not findings. Orphan
edge types (`founding-documents`, `git-repository`, `plan`,
`roadmap`, `runbook`) are siblings.

## Findings (the requirements)

Numbering is **per skill**, as reported. Disposition of every
item: **fold**.

### checkpoint 1. mid — First-save root resolution never names the git toplevel

Location: `skills/checkpoint/SKILL.md` (*Where it writes*)
Class: nice-to-have
Disposition: **fold**

Root is “(1) the project directory the conversation references;
(2) `./CHECKPOINT.md` in the cwd; (3) still unsure → ask.” On a
first save the file does not exist, so (2) cannot fire. A git repo
with a clear cwd falls through to ask, or the agent invents
`rev-parse --show-toplevel`. `verbs/save.md` then needs a `<dir>`
for `scripts/save-guard.sh` that this list never produces.

### mailbox 1. mid — When-to-use claims the model-routing job the lead sentence disclaims

Location: `skills/mailbox/SKILL.md` (description; *When to use*
bullet 2)
Class: nice-to-have
Disposition: **fold**

Lead says mailbox is HOW the artifact crosses back, not WHETHER to
delegate. Bullet 2 still says use mailbox when “routing work to a
different model than the orchestrator.” Description is 734
characters of transport lecture plus keywords (`worktree
corruption`, `single-writer`) that also match ordinary worktree
debugging.

### mailbox 2. mid — No done-when

Location: `skills/mailbox/SKILL.md` (ends at *Edges*)
Class: nice-to-have
Disposition: **fold**

Protocol steps 1–5 imply an end. An agent can stop after mint, or
after apply, and call it done.

### delegate 1. high — Mechanical-coding branch sends Codex into a shared worktree

Location: `skills/delegate/SKILL.md` (decision tree, mailbox vs
Codex rows); `skills/delegate/references/codex.md` (*Commit*);
anti-pattern “Delegate edits a shared worktree”
Class: must-fix
Disposition: **fold**

Mailbox is “file-work … or worktree single-writer safety.” The
next row is “mechanical CODING → a diff → CODEX.” Codex writes
the working tree. The more specific coding row wins in a
workstream worktree, and the executor becomes a second writer.

### delegate 2. mid — Isolated worktree is a named mechanism with no procedure

Location: `skills/delegate/SKILL.md` (decision tree last row;
paragraph after the tree)
Class: nice-to-have
Disposition: **fold**

Mailbox refuses a live red-green loop and sends you here. The
whole instruction is “own branch; you merge” plus a brief shape.

### delegate 3. mid — Description fires on almost any non-trivial turn

Location: `skills/delegate/SKILL.md` (frontmatter `description:`)
Class: nice-to-have
Disposition: **fold**

Lead is “Use when about to do work a sub-agent could do.” The
three-part delegable test lives only in the body.

### delegate 4. mid — Byproducts require `/backlog debrief`’s taxonomy

Location: `skills/delegate/SKILL.md` (*The return contract*,
byproducts block)
Class: nice-to-have
Disposition: **fold**

Every dispatch must return Backlog/bug/Issues/Feedback via that
sibling verb. On a non-workshop host the verb is not installed.

### delegate 5. mid — No done-when

Location: `skills/delegate/SKILL.md` (ends at *Edges*)
Class: nice-to-have
Disposition: **fold**

Quick reference is a checklist, not a close.

### scheduler 1. mid — Description keywords match ordinary OS cron, not agent ticks

Location: `skills/scheduler/SKILL.md` (frontmatter `description:`)
Class: nice-to-have
Disposition: **fold**

Niche is a harness tick. Keywords include `cron`, `crontab`,
`launchd`, `plist`, `daemon`, `background task`. “Add a crontab
to rotate logs” loads this skill.

### scheduler 2. mid — Reinstall/update is a silent overwrite

Location: `skills/scheduler/SKILL.md` (*Quick reference*);
`skills/scheduler/scripts/schedule.sh` (`cmd_install`)
Class: nice-to-have
Disposition: **fold**

The script overwrites an existing name. The prose never says
install-again updates.

### scheduler 3. mid — No done-when

Location: `skills/scheduler/SKILL.md` (ends at *Triage a run*)
Class: nice-to-have
Disposition: **fold**

### notepad 1. mid — Keywords fire on explain-this and any “note”

Location: `skills/notepad/SKILL.md` (frontmatter `description:`)
Class: nice-to-have
Disposition: **fold**

Use-when is tight. Keywords add `note`, `notes`, and `how does
this work`.

### notepad 2. mid — Record contract is cited on a sibling file this package does not ship

Location: `skills/notepad/SKILL.md` (*Shared discipline*, “Cite
the record contract”)
Class: nice-to-have
Disposition: **fold**

“Do not restate it (the format authority’s SKILL.md …): five
front-matter keys, status vocabulary…” The minter can write the
shape from `templates/notes.md`. The agent is still sent to a
format-authority `SKILL.md` that is not in this package.

## Receiving locks (do not fold past these)

The human accepted every numbered finding. These locks are the
chosen remedies — not options for the implementer.

1. **Shared worktree (delegate 1).** A target checkout is
   **held** when either (a) `<toplevel>/WORKSTREAM.md` exists, or
   (b) a `<toplevel>/.workstreams/*/WORKSTREAM.md` records
   `isolation: in-place` and its Coordinates `branch:` equals
   `git -C <toplevel> branch --show-current`. “Held” is only
   this refuse — lock 2’s walk keys on **target**, not held.
   Codex (or any tree-writing executor) **must not** write a
   held tree. That path is mailbox (parent applies) or isolated
   worktree (dispatch owns a different tree). Name every leftover
   default-write sentence, not just the decision-tree rows:

   - Both decision-tree rows (mailbox and Codex) carry the
     held-tree tie-break.
   - `references/codex.md` Guardrails: hard refuse of a `-C` /
     cwd that is a held tree. When the route is isolated
     worktree, `-C` / cwd **is** that worktree’s `<abs-path>`,
     never the held/target path.
   - Retract or qualify `codex.md` “Worktree isolation is
     optional — not by default”: isolation is **required** when
     the target is held (mailbox or isolated worktree); optional
     only on an **unheld** target for large or parallel runs.
   - Spawn seam (`SKILL.md`): for coding, run the held check
     first; if held → mailbox or isolated, never `codex exec`
     against the target. If unheld → `codex exec -C <target>`
     remains allowed.
   - Anti-pattern “Delegate edits a shared worktree”: “shared”
     / held is the noun. Isolated-worktree writes are allowed.
     Drop “Tree-read-only; it writes only its slot” as a
     universal (that is mailbox, not isolated).

   Do not add a script. Do not require `checkpoint` to be
   installed; the two checks are the test. Reuse
   `save-guard.sh` facts only if this session already has
   them — never as a dependency.

2. **Isolated worktree walk (delegate 2).** Fold a short
   executable walk into `SKILL.md`, not a refuse. The walk
   keys on the **target checkout** (the parent’s
   `git rev-parse --show-toplevel` for the tree the artifact
   is for) — it must work on an unheld clone too. “Held”
   appears only as lock 1’s refuse. Steps, in order:

   1. Slug the unit. Branch is `delegate/<slug>`. If that
      branch already exists → refuse and ask for a new slug.
      Do not `-B`.
   2. `<abs-path>` default is the sibling
      `<parent-of-target>/delegate-<slug>`. If that path
      exists or is not writable → ask. Never a path inside
      the target.
   3. Record **base** = `git -C <target> rev-parse HEAD`.
      Then `git -C <target> worktree add <abs-path> -b
      delegate/<slug>`.
   4. Dispatch with cwd = `<abs-path>`. The delegate may
      write and commit **there only**. Any executor `-C` is
      `<abs-path>`.
   5. You review `git -C <abs-path> log` + diff vs **base**,
      run the gate in that tree, then you merge or
      cherry-pick into **target**. The delegate never merges
      into the target.
   6. After land: `git -C <target> worktree remove
      <abs-path>`. If the worktree is dirty → refuse remove
      and surface.

   Keep the existing “narrow list-shaped brief + flag
   same-pattern sites” clause. Do not add a script. Do not
   name `/workstream`.

3. **Description replacements are the text below**, not a
   paraphrase. Stay under 1024 characters (these are all ≤400).
   Keep each skill’s verb / Use-when clause named in the lock.

   - **delegate** (keep `/delegate`, the five mechanisms, confirm
     once, degrade-to-inline):
     `Use when work is well-scoped, returns a checkable artifact or conclusion, and does not need your taste to produce — or on explicit /delegate [task]. Pick the mechanism (inline read-only, mailbox slot, Codex executor, parallel fan-out, isolated worktree), confirm the provider/model once, degrade to inline on provider failure. Keywords: /delegate, dispatch, byproducts, model routing.`
   - **mailbox** (keep HOW-not-WHETHER; drop model-routing,
     `worktree corruption`, `single-writer`):
     `Use when a sub-agent must return a file-work artifact without writing the shared tree: mint a git-excluded mailbox slot, pass its absolute path, collect a handle + one-line summary, then apply the patch or consume the doc. Transport only — not whether to delegate. Keywords: mailbox slot, absolute slot path, pass-by-reference, tokenless apply.`
   - **scheduler** (keep list/check/test-fire/remove; drop bare
     `cron` / `crontab` / `daemon` / `background task` as
     triggers; ordinary OS cron is when-not):
     `Schedule recurring agent-harness runs on this machine (claude or codex) via launchd on macOS or cron on Linux. Each OS tick is one short-lived headless harness invocation. Use when the user wants a recurring agent run, or to list, check, test-fire, or remove one. Not ordinary OS cron unless a harness is the payload. Keywords: scheduled agent, heartbeat, recurring harness.`
   - **notepad** (keep `/notepad` and the four verbs; drop `note`,
     `notes`, `how does this work`):
     `Use when the user runs /notepad, asks to write down a project fact, look up or update existing notes, supersede a note that is no longer true, or drop a note with no successor. Keywords: notepad, write this down, project memory, capture this fact.`

   **checkpoint** description is unchanged.

4. **Mailbox *When to use* bullet 2 is deleted.** Do not replace
   it with a pointer to `/delegate` beyond the one-word
   HOW-not-WHETHER line already in the description. Remaining
   bullets (file-work without polluting context; shared worktree
   safety) stay.

5. **Done-when text is locked** (add a `## Done when` section;
   do not invent a different close):

   - **mailbox:** slot minted; collected only after a completion
     return; tree snapshot matched; apply-or-consume finished;
     slot reaped on success or kept on refuse. Drift → tree
     preserved, no apply. Salvaged mid-task slot → dry-run /
     read skeptically, never trusted as a completion.
   - **delegate:** mechanism picked; route confirmed or
     pre-confirmed; return contract received (deliverable +
     status + byproducts); trust re-established from evidence;
     byproducts stashed. If the route failed: fallback or floor
     named.
   - **scheduler:** per subcommand. `install`: the four
     confirmations (schedule+timezone, permission stance, right
     tool, cost) ran **and** the script printed `installed:`.
     Nothing is installed without those confirmations.
     `uninstall` / `list` / `status` / `run` / `convert`: the
     script’s printed facts, or a clean refuse. Do not install
     on an unsupported platform.

6. **Checkpoint *Where it writes* resolver.** Order, for a
   no-argument (root) save:

   1. The project directory the conversation references, if
      any.
   2. Else if that path (else cwd) is inside a git repo →
      that `git rev-parse --show-toplevel`.
   3. Else if `./CHECKPOINT.md` exists in cwd → that
      directory (the file’s parent).
   4. Else ask.

   `./CHECKPOINT.md` is a discovery step, not a prerequisite
   for a first save in a git repo (step 2 fires first). Do
   not skip an existing `./CHECKPOINT.md` in a non-git cwd.
   **Require** a one-line clarification in `verbs/save.md`:
   `<dir>` passed to `save-guard.sh` **is** that resolved
   root. Do not change `save-guard.sh`.

7. **Scheduler reinstall.** One sentence on the quick-reference
   / install path: `install` of an existing `<name>` replaces
   the spec and the supervisor entry; logs are preserved. Do
   not add an `update` subcommand. Do not edit
   `scripts/schedule.sh` (the overwrite is already the
   behavior).

8. **Notepad record contract lives in this package.** Replace
   “cite the format authority’s SKILL.md” with the keys and
   status words, here:

   - Front-matter keys: `doctype`, `status`, `created`,
     `updated`, `tags` (the bundled `templates/notes.md`
     already has them).
   - Live statuses: `open`, `current`.
   - Closed statuses: `done`, `dropped`, `superseded`,
     `consumed`.
   - Record-link form (already quoted): `→ <store>/<file>.md`.

   Keep “`note-mint.sh` is the one minter” and “never write
   `history.tsv` by hand.” In the minter parenthetical, drop
   “format authority”: write “matching this package’s `fill`
   + slug/collision.” Do not name `journal`. Do not send the
   agent to another skill’s `SKILL.md`. Do not restate the
   rest of the records contract. The verify grep `no format
   authority / journal` applies to the whole file.

9. **Delegate byproducts vocabulary lives here.** Name the
   kinds in `SKILL.md`: follow-up work; defect; project
   problem/risk; dev-experience observation; skill feedback
   (home channel, tagged by skill). Empty remains fine and
   explicit. `/backlog debrief` is the workshop *drain* when
   that verb exists; otherwise the project’s own
   close-the-books sweep. Do not treat `/backlog` as the
   vocabulary source. Do not inline backlog’s procedure.
   Also rewrite the leftovers in the same section: the
   “stash … `/backlog debrief`” sentence becomes stash into
   running capture notes for the host’s close-the-books
   sweep; drop `Issues` / `Feedback` store names (including
   `ISSUES / FEEDBACK` on fallbacks); the quick-reference
   cell lists the five kinds, not “debrief taxonomy.”

10. **No new scripts. No `PACK.md` bump.** Member set is
    unchanged. Do not run `/clankshop setup` or `/clankshop
    migrate` in this library (patient-zero). Do not drive
    sibling `feat`. Root checkout dirt (blueprint + mailbox
    scripts + two untracked design docs) is disjoint — do not
    sweep it into stream commits. Host leftovers
    (`./install.sh notepad`, `./install.sh --remove bootstrap`)
    are not this unit.

11. **Do not edit** `scripts/`, `tests/`, or
    `templates/notes.md` except if a comment becomes false
    (none should). `references/disciplines.md` is out of
    scope. `references/codex.md` is in scope for lock 1’s
    named leftovers (Guardrails held-tree refuse, `-C` must
    be the isolated path when that is the route, qualify
    “isolation is optional”). Do not rewrite the rest of
    `codex.md` (preflight, loop, sandbox gotcha).

## Mechanism

Five independent file clusters. Slice 1 is the tracer (the
must-fix). Later slices do not depend on it except that they
share the lint gate.

Each slice is a surgical prose edit: re-read the cited span
against worktree HEAD, replace only what the lock names, leave
surrounding procedure intact.

## Verification

- `skills/skill-builder/scripts/skills-lint.sh`
  `/Users/cscott/Repos/grimoire/.workstreams/grok` → `fails=0`.
  The five symlink WARNs remain.
- Grep: no `format authority` / `journal` in
  `skills/notepad/SKILL.md`. No “sub-agent could do” in
  `skills/delegate/SKILL.md` description. No
  `worktree corruption` / `single-writer` in mailbox
  description. No bare keyword `how does this work` in notepad
  description. `## Done when` present in mailbox, delegate,
  scheduler.
- Description character counts ≤1024 (locked texts are ≤400).
- Hand-trace: a mechanical-coding task whose target checkout
  has `WORKSTREAM.md` at toplevel must take mailbox or isolated
  worktree, not Codex.

No live `/delegate` spawn, no live `schedule.sh install`, no
live `/clankshop` onramp.

## Slices

- [x] **Slice 1: delegate (the tracer)** <requires: —>

  - Files: `skills/delegate/SKILL.md`,
    `skills/delegate/references/codex.md`
  - Findings: delegate 1, 2, 3, 4, 5
  - Change: locks 1, 2, 3 (delegate description), 5 (delegate
    done-when), 9.
  - Verify: lint `fails=0`; grep the description lead; both
    decision-tree rows carry the held-tree tie-break;
    `codex.md` Guardrails forbids `-C` on a held tree and
    requires `-C` = isolated `<abs-path>` on that route;
    “isolation is optional” is qualified; spawn seam runs the
    held check before `codex exec`; anti-pattern allows
    isolated writes; isolated walk has the six steps keyed on
    **target** (not held); byproducts list the five kinds
    without `/backlog` as vocabulary and without Issues/
    Feedback store names; `## Done when` present.

- [x] **Slice 2: mailbox** <requires: —>

  - Files: `skills/mailbox/SKILL.md`
  - Findings: mailbox 1, 2
  - Change: locks 3 (mailbox description), 4, 5 (mailbox
    done-when).
  - Verify: lint `fails=0`; bullet 2 gone; description matches
    lock 3; `## Done when` present.

- [x] **Slice 3: scheduler** <requires: —>

  - Files: `skills/scheduler/SKILL.md`
  - Findings: scheduler 1, 2, 3
  - Change: locks 3 (scheduler description), 5 (scheduler
    done-when), 7.
  - Verify: lint `fails=0`; reinstall sentence present; no
    script edit; `## Done when` present.

- [x] **Slice 4: notepad** <requires: —>

  - Files: `skills/notepad/SKILL.md`
  - Findings: notepad 1, 2
  - Change: locks 3 (notepad description), 8.
  - Verify: lint `fails=0`; no `format authority` / `journal`;
    five keys + live/closed statuses stated; description
    matches lock 3.

- [x] **Slice 5: checkpoint** <requires: —>

  - Files: `skills/checkpoint/SKILL.md`,
    `skills/checkpoint/verbs/save.md`
  - Findings: checkpoint 1
  - Change: lock 6 (both files; `save.md` one-liner is
    required).
  - Verify: lint `fails=0`; *Where it writes* names
    `rev-parse --show-toplevel` before the `./CHECKPOINT.md`
    discovery step; `save.md` defines `<dir>` as that
    resolved root.

## Out of scope this pass

- Review *Notes*, not numbered findings.
- New scripts, tests, or a `check` facts walker (clankshop
  finding 4 remainder).
- Host leftovers (`./install.sh notepad`, `--remove bootstrap`).
- Root checkout dirt.
- Convening a panel.
- Editing `PACK.md`, `seed/`, or any sibling skill.
- Changing checkpoint’s four disciplines or the ignore
  mechanism.

## Done when

Every numbered finding has a landed slice. Lint `fails=0`. The
worktree-vs-clone WARNs remain.

## Review history

Independent `/blueprint review` 2026-08-18 (`needs-rework`).
Folded into the locks the same day before build:

1. **must-fix** — Lock 1 + old lock 11 left `codex.md`’s
   default-write path, the spawn seam, and the anti-pattern
   standing. Folded: lock 1 now names those leftover
   sentences; lock 11 widened.
2. **must-fix** — Lock 2 used “held” for a walk that must
   also run on an unheld clone, and left `<abs-path>` / base /
   `git -C` unbound. Folded: walk keys on **target**; six
   closed steps.
3. **nice-to-have** — Lock 8 keep-clause vs `format
   authority` grep. Folded: minter parenthetical drops the
   phrase.
4. **nice-to-have** — Lock 6 left `./CHECKPOINT.md` as an
   unbound hint and made `save.md` optional. Folded: four-step
   order; `save.md` one-liner required.
5. **nice-to-have** — Lock 9 left sibling drain names in the
   same section. Folded: leftovers named.
