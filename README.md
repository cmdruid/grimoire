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
./install.sh chiropractor        # install one skill (into ~/.claude/skills)
./install.sh --pack clankshop    # install a whole pack
./install.sh --remove handoff    # uninstall
```

- **Claude Code** loads user-level skills from `~/.claude/skills/` — the default target.
- **Codex** (and other harnesses that read a skills directory): point it at this clone's
  `skills/` directly, e.g. `ln -s <clone>/skills ~/.agents/skills` — no per-skill wiring.

## The skills

The `clankshop` pack binds most of them into one development loop, tiered by the pack doctrine's
roster (`skills/clankshop/doctrine/README.md`): **roles** — expertise an agent assumes when the
moment calls for it (`architect` design, `foreman` operations and routing, `guardian` verification,
`auditor` code quality, `chiropractor` docs quality, `calibrator` the improvement loop);
**instruments** — procedures anyone operates (`backlog` the records instrument, `debugger` the
diagnostic instrument); **pipelines** — the work processes (`feature` turns an idea into gate-green
code, `workstream` encapsulates continuous shipping); **helpers** — portable plumbing useful on any
repo (`delegate`, `mailbox`, `handoff`); plus the pack **face** (`clankshop`) and the optional
capture aliases (`bug`, `task`). `skill-builder` is a category of one: the **toolmaker** — it
stewards the skills in this library themselves (scaffold new ones, audit boundary health, calibrate
authoring doctrine), not project code, and is deliberately outside the `clankshop` pack (see *The
packs* below).

| skill | what it does |
|---|---|
| `architect` | the design-system engine: a project's regenerable `.handbook/design/` seed — stand up (`init`/`extract`), evaluate (`check`), drift-correct (`reconcile`), evolve (`distill`/`plan`/`brainstorm`), plus `prep` |
| `auditor` | code-quality audit framework: per-dimension rubric, metrics, findings → trackers |
| `backlog` | the records instrument: capture by kind, complete (`done` + the done log), escalate via tickets (+ mirror), curate, debrief |
| `bug` | capture alias: `/bug` proxies the records instrument's bug capture (optional pack member) |
| `calibrator` | the improvement loop: intake captured signal + quality findings, dispatch to the owning role, verify uptake, close; the doctrine seam both ways |
| `chiropractor` | audit + tune a repo's documentation spine for agent ergonomics |
| `clankshop` | the clankshop pack's executable face: the pack's doctrine + runbook home and the system verbs — `setup` (greenfield bootstrap), `migrate` (brownfield onramp), `check` (whole-system assembly validation) |
| `debugger` | root-cause a bug/test-failure/build-break before proposing any fix — four-phase investigate discipline, human confirms before landing |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `feature` | the planning spine: brainstorm → design → plan → build, plus independent review |
| `foreman` | the change router + rulebook steward: classify a change, dispatch it to its lane, tend the deployed routing/workflow chapters |
| `guardian` | the verification role: tend `.handbook/testing/` (gate / pipeline / diagnostics playbook) + the defect-vs-flake and verification-depth judgment |
| `handoff` | save/resume a session as a self-contained hand-off any agent can pick up |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `skill-builder` | the toolmaker: scaffold (`new`), audit/lint (`check`), and calibrate the doctrine for building skills — bundles the portable authoring doctrine + gate |
| `task` | capture alias: `/task` proxies the records instrument's task capture (optional pack member) |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

`foreman` and `backlog` split what used to be one skill (`dev`): `foreman` kept the router +
system-maintainer half, `backlog` took the capture-inbox half — one collection front-door instead
of a shared one. `architect` is a rename of `design` (verbs unchanged); `auditor` is a rename of
`audit` (see *Storage convention* below and `docs/design/2026-07-17-library-refactor.md` for the
full rationale).

### Storage convention: what a deployed project carries

A project the pack is deployed onto carries three agent-tooling roots, filtered from a direct code
read the way `.github/` is. **`.handbook/`** holds the projected, locally-grown chapters — that
project's source of truth (`rules/` and `workflows/` tended by the operations role, `design/` by
the design role, `testing/` by the verification role, plus the records instrument's stamped
projection `rules/RECORDS.md`). **`.records/`** holds every typed record (trackers, tickets, the
done log, plans/ADRs, design drafts, reports, audit deliverables). **`.agents/roles/`** holds lazy
machinery-only seats (e.g. the auditor's rubric). Because paths don't encode ownership,
`/clankshop setup` writes the two-region **stewardship maps** (`.handbook/README.md` +
`.records/README.md`) mapping content → location → steward, each block stamped against its input.

Session hand-offs stay **gitignored scratch** (root `HANDOFF.md`, steward `handoff`) —
not a `.records/` store. The full store tree lives in the pack doctrine's record schema
(`skills/clankshop/doctrine/rules/RECORDS.md`); the roster and door profile live in the doctrine
index (`skills/clankshop/doctrine/README.md`).

## The packs

A pack is a **skill directory with a `PACK.md` manifest** (`docs/spec/pack-format.md`, format 1):
the face installs like any skill, `install.sh --pack` resolves the manifest, installs the members
transactionally, and records the install in the sidecar `grimoire.lock` beside the target dir.

- **`clankshop`** (`skills/clankshop/PACK.md`) — the skills above (minus `skill-builder`, its own
  maintainer tool) as one disciplined development loop: the composition lives with the face — the
  doctrine (chapter registry, roster, door profile) in `skills/clankshop/doctrine/` and the
  methodology in `skills/clankshop/docs/RUNBOOK.md`.

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
