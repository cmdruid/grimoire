# `/foreman init` — instantiate a composition's glue on a fresh project

Stand up a project's `.agents/dev/` development system where none exists, wired to the **composition**
of skills the host actually has. This verb is the **oven, not the recipe**: it knows *how* to
instantiate glue from a composition, but the composition itself comes from **outside** — a pack
runbook when one is present, otherwise a **baseline** introspection of the installed skills. The
methodology lives in the bundled `BOOTSTRAP.md` (the portable blueprint) and, once deployed, in the
host's own `.agents/dev/docs/` (the source of truth). The verb orchestrates; it does not restate the policy.

**Mechanism vs. composition (do not fuse them).** `foreman` is pack-agnostic — it must never
hardcode a specific skill or pack. It reads a composition and wires it. The pack **calls** this verb;
this verb never depends on any pack. That separation is what lets `init` serve a full pack, a
partial install, or a bare one skill deep.

**On-disk home root (spec §3.1).** The artifact homes live under a single `.agents/` root: `init`
scaffolds `.agents/dev/`, and `/architect` uses `.agents/design/`. **Record the chosen root in the
glue you write** (the host's `AGENTS.md`, step 6) so every companion skill and agent **reads the
recorded location** rather than assuming a hardcoded path — the root is a pointer, not a constant.

## Step 0 — Determine the composition

Before scaffolding, decide *what* you are wiring. Two sources, in order:

1. **A pack runbook, if present.** If a pack manifest (e.g. `packs/<pack>.md` in the grimoire clone,
   or one the user names) applies, **read it and consume it as the composition.** The runbook carries
   what introspection cannot derive: the **member list**, the **cross-skill seam contracts** (which
   skill owns which boundary), and the **glue-workflows** (how a change flows across the seams). Wire
   the deployed doctrine and the `AGENTS.md` companion-skills section to match that composition, seams
   included. The runbook is the enrichment; it drives this verb.
2. **Else, baseline (introspect the installed skills).** With no runbook, discover which companion
   skills are installed, **wire the ones you recognize** into the deployed doctrine and `AGENTS.md`
   (`/backlog` for capture, `/feature`/`/workstream` for plan-build-land, `/architect` for the design
   seed, `/handoff` for sessions, `/auditor`/`/chiropractor` for audits), and for any recognized
   companion that is **absent**, **name the by-hand fallback** in the deployed docs ("no `/backlog`
   installed → capture by hand into the trackers per `.agents/dev/docs/`"). Baseline covers the bare
   install; it wires the members but *not* the cross-skill seams — those only exist in a runbook.

Either way the output is the same shape of glue; the runbook just supplies richer seam wiring than
introspection can.

## What the `foreman` skill bundles (for deployment)

- **`BOOTSTRAP.md`** — the portable blueprint (principles, slots, module map, the directory
  manifest, the decision walk, the capture taxonomy, planning tiers, the worktree pipeline,
  maintenance, the sync contract, the template contract, the deployment playbook). Canonical here.
- **`docs/`** — a generic, language-neutral process-doc set (`DEVELOPMENT`, `PLANNING`, `WORKTREES`,
  `WORKFLOWS`, `MAINTENANCE`) with host specifics as `<slots>`. The deployable rubric: copy and fill.
  The capture taxonomy (the `TAXONOMY` doc + the trackers) is `/backlog`'s to deploy — install it alongside.
- **`templates/`** — a generic, hand-authored template seed (`plan-design`, `plan-implementation`,
  `roadmap`, `adr`, `report`, `done-record`) to copy into the host's `.agents/dev/templates/`. The capture templates
  (`bug-report`, `feedback`, `note`) ship with `/backlog`.

There is **no generated worked-example mirror.** Scaffold from the bundled `docs/` + `templates/`
(BOOTSTRAP §12) and use the **host repo's own `.agents/dev/`**, as it fills in, as the live example.

## Procedure

Follow the bundled `BOOTSTRAP.md` deployment playbook (§13), wiring the composition from Step 0:

1. **Fill the slots** (§2): `<keystone>` (the project's sacred invariants), `<gate>` (the one
   test/lint command), `<stack>`; pick modules from the Module Map (§3) — Core always; worktree
   pipeline / maintenance / sync / etc. opt-in.
2. **Scaffold the tree** (§4) from the manifest + the bundled `templates/` (§12), and copy the
   generic `docs/` into the host's `.agents/dev/docs/` and fill the slots. Copy the generic
   `templates/` into the host's `.agents/dev/templates/`, adjusting any host specifics.
3. **Write the trackers + `.agents/dev/README`** from the `BOOTSTRAP` templates (empty files with
   their one-line headers; the index genericized to the host) — the trackers + capture taxonomy come
   from `/backlog` where it is installed.
4. **Wire the linter** (§11) into the host's `<gate>`: internal links resolve; enumerable doc series
   are indexed; banned paths are absent; store-dir files carry valid frontmatter.
5. **Author the `<content docs>`** (ARCHITECTURE / GOTCHAS / DIAGNOSTICS / PERFORMANCE) — the
   project's own.
6. **Surface the operational entrypoints + the composition in the host's `AGENTS.md`.** Name the
   **gate** command (`<gate>`), the **fast doc-linter** (`<linter>`), and the **diagnostics** tooling
   in a *Build / test / run* (or equivalent) section. This is **load-bearing**: the companion skills
   reference these *generically* — "run the host's gate", "the fast doc-linter", "the host's
   diagnostics tooling" — and rely on `AGENTS.md` being in the agent's context to resolve them to
   concrete commands. The skills carry **no** project-specific commands, by design; if `AGENTS.md`
   doesn't name the gate, "run the gate" has nothing to resolve to. **Also record the on-disk home
   root here** (the `.agents/dev/` — and `.agents/design/` — location) so the recorded pointer, not a
   hardcoded path, is what agents resolve (§3.1). (`.agents/dev/docs/` holds the longer-form detail;
   `AGENTS.md` is the always-loaded surface.)
7. **List the composition's companion skills in `AGENTS.md`** — the members from Step 0 (`/backlog`,
   `/feature`, `/workstream`, `/architect`, `/handoff`, `/auditor`, `/chiropractor` for the full
   pack; a subset for a baseline install), and where a runbook drove `init`, a one-line note on the
   **seams** that bind them (feature ends at gate-green → workstream lands → backlog debriefs). Note
   that `/foreman`'s own verbs (`route`, `tune`, `check`) cover route/tune/validate and `/backlog`
   covers capture/debrief/groom; for any *absent* recognized companion, state the by-hand fallback.
   The deployed system also works entirely by hand (BOOTSTRAP's "follow the conventions by hand").
8. **Stamp what you built against (snapshot doctrine).** The generated glue is a snapshot of a moving
   target — record, in the deployed glue (a stamp line in `.agents/dev/README.md`, or an `AGENTS.md`
   footer), **which composition and skill versions this `init` ran against**: the runbook source
   (pack name + its file, or "baseline / introspection" when none) and the set of companion skills
   wired, with the date (`date +%Y-%m-%d`, never guessed). Say *verify before trusting* — the stamp is
   a pointer to what was true at deploy time, not a guarantee it still is. **`/foreman check` is the
   drift validator**: it re-reads this stamp and flags where the deployed glue has drifted from the
   runbook it names or from the skills now installed. Name it in the stamp so the next agent knows how
   to re-validate.

## Keeping the bundle current (this skill's home repo)

`BOOTSTRAP.md` is **canonical here** — edit it in place. The generic `docs/` and `templates/` are an
authored distillation — update them by hand when a process's *method* changes. There is no mirror to
re-sync.

## Done when

A `.agents/dev/` system that passes the host's `<gate>` — trackers, templates, routing/planning/worktree/
maintenance docs, the linter wired, the `<content docs>` authored, the **gate / doc-linter /
diagnostics surfaced in `AGENTS.md`** (so the skills' generic instructions resolve), the
**composition's companion skills listed** (with by-hand fallbacks for the absent), and a **stamp**
recording the runbook + skill versions built against, pointing at `/foreman check` as the drift
validator.
