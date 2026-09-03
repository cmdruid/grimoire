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

3. **Record-writer?** — ask, orthogonal to the tier: *will this skill write typed records
   into fixed `.records`?* Not automatically durable-home; notepad is the worked
   example of a records-path client.
   - **Yes** → scaffold, in `SKILL.md` (see `docs/DOCTRINE.md` § Record-writing skills):
     - direct construction beneath fixed `.records/` and the
       fixed templates home `.agents/skilldata/<name>/templates/`; and, for a skill that reads or writes
       doctrine, direct construction beneath fixed `.agents/skilldata` — its doctrine home is
       `.agents/skilldata/<name>/doctrine/`;
     - the four-key in-package contract — do not send the agent to another
       skill for those bytes. State: the four keys (`doctype`, `status`,
       `schema`, `tags`) and every package-owned schema identifier; `status`: `draft` | `published` live,
       `archived` closed; optional `stage` (non-empty if present; values
       declared here if this skill uses the key); the dated slug
       (`YYYY-MM-DD-<slug>.md`); the record-link form (`→ <store>/<file>.md`);
       file-mode close → `archived`, not a ledger disposition word. The
       registered contract is `specs/records-front-matter.md`. Do not scaffold retired generic
       timestamps/revisions or a `stage` key onto templates;
     - a no-floor sentence: missing `records.sh` is not an error; journal standup is
       never a precondition;
     - `## Project templates` (only named body scaffolds the skill actively resolves, or an explicit
       "none"). A nonempty inventory also gets a routed `setup` procedure that names every listed
       file, deploys it absent-only, and preserves schemas, validators, and migrations in-package.
       Ordinary work resolves canonical incumbent → recognized-legacy refusal → bundled read-only
       fallback and never creates `.agents/skilldata`.
   - **No** → do not add those sections.

3b. **Project hooks?** — ask, orthogonal to the tier and to record-writer: *does
    this skill have a named-seam loop a project might extend?*
    - **Yes** → document each known seam at
      `.agents/skilldata/<name>/hooks/<seam>.md`. The owner may bundle an
      absent-only skeleton and routes explicit `setup` when the hook is meaningful to predeploy;
      do not scaffold one generic hooks file and do not add a lint check that requires project files
      to exist.
   - **No** → nothing.

3c. **User-global skilldata?** — ask independently of project durability: *does this skill need
    user-owned data that must span projects, and what concrete need rules out both project storage
    and installed package bytes?* Default to **No**. A durable-home answer does not imply global
    storage.
    - **Yes** → name a fixed owner-local path beneath
      `~/.agents/skilldata/<new-skill>/...`, define the internal artifact contract, initialization
      mode, permissions and sensitive-data behavior, and scaffold this exact section in `SKILL.md`:

      ```markdown
      ## Global skilldata

      - Scope: user-global, <artifact boundary>.
      - Path: `~/.agents/skilldata/<new-skill>/<owned-tail>/`.
      - Access: read-only | read-write; <initialization behavior>.
      - Safety: <unsafe-state, permissions, and sensitive-data behavior>.
      - Justification: <why project and package storage are unsuitable>.
      ```

      A global-only package states that it writes no project data. A package owning both scopes also
      states project/global precedence and the reviewed transfer or materialization boundary. Add no
      project setup unless steps 2, 3, or 3b independently require one.
    - **No** → add no `## Global skilldata` declaration and no global path.

4. **Write `SKILL.md`:**
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

5. **Durable-home tier only — scaffold `setup`:**
   - Draft the new skill's own `<new-skill>/verbs/setup.md`: an idempotent home-scaffold
     beneath `.agents/skilldata/<name>/<owned-kind>/` (create-if-absent for each store the skill
     owns; never touch existing content or another owner namespace). Durable state does not imply a
     front-door route.
   - Setup may create its declared workspace when absent. Before
     each mkdir, recheck that every existing parent is a real directory and not
     a symlink; refuse unsafe parents without partial writes.
   - Do not scaffold `repair` by default. Add it only when an initialized layer has a narrow
     package-managed operational surface that can drift independently of project configuration or
     data; it must call setup's reconciler with a smaller write set and direct missing prerequisites
     back to setup.
   - Separately decide whether the skill owns a justified always-loaded route. When it does, model
     the front-door registration mechanism in `docs/DOCTRINE.md` § Typed edges & registration:
     content-vs-arrangement split, absent→append / present→replace-between-delimiters /
     malformed→report-and-stop. Bundle the skill's **own** registration script (self-containment: no
     runtime call-out to another skill's copy — it must work installed alone, BL-6), and state the
     `built-against` stamp formula as **path-scoped to the new skill's own directory** —
     `git -C <skill-dir> log -1 --format=%h -- .`, never
     `git -C <skill-dir> rev-parse --short HEAD` (the latter collapses to one value across every skill
     on a monorepo skills-root, BL-7) — else a version string, else `v0-<date>`.
   - State the **fixture caveat** explicitly when this scaffold is being built *inside* the same
     library that authors the doctrine and registration was selected: never register against that
     library's own real front door; exercise against a throwaway fixture.

6. **Other tiers:** no `setup` merely because of tier. Keep setup only when steps 3 or 3b identified a
   deployable project surface; otherwise state the "no home" disposition in the skill's body (one
   sentence) so it is a recorded fact, not a silent gap.

7. **Wire consumption:** add the skill to the host's install mechanism (however it lists/symlinks
   skills) and mention it in the library's own README/inventory, if one exists — `scripts/skills-lint.sh`
   check 4 flags a missing README mention.

8. **Gate.** Run `scripts/skills-lint.sh` → `fails=0`. A fresh skill commonly WARNs on nothing if the
   description, edges, and any global-skilldata declaration are well-formed; treat any FAIL as a
   scaffolding bug, not a thing to suppress.

## Done when

`skills/<name>/SKILL.md` exists with a self-scoping description and a well-formed `## Edges` block
(every kind stated, none empty by omission); a durable-home skill also has a working, idempotent
`setup` verb; the lint gate passes; the skill is wired into the host's consumption + inventory.
