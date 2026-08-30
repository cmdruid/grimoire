# grimoire 🜃 — cmdruid's library of agent skills

An ever-expanding, version-controlled library of skills for coding agents (Claude Code, Codex,
and anything else that reads `SKILL.md` packages). Skills are the atoms — each one self-contained
and individually useful. **Packs** bind them into systems: a pack is a curated manifest, not a
directory, so one skill can serve many packs.

Agents *invoke* skills; a grimoire is the book they're invoked from.

## Install

Clone anywhere, then symlink what you want — the clone stays canonical, so `git pull` updates
every installed skill in place:

```
git clone https://github.com/cmdruid/grimoire && cd grimoire
./install.sh --list              # see what's here
./install.sh debugger            # install one skill (into ~/.claude/skills)
./install.sh --pack clankshop    # install a whole pack
./install.sh --check --pack clankshop
./install.sh --remove --pack clankshop
./install.sh --remove checkpoint # uninstall
```

- **Claude Code** loads user-level skills from `~/.claude/skills/` — the default target.
- **Codex** (and other harnesses that read a skills directory): point it at this clone's
  `skills/` directly, e.g. `ln -s <clone>/skills ~/.agents/skills` — no per-skill wiring.

## The skills

The root, faceless `clankshop` pack binds most of them into one installable toolkit:
**helpers** — `architect` (specification spine), `contractor` (job lead), `inspector` (critique and fold), `journal` (the records format authority —
the one required member), `backlog` (the follow-up lifecycle), `notepad` (project memory),
`workstream` (development streams), `auditor` (code-quality audits), `debugger` (root-cause
diagnostics), `analyst` (reports and briefings read back out of the records), `foreman`
(project operations, brownfield curation, and goal runbooks), `chiropractor` (documentation-spine
discoverability and confirmed route repair); **utilities** —
`checkpoint`, `mailbox`, `delegate`, `scheduler`, `workspace` (the owner-first workspace guard).
Four skills sit outside the pack on
purpose: `agent-council` (cross-vendor review panel), `skill-builder` (the **toolmaker** —
scaffold, audit, and calibrate authoring doctrine), `developer-writing`
(purpose-aware, human-facing developer prose with Google documentation mechanics), and
`code-humanizer` (keep durable source fit for human ownership). See *The packs* below.

| skill | what it does |
|---|---|
| `agent-council` | three-family review panel: independent Claude, Grok, and Codex opinions on a skill package, clustered and ranked by agreement; standalone, outside every pack |
| `analyst` | reports and briefings for the developer: catch-ups, status, subsystem and health snapshots, guides — synthesized from the records layer and git, from a customizable template catalog |
| `architect` | specification spine: ideation → argued spec; genesis (`new` / `deploy`) mints a founding spec and a new repo; never plans or builds |
| `auditor` | code-quality audit framework: per-dimension rubric and metrics; findings stay in the audit report and promote through the host capture lane; standalone on any repo |
| `backlog` | first-class living TSV trackers: setup, extensible queues, receipts, paging, filing, universal debriefing, and curation through `tracker@1` |
| `checkpoint` | living session save-state: `save` / `resume` / `close` + compaction recovery — the persistence disciplines other skills borrow |
| `chiropractor` | audit documentation-spine discoverability and authority from `AGENTS.md`; trace task routes into docs, workflows, and helper scripts, then confirmation-gate minimal documentation-only repairs |
| `code-humanizer` | keep durable application, service, library, shipped CLI, and maintained test source fit for human ownership at write time; `mark` / `map` / `walk` on supported existing code; standalone, outside every pack |
| `contractor` | one job lead — roadmap, plan, runbook, build; never ships; never writes a spec |
| `debugger` | root-cause a bug/test-failure/build-break before proposing any fix — four-phase investigate discipline, human confirms before landing |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `developer-writing` | write and edit human-facing developer prose with purpose-aware structure, human editorial judgment, and Google documentation mechanics; agent-executed operational artifacts get wording-only help on explicit request; standalone, outside every pack |
| `journal` | the records format authority: discriminator, contract, adjacent `records.sh`, and history ledger; durable setup, narrow repair, search, close, and substrate curation |
| `inspector` | material review of documents and completed implementations; revise folds supported document findings, refine simplifies specs and plans, and setup deploys Inspector-owned kind doctrine absent-only |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `notepad` | project memory: write, find, update, supersede, and drop durable facts in `notes/` — path-first, opportunistic `records.sh` |
| `scheduler` | recurring agent runs via launchd/cron: job specs + logs in a self-gitignoring `.scheduler/`, one short-lived headless tick per fire |
| `foreman` | curate project operations: inventory and run publisher-owned procedures, capture or ingest brownfield know-how, verify and compose operations, and compile immutable goal runbooks |
| `skill-builder` | the toolmaker: scaffold (`new`), audit/lint (`check`), and calibrate the doctrine for building skills — bundles the portable authoring doctrine + gate |
| `workspace` | read-only workspace format guard: validate open owner namespaces, closed kinds, safe paths, and split/coincident workspace and records roots |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

