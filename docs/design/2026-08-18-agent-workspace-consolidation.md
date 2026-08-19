---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Two homes — `agent-records` + `agent-workspace` — Draft

Brainstorm draft, `stream/feat` **feature 3** (the `handbook` extraction is parked behind this —
see `2026-08-18-handbook-skill-extraction.md`, *Status: PARKED*). Grounded against `main` @
`ce7e758` + branch `3b1cc99`. Not yet argued into a spec — `grill` or `spec` resolves the open
questions at the foot.

## Problem

The front door carries **three** path variables where only one has ever demonstrated variance, and
the two dependent ones nest *inside* the first — which forces the records layer to disown part of
its own directory.

1. **Two of three variables have no variance case.** `agent-records` has real brownfield history
   (hosts declaring `records-root: dev`, kept in place rather than `git mv`'d — `migrate.md:24-26`).
   `agent-templates` and `agent-doctrine` both default *under* the resolved records home
   (`DOCTRINE.md:217-223`) so that "one `agent-records:` line moves all three." Neither has a live
   host declaring it. `DOCTRINE.md:236` concedes `agent-doctrine`'s case is "partly **prospective**."

2. **The nesting forces the records tool to exclude its own subdirectories.** `records.sh:64`:

       templates/*|scripts/*|doctrine/*|history.tsv) err "reserved path, not a record: $rel" ;;

   and `:82` skips `templates|scripts|doctrine` when enumerating stores. `:70`'s comment says why:
   *"doctrine is reserved because the agent-doctrine home defaults to…"*. **The carve-out list is
   the defect's signature** — `.records/` hosts three kinds of thing that are not records, so the
   records layer must be taught to ignore them.

3. **A workshop adds a fourth home nobody declares.** `.handbook/` is the deployed doctrine tree,
   but no skill writes an `agent-doctrine:` declaration (verified: **5 consumer skills read it, 0
   write it**), so consumers resolve the default `.records/doctrine/`, miss `.handbook/` entirely,
   and — per Doctrine-touching rule 3 — `/auditor setup` will *create a second doctrine tree* there
   beside the real one. Feature 2 shipped the readers; the writer was deferred to the parked
   feature. See the parked spec's Review history, finding 16.

## Goal

**Two homes, positively defined.** `agent-records` is the file cabinet — dated, typed, closeable
documents. `agent-workspace` is the development environment — doctrine, templates, scripts,
workflows, station chapters: everything the agents need on this project that is not a record.
Done means the carve-out list is no longer architectural and no home defaults inside another.

## Approach

Two front-door variables, each defaulting to a directory that **echoes its own name** — the rule
the existing set already follows, which is why nobody has to memorize the mapping:

    agent-records:   .records   (unchanged; `records-root:` still accepted)
    agent-workspace: .dev       (new)

`agent-templates` and `agent-doctrine` are **retired as variables** and become fixed subpaths of
the workspace, so there is nothing new to declare and one `agent-workspace:` line moves them
together:

    .records/                      .dev/
      adr/ bugs/ design/ notes/      doctrine/     living normative prose
      plans/ reports/ tickets/       templates/    schemas instances mint from
      trackers/                      scripts/      deployed tools
      history.tsv                    workflows/    (or under doctrine/ — open Q3)

**The pair deliberately breaks the echo pattern — do not "fix" it.** The other three variables
name their own default (`agent-records`→`.records`, and both retired siblings echoed too). This one
does not, on purpose (settled 2026-08-18, human): the **variable** must name the concept precisely
for prose that explains *what the home is for*, while the **directory** must stay short and
conventional for a literal that appears at depth in ~30 files —
`.dev/doctrine/test/workflows/audit/GUIDE.md` versus
`.workspace/doctrine/test/workflows/audit/GUIDE.md`, where the second also stutters against
`workflows/`. Forcing one word to do both jobs compromises one of them. The consistency cost is
small because `DOCTRINE.md:223-224` already requires skills to write default paths **literally**
rather than as variables, so the mapping is stated wherever it is used and learned once. Document
it explicitly in the front-door section so it is learnable in one place.

**The two homes may coincide** (settled 2026-08-18, human). A legacy host declaring both at `dev/`
keeps working: those hosts were *already* mixed, so nothing is lost and no `git mv` is forced. The
consequence, stated rather than glossed: **`records.sh`'s reserved-name skip does not die — it
demotes.** Today it is architectural (every host nests doctrine and templates inside records);
after this it is legacy-compat, needed only where a host deliberately points both homes at one
directory. Greenfield hosts stop depending on it.

**Any other layout is a declaration, not a redesign.** A host preferring `.workspace/`, `.handbook/`,
or a legacy `dev/` writes one `agent-workspace:` line; the default only has to be right for a fresh
project.

### Why not the alternatives

- **One root** (`.agents/records/`, `.agents/doctrine/`, …) — the fewest variables, and the
  tempting answer to "too many dynamic paths." Rejected because it breaks the *only* variance that
  has ever been demonstrated: a brownfield host declaring `records-root: dev` cannot relocate
  records independently if records live inside the other home.
- **De-nest the three existing homes** (keep `agent-templates`/`agent-doctrine`, change their
  defaults from `<records>/x` to top-level) — kills the carve-outs without inventing a name.
  Rejected because it keeps three variables to express two concepts, and leaves two of them still
  without a variance case.
- **Leave it alone.** The carve-out list works today. Rejected because the parked feature cannot be
  specced without answering "where does the seed land," and that question is downstream of this one.

### Naming — four candidates burned, and why (hard-won; do not re-propose)

| candidate | killed by |
|---|---|
| `.agents/` | **Already adjudicated twice.** `2026-08-18-records-layer-init.md:173-174` + its rejected table `:1120`: *"This library already lives at `~/.agents/`. A project path that starts `.agents/` sends agents to the home directory."* Also **reverted** — `2026-07-17-library-refactor-plan.md` Task 6 was literally *"Relocate on-disk homes under `.agents/`"*, and the library migrated off it. |
| `.artifacts/` | **Inverts this library's own vocabulary.** 140+ uses of "artifact" in `skills/`, dominant sense = a record under management (`contractor:123` *"job artifacts in `<agent-records>/plans/`"*; `migrate.md:30`'s table header `\| legacy artifact \| store \|`). Would mean the artifacts live in `.records/` and the non-artifacts in `.artifacts/`. Externally it is a build-output convention connoting *disposable*, which invites gitignoring hand-curated doctrine. |
| `test/` | Conventional **source** directory for test suites across most ecosystems — defaulting there writes doctrine into the project's source tree. Also already claimed: `test` is one of the four station names (`context.sh:16`), so `.handbook/test/` and a top-level `test/` would be two meanings one level apart. |
| `test/` + `dev/` **undotted** | Undotted breaks the dotted = tooling-not-source signal every current home follows, which is what makes the `test/` collision bite. Dotted `.dev/` is a different string from the legacy undotted `dev/` records root and is **not** rejected — see below. |

**A fifth prior mention, checked and found non-binding.** `2026-07-17-library-refactor.md:310-312`
chose `.agents/` *"over `.artifacts/` (which mislabels source-of-truth as derived output) and over
bare `.design`/`.dev` (unclear ownership + root clutter)."* Three reasons it does not settle this:
(a) it rejected **two** domain-split roots, where "root clutter" is the argument — this proposal is
**one** directory that *replaces* `.handbook/`, so the root count is unchanged; (b) "unclear
ownership" was true in July because no front-door variable existed — that doc's §12 explicitly ruled
one out (*"a fixed default + a recorded pointer, not a config system"*), and `agent-workspace:`
closes exactly that gap; (c) the winner of that comparison is **dead** — `.agents/` was overturned
and `.records/` shipped, so the runners-up were never re-weighed. Its `.artifacts/` reasoning is
independently the same conclusion reached above, which is why that row stands.

The lesson worth keeping: the first four candidates were all **negative** definitions ("everything
that isn't a record"), and negative definitions name badly. *Workspace* names what the home **is** —
which is why it survives as the **variable** even though the directory is `.dev/`. Mild overload with
Cargo's workspace concept (this repo is Cargo-based) touches only the variable name, not a path, and
is judged acceptable.

## Risks

- **Re-flips feature 2's five consumers three days after it shipped.** They move from resolving
  `agent-doctrine` to resolving `agent-workspace`. Cheapest it will ever be — the variance case is
  still prospective and no sixth consumer has accreted — but it is churn, and the second flip in a
  week for the same files.
- **~30 files of resolution prose.** 24 files carry `agent-templates` (50 refs), ~10 carry
  `agent-doctrine`; `agent-records`'s 44 files keep their semantics but their sibling-defaults
  sentence changes.
- **Lint checks 14 and 15 encode the old literals** and would need rewriting; check 15's exemption
  is name-based (`is_pack_face()`, `skills-lint.sh:118-123`) and already known-fragile.
- **One deployed workshop** (the human's own, confirmed 2026-08-18) migrates by `git mv` + a door
  edit. No other install population exists.

## Open questions (for `grill` / `spec`)

1. **Does `records.sh` move to `.dev/scripts/`?** It is tooling, not a record, so the new rule
   says yes — and that would leave `.records/` as *purely* the eight stores. But its deployed path
   is referenced across the `agent-records` surface, making it the expensive half.
2. **Does `history.tsv` stay in `.records/`?** Unlike the other three carve-outs it is genuinely
   records-layer *state*, not tooling. Keeping it leaves exactly one reserved entry.
3. **Do `workflows/` live at `.dev/workflows/` or under `.dev/doctrine/`?** Today they
   are station-scoped (`.handbook/build/workflows/feature.md`), which argues for staying inside
   whatever holds the station chapters.
4. **What happens to `.handbook/`?** Presumably becomes `.dev/doctrine/` — which would make
   the parked feature's central question moot rather than merely deferred. Confirm, because it also
   relocates the install stamp (`.handbook/README.md`) and its three surviving policy-probe sites.
5. **Is there a legacy alias for `agent-workspace`?** `agent-records` accepts `records-root:` for
   history. A brand-new variable arguably needs none.
6. **Do the retired variables get a deprecation window,** or is the flip atomic? Nothing declares
   `agent-templates`/`agent-doctrine` today, which argues for atomic.
7. **What is the migration story for a host that declared `agent-doctrine:` after feature 2 shipped
   but before this lands?** Population is believed to be zero; confirm before assuming it.

## Grounding

Verified at draft time, not assumed:

- `records.sh:64,82` reserved-name carve-outs, and `:70`'s comment naming the nesting as the cause.
- `DOCTRINE.md:217-223` (the three homes, two defaulting under the first), `:236` ("partly
  prospective"), `:228` (`agent-doctrine: .handbook` as the canonical override example).
- `migrate.md:24-26` uses `dev/` as the worked example of a legacy **records** root.
- 5 consumer skills read `agent-doctrine:`; **0 writers** repo-wide.
- `agent-templates`: 24 files, 50 refs. `agent-records`: 44 files.
- `context.sh:16` — `STATIONS="design build test review"`; `test` is a station name.
- `.agents/` rejected in `2026-08-18-records-layer-init.md:173-174,1120`; previously the on-disk
  convention per `2026-07-17-library-refactor-plan.md` Task 6.
- "artifact" appears 140+ times in `skills/`, dominantly meaning a managed record.
- No `agent-workspace` reference exists anywhere in the repo — the variable name is unclaimed.
- `.dev` appears once, in `2026-07-17-library-refactor.md:312`'s rejected list, in the different
  form addressed above. No live `.dev` path or `.dev/` directory exists in the repo or the seed.
