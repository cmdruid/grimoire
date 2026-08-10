# Clankshop role merge — flattened routes, role hats, one skill

**Status: draft for owner review** (2026-08-10). Third ratified divergence from the pack plan's
Appendix H once approved; supersedes the role-tier *skill* packaging of
`docs/design/2026-08-06-clankshop-pack.md` (roles remain as an instruction layer; their
standalone-skill packaging is retired).

## Problem

The pack spreads its API across five role skills the user never really calls directly
(`architect`, `foreman`, `guardian`, `calibrator`, `chiropractor`): each burns an always-loaded
~750-char description in every session, doctrine changes ripple across six skills in lockstep,
and the coupling needs standing machinery (core-member lint exemptions, per-member registration
blocks, the drift check) just to stay safe. These five are framework stewards with no standalone
life — unlike `feature`/`backlog`/`auditor`, which earn theirs.

## Decision (proposed)

Merge the five framework roles into the `clankshop` skill. **Routes are flattened intent verbs;
roles survive as an inherited instruction layer ("hats").**

**The two-layer contract:** role names never appear as procedure routes; routes never carry the
expertise. The mapping lives in exactly one place — the router table. Persona names get exactly
one routing surface: the `ask` verb, which addresses the role layer directly.

**The calibrator folds into the chiropractor** (owner call): document health and the improvement
loop are both *alignment* work — one hat, two intent verbs (`docs`, `calibrate`). Four hats
total: architect, foreman, guardian, chiropractor.

Out of scope: `auditor` stays standalone (owner call — it just gained standalone value and
behaves as an operable instrument, alongside `debugger`); instruments, pipelines, and helpers
unchanged; the deployed record schema unchanged.

## The grammar

| route | hat (roles/) | subverbs | was |
|---|---|---|---|
| `setup` / `migrate` / `check` | — (system verbs) | — | clankshop |
| `design` | architect | `brainstorm`, `plan`, `extract`, `distill`, `reconcile`, `health` (was architect `check`), `prep`; bare = its default seed work | architect |
| `route` | foreman | — (`<change>` as arg; rulebook tending folds in) | foreman |
| `verify` | guardian | `tend`, `judge` | guardian |
| `calibrate` | chiropractor | `intake` (default), `doctrine` | calibrator |
| `docs` | chiropractor | — (`<scope>` as arg) | chiropractor |
| `ask <role> [<prompt>]` | the named role | — | (new) |

Renames inside the map: architect `check` → `design health` (never echo the system verb);
architect `setup` (the design-seed bootstrap) → `design init`? — **no**: it folds into `setup`'s
projection walk on a clankshop host and survives as `design extract`/migrate-mode for the
brownfield seed; the standalone design-seed case is `design` bare on a repo with no seed (the
verb file handles both, as today's architect setup did).

## Dispatch — how a verb inherits its hat

`SKILL.md` is the router. The dispatch rule is stated once: **read the role file first, then the
verb file; you operate the verb as that role.** Each verb file also opens with a one-line
`Hat: roles/<role>.md` pointer so an agent landing on the file directly still finds it. System
verbs (`setup`/`migrate`/`check`) carry no hat.

```
skills/clankshop/
  SKILL.md            — router: verb | hat | when-to-use (three columns, one table)
  roles/              — the hats: identity, standing judgments, domain boundaries
    architect.md  foreman.md  guardian.md  chiropractor.md
  verbs/
    setup.md  migrate.md  check.md  ask.md
    design/  route.md  verify/  calibrate/  docs.md
  doctrine/  docs/  scripts/  PACK.md      — unchanged homes
```

**Hats are small** (identity + standing judgments + boundaries, a few hundred words — every verb
call pays their read). The old role SKILL.md content splits: judgments → `roles/<role>.md`;
procedure → `verbs/`; self-registration machinery → deleted (the face registers once).

## The `ask` verb — expertise without a procedure

`/clankshop ask <role> [<prompt>]` (role name canonical; the intent token accepted): put the hat
on for a discussion. Load `roles/<role>.md`, the deployed seat (`.agents/roles/<role>/`) when
present, and the role's domain chapters; with a `<prompt>`, open the discussion by answering it
as the role, else await direction. **Discussion first: execute nothing until asked.** When talk
becomes work, route to the owning intent verb, hat still on. The hat persists until the user
switches or removes it. Bundled hat = universal judgment; the deployed seat = project-grown
judgment; they compose (source vs projection, as everywhere).

## What changes where

- **Five skills deleted** (`skills/{architect,foreman,guardian,calibrator,chiropractor}/`),
  content redistributed per the split above. Their `register-route.sh` copies die with them.
- **PACK.md:** `required:` drops the five (13 → 8); `core:` shrinks to
  `clankshop, auditor, backlog, debugger, feature, workstream`. 16 → 11 members.
- **Doctrine (`doctrine/README.md`):** door-profile rows repoint (`/architect` →
  `/clankshop design`, etc.); the five roles' registration-block bodies are removed (only
  separate members register); roster table reworked — the role tier becomes "hats (internal to
  the face)". Stewardship maps: **one `steward:clankshop` block** covering
  rules/workflows/design/testing; the preamble's per-chapter lines name the tending hat.
  Doctrine stays **v1** — no installation exists to reconcile, and versioning starts mattering
  at first deployment (same rationale as the sync-machinery removal).
- **`check-facts.sh`:** registration facts stop expecting the five as members (the member set
  already derives from PACK.md); steward-block logic follows the single-block shape; `seats`
  fact unchanged (deployed seats keep role names — they name hats).
- **Fixtures:** onramp `MEMBERS` derives from PACK.md (auto-shrinks); `project_doctrine` writes
  the single steward block; registration-stability fixture drops architect (its copy is gone) —
  backlog, auditor, feature remain the self-registering set.
- **Prose sweep:** RUNBOOK ("when to assume which role" → the verbs that assume them; roster),
  clankshop SKILL.md description (carries the intent triggers), library `README.md`/`AGENTS.md`
  roster text, cross-references in `feature`/`backlog`/`workstream`/`debugger` prose
  (`/architect` → `/clankshop design`, `/foreman` → `/clankshop route`, …).
- **Records:** third Appendix-H divergence line in the pack plan's close-out block.

## Task list

- [ ] **T1** — this design lands (owner-approved) + the plan-status divergence line.
- [ ] **T2** — the merged skeleton: `roles/` (four hats distilled from the five role SKILL.mds —
      calibrator folds into chiropractor), `verbs/` moves (procedure files relocated + renamed
      per the grammar), router table + dispatch rule + `ask` verb in SKILL.md. Old skills still
      present; suite green.
- [ ] **T3** — the cutover: PACK.md manifest + core list; doctrine door profile + roster +
      stewardship shape; `check-facts.sh` + `lib.sh` + onramp fixture; delete the five skill
      dirs. One commit, suite green (count will drop with the registration asserts).
- [ ] **T4** — the prose sweep: RUNBOOK, descriptions, cross-skill references, library
      README/AGENTS.md. Lint baseline re-stated (five description WARNs disappear).
- [ ] **T5** — verify: full suite + lint + drift check; repo-wide grep proves no `/architect`,
      `/foreman`, `/guardian`, `/calibrator`, `/chiropractor` routes remain (persona names
      survive only as hat/seat names and in historical design docs).
