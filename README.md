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

Concrete agent roles: `architect`, `foreman`, `chiropractor`, `auditor`, `debugger`. Three of those
are **stewards**: each stands up, evaluates, maintains, and drift-corrects one cross-cutting layer
against the code (`architect` the design seed, `foreman` the workflow glue, `chiropractor` the doc
spine) — even bootstrapping that layer on a repo that doesn't have it yet. `auditor` and `debugger`
both investigate rather than steward a layer: `auditor` scores code against a quality rubric on a
scheduled sweep and emits findings; `debugger` root-causes one specific reported failure, symptom-
triggered, and proposes a fix rather than a finding. Six more group as **operators** (`feature`,
`backlog`, `workstream` — consume the stewards' seeds and act) and **plumbing** (`delegate`,
`mailbox`, `handoff` — orchestration/transport used throughout). `skill-builder` is a category of
one: the **toolmaker** — it stewards the skills in this library themselves (scaffold new ones, audit
boundary health, calibrate authoring doctrine), not project code, and is deliberately outside the
`clankshop` pack (see *The packs* below).

| skill | what it does |
|---|---|
| `architect` | the design-system engine: a project's regenerable `.agents/architect/` seed — stand up (`init`/`extract`), evaluate (`check`), drift-correct (`reconcile`), evolve (`distill`/`plan`/`brainstorm`), plus `prep` |
| `auditor` | code-quality audit framework: per-dimension rubric, metrics, findings → trackers |
| `backlog` | the capture desk: file follow-ups by kind (task/bug/issue/feedback/note), sweep finished work (`debrief`), curate the lists (`curate`) |
| `chiropractor` | audit + tune a repo's documentation spine for agent ergonomics |
| `debugger` | root-cause a bug/test-failure/build-break before proposing any fix — four-phase investigate discipline, human confirms before landing |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `feature` | the planning spine: brainstorm → design → plan → build, plus independent review |
| `foreman` | the dev-workflow hub: route changes, deploy/operate a `.agents/foreman/` docs system — `init` (greenfield) or `migrate` (brownfield onramp) |
| `handoff` | save/resume a session as a self-contained hand-off any agent can pick up |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `skill-builder` | the toolmaker: scaffold (`new`), audit/lint (`check`), and calibrate the doctrine for building skills — bundles the portable authoring doctrine + gate |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

`foreman` and `backlog` split what used to be one skill (`dev`): `foreman` kept the router +
system-maintainer half, `backlog` took the capture-inbox half — one collection front-door instead
of a shared one. `architect` is a rename of `design` (verbs unchanged); `auditor` is a rename of
`audit` (see *Storage convention* below and `docs/design/2026-07-17-library-refactor.md` for the
full rationale).

### Storage convention: two roots (`.agents/` + `.records/`)

Committed, agent-tooling-managed project artifacts split by *kind*, filtered from a direct code read
the way `.github/` is. **`.agents/`** holds hand-curated **seeds** (source of truth, one home per
steward); **`.records/`** holds every typed **record** (trackers + durable history). Because the
paths no longer encode ownership, `foreman init` writes an **ownership index** (`.agents/README.md` +
`.records/README.md`) mapping content → location → steward:

| content | location | steward |
|---|---|---|
| design seed | `.agents/architect/` | `architect` |
| provisional design draft (brownfield onramp) | `.records/design-draft/` | `architect extract` (writer) |
| dev doctrine: `docs/` + `MEMORY`/`GOTCHAS`/`README` glue | `.agents/foreman/` | `foreman` |
| audit rubric: `GUIDE`, `rules/`, `metrics.sh` | `.agents/auditor/` | `auditor` |
| tasks · issues · feedback · bugs/ · notes/ | `.records/` | `backlog` |
| plans / roadmaps | `.records/plans/` | `feature` |
| shipped / done records | `.records/archive/` | `workstream` |
| architecture decision records | `.records/adr/` | `feature` (writer); distilled by `architect` |
| research reports · run logs | `.records/reports/`, `.records/logs/` | foreman / various |
| seed↔code drift reports | `.records/reports/` | `architect reconcile` (writer) |
| audit deliverables: `FINDINGS` · `metrics.csv` · `history/` | `.records/audit/` | `auditor` |

Session hand-offs stay **gitignored scratch** (root `HANDOFF.md` · `.sessions/`, steward `handoff`) —
not a `.records/` store. The full tree lives in `foreman`'s `BOOTSTRAP.md` (§4); the steward map is
the runbook's (`packs/clankshop.md`).

## The packs

- **`clankshop`** (`packs/clankshop.md`) — the skills above (minus `skill-builder`, its own
  maintainer tool) as one disciplined development loop: the layer map, the seam contracts, and which
  skill owns what live in the manifest.

## Authoring conventions

- **Self-contained + location-agnostic.** A skill references its own bundled resources
  (`scripts/`, `templates/`, `docs/`, `verbs/`, `BOOTSTRAP.md`) **relative to its own base
  directory** — never a host-project path — so it works wherever installed.
- **Instruct generically; let the project resolve specifics.** Skills say "run the host's gate /
  fast doc-linter / diagnostics" and rely on the consuming project's `AGENTS.md` to resolve them
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
