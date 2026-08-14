---
name: clankshop
version: 2.0.0
description: "An agentic workshop for a code project: doctrine, records, and routing deployed as four stations (design/build/test/review), with helpers for planning, records, streams, audits, and debugging."
required: journal
optional: auditor, blueprint, debugger, delegate, checkpoint, mailbox, scheduler, workstream, bug, task
---

# clankshop — the workshop pack

The frontmatter above is the pack's **manifest** (spec format 1) — the machine surface
`install.sh` reads. Installing the face installs the members; `required:` names the workshop's
hard dependencies (the records layer), `optional:` the members installed by default but
removable without trace.

The v2 roster, by coupling tier (how much workshop a skill needs):

| tier | skill | is |
|---|---|---|
| system | `clankshop` | the seed (handbook + `context.sh`) + `setup` / `migrate` / `check` / persona summons |
| helper | `blueprint` | feature planning on any repo — ideation to implementation plan |
| helper | `journal` | **owns the records layer** — `records.sh`, templates, stores, the history ledger; required (setup delegates records standup to it) |
| helper | `workstream` | long-lived development streams — worktrees, queues, shipping |
| helper | `auditor` | code-quality audits; drains findings into the records when a workshop is present |
| helper | `debugger` | root-cause debugging anywhere; guided by the test station's diagnostics when present |
| utility | `checkpoint` | living session save-state: save/resume/done + compaction recovery |
| utility | `mailbox` | worktree-safe transport for delegated results |
| utility | `delegate` | sub-agent dispatch routing |
| utility | `scheduler` | cron/launchd wrapper for recurring agent runs |

**Transition note (v2 rollout):** the manifest lists members by their **current** directory
names so the pack stays installable at every phase of the v2 rebuild; the roster above uses
the v2 names. Landed: `backlog` → `journal` (the v2 records layer — stores + `records.sh` +
the history ledger); `feature` → `blueprint` (the six-verb planning spine); `scheduler` (new
port — the recurring-runs utility); `handoff` → `checkpoint` (the persistence utility — living
save-state, the Save/Resume/Lifecycle/Recovery disciplines, compaction recovery). All v2
renames have landed. The `bug`/`task` capture proxies remain optional members.

**One library skill is deliberately not a member:** `skill-builder`, the toolmaker steward for
the skills library itself — a maintainer's tool for whoever authors skills, not part of the
workshop this pack deploys.
