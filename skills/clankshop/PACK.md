---
name: clankshop
version: 2.4.0
description: "An agentic workshop for a code project: doctrine, records, and routing deployed as four stations (design/build/test/review), with helpers for planning, records, follow-ups, streams, audits, debugging, and reporting."
required: journal
optional: analyst, auditor, backlog, blueprint, contractor, debugger, delegate, checkpoint, mailbox, notepad, scheduler, workstream
---

# clankshop — the workshop pack

The frontmatter above is the pack's **manifest** (spec format 1) — the machine surface
`install.sh` reads. Installing the face installs the members; `required:` names the workshop's
hard dependencies (the records layer), `optional:` the members installed by default but
removable without trace.

**Versioning rule:** `version:` bumps when the **member set** changes — a skill added, removed,
renamed, or moved between `required:`/`optional:` (minor bump; a manifest spec-format change is
the major). Content-only edits to this document (roster blurbs, seam notes, the transition
note) do **not** bump. Consequence to know: `install.sh` stamps `pack_version` into the install
lock, so a content-only edit ships under the unchanged stamp — the stamp dates the *install*,
the manifest text is authoritative for what the pack currently says.

The v2 roster, by coupling tier (how much workshop a skill needs):

| tier | skill | is |
|---|---|---|
| system | `clankshop` | the seed (doctrine + `context.sh`) + `setup` / `migrate` / `check` / persona summons |
| helper | `blueprint` | specification spine — ideation to argued spec; genesis (`new` / `deploy`) for a founding repo; never implementation plans |
| helper | `contractor` | one job: roadmap / plan / runbook / review / build |
| helper | `journal` | **the records format authority** — the record contract, `records.sh`, the history ledger; required (setup delegates tool-layer standup to it) |
| helper | `backlog` | the follow-up lifecycle — file, promote, debrief, and curate the three trackers |
| helper | `notepad` | project memory — write, find, update, supersede, and drop durable facts in `notes/` |
| helper | `workstream` | long-lived development streams — worktrees, queues, shipping |
| helper | `auditor` | code-quality audits; pass reports land in the agent-records home |
| helper | `debugger` | root-cause debugging anywhere; guided by the test station's diagnostics when present |
| helper | `analyst` | reports and briefings for the developer — the records layer read back as prose, from a customizable template catalog |
| utility | `checkpoint` | living session save-state: save/resume/done + compaction recovery |
| utility | `mailbox` | worktree-safe transport for delegated results |
| utility | `delegate` | sub-agent dispatch routing |
| utility | `scheduler` | cron/launchd wrapper for recurring agent runs |

**Seam — `checkpoint` / `workstream`:** one session's save-state has exactly one home, picked
by where the session lives. The single root session → `checkpoint`'s root `CHECKPOINT.md`; a
session driving a stream (worktree or in-place) → that stream's `WORKSTREAM.md` hand-off and
`/workstream save` — "save a checkpoint" spoken inside a stream means the stream's verb.
Checkpoint refuses the stream case mechanically; the canonical probe for its sites is the
`save-guard.sh` script bundled with checkpoint (workstream's verbs carry their own probe).

**Seam — `clankshop` / `journal`:** workshop `setup` / `migrate` delegates records
tool-layer standup to journal. Journal does not write the door or seed doctrine.

**Seam — `workstream` / `backlog`:** `workstream` publishes
`<agent-workspace>/hooks/workstream.md` from its own package
skeleton (`skills/workstream/templates/hooks.md`). `setup` step 5 / `migrate` copy that skeleton
if absent and fill empty `Feature completion` and `After eventful
ship` with `/backlog debrief`. `check` reports empty pack glue only
when that skeleton is installed; it does not write. Leaves do not
name each other.

**Seam — `delegate` / `mailbox`:** delegate decides whether and how to farm work.
Mailbox is transport only (slot mint / apply / consume). Whether to dispatch is
never mailbox's question.

**Seam — workstream build lane:** when the helpers are present, PLAN is the spec
spine, then the job lead only if sequencing is required; BUILD walks the plan.
`flow.md` points at those leaves; it does not restate their protocols.

**Transition note (v2 rollout):** the manifest lists members by their **current** directory
names so the pack stays installable at every phase of the v2 rebuild; the roster above uses
the v2 names. Landed: `backlog` → `journal` (the v2 records layer — stores + `records.sh` +
the history ledger); `feature` → `blueprint` (the specification spine); `scheduler` (new
port — the recurring-runs utility); `handoff` → `checkpoint` (the persistence utility — living
save-state, the Save/Resume/Lifecycle/Recovery disciplines, compaction recovery). All v2
renames have landed. The Phase 6 split then stood `backlog` up as the follow-up lifecycle
(the name re-minted — v1's `backlog` was the records instrument that became `journal`) and
**retired the v1 `bug`/`task` capture proxies** — capture routes through `/backlog` directly.
**2.2.0:** `blueprint`'s plan/roadmap verbs moved to `contractor`.
**2.3.0:** `notepad` — project memory; `/backlog note` retired.
**2.4.0:** `analyst` joins as a helper — the first member that reads the records layer back out
as developer-facing prose.

**One library skill is deliberately not a member:** `skill-builder`, the toolmaker steward for
the skills library itself — a maintainer's tool for whoever authors skills, not part of the
workshop this pack deploys.
