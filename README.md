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
./install.sh --remove checkpoint # uninstall
```

- **Claude Code** loads user-level skills from `~/.claude/skills/` — the default target.
- **Codex** (and other harnesses that read a skills directory): point it at this clone's
  `skills/` directly, e.g. `ln -s <clone>/skills ~/.agents/skills` — no per-skill wiring.

## The skills

The `clankshop` pack binds most of them into one **agentic workshop**, tiered by coupling in the
pack manifest (`skills/clankshop/PACK.md`): the pack **face** (`clankshop`) carries the seed
handbook and the four **stations** — `design` (the architect), `build` (the foreman), `test` (the
guardian), `review` (the admin) — with system verbs (`setup` / `migrate` / `check`) and persona
summons; **helpers** — `blueprint` (specification spine), `contractor` (job lead), `journal` (the records format authority —
the one required member), `backlog` (the follow-up lifecycle), `notepad` (project memory),
`workstream` (development streams), `auditor` (code-quality audits), `debugger` (root-cause
diagnostics), `analyst` (reports and briefings read back out of the records); **utilities** —
`checkpoint`, `mailbox`, `delegate`, `scheduler`. Three skills sit outside the pack on
purpose: `agent-council` (cross-vendor review panel), `skill-builder` (the **toolmaker** —
scaffold, audit, and calibrate authoring doctrine), and `google-developer-style`
(developer-docs house style). See *The packs* below.

| skill | what it does |
|---|---|
| `agent-council` | three-family review panel: independent Claude, Grok, and Codex opinions on a skill package, clustered and ranked by agreement; standalone, outside every pack |
| `analyst` | reports and briefings for the developer: catch-ups, status, subsystem and health snapshots, guides — synthesized from the records layer and git, from a customizable template catalog |
| `auditor` | code-quality audit framework: per-dimension rubric, metrics, findings → trackers; standalone on any repo |
| `backlog` | the follow-up lifecycle: file, promote, debrief, and curate the three trackers — a client of the records layer (guards when none) |
| `blueprint` | specification spine: ideation → argued spec; genesis (`new` / `deploy`) mints a founding spec and a new repo; never plans or builds |
| `checkpoint` | living session save-state: `save` / `resume` / `done` + compaction recovery — the persistence disciplines other skills borrow |
| `clankshop` | the workshop face: seed doctrine + the four stations; `setup` / `migrate` / `check`, and persona summons for hat-on discussion |
| `contractor` | one job lead — roadmap, plan, runbook, review, revise, build; never ships; never writes a spec |
| `debugger` | root-cause a bug/test-failure/build-break before proposing any fix — four-phase investigate discipline, human confirms before landing |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `google-developer-style` | write developer docs in Google's house style; snapshot, no live-site floor; standalone, outside every pack |
| `journal` | the records format authority: the record discriminator + contract + `records.sh` + the history ledger; setup, done, substrate curate |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `notepad` | project memory: write, find, update, supersede, and drop durable facts in `notes/` — path-first, opportunistic `records.sh` |
| `scheduler` | recurring agent runs via launchd/cron: job specs + logs in a self-gitignoring `.scheduler/`, one short-lived headless tick per fire |
| `skill-builder` | the toolmaker: scaffold (`new`), audit/lint (`check`), and calibrate the doctrine for building skills — bundles the portable authoring doctrine + gate |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

The v2 rebuild (`docs/design/2026-08-12-clankshop-v2.md`) reshaped the pack into the four-station
workshop and renamed `backlog` → `journal`, `feature` → `blueprint`, `handoff` → `checkpoint`
(adding `scheduler`); the journal/backlog split
(`docs/design/2026-08-14-journal-backlog-split-design.md`) then re-minted `backlog` as the
follow-up lifecycle over the records layer and retired the v1 `bug`/`task` capture aliases; the
former role skills had already merged into the face
(`docs/design/2026-08-10-clankshop-role-merge.md`); earlier lineage lives in
`docs/design/2026-07-17-library-refactor.md`.

### Storage convention: what a deployed project carries

A project the workshop is deployed onto carries three surfaces, filtered from a direct code read
the way `.github/` is. **`<agent-workspace>/doctrine/`** (by default `.dev/doctrine/`) holds
the project's own doctrine — a README (load rules + the one install stamp line), `core/`, the
four station chapters, and `scripts/context.sh` — seeded from the pack face and locally grown
thereafter. **`.records/`** holds the work products:
dated, typed records (`YYYY-MM-DD-<slug>.md` carrying front-matter that declares a `doctype`)
in whatever directories their writers mint, plus `records.sh` and the `history.tsv` closure
ledger — the format is `journal`'s (templates arrive with the skills that mint them;
`journal` ships the commons).
**`AGENTS.md`** is the door: a thin routing table plus the doctrine pointer, and the one place
`agent-workspace:` / `agent-records:` are declared when they are not the defaults. Once seeded,
all three are the project's documents; the deployed doctrine and records READMEs document their own
layout.

Session checkpoints stay **gitignored scratch** (root `CHECKPOINT.md`, steward `checkpoint`) —
not a `.records/` store.

## The packs

A pack is a **skill directory with a `PACK.md` manifest** (`docs/spec/pack-format.md`, format 1):
the face installs like any skill, `install.sh --pack` resolves the manifest, installs the members
transactionally, and records the install in the sidecar `grimoire.lock` beside the target dir.

- **`clankshop`** (`skills/clankshop/PACK.md`) — the skills above (minus `agent-council`,
  `google-developer-style`, and `skill-builder`) as one agentic workshop: the composition lives with the face — the seed
  doctrine in `skills/clankshop/seed/` (mirroring a deployed `<agent-workspace>/doctrine/`
  exactly) and the
  coupling-tier roster in the manifest itself.

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

## License

MIT — see `LICENSE`.
