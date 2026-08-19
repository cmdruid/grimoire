---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `agent-workspace`, part 2 — the templates home — Draft

`stream/feat` **feature 3b**. Split out of `2026-08-18-agent-workspace-consolidation.md` on
2026-08-18 (human) after that feature's `agent-templates` half failed **three consecutive review
censuses**. Draft weight — not yet argued; `grill` or `spec` resolves the open questions at the foot.

> **Depends on feature 3a**, which introduces `agent-workspace` (default `.dev/`) and retires
> `agent-doctrine`. This feature retires the second variable into the same home. Do not start it
> before 3a lands — the variable it depends on will not exist.

## Problem

`agent-templates` is the second front-door variable with no demonstrated variance case. It defaults
to `<agent-records>/templates` (`DOCTRINE.md:217-221`), which is why `records.sh` must carve
`templates/` out of its own store enumeration (`records.sh:64,82`). After 3a, it is the **only**
variable still defaulting inside another home, and the carve-out list is the only thing still
architectural about the arrangement.

## Goal

Retire `agent-templates` into `<agent-workspace>/templates`, and demote `records.sh`'s reserved-name
list from architectural to legacy-compat.

## Why this is the hard half — the inherited findings

**Read these before scoping. They are why the split happened, and every one is verified against
code.** Three review rounds produced an incomplete census each time; these are the sites that kept
being missed.

1. **The retired variable is a positional CLI argument, not prose.** `record-mint.sh` and
   `note-mint.sh` take `<agent-templates>` as an argument (`$at`, arg 2). Retiring the variable is a
   **tool contract change**, cascading to `backlog`'s five verbs + `SKILL.md` + tests and
   `notepad`'s two verbs + `SKILL.md` + tests. Decide there whether the parameter keeps the name or
   becomes `<templates-home>`.

2. **`records.sh:180`'s template fallback is load-bearing and must NOT be naively deleted.**
   `[ -n "$tpl" ] || tpl="$RR/templates/$doctype.md"`. A prior draft proposed deleting it on the
   claim that "both real callers always pass `--template`" — **false.** Three shipped verbs call it
   bare and would hard-error: `contractor/verbs/plan.md:62`, `roadmap.md:28`, `runbook.md:15`
   (`records.sh new plans --title "…"`). Contractor ships `templates/plans.md` precisely to be
   resolved by that fallback. Either keep it and re-anchor to the workspace, or delete it **and**
   convert those three verbs to `--template <resolved>` per the agent-templates rule
   (`contractor/SKILL.md:38` already prescribes that form — the verbs drifted).

3. **The legacy-flat adopt arm derives from the RECORDS root, deliberately.**
   `record-mint.sh:85` (`flat="$rr/templates/$file"`) and `note-mint.sh:82` implement
   `DOCTRINE.md:356-367` ladder **step 2**. That probe is a *brownfield adopt*, not a home — it
   should probably stay anchored at `<agent-records>/templates/<doctype>.md` even after the home
   moves. Decide and state it; "only the base path moves" is ambiguous exactly here.

4. **De-reserving `templates/` breaks brownfield hosts.** `DOCTRINE.md:362` says the legacy-flat file
   is copied and **"Do not delete the old file"** — so `.records/templates/plans.md` persists by
   design, carrying unfilled slots (`created: <date>`). The moment `stores()` stops skipping
   `templates`, `records.sh check` FAILs on it forever. The reserved list can only demote for hosts
   that have no legacy-flat survivors — or the demotion must be conditional.

5. **`analyst` scans the front door itself.** `analyst-deploy.sh:15-24` + `:33`
   (`DEST="$RR/templates/analyst"`), `analyst-facts.sh:32`, `:303`, and `:76-81` — which carries a
   **second, drifted copy** of the carve-out that omits `doctrine/`. Not a prose edit; it needs the
   workspace resolver.

6. **The full `agent-templates` carrier census: 50 refs across 24 files.** Sites a prior draft left
   unowned: `backlog/{SKILL.md:43, scripts/record-mint.sh, scripts/tests/, verbs/*}`,
   `notepad/{SKILL.md:45,51, scripts/note-mint.sh, verbs/{supersede,write}.md}`,
   `skill-builder/verbs/new.md:35-36` (it tells `new` to inline the retired resolver, so unfixed it
   keeps minting new skills with it), `workstream/verbs/ship.md:129,154`, `journal/scripts/standup.sh`
   (incl. its header `:12-13` and the records README it writes at `:56-64`), and
   `DOCTRINE.md:356-367`.

7. **Sequencing hazard.** If sliced carelessly, `backlog`/`notepad` mint into `.records/templates/`
   while `journal`/`analyst` deploy to `.dev/templates/` — a silent divergence of exactly Problem
   3's shape, the thing feature 3a exists to fix.

## Open questions (for `grill` / `spec`)

1. Does ladder step 2's legacy-flat probe stay anchored at `<agent-records>/templates/`?
2. Keep `records.sh:180`'s fallback re-anchored, or delete it and fix contractor's three verbs?
3. Can the reserved list demote at all given legacy-flat survivors, or must it stay unconditional?
4. Do the mint scripts' positional parameters get renamed, and what is the migration for callers?
5. Does `standup.sh` gain a `--workspace` flag, and does the records README it writes name a
   resolved path or a literal default?
6. **Should the census be generated rather than asserted?** Three rounds failed on prose enumeration.
   A slice zero that emits the affected-file list mechanically — and checks it in — would make the
   census a verifiable artifact instead of a claim.

## Grounding

Verified 2026-08-18: `records.sh:180`; `record-mint.sh:74,85`; `note-mint.sh:75,82`;
`contractor/verbs/{plan.md:62,roadmap.md:28,runbook.md:15}`; `analyst-deploy.sh:33`;
`analyst-facts.sh:76-81,303`; `DOCTRINE.md:356-367`; `agent-templates` = 50 refs / 24 files.