The v2 rebuild (`docs/design/2026-08-12-clankshop-v2.md`) once shaped the pack as a faced
workshop and renamed `backlog` → `journal`, `feature` → `blueprint`, `handoff` → `checkpoint`
(adding `scheduler`); the journal/backlog split
(`docs/design/2026-08-14-journal-backlog-split-design.md`) then re-minted `backlog` as the
follow-up lifecycle over the records layer and retired the v1 `bug`/`task` capture aliases; the
former role skills had already merged into the face
(`docs/design/2026-08-10-clankshop-role-merge.md`); earlier lineage lives in
`docs/design/2026-07-17-library-refactor.md`.

### Storage convention: what skills may maintain in a project

A project has three fixed, independent roots. **`.spaces`**
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
**`.trackers`** holds public `tracker@1` queue TSVs, the shared
receipt ledger, and adjacent canonical provider `.trackers/trackers.sh`. Backlog owns that
layer; consumer skills invoke the installed provider directly.
These canonical homes are constants, not front-door configuration. Each durable-home skill owns
its files and optional route block;
the pack installs skills but writes none of these project surfaces.

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

A pack is a format-1 `PACK.md` manifest (`docs/spec/pack-format.md`). A manifest may sit beside
a face skill or, as here, at repository root with no face. `install.sh --pack` installs members
transactionally and records the install in the sidecar `grimoire.lock` beside the target dir.

- **`clankshop`** (`PACK.md`) — the skills above (minus `agent-council`,
  `code-humanizer`, `developer-writing`, and `skill-builder`) as a faceless toolkit. The manifest body is the
  seam map; there is no `clankshop` skill or project assembler.

## Repo layout

Beyond the skills, this repo carries the pack format and its tooling (the umbrella design:
`docs/design/2026-08-07-grimoire-repurpose-design.md`):

- **`crates/`** — a Cargo workspace (build from the repo root). `grimoire-pack` is the pack
  format's reference library; `grimoire-core` (operations) and the `grimoire` TUI itself land
  next (the app crate publishes as `skill-grimoire`; the binary is `grimoire`). Crates never
  read `skills/` at build time — content appears only as test fixtures.
- **`docs/spec/`** — the pack format spec (`pack-format.md`); `install.sh` stays the
  zero-dependency shell reference implementation.
- **`repos/`** — gitignored reading references (e.g. the qntx `skill` clone); real dependencies
  come from crates.io, pinned.

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
name**, tied to a concrete instance — "would this change the skill?" is the bar. (Your own
installation can also keep a local collection file and drain it into issues periodically.)

Before submitting a change:

1. **De-host it.** No project names, no host paths, no host tool commands — generic phrasing or
   `<project: …>` placeholders only.
2. **Description = trigger, not summary** (≤ ~700 chars; quote it if it contains `: `).
3. **Run the gate:** `skills/skill-builder/scripts/skills-lint.sh` — frontmatter limits,
   bundled-ref resolution, manifest checks, script syntax, cross-skill refs. Fix every FAIL.
4. **Run the repository integration tests:** `scripts/tests/run.sh` — exercises pack installation
   and Clankshop project configuration against throwaway projects.

## License

MIT — see `LICENSE`.
