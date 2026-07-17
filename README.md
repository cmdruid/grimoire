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

| skill | what it does |
|---|---|
| `architect` | the design-system engine: a project's regenerable `design/` seed and its verbs |
| `auditor` | code-quality audit framework: per-dimension rubric, metrics, findings → trackers |
| `chiropractor` | audit + tune a repo's documentation spine for agent ergonomics |
| `delegate` | the delegation front-door: delegate-or-not, mechanism, route confirmation |
| `dev` | the dev-workflow umbrella: route changes, deploy/operate a `dev/` docs system |
| `feature` | the planning spine: brainstorm → design → plan → build, plus independent review |
| `handoff` | save/resume a session as a self-contained hand-off any agent can pick up |
| `mailbox` | out-of-band sub-agent handoff: worktree-safe result transport via slots |
| `workstream` | drive a long-lived dev stream in its own worktree: create → ship → recycle |

## The packs

- **`clankshop`** (`packs/clankshop.md`) — all nine skills as one disciplined development loop:
  the layer map, the seam contracts, and which skill owns what live in the manifest.

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
3. **Run the gate:** `scripts/skills-lint.sh` — frontmatter limits, bundled-ref resolution,
   manifest checks, script syntax, cross-skill refs. Fix every FAIL.

## License

MIT — see `LICENSE`.
