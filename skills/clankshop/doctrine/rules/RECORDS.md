# RECORDS — the record formats

<!-- spine-doc v1
kind: records
doctrine: clankshop
doctrine-version: 2
refs: .handbook/** .records/**
-->

The deployed reference for every record a contributor writes: the capture kinds, the typed-ID
namespace, the per-store wire formats, the done log, the ticket schema with its escalation layer,
and the report wire contract. This chapter is **complete as seeded** — formats are not
project-variable. It is the sole statement of the record schema: every other doc cites it, none
restates it.

## The five capture kinds

Capture is **uniform**: every byproduct lands in exactly one durable home by its **kind**, and the
cut between kinds is by **subject** — is this about the *project* being built, or the *dev
experience* of building it? Four kinds are project-subject; `feedback` is the single
dev-experience channel.

| kind | subject | nature | store |
|---|---|---|---|
| `note` | project | a durable fact / piece of knowledge | `.records/trackers/notes/<slug>.md` |
| `task` | project | an action to build / do | `.records/trackers/tasks.md` |
| `issue` | project | a problem / concern / limitation | `.records/trackers/issues.md` |
| `bug` | project | a reproducible code defect | `.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md` |
| `feedback` | dev-experience | any observation (skills / tooling / env / workflow) | `.records/trackers/feedback.md` |

The five kinds are the whole taxonomy — a host does not extend the set. "Needs a human" is never a
kind: it is a lifecycle layer (tickets, below) over exactly one of these five.

**The classifiers** — three boundaries carry real judgment:

- **`bug` vs `issue`** (both project problems): if you can write a repro, it's a `bug`; a concern
  *about* the project — a limitation, a risk, a gap without a single repro — is an `issue`.
- **`note` vs `feedback`** (the subject cut): a `note` records a durable fact about the *project*;
  `feedback` records an observation about the *dev experience* — the skills, tooling, and
  environment you work through. All dev-experience signal lands in `feedback`, never split.
- **`note` vs an INVARIANTS entry** (the bar): a note is **lower-bar** — it captures a durable
  fact worth remembering; `INVARIANTS.md` holds only load-bearing rules, a very high bar. Capture
  never promotes: landing a proven note as an INV entry is improvement-loop work, dispatched to
  the rules steward.

## Typed IDs — the namespace

One prefix per store:

| prefix | store | | prefix | store |
|---|---|---|---|---|
| `G-` | gotchas | | `T-` | tasks |
| `INV-` | invariants | | `I-` | issues |
| `POL-` | policy | | `B-` | bugs |
| — | workflows (path-addressed) | | `N-` | notes |
| `TK-` | tickets | | `F-` | feedback |

**Identity and allocation:** an ID is **immutable once published** — published means referenced
outside its own store (a commit message, the done log, a ticket `origin:`, a mirror footer).
Counter IDs are **allocated only on the trunk checkout** (a pathspec-scoped commit); a capture
made where the trunk is unreachable carries a slug placeholder, and curation stamps the real ID at
landing, before anything cites it. `TK-` IDs — globally unique by construction (date + slug) —
are the **only** ID legal in cross-installation citations; bare counter IDs never cross a
boundary, and no qualified-path citation form exists. Report IDs are filename-derived, not
counter-based (the report contract, below).

## Per-store wire formats

- `tasks.md`: `- T-041 — <task text> · added 2026-08-05`
- `issues.md`: `### I-017 — <title> (HIGH)` — entries grouped under `##` category headings; the
  model owns the impact ranking (HIGH | MEDIUM | LOW).
- `feedback.md`: `### F-003 · <short title> · 2026-08-05`
- `bugs/`, `notes/`: one file per item; the store-dir frontmatter carries `id:` (`id: B-009`)
  beside `type`, `status`, `updated`.
- tickets: file `.records/tickets/<YYYY-MM-DD>-<slug>.md`, ID derived by prefixing:
  `TK-<YYYY-MM-DD>-<slug>`. Never renamed. **Same-day slug collision** (including re-promotion of
  the same origin, which mints a new ticket by rule): suffix the slug deterministically
  (`-2`, `-3`, …) **before first publication** — file and derived ID together; never rename after.

**Alias encoding, per store** (migration preserves pre-existing identifiers verbatim):
`issues.md` / `feedback.md` — `(alias <old>)` appended to the heading line; `tasks.md` — appended
to the bullet; `bugs/` / `notes/` / tickets — a frontmatter `alias: <old>` key.

## The done log

Completing an entry appends **one line** to `.records/done/log.md`:

```
- 2026-08-05 · T-041 · <one-line gist> · commits: abc1234,def5678 · <outcome>
```

Outcome ∈ `done | dropped | wontfix | drained`. No-work-commit outcomes write `commits: -` (the
log mutation's own commit is never cited). Work commits reference the entry ID. An auditor
reconstructs any item via done-log → commits → diff. The completion moment is **landed on the
trunk**, not gate-green.

**The writer map** (stated once, here): a fast-path item finished → `backlog done`; a ticket
resolved or wontfixed → `backlog close` (writes the line itself); a dispatched improvement item
landed → the improvement loop confirms uptake, then `backlog done … --outcome drained`; a
workstream ship → `backlog done` per shipped item **and** its own full done-record file into
`.records/done/`; dropped at curation → `curate` logs the `dropped` outcome. Full done-record
files remain a feature-lane / workstream artifact only. **The logged ID for ticket completion:** a
**promoted** ticket's line carries the **origin entry's ID** (the work item; the gist cites the
`TK-`); a **direct** ticket's line carries the **`TK-` ID** (it has no origin by rule).

**Completion mutation, per store** (the writer's and checker's shared contract): flat aggregators
(`tasks.md`, `issues.md`, `feedback.md`) — the entry is **removed** from the live file on
completion; its done-log line is the archive. **Removal span:** a bullet entry is its one line; a
heading-led entry (`issues.md`, `feedback.md` — multi-line blocks) is the heading line through the
line before the **next heading of equal or higher rank** or EOF — live `###` entries sit under
`##` category headings, so a same-level-only rule would consume the following category header when
completing a category's last entry. Store-dir items (`bugs/`, `notes/`) — the file is retained;
completion advances its frontmatter (`status: resolved` + date), and curation may age it into the
store's `archive/`. A completion naming an ID that is absent, already completed, or paused
**refuses with a fact** — never a duplicate done-log line.

## Tickets — the escalation layer

A **ticket** is what a tracker entry *graduates into* when it needs the human. The default path
stays fast (tracker → agent → done log); nothing routes through tickets by default. A ticket is an
**escalation wrapper over a capture kind**, never a sixth kind: every ticket carries a required
`subject_kind`, plus — when promoted — the `origin:` entry ID it wraps. Two entry paths: a
**direct** ticket (capture-plus-escalation in one motion; `origin:` absent by rule) and a
**promoted** one (`/backlog promote <id>` graduates an existing entry, stamping `origin:` and
pausing it). Promotion and its pause marker are **trunk-side scoped commits**, always; the working
branch cites the `TK-` ID.

File `.records/tickets/<YYYY-MM-DD>-<slug>.md`; frontmatter:

```yaml
---
type: ticket
id: TK-2026-08-05-gate-choice   # derived from the filename; stated for grep-ability
status: open                    # open | answered | resolved
subject_kind: issue             # REQUIRED — one of the five capture kinds
origin: I-017                   # promoted tickets only; absent on direct tickets
blocking: [TK-…]                # optional; gates THIS ticket's resolution only; cycles = check fact
mirror:                         # present only while mirrored
  provider: github
  issue: 214
  pushed_hash: 5f2a…
  comments:
    - {id: 1888214301, updated: 2026-08-05T14:02Z, hash: 9c1b…}
updated: 2026-08-05
---
```

Body sections: `## Context`, `## Decision needed` (with the agent's recommended answer),
`## Comments` (append-only; imported comments keyed by remote ID), `## Resolution`. The `mirror:`
block is sync state for the remote **mirror** (the in-repo file is canonical; the mirror is a
stamped projection — its protocol lives with the sync verb, not here).

**Lifecycle** — the agent is the only state writer; the human converses and the agent interprets.
Rows marked *(p)* are promoted-only:

| event | actor | state | origin entry *(p)* | done log |
|---|---|---|---|---|
| create (direct) | agent | → open | n/a | — |
| promote | agent | → open | paused `[⇧ TK-…]` | — |
| human comment (sufficient) | human→agent | → answered | paused | — |
| human comment (partial) | human→agent | stays open | paused | — |
| agent follow-up | agent | answered → open | paused | — |
| resolve | agent | → resolved | un-paused; advances/closes | one line, outcome + commits |
| wontfix | agent per human | → resolved (wontfix) | un-paused; closes | one line, `commits: -` |
| demote | agent per human | → resolved (demoted) | un-paused, live | — |

**Pause encoding, declaration-led:** flat aggregators declare `paused: \[⇧ TK-[^]]+\]` matched
against the entry line; store-dir items declare frontmatter `paused: <TK-id>`. Consumers skip what
the declaration matches — a paused entry is excluded from fast-path pickup and every drain until
its ticket resolves. **Fail-safe:** a drain that cannot prove an item unpaused (missing or
malformed declaration) skips it and emits a fact — never drain what you cannot prove unpaused.

**The promotion bar** — promote exactly when resolving the item would require standing in for the
human (the HITL litmus). Four triggers:

| trigger | promote when… |
|---|---|
| **decision** | a preference / tradeoff / scope call only the human can make |
| **sign-off** | risky, irreversible, or outward-facing enough to want approval |
| **ambiguity** | unclear enough that guessing risks real waste |
| **access** | human-only provisioning — accounts, credentials, purchases |

Multi-session scope alone is NOT a trigger (big-but-clear work belongs to plans/roadmaps).
Tie-breaker favors motion: when uncertain, proceed if the action is cheaply reversible; promote
only if it isn't. Applied at two points — the router at dispatch, and any agent mid-work; humans
can force-promote or demote at will. Re-promotion after demotion mints a new ticket citing the
same `origin:`.

## Reports — the wire contract

Each writer into `.records/reports/` owns a distinct `type:`. Common frontmatter floor: `type`,
`id`, `date`, `source`, optional `processed:`. Disjoint filename namespaces —
`investigation-<date>-<slug>.md` (the diagnostic procedure), `doc-drift-<date>-<slug>.md` (the
docs-quality role), `reconcile-<date>-<slug>.md` (the design role) — so writers can never
collide. `bugs/` is a report store, never a work queue.

**Report IDs:** `id` = the filename stem verbatim (`investigation-2026-08-07-<slug>`) — derived by
construction like ticket IDs, unique via type-prefix + date + slug, never renamed; stated in
frontmatter for grep-ability. Uniqueness scope is the installation; report IDs never cross an
installation boundary. **Collision allocation:** date + slug is a derivation, not a guarantee —
if the target filename already exists in the namespace, the writer suffixes deterministically
(`-2`, `-3`, …) **before first publication**; a report file is never renamed after.

**Finding keys:** every multi-finding report type (doc-drift, investigation, reconcile, and the
audit FINDINGS store) gives each finding a **stable key** — a keyed finding heading
`#### <key> — <title>` where `<key>` matches `[a-z0-9-]+` and is unique within the report. A
consumer citing one finding writes `<source-identifier>#<finding-key>` (the report ID for
reports, the repo-relative path for the FINDINGS store); `processed:` is a **YAML list of finding
keys** (`processed: [gate-gap, stale-map]`), never a boolean — one writer grammar, so no two
writers can produce incompatible processing state.
