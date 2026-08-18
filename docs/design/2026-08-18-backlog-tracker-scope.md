---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Backlog as trackers only — promote, rehome bugs, drop tickets — Spec

Settled 2026-08-18 on stream `grok`. Brainstormed in session; grilled
in conversation; folded a `needs-rework` review the same day. This
file is spec weight: every branch below is resolved. Small-to-medium
feature: slices live in this file.

Lineage this amends, not replaces:
`docs/design/2026-08-14-journal-backlog-split-design.md` (Phase 6 split:
journal = format, backlog = follow-up workflow; drain explicitly
shelved). Pack 2.3.0 already retired `/backlog note` in favor of
`notepad`. This spec finishes that narrowing and unshelves **one**
drain: Issues / Feedback → Backlog tasks.

## Problem

`backlog` is supposed to be the follow-up **lifecycle** over three
trackers (Backlog, Issues, Feedback). In the field it is a grab-bag of
kinds. It mints `bugs/` records, escalates through `tickets/` records,
and its sweep still calls `notepad` to persist facts. Meanwhile the
one drain the trackers actually need — promoting Issues and Feedback
into things to build — is written out of scope ("it captures; it never
drains"). INV-11 (every capture surface has a drain) is therefore
unmet by the skill that owns those surfaces.

The extra kinds are the wrong owner's work:

- A reproducible defect with a cold-standing repro is capture-for-
  diagnosis, not a tracker line. `debugger` already investigates and
  already **refuses** to mint `bugs/` (`SKILL.md:38`); `/backlog bug`
  is the dispatch writer. `issue.md` step 3 is a second path on
  "substantial analysis." Auditor drains defects through
  `/backlog bug`.
- Durable facts are `notepad`'s store. `/backlog note` is gone; the
  leftover seam is `debrief` / `issue` invoking notepad write-only.
- `ticket` is a second dated-record type for "ask the human." It
  forces every consumer (debugger's ticket-owned refuse, seed
  ROUTING step 6, migrate's tickets row) to know a concept we are
  not ready to keep.

The result: backlog juggles four stores (`trackers`, `bugs`,
`tickets`, plus a notepad call) and still cannot empty Issues or
Feedback.

## Goal

`backlog` is a **tracker skill**. It files, sweeps, grooms, and
promotes among Backlog / Issues / Feedback. It mints no `bugs/`,
no `tickets/`, and no `notes/`. A reproducible defect is filed by
`debugger`. A fact is written by `notepad`. "Needs the human" is
not a doctype — a leftover ask is an Issue line. Issues and
Feedback have a judgment drain onto Backlog. Every leftover that
must survive a reset lands on one of the three trackers.

## Approach

Narrow backlog to the three trackers and add one verb. Rehome the
`bugs/` writer onto debugger as a **file** verb (capture, not
diagnosis). Delete tickets as a concept for now. Stop every
backlog→notepad call. Retarget the consumers that name
`/backlog bug` or `ticket`. Do not delete the `/backlog bug`
writer until the new writer and its routing exist.

**Why this cut, not a bigger one.** The original conversation also
sketched `next` / `done` (pick a task, mark it done). Curate already
flips lines that finished without ceremony; performing the work is
not backlog's job. Pick-and-close is a later feature. This spec
does not add it.

**Alternatives rejected** (settled 2026-08-18):

- **Keep `/backlog bug` and only add `promote`.** Leaves the kind-
  juggling that prompted the rescope. Ownership follows the minting
  verb (`2026-08-14-journal-backlog-split-design.md` addendum).
- **Fold uninvestigated defects into `reports/`.** A filed-but-
  undiagnosed bug has no root cause. `reports/` is the investigation
  artifact. Two moments, two doctypes.
- **File a crash as an Issue and wait for debugger.** The repro
  (full trace, exact steps) dies in a one-sentence tracker line.
  `bugs/` exists for that payload. A leftover crash becomes a
  Backlog line `file repro: …` until the host's bug-filing lane
  writes the record.
- **Let debugger write Backlog lines when filing.** Scheduling is
  tracker work. Today `bug.md` and seed `bug.md` step 1 file-and-
  link in one step. After S4 the split is a **change**: debugger
  files the record and stops; a later `/backlog task` may link
  `→ bugs/<file>.md`.
- **Give debrief a debugger/notepad call** so the sweep still
  "routes every byproduct." That re-crosses sibling seams. Debrief
  routes follow-ups onto the three trackers, including leftover
  lines that *name* an unfiled repro, fact, or human ask. It does
  not invoke debugger or notepad.
- **Replace tickets with Issues used as asks.** Issues are project
  problems, not a standing ask queue with Ask/Context/Resolution.
  A leftover `needs human: …` Issue line is a debrief remainder,
  not that queue under another name.
- **`<agent-workflows>` as a fourth front-door home.** Sibling
  `feat` owns the three-home standard (`agent-records` /
  `agent-templates` / `agent-doctrine`). Station playbooks are
  doctrine. Typed edges already declare composition. A lock-in
  workflows home is earned at a second consumer (INV-13). Not this
  feature, not this stream.
- **Change journal's eight store names.** Format authority is not
  this feature. `tickets/` and `bugs/` remain legal store names.
  Writers stop minting `tickets/`; `bugs/` gains a new writer.
  Incumbent records stay.

## Mechanism

### Backlog surface after

| Invocation | Does |
|---|---|
| `/backlog task` | Append a Backlog line |
| `/backlog issue` | Append an Issues line |
| `/backlog feedback` | Append a Feedback line |
| `/backlog debrief` | Sweep follow-ups onto those three trackers; one commit |
| `/backlog curate` | Hygiene only (dedupe, sharpen, re-rank, flip finished) |
| `/backlog promote` | Judgment drain: Issues / Feedback → Backlog tasks |

Deleted by the last slice (S4), not by S1: `verbs/bug.md`,
`templates/bugs.md`. Deleted in S1: `verbs/ticket.md`,
`templates/tickets.md`.

`record-mint.sh` remains the one minter. After S1 it still bundles
`trackers.md` and `bugs.md`; minting `tickets` from this package is
a hard error. After S4 it bundles `trackers.md` only; minting
`bugs` is then a hard error too. Retarget
`scripts/tests/record-mint-test.sh` in two steps: the records-mode
`tickets` arm (L93) → `trackers` in S1; the file-mode `bugs` arm
(L51) → `trackers` in S4. Keep the `gizmos` missing-template refuse.

**Description** after S1 still routes the live bug verb (dispatch
row + "file a bug" / "this is broken — repro" triggers stay until
S4). It does not name `ticket`, `debugger`, or `notepad`. After S4
the description is tracker-lifecycle only. Retired bug / ticket
verbs are **refuses in un-backticked prose** ("bug and ticket are
not verbs here — not this skill") — not a backticked
`/backlog bug` token, and not "no recognized verb → classify as
task/issue/feedback."

**Kind-juggling prose** in `task.md` / `issue.md` is deleted. A
reproducible defect is not classified here. A durable fact is not
classified here. An item that needs the human is not classified
here. `issue.md` step 3 today also mints a `bugs/` record or calls
notepad write-only on "substantial analysis" — that mint path is
deleted with the kind-juggling; substantial analysis stays one
sentence or is split into two lines.

**`## Project templates`** becomes `trackers.md` only (after S4;
S1 drops `tickets.md` and keeps `bugs.md` until S4).

**`## Edges`** (delimited so lint check 8 parses), after S1:

```
<!-- edges:backlog -->
- produces: record — tracker records and tracker lines; bugs/
  while `verbs/bug.md` still exists
- handoff: record — promote drains Issues/Feedback onto Backlog
- consumes: record — debrief, curate, and promote read existing
  tracker lines
<!-- /edges:backlog -->
```

Drop `tickets/` from `produces` and drop
`handoff: — (none; it captures, it never drains)`. After S4 drop
`bugs/` from `produces` too.

### `promote`

New verb, not an arm of `curate`. Curate stays hygiene; promote is
the judgment INV-11 asked for.

1. Resolve both homes (existing SKILL.md discipline).
2. Load the live Issues and Feedback trackers **if they already
   exist**. Do not find-or-create a tracker in order to walk it.
   Default: every live `- [ ]` line on both existing trackers. A
   human-named subset is allowed ("promote that feedback line").
   If both trackers are absent, or every candidate is Leave →
   **no-op**: do not create empty trackers, do not stamp, do not
   commit.
3. For each candidate, **judge** — not mechanical promotion:
   - **Promote** iff the line is now one cold-actionable thing to
     **build**. Find-or-create the Backlog tracker, append one
     newest-last line, stamp Backlog. The new line is one concrete
     sentence. If the source carried `→ <store>/<file>.md`, copy
     that link onto the new line; otherwise the sentence names
     origin (`promoted from Issues: …` / `promoted from Feedback:
     …`). Rewrite the source line to the contract's **completed**
     form with today's date. No new dated record is minted.
   - **Drop** iff it is no longer a live concern (done elsewhere,
     wontfix, noise). Rewrite the source line to the completed
     form (same contract rewrite). Do not mint a task. The sentence
     keeps enough of the original to say what was dropped.
   - **Leave** iff it remains a valid issue or feedback that is
     not yet a task, **or** the line is a leftover remainder
     (`needs human:`, `file repro:`, `write down:`). Those prefixes
     are prose convention, not a journal format change. No edit.
4. `record-mint.sh stamp` every tracker that was actually edited.
5. If anything was edited: one scoped commit
   (`Backlog: promote`). `debrief` does **not** invoke `promote`.
   There is no write-only arm.

A Backlog task is a tracker line, not a file, so there is no
`→ trackers/…` link back from the completed issue. Origin is the
completed source line plus the copied record link or the
`promoted from …` clause. Do not invent a second link form.

Promote-drop always uses the journal completed form
(`- [x] … — <today>`). Curate may still strike or delete a line
that no longer applies — that is hygiene, not this drain. Residual
form depends on which verb ran; do not unify them.

### `debrief` after

Gather as today (status, merge-base diff, conversation). Route
write-only to **`task` / `issue` / `feedback` only**. The optional
`reports/` debrief page (tagged `debrief`, when the story warrants
narrative) **stays**.

- A leftover that is a thing to build → task.
- A leftover that is a project concern / limitation → issue.
- A leftover that is a dev-experience observation → feedback.
- A leftover that needs the human → one Issue line
  `needs human: <the ask, one sentence>`. Do not mint a `tickets/`
  record.
- A leftover that looks like a fileable repro → one Backlog line
  `file repro: <symptom, one sentence>`. Do not mint `bugs/`. Do
  not call debugger. The cold record is the host's bug-filing
  lane later. When that record exists, rewrite this line to the
  completed form and add `→ bugs/<file>.md` (or let
  `/journal done` on the record do the linked-line rewrite — that
  path already exists).
- A leftover durable fact → one Backlog line
  `write down: <the fact, one sentence>`. Do not call notepad.
  When the fact is written, complete the line.

Close completed records / tracker lines as today. A `needs human:`
line completes when the human answers (completed form, no
Resolution section). One scoped commit. The sweep list names
every leftover line filed. Speech alone is not a drain.

### `curate` after

Delete step 3's "graduate to a ticket." An item that needs the
human becomes an Issue line `needs human: …` (same remainder as
debrief), not a dated record. Detail that outgrew one sentence is
sharpened or split into two lines — never minted as a dated record
from this verb. Curate may still strike or delete a line that no
longer applies (hygiene); that is distinct from promote-drop's
completed form.

### Debugger `file`

Debugger becomes a thin router. **Utterance rule:** a prompt that
matches file / repro / "capture the repro" / "this is broken —
capture" (including the invocation `/debugger file`) reads
`verbs/file.md` and does **not** enter Phases 1–4. Bare
`/debugger` and symptom / root-cause / "why is this failing"
language is today's Phases 1–4. Do not ask which; do not
investigate a file trigger. `SKILL.md` cites `verbs/file.md`
(lint check 11). `description:` gains the file/repro triggers
**without** naming backlog. The Iron Rule is scoped to the
investigate path only.

`file` is capture, not diagnosis:

1. Resolve both homes (debugger inlines the same resolvers it
   already uses for `reports/`).
2. Mint `bugs/` via a new in-package `scripts/bug-mint.sh`
   (notepad's `note-mint.sh` shape: facts only; opportunistic
   `records.sh new --template <resolved>`; else file-mode).
   Template is a **copy** of today's `backlog/templates/bugs.md`
   into `debugger/templates/bugs.md` (Repro / Expected vs actual /
   Notes). Backlog keeps its copy until S4. Fill so the record
   stands cold.
3. Do **not** append a tracker line.
4. Do **not** enter Phases 1–4.
5. **Always commit itself.** Debugger today has no capture-commit
   policy — this spec adds one, copied from notepad: the same
   commit-tree probe, plus `scripts/scoped-commit.sh` (copy, do not
   call another skill's). Standalone message
   `Debugger: file — <slug>` over exactly the minted path. There
   is **no** write-only / drain-caller arm. Leaves do not name
   this verb.

Delete the **ticket-owned refuse** (`SKILL.md:15–20`, Done-when
bullet). Tickets are not a concept. Debugger still **never
enumerates** `bugs/` looking for work (INV-8). A filed record is
welcome input when routed; it is not a queue.

`## Project templates` on debugger becomes `reports.md`,
`investigation.md`, `bugs.md`. Edges:

```
<!-- edges:debugger -->
- produces: report, bug — investigation record; filed repro record
- handoff: — (none; the operator owns the fix)
- consumes: bug — investigation accepts a routed file
<!-- /edges:debugger -->
```

`Do not mint bugs/` is deleted.

Investigation (`reports/`, Phases 1–4, mutation policy) is
unchanged except the Iron Rule's scope note above.

**Close path for a `bugs/` record** (after `bug.md` is gone):
`/journal done` on the record. That verb already rewrites every
tracker line that carried `→ bugs/<file>.md` to the completed
form (`skills/journal/verbs/done.md`). `file` does not close. A
`file repro:` line with no record link yet is completed by the
operator (or debrief) when the record exists — see debrief.

### Journal

No format change. The eight store names stay. Journal's scope-
boundary sentence that describes backlog as "escalating to the
human" is rewritten so it does not claim a ticket verb. Journal
does not take `tickets.md`; there is no minting verb.

Incumbent `tickets/` records: close with `/journal done` only.
There is no Ask / Context / Resolution procedure after S1. Journal
`curate` / `records.sh check` may still list `open tickets: N` —
that is format, not a workflow. Nobody is required to surface an
open ticket as an escalation; a leftover ask that must survive
reset is the debrief/curate `needs human:` Issue line.

### Consumers (same feature — otherwise the hole moves)

Leaves must not grow a sibling name in `description:` **or** in
the body. They say **host's bug-filing lane** and stop. Only the
pack seed (`ROUTING.md`, `build/workflows/bug.md`) names
`/debugger file`, and only after that verb exists (S4).

| Site | Change |
|---|---|
| `auditor` (`SKILL.md`, `templates/reports.md`, `BOOTSTRAP.md`) | Defect drain is the host's bug-filing lane. Stop writing `/backlog bug`. Do not mint `bugs/` from auditor (unchanged). Do not name `/debugger file`. If no lane exists, stay in the report. |
| `workstream` (`SKILL.md` Scope, `verbs/create.md` GUARD, `flow.md` eventful-ship line) | Mid-loop capture of a **defect** is the host's bug-filing lane, not `/backlog bug`. Feature work stays `/backlog task`. Eventful-ship "a `bug` capture" becomes a Backlog `file repro:` remainder or the host's bug-filing lane. |
| `clankshop/PACK.md` | Roster blurb: tracker lifecycle, no tickets. No `version:` bump (member set unchanged). |
| `clankshop/seed/core/ROUTING.md` | Delete step 6 (ticket escalation). A call only the human can make is asked in the conversation when a human is present; if it must survive reset, debrief/curate files `needs human:`. The bug-lane row already points at `/debugger`. S4 **adds** `file` as the filing step. |
| `clankshop/seed/core/INVARIANTS.md` | INV-4: "ticket updates" → "record captures, closures". |
| `clankshop/seed/build/workflows/bug.md` | S4: step 1 files via `/debugger file`. **Change** (not current behavior): do not file-and-link in one step. Linking a tracker entry becomes a later `/backlog task` when the defect needs scheduling (INV-8). |
| `clankshop/verbs/migrate.md` | The `open asks awaiting a human → tickets` row becomes **leave-in-place**. Do not map asks onto Issues (that is the rename this spec refused). |
| `skills/skill-builder/scripts/skills-lint.sh` | S4: reword the BL-1 rationale comment (the `/backlog bug` example, ~L382) so it cites `/backlog task` and `/backlog debrief` only. |
| `skills/journal/SKILL.md` | Scope-boundary sentence only (no ticket verb). Store-name list unchanged. |
| library `README.md` | Inventory row: drop "tickets". |

`feat` / `app` streams are not this change. Do not edit their
trees.

### Independence

- Backlog's `description:` names no sibling. Until S4 it still
  names the live bug verb; after S4 it names no retired verb.
- Backlog procedures do not invoke debugger or notepad.
- Debugger procedures do not write tracker lines and do not
  invoke backlog.
- Leaves say "host's bug-filing lane." The pack seed / ROUTING
  walk is the composer that names `/debugger file`.

### Out of scope

- `/backlog next` / `/backlog done` / performing the work.
- `<agent-workflows>` or any new front-door variable.
- Renaming or deleting journal stores.
- Bulk-migrating or bulk-closing incumbent `tickets/` / `bugs/`
  records (close path is `/journal done` when one is actually
  done).
- Changing debugger's four-phase investigation (except scoping
  the Iron Rule and adding the `file` fork).
- Handbook extraction / `<agent-doctrine>` (sibling `feat`).

## Verification

**Mechanical**

- `cd <worktree>/skills/backlog/scripts/tests && ./run.sh` — green
  after S1 (tickets arm retargeted) and after S4 (bugs arm
  retargeted).
- New `skills/debugger/scripts/tests/` for `bug-mint.sh`: file-mode
  mint, lock-in copy to `<agent-templates>/debugger/bugs.md`, no
  flat `templates/bugs.md`, collision suffix, missing-template
  refuse, file-mode stamp does not write `history.tsv`. Prove the
  new assertions by breaking them once (DOCTRINE: prove-by-breaking).
  Assert the script never opens a `trackers/` path (red-proof:
  plant a tracker write, demand red).
- `skills/skill-builder/scripts/skills-lint.sh` clean for
  `backlog` and `debugger`.

**Absence (population = this library's `skills/` trees, not host
clones)**

After S4, these have **zero** hits under `skills/`:

- `/backlog bug`
- `/backlog ticket`
- `verbs/ticket.md` / `backlog/verbs/bug.md`
- `backlog/templates/bugs.md` / `backlog/templates/tickets.md`

Allowed remnants: journal's store-name list; historical
`docs/design/` prose; this spec. Lint comments are **not** allowed
remnants — S4 rewrites the one live hit.

Red-proof the sweep: plant `/backlog bug` in a temp file under
`skills/`, demand the grep fails, remove the plant.

After S3 (before S4), leaves must contain **zero** `/debugger file`
hits. Backlog debrief/curate must also contain **zero** of that
string (they say "host's bug-filing lane"). Seed may gain that
string only in S4.

**Procedure**

- `promote`: three arms on a fixture tracker (promote copies a
  record link and completes the source; drop completes without a
  new Backlog line; leave is a no-op that creates no tracker).
  Agent-walked, not a unit test of judgment.
- `debrief`: a sweep whose leftovers include a human ask, a stack
  trace, and a project fact files three tracker lines (`needs
  human:`, `file repro:`, `write down:`) and mints no `tickets/`,
  `bugs/`, or `notes/` records.
- `file`: minting a bug does not create or edit a tracker file;
  the mint is followed by a scoped commit (or a commit-tree STOP).

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | Add `promote`; delete ticket verb + `tickets.md`; leftover tracker lines; rewrite debrief/curate/task/issue/SKILL.md (edges, kind-juggling including the `issue.md` bugs/notepad mint). **Keep** `verbs/bug.md`, `templates/bugs.md`, and the bug dispatch row + description triggers. Retarget the **tickets** mint-test arm. | `skills/backlog/scripts/tests/run.sh`; lint `backlog` | `skills/backlog/**` |
| S2 | Debugger thin router + `file`: copy `bugs.md`, add `bug-mint.sh` + `scoped-commit.sh` + tests, description + utterance rule, drop ticket refuse, `consumes: bug`. Backlog still files bugs. | new debugger mint tests; lint `debugger` | `skills/debugger/**` |
| S3 | Consumer retargets to the generic **host's bug-filing lane**; delete ROUTING step 6; migrate asks → leave-in-place; INV-4 wording; journal scope sentence; PACK.md; README; `flow.md` eventful-ship. Leaves do **not** name `/debugger file`. | zero `/backlog ticket` under `skills/`; zero `/debugger file` in leaves | `skills/auditor/**`, `skills/workstream/SKILL.md`, `skills/workstream/verbs/create.md`, `skills/workstream/flow.md`, `skills/clankshop/PACK.md`, `skills/clankshop/seed/core/ROUTING.md`, `skills/clankshop/seed/core/INVARIANTS.md`, `skills/clankshop/verbs/migrate.md`, `skills/journal/SKILL.md` (scope sentence only), `README.md` |
| S4 | Delete `verbs/bug.md` + `templates/bugs.md`; drop the bug dispatch row + description triggers (un-backticked refuse); retarget the **bugs** mint-test arm; seed `bug.md` step 1 names `/debugger file`; reword the `skills-lint.sh` BL-1 comment; absence grep + red-proof. | Verification absence grep; lint `backlog` | `skills/backlog/**`, `skills/clankshop/seed/build/workflows/bug.md`, `skills/clankshop/seed/core/ROUTING.md` (file step only), `skills/skill-builder/scripts/skills-lint.sh` |

Land order is S1 → S2 → S3 → S4. S1 does not delete the bug
writer or its description trigger. S2 stands the new writer up
beside the old one. S3 retargets leaves to the generic lane
(both writers exist). S4 removes the old writer and lets the
seed name the new one. `promote` ships in S1 without opening
a filing hole.

## Review history

### 2026-08-18 — approve-with-changes

Delta pass (soundness, groundedness, skeptic) on the fold. Prior
must-fixes 1–10 are closed. Ground-check: `checked=16`, one
unresolved path (`skills/debugger/scripts/tests/`) is still a
proposed directory. No missed `/backlog bug` / `/backlog ticket`
consumers under `skills/`.

**Must-fix** (local; does not reopen promote, ticket-store aftermath,
or the S4 delete)

1. **Mechanism → Debugger `file` (utterance).** Description gains
   file/repro triggers but default `/debugger` is still Phases 1–4.
   Two legal routers. Fix: utterance matching file/repro/capture →
   `verbs/file.md`; bare `/debugger` and symptom language →
   Phases 1–4.

2. **Mechanism L138–141 vs Verification absence.** A backticked
   refuse of `/backlog bug` fails the zero-hit grep. Fix: refuse in
   un-backticked prose, or list a backticked refuse as an allowed
   remnant.

3. **Consumers → seed `bug.md`.** “Linking a tracker entry **stays**
   a later `/backlog task`” is invented. Live `bug.md` and seed
   step 1 file-and-link in one step. Say the split is a change.

4. **Mechanism → Debugger `file` L270–271.** “Auditor invokes
   `/debugger file`” contradicts Independence / S3 (leaves never
   name that verb). Delete the sentence; always-commit already
   removes the scoop problem.

5. **Mechanism → `debrief` L224.** “The cold record is
   `/debugger file` later” is a sibling verb in a leaf. Name
   “host’s bug-filing lane” only. Only S4 seed may contain the
   string `/debugger file`.

6. **Slices land order.** S1 strips the bug trigger from backlog’s
   description and S3 strips `/backlog bug` from leaves before S2
   exists. Keep backlog’s bug description trigger until S4, **or**
   land S2 before S3.

**Nice-to-have**

- Promote has no arm for leftover prefixes; close path does not
  rewrite a `file repro:` line after `/debugger file`. Either treat
  prefixes as prose (promote Leaves them; complete the line when
  the file/note/ask is done) or drop reserved leads for ordinary
  sentences.
- Spec the `<!-- edges:… -->` delimiters so lint check 8 parses.
- Problem still says `/backlog bug` is the only writer; `issue.md`
  is a second path (already deleted in S1 kind-juggling).
- `journal done` already rewrites linked tracker lines — cite it,
  don’t invent a second rewrite.
- Lint comment pin `skills-lint.sh:377` has drifted (~382).

`needs human:` as a debrief/curate remainder is the approved
durable-ask path, not a ticket doctype. What drains that line
when the human answers (completed form) is the prefix nice-to-have
above, not a reopen of the drop.

Dispositions (this fold):
1. resolved — utterance rule: file/repro → `verbs/file.md`; bare
   `/debugger` and symptom language → Phases 1–4.
2. resolved — retired-verb refuse is un-backticked prose.
3. resolved — file-and-link split is named as a change.
4. resolved — auditor-invoke sentence deleted.
5. resolved — debrief says "host's bug-filing lane."
6. resolved — land order S1 → S2 → S3 → S4; bug description
   trigger stays until S4.

Nice-to-have: leftover prefixes are prose (promote Leaves them;
complete when the file/note/ask is done); edge delimiters
specified; Problem names the `issue.md` second path; close path
cites `journal done`; lint comment pin un-pinned to ~L382.

### 2026-08-18 — needs-rework

Three independent lenses (soundness, groundedness, skeptic). Ground-check:
`checked=13`, one unresolved path (`skills/debugger/scripts/tests/`) is a
proposed directory. Citations of live HEAD were accurate except where
noted below.

**Must-fix**

1. **Mechanism → Debugger `file` (write policy).** "Commit per debugger's
   existing write policy" has no referent. Debugger has no commit-tree
   probe, no `scoped-commit.sh`, no write-only sweep contract (only Phase
   1–3 mutation policy). Invent the policy here: add notepad-shaped
   scoped commit + write-only-when-caller-is-sweep; say whether auditor
   scoops `path=`/`rel=` into its pass commit or `file` always commits
   itself.
   Disposition: resolved — `file` always commits itself; no write-only arm.

2. **Mechanism → Debugger `file` (dispatch).** Debugger is a single
   four-phase `SKILL.md` with no verb table. Adding `verbs/file.md`
   without a router is lint-red (orphan verb) and will not win "file a
   bug" routing once backlog's description drops that trigger. Specify:
   default `/debugger` = Phases 1–4; `/debugger file` → `verbs/file.md`;
   `description:` gains file/repro triggers without naming backlog; Iron
   Rule scoped to the investigate path.
   Disposition: resolved — thin router, description triggers, Iron Rule scoped.

3. **Mechanism → Backlog mint tests.** "Retarget off `bugs` onto
   `trackers`" understates `record-mint-test.sh`: file-mode mints `bugs`
   (L51) **and** records-mode mints `tickets` (L93). Both arms must
   retarget or S1 is red after `tickets.md` is deleted.
   Disposition: resolved — S1 retargets the tickets arm; S4 retargets the bugs arm.

4. **Verification → Absence.** Zero `/backlog bug` hits under `skills/`
   fails on `skills/skill-builder/scripts/skills-lint.sh:377` (BL-1
   rationale comment). Add that file to S3 or list lint comments as
   allowed remnants. Prove the sweep by planting a hit once (red-proof).
   Disposition: resolved — S4 rewords the comment; absence grep is red-proofed.

5. **Mechanism → `promote` step 3.** Three rewrites, no rule for which
   arm. Add one-line criteria (promote = cold-actionable thing to build;
   drop = no longer a live concern; leave = still valid and not yet a
   task). No-op promote must not find-or-create empty trackers.
   Disposition: resolved — criteria + no-op written.

6. **Mechanism → `debrief` leftovers vs INV-11.** The spec cites INV-11
   to justify `promote`, then lets human-asks / fileable repros / facts
   die as spoken sweep-report lines. Debrief is the route-before-loss
   sweep; the next session's truth is disk. Speech is not a drain.
   Persist leftovers on disk with a named follow-up (tracker line naming
   the leftover, or a mandatory `reports/` debrief page that curate/
   load consumes). Do not restore sibling verb calls unless a typed
   edge is the chosen composition.
   Disposition: resolved — leftovers are `needs human:` / `file repro:` /
   `write down:` tracker lines; optional `reports/` page stays.

7. **Approach → ticket drop consequences.** Dropping the *concept* was
   settled; the spec does not say what happens to (a) incumbent
   `tickets/` resolve + writeback after `ticket.md` is deleted, (b)
   migrate's "open asks awaiting a human" row if the destination is
   neither tickets nor a rename to Issues, (c) an unattended /
   post-reset ask. Name those three. Do not leave a living store with
   no owner and no drain.
   Disposition: resolved — `/journal done` only; migrate leave-in-place;
   unattended ask is the `needs human:` Issue line.

8. **Slices → S1 independently valuable.** Contradicts "Consumers (same
   feature — otherwise the hole moves)." After S1 alone, `/backlog bug`
   is gone, debugger's description still does not file, and auditor /
   workstream still point at the deleted verb. Land order: retarget
   leaves to the generic "host's bug-filing lane" first; stand up
   `/debugger file` + its description trigger; then delete
   `verbs/bug.md`. `promote` can ship without deleting a writer.
   Disposition: resolved — land order S1 → S3 → S2 → S4; S1 keeps the
   bug writer; "independently valuable" dropped.

9. **Independence vs S3.** Leaves must stay on "host's bug-filing lane."
   Only seed / ROUTING / `bug.md` name `/debugger file`. Delete S3's
   "then names it" sentence.
   Disposition: resolved — leaves stay generic; seed names `file` in S4.

10. **Mechanism → edges / templates / debrief reports.** S1 must rewrite
    backlog `## Edges` (today: `produces: … bugs/, tickets/` and
    `handoff: — (none; it captures, it never drains)`) and
    `## Project templates` → `trackers.md` only (lint check 13). Say
    whether the optional `reports/` debrief page stays.
    Disposition: resolved — Edges rewritten; templates drop tickets in S1
    and bugs in S4; `reports/` debrief page stays.

**Nice-to-have**

- Seed INV-4 still says "ticket updates."
  Disposition: resolved — S3 rewrites INV-4.
- `workstream/flow.md` eventful-ship line still says "a `bug` capture."
  Disposition: resolved — S3 retargets `flow.md`.
- `promote` write-only arm has no caller once debrief does not invoke it.
  Disposition: resolved — write-only arm dropped.
- Promote-drop uses completed form; curate may delete — distinguish.
  Disposition: resolved — both forms named; not unified.
- Close path for new `bugs/` records after `bug.md` is deleted (`/journal
  done` + tracker writeback).
  Disposition: resolved — close path written under Debugger `file`.
- `issue.md` also mints `bugs/` on "substantial analysis" — call that
  path out in the kind-juggling delete so it cannot survive.
  Disposition: resolved — named in the kind-juggling delete.
- `produces: bug` will WARN as an unmatched type; pair `consumes: bug`
  on debugger's investigate path if a quiet gate is wanted.
  Disposition: resolved — `consumes: bug` on the investigate path.

Promote + tracker-only backlog hold. Debugger `file` holds if dispatch
and commit are written. Ticket-drop and speech-only debrief do not,
until their reset-surviving homes are named.
