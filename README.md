# grimoire 🜃 — cmdruid's library of agent skills

An ever-expanding, version-controlled library of skills for coding agents (Claude Code, Codex,
and anything else that reads `SKILL.md` packages). Skills are the atoms — each one self-contained
and individually useful. **Packs** bind them into systems: a pack is a curated manifest, not a
directory, so one skill can serve many packs.

Agents *invoke* skills; a grimoire is the book they're invoked from.

## Status

Grimoire's hard-cut rebuild as a symlink package manager for agent skills is implemented. The
published contract is `.records/specs/2026-08-31-grimoire-symlink-package-manager.md`; the
implementation roadmap is
`.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md`. All seven roadmap phases are
complete: the source inventory, pure-pack format, declarative manifests and locks, same-snapshot
resolution, pure planning kernel, source custody and trust, transactional core, command-line adapter,
and Project/Global tree TUI are covered by the final integration gate. The accumulated Phase 2–7
implementation remains on `stream/app` pending its explicit landing decision.

### Use the tree interface

Run `grimoire` without a subcommand in an interactive terminal. It opens the nearest Project scope
when one exists and otherwise opens Global. Tree changes stay in memory until you apply the plan;
switching tabs doesn't merge Project and Global staging.

- Press Tab to switch scopes.
- Press Up/Down or `j`/`k` to move, and press Space to toggle a skill, pack, or optional member.
- Press Enter or `a` to apply the displayed plan. Destructive plans default to no.
- Press `c` or Escape to discard staged changes.
- On a source row, press `f` to fetch, `u` to update from the cached candidate, or `t` to open the
  separate trust-all confirmation. Update never fetches.
- Press `q` to quit and discard unapplied changes.

### Verify the implementation

