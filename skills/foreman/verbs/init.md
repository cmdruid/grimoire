# `/foreman init` — stand up the `dev/` system on a fresh project

Deploy a project's `dev/` development system where none exists. This verb is a **thin driver**: the
methodology lives in the bundled `BOOTSTRAP.md` (the portable blueprint) and, once deployed, in the
host's own `dev/docs/` (the source of truth). The verb orchestrates; it does not restate the policy.

## What the `foreman` skill bundles (for deployment)

- **`BOOTSTRAP.md`** — the portable blueprint (principles, slots, module map, the directory
  manifest, the decision walk, the capture taxonomy, planning tiers, the worktree pipeline,
  maintenance, the sync contract, the template contract, the deployment playbook). Canonical here.
- **`docs/`** — a generic, language-neutral process-doc set (`DEVELOPMENT`, `PLANNING`, `WORKTREES`,
  `WORKFLOWS`, `MAINTENANCE`) with host specifics as `<slots>`. The deployable rubric: copy and fill.
  The capture taxonomy (`TAXONOMY.md`, the trackers) is `/backlog`'s to deploy — install it alongside.
- **`templates/`** — a generic, hand-authored template seed (`plan-design`, `plan-implementation`,
  `roadmap`, `adr`, `report`) to copy into the host's `dev/templates/`. The capture templates
  (`bug-report`, `feedback`, `task-record`, `note`) ship with `/backlog`.

There is **no generated worked-example mirror.** Scaffold from the bundled `docs/` + `templates/`
(BOOTSTRAP §12) and use the **host repo's own `dev/`**, as it fills in, as the live example.

## Procedure

Follow the bundled `BOOTSTRAP.md` deployment playbook (§13):

1. **Fill the slots** (§2): `<keystone>` (the project's sacred invariants), `<gate>` (the one
   test/lint command), `<stack>`; pick modules from the Module Map (§3) — Core always; worktree
   pipeline / maintenance / sync / etc. opt-in.
2. **Scaffold the tree** (§4) from the manifest + the bundled `templates/` (§12).
3. **Copy the generic `docs/`** into the host's `dev/docs/` and fill the slots.
4. **Copy the generic `templates/`** into the host's `dev/templates/`, adjusting any host specifics.
5. **Write the trackers + `dev/README`** from the `BOOTSTRAP` templates (empty files with their
   one-line headers; the index genericized to the host) — the trackers + capture taxonomy come from
   `/backlog` where it is installed.
6. **Wire the linter** (§11) into the host's `<gate>`: internal links resolve; enumerable doc series
   are indexed; banned paths are absent; store-dir files carry valid frontmatter.
7. **Author the `<content docs>`** (ARCHITECTURE / GOTCHAS / DIAGNOSTICS / PERFORMANCE) — the
   project's own.
8. **Surface the operational entrypoints in the host's `AGENTS.md`** — name the **gate** command
   (`<gate>`), the **fast doc-linter** (`<linter>`), and the **diagnostics** tooling in a *Build /
   test / run* (or equivalent) section. This is **load-bearing**: the companion skills reference these
   *generically* — "run the host's gate", "the fast doc-linter", "the host's diagnostics tooling" —
   and rely on `AGENTS.md` being in the agent's context to resolve them to concrete commands. The
   skills carry **no** project-specific commands, by design; if `AGENTS.md` doesn't name the gate,
   "run the gate" has nothing to resolve to. (`dev/docs/` holds the longer-form detail;
   `AGENTS.md` is the always-loaded surface.)
9. **List the companion skills** (`/backlog`, `/feature`, `/workstream`, `/handoff`, `/auditor`) as
   recommended installs — and note that `/foreman`'s own verbs (`route`, `tune`, `check`) cover
   route/tune/validate, while `/backlog` covers capture/debrief/groom. The deployed system also works
   by hand (BOOTSTRAP's "follow the conventions by hand").

## Keeping the bundle current (this skill's home repo)

`BOOTSTRAP.md` is **canonical here** — edit it in place. The generic `docs/` and `templates/` are an
authored distillation — update them by hand when a process's *method* changes. There is no mirror to
re-sync.

## Done when

A `dev/` system that passes the host's `<gate>` — trackers, templates, routing/planning/worktree/
maintenance docs, the linter wired, the `<content docs>` authored, the **gate / doc-linter /
diagnostics surfaced in `AGENTS.md`** (so the skills' generic instructions resolve), and the
companion skills listed.
