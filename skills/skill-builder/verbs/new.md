# `/skill-builder new` — scaffold a new skill

Stand up a new `skills/<name>/` package against the proven pattern (`docs/DOCTRINE.md`), tier-templated
rather than one-size-fits-all. This turns "the five things Phase-by-phase hand-authoring built" into a
repeatable scaffold — it does not invent new doctrine, it applies the settled one.

## When to use

- Adding a new skill to the library.
- The user says "scaffold a new skill", "start a skill for X", "set up `/<new-name>`".

**Do NOT use** to add a verb to an *existing* skill (just add a `verbs/<verb>.md` and a dispatch-table
row by hand) or to migrate a skill from another shape (that's a one-off, judgment-heavy edit, not this
verb's job).

## Procedure

1. **Name + one-line role.** Get the skill's slug (`skills/<name>/`, lowercase, hyphenated) and a
   one-sentence statement of its job — this seeds the frontmatter `description:` draft, not the final
   copy (the human/agent still tunes it against the self-scoping rule below).

2. **Classify the tier** (`docs/DOCTRINE.md` § Self-init tiers) — ask, don't guess:
   - Does it own a durable project artifact store (a tracker, a rubric, a seed) that must exist before
     it can act? → **durable-home**.
   - Does it maintain a layer of the *host repo itself* in place, with nothing private to keep? →
     **in-place steward**.
   - Does it need a working area, but one that's fine to lose (gitignored scratch, lazily created)? →
     **scratch-only**.
   - Is it a pure router/transport with no storage at all? → **pure mechanism**.

3. **Write `SKILL.md`:**
   - Frontmatter: `name`, and a `description:` that **routes on its own** — states only this skill's
     job/domain, names no sibling to defer/disambiguate/contrast (the self-scoping rule; router and
     fragment exceptions are documented in `docs/DOCTRINE.md`). Keep it ≤ ~700 chars (hard cap 1024);
     quote it if it contains `: `.
   - A verb-dispatch table if the skill has more than one verb (thin router pattern — each verb's
     procedure lives in its own `verbs/<verb>.md`, read on demand).
   - A `## Edges` block (**every** skill gets one, even if all-empty):
     ```markdown
     ## Edges
     <!-- edges:<name> -->
     - produces: — (state what, once decided — or leave empty if genuinely none)
     - handoff: — (state the baton type, once decided — or leave empty)
     - consumes: — (state the input type, once decided — or leave empty)
     <!-- /edges:<name> -->
     ```
     Fill in real types only where they're real; an honest all-`—` is a legitimate disposition for
     in-place-steward/scratch-only/pure-mechanism tiers (`docs/DOCTRINE.md` table).

4. **Durable-home tier only — scaffold `init`:**
   - Draft the new skill's own `<new-skill>/verbs/init.md`: an idempotent home-scaffold
     (create-if-absent for each store the skill
     owns; never touch existing content) **plus** front-door self-registration, modeled on the
     `register-route.sh` mechanism (`docs/DOCTRINE.md` § Typed edges & registration) — content-vs-
     arrangement split, absent→append / present→replace-between-delimiters / malformed→report-and-stop.
   - Copy `skill-builder`'s own `scripts/register-route.sh` (the canonical reference — not another
     skill's copy) into the new skill's `scripts/`, unmodified except its header comment (which may
     name the new skill for orientation). Do **not** have the new skill call out to `skill-builder`'s
     copy at runtime — each durable-home skill bundles its own, so it stays self-contained and works
     installed alone (BL-6). `skill-builder check`'s drift pass verifies every deployed copy stays in
     functional sync with the reference going forward.
   - State the `built-against` stamp formula as **path-scoped to the new skill's own directory** —
     `git -C <skill-dir> log -1 --format=%h -- .`, never `git -C <skill-dir> rev-parse --short HEAD`
     (the latter collapses to one value across every skill on a monorepo skills-root, BL-7) — else a
     version string, else `v0-<date>`.
   - State the **fixture caveat** explicitly in the new skill's `init` verb if this scaffold is being built
     *inside* the same library that authors the doctrine: never register against that library's own
     real front-door; exercise against a throwaway fixture.

5. **Other tiers:** no `init` verb. State the "no home" disposition in the skill's body (one sentence)
   so it's a recorded fact, not a silent gap.

6. **Wire consumption:** add the skill to the host's install mechanism (however it lists/symlinks
   skills) and mention it in the library's own README/inventory, if one exists — `scripts/skills-lint.sh`
   check 4 flags a missing README mention.

7. **Gate.** Run `scripts/skills-lint.sh` → `fails=0`. A fresh skill commonly WARNs on nothing if the
   description and edges are well-formed; treat any FAIL as a scaffolding bug, not a thing to suppress.

## Done when

`skills/<name>/SKILL.md` exists with a self-scoping description and a well-formed `## Edges` block
(every kind stated, none empty by omission); a durable-home skill also has a working, idempotent
`init` verb; the lint gate passes; the skill is wired into the host's consumption + inventory.