Run the complete repository gate from the checkout root:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test
RUSTC_WRAPPER= cargo clippy --all-targets -- -D warnings
skills/skill-builder/scripts/skills-lint.sh
skills/skill-builder/scripts/tests/run.sh
scripts/tests/run.sh
```

The root-layout dogfood tests accept `GRIMOIRE_LIVE_ROOT=/absolute/path/to/checkout` when they need
to exercise a different checkout than the one Cargo is building.

## The skills

The root pure-bundle `clankshop` pack groups most of them into one toolkit:
**helpers** — `architect` (specification spine), `contractor` (job lead), `inspector` (critique and fold), `journal` (the records format authority —
the one required member), `backlog` (the follow-up lifecycle), `notepad` (project memory),
`workstream` (development streams), `auditor` (code-quality audits), `debugger` (root-cause
diagnostics), `analyst` (reports and briefings read back out of the records), `foreman`
(project operations, brownfield curation, and goal runbooks), `chiropractor` (documentation-spine
discoverability and confirmed route repair); **utilities** —
`checkpoint`, `mailbox`, `delegate`, and `scheduler`.
Five skills sit outside the pack on
purpose: `agent-council` (cross-vendor review panel), `skill-builder` (the **toolmaker** —
scaffold, audit, and calibrate authoring doctrine), `developer-writing`
(purpose-aware, human-facing developer prose with Google documentation mechanics), and
`code-humanizer` (keep durable source fit for human ownership), plus `skill-feedback` (private,
global capture and guided tuning of reusable-skill observations). See *The packs* below.

| skill | what it does |
|---|---|
| `agent-council` | three-family review panel: independent Claude, Grok, and Codex opinions on a skill package, clustered and ranked by agreement; standalone, outside every pack |
| `analyst` | reports and briefings for the developer: catch-ups, status, subsystem and health snapshots, guides — synthesized from the records layer and git, from a customizable template catalog |
| `architect` | specification spine: ideation → argued spec; genesis (`new` / `deploy`) mints a founding spec and a new repo; never plans or builds |
| `auditor` | code-quality audit framework: per-dimension rubric and metrics; findings stay in the audit report and promote through the host capture lane; standalone on any repo |
| `backlog` | first-class living TSV trackers: selectable first-time queues (five packaged defaults, including unresolved failures), bounded tracker@1 migration, lifecycle history, paging, filing, debriefing, and curation through `tracker@2`; optional `anchor` manages an explicit project debrief route |
| `checkpoint` | living session save-state: `save` / `resume` / `close` + compaction recovery — the persistence disciplines other skills borrow |
| `chiropractor` | audit documentation-spine discoverability and authority from `AGENTS.md`; trace task routes into docs, workflows, and helper scripts, then confirmation-gate minimal documentation-only repairs |
| `code-humanizer` | keep durable application, service, library, shipped CLI, and maintained test source fit for human ownership at write time; `mark` / `map` / `walk` on supported existing code; standalone, outside every pack |
| `contractor` | one job lead — roadmap, plan, runbook, build; never ships; never writes a spec |
| `debugger` | root-cause a bug/test-failure/build-break before proposing any fix — four-phase investigate discipline, human confirms before landing |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `developer-writing` | write and edit human-facing developer prose with purpose-aware structure, human editorial judgment, and Google documentation mechanics; agent-executed operational artifacts get wording-only help on explicit request; standalone, outside every pack |
| `journal` | the records format authority: discriminator, contract, adjacent `records.sh`, and history ledger; durable setup, narrow repair, dedicated-root migration, search, close, and substrate curation; optional `anchor` points project agents at the standalone `.records/README.md` guide |
| `inspector` | material review of documents and completed implementations, with a plain-text numbered/lettered close for confirmed implementation fixes and full re-review; revise folds supported document findings, refine simplifies specs and plans, and setup deploys Inspector-owned kind doctrine absent-only |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `notepad` | project memory: write, find, update, supersede, and drop durable facts in `notes/` — path-first, opportunistic `records.sh` |
| `scheduler` | recurring agent runs via launchd/cron: job specs + logs in a self-gitignoring `.scheduler/`, one short-lived headless tick per fire |
| `foreman` | curate project operations: inventory and run publisher-owned procedures, capture or ingest brownfield know-how, verify and compose operations, and compile immutable goal runbooks |
| `skill-feedback` | capture concrete reusable-skill observations into a private global TSV and guide later bounded review; standalone, outside every pack |
| `skill-builder` | the toolmaker: scaffold (`new`), audit/lint (`check`), and calibrate the doctrine for building skills — bundles the portable authoring doctrine + gate |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

Historical records that still explain the repository and skills library live under `docs/design/`.
The published product contract above is the sole authority for Grimoire package-manager behavior.

### Storage convention: packages and skill-owned data

A project has four distinct fixed surfaces. **`.agents/skills/`** contains project-local installed
skill packages and is never mutable skill data. **`.agents/skilldata/`**
holds skill-owned working files beneath `<skill>/<kind>/`; owners are open and the kinds are
`doctrine`, `drafts`, `hooks`, `operations`, `scripts`, and `templates`. Operations are flat
Markdown under the publishing owner's namespace and remain directly usable without a curator.
**`.records`** holds work products:
dated, typed records (`YYYY-MM-DD-<slug>.md` carrying front-matter that declares a `doctype`)
in whatever directories their writers mint, plus the `history.tsv` closure ledger. Journal's
staged engine lives at `.records/records.sh`, beside the introductory
`.records/README.md`; the format is `journal`'s
(templates arrive with the skills that mint them;
`journal` ships the commons).
**`.trackers`** holds public `tracker@2` queue TSVs under `tables/`, the shared
`history.tsv` lifecycle ledger, and adjacent canonical provider `.trackers/trackers.sh`. Backlog owns that
layer; consumer skills invoke the installed provider directly.
These canonical homes are constants, not front-door configuration. Each durable-home skill owns
its files. Backlog's first initialization selects a nonempty subset of
`tasks,issues,failures,feedback,routines` and defaults to all five; initialized projects preserve
their incumbent queue population and prompt prose. Unresolved test/build/tool sightings belong in
`failures`, while qualitative project-development experience belongs in `feedback`.

Projects can explicitly invoke `/journal anchor` for Journal's short guide pointer or
`/backlog anchor` for Backlog's managed project debrief route. Backlog's first attended setup may
offer that route as a separate, default-off choice; `setup --debrief` opts in explicitly, while
unattended setup without the flag, repair, migration, and pack installation remain front-door
neutral. The local READMEs and adjacent providers support ordinary record and tracker work without
the source skills, while maintenance and judgment still belong to those skills. The pack installs
skills but writes none of these project surfaces.

User-global installed packages remain under **`~/.agents/skills/`**. A skill with a separately
justified cross-project data contract may use its own child beneath
**`~/.agents/skilldata/<skill>/...`**; global data is opt-in, owner-defined, and never a transparent
fallback or executable project authority.

Session checkpoints stay **gitignored scratch** (one root `CHECKPOINT.md`, steward `checkpoint`) —
not a `.records/` store.

Foreman indexes those publisher-owned operations without copying them, learns accepted operations
and doctrine from attended debriefs, and compiles verified closures into immutable
`.records/goals/` runbooks. Mutable pursuit state stays with the one root checkpoint or the
active workstream, never with Foreman.
For isolated pursuit, a root coordinator can opt into a lean bridge: prove the committed goal
closure, seed a Workstream, prime its one queue unit, and resume Foreman from inside it. The bridge
does not alter ordinary Workstream creation or add callbacks.

## The packs

A pack is a pure `grimoire/pack@1` `PACK.md` manifest: distribution metadata plus required and
optional skill-name sequences. Source repositories need no repository manifest, and a pack never
acts as a skill. See the published Grimoire product contract above.

- **`clankshop`** (`PACK.md`) — the skills above (minus `agent-council`,
  `code-humanizer`, `developer-writing`, and `skill-builder`) as a pure bundle. The manifest body is
  the seam map; there is no `clankshop` skill or project assembler.

## Repo layout

Beyond the skills, this repo carries the package manager and its product records:

- **`crates/`** — a Cargo workspace (build from the repo root). `grimoire-pack` owns canonical
  source inventory, `grimoire-core` owns declarative state, resolution, and the pure planner, and
  `skill-grimoire` provides the command-line and staged tree adapters. Crates never read `skills/`
  at build time — content appears only as test fixtures.
- **`.records/specs/`** — published product contracts, including the canonical pack and inventory
  format.
- **`docs/design/`** — retained historical records about repository and skills-library evolution;
  package-manager behavior comes from the published contract, not these records.

## Authoring conventions

- **Self-contained + location-agnostic.** A skill references its own bundled resources
  (`scripts/`, `templates/`, `docs/`, `verbs/`) **relative to its own base
  directory** — never a host-project path — so it works wherever installed.
- **Instruct generically; let the project resolve specifics.** Skills say "run the host's gate /
  checks / diagnostics" and rely on the consuming project's `AGENTS.md` to resolve them
  to concrete commands. They carry **no** project-specific commands.
- **`SKILL.md` frontmatter must be strict-YAML valid** (some harnesses enforce this):
  - **Quote** any `description:` whose value contains `: `.
  - Keep `description:` **≤ 1024 characters** (aim ~700).
  - **The `description` is a trigger, not a summary** — when to fire + keywords, not a feature
    inventory (that's the body's job).
- The design philosophy behind all of this lives in `AGENTS.md`.

## Contributing / feedback

Skills are living artifacts: strong, concrete feedback from *using* one (a friction, a gap, a win
worth keeping) is the signal that improves it. **Open a GitHub issue tagged with the skill's
name**, tied to a concrete instance — "would this change the skill?" is the bar. GitHub issues remain
this library's default feedback channel. For a private cross-project local queue, the optional
standalone `/skill-feedback` skill can capture observations and guide later curation into source
changes or issues.

Before submitting a change:

1. **De-host it.** No project names, no host paths, no host tool commands — generic phrasing or
   `<project: …>` placeholders only.
2. **Description = trigger, not summary** (≤ ~700 chars; quote it if it contains `: `).
3. **Run the gate:** `skills/skill-builder/scripts/skills-lint.sh` — frontmatter limits,
   bundled-ref resolution, manifest checks, script syntax, cross-skill refs. Fix every FAIL.
4. **Run the repository integration tests:** `scripts/tests/run.sh` — exercises Clankshop and
   project configuration contracts against throwaway projects.

## License

MIT — see `LICENSE`.
