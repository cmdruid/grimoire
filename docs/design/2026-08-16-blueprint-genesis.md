---
doctype: design
status: current
created: 2026-08-16
updated: 2026-08-17
tags: [spec]
---

# Genesis on blueprint — Spec

Argued 2026-08-16 on stream `grok`. Grill resolved dest-suggestion, dest vs
file name, confirm-to-delete, land-with-open-questions, walk-until-outside-every
repo, and project name = dest basename. Four `/blueprint review` passes
returned `needs-rework` (passes 3–4 via Codex). Accepted findings are folded
here; two pass-4 items were declined (helper script as a spec blocker;
per-guard mutation matrix as test-plan depth). Human review: this library’s
scope of work names `bootstrap`; the new `blueprint` package does not. No
open decision branches remain. Accepted 2026-08-17 (`status: current`).

## Problem

Nothing in this library turns the empty-world moment — no directory, no git,
only an idea — into a repository whose founding prose is a consequence of the
design, not a template pick.

Workshop `setup` stands a workshop up on an **existing project directory**: it
resolves `<root>`, runs `git -C <root> branch --show-current` for trunk (it
does not offer `git init`), and writes or integrates the `AGENTS.md` **door**
(routing pointer), not founding conventions. `blueprint` today assumes a root
it can write into. Contractor owns roadmaps, plans, and runbooks — those are
the wrong day-one files.

This library currently ships `skills/bootstrap/` for that empty-world job: a
second grill plus a five-document founding set (README, AGENTS, ARCHITECTURE,
ROADMAP, RUNBOOK). ROADMAP/RUNBOOK collide with contractor. The interview is
already `blueprint grill`. The name also collides with the workshop face’s
“greenfield bootstrap.” That package is this slice’s teardown, not a
capability blueprint should narrate.

Until genesis lives on `blueprint` and `skills/bootstrap/` is gone, “start a
new project from scratch” is either unrouted or routed at the stale skill.

## Goal

Genesis lives on `blueprint` as two verbs around the existing spine (`new`
mints, `grill`/`spec` fill **in place**, `deploy` materializes). A founding
spec is a working file that is **safe to delete** after a complete deploy
because every settled byte under a mapped heading has been copied into the
three founding documents.

This library: `skills/bootstrap/` is gone (three files, README inventory row,
pack minus-list token). Host symlink cleanup is install-time, not this tree.

## Approach

**Chosen:** two thin verbs on blueprint.

- `/blueprint new <name>` writes `./<name>.md` in cwd (not a records mint, even
  on a workshop host). Mint only — no interview.
- That file is a **founding-shaped spec** (same `spec` type, tagged
  `founding`). Its sections *are* the seeded roots; each names which founding
  file it feeds. Extra **H2s** are out of scope by construction until the
  human finds them a home or discards them.
- `/blueprint grill` and `/blueprint spec` aimed at a founding file fill the
  six map sections **in place**. They do not reshape to `templates/spec.md`,
  do not records-mint, do not strip `founding`, and do not add unmapped H2s.
  They never auto-detect a founding file in cwd.
- `/blueprint deploy <file>` reads the spec, prompts **new directory vs cwd**,
  writes README + AGENTS + ARCHITECTURE by lossless copy-through, `git init`,
  first commit. Remote only on explicit request, default private.
- The working file is **never committed**. It may remain untracked in dest if
  dest is cwd. Deploy’s done-when is a completeness walk: leftover (unmapped
  **H2** or authored bytes outside mapped bodies) → refuse; mapped gaps the
  user accepts become one grouped `## Open questions` per fed file (never
  inline `TODO:`). After success, prompt confirm-to-delete the working file
  (explicit yes required; default is leave it).

**Rejected:**

- No materialize verb — drops the only unique capability.
- `/blueprint init` — in this library `init` means durable-home self-init, not
  “new project.”
- Calling the working file a “seed” — the workshop already owns that word
  (handbook projection + stamp).
- Founding ROADMAP/RUNBOOK — contractor’s types; wrong day-one files.
- Session-bound grill with no file — blueprint’s state is artifacts; a file in
  cwd is the cheap “abort costs no repo” rule.
- Binding `<name>` across `new` and `deploy` — naming is a late design
  decision. `new` needs a filename; grill often improves the name; `deploy`
  already confirms dest.
- A third `Name:` field — dest is already confirmed at deploy; a third
  identifier drifts.
- Renaming workshop “deploy” so blueprint can have the word — there is no
  workshop `deploy` verb. Shared verb words already exist (`setup`, `review`,
  `check`). Discriminator is the object: workshop vs founding spec / new repo.
  Descriptions self-scope; no sibling pointer.
- Suggesting `$HOME/<name>` as dest — dumps into the home directory.
- Auto-delete of the working file — a design record disappears before anyone
  checks the projection.
- Auto-promoting empty sections to `## Open questions` and landing — silent
  land over gaps is the failure deploy exists to prevent.
- Refusing every incomplete spec — blocks a founding repo whose architecture
  is settled and whose conventions are not.
- Treating `spec` on a founding file as “unchanged” feature-spec — live `spec`
  rewrites to `templates/spec.md` and would destroy the map.

Workshop prose stays (“deployed structure”, “workshop deployed, not copied”).
Precision only: you deploy the **workshop**; the handbook is one surface that
gets **seeded**. No vocabulary sweep. `lazy-deploy` (records template
convention) is a different sense and stays.

**Two surfaces.** This **spec** names `bootstrap` as library teardown. The
**blueprint package** (`SKILL.md`, `verbs/`, `templates/`, `docs/ideal-use.md`,
`description:`) does not: no sibling name, no “formerly,” no alias, no
redirect. Descriptions self-scope.

**Greenfield check:** do not add a compatibility shim or a `bootstrap` alias
inside blueprint. Delete the old package; do not keep a name that collides
with the workshop face.

## Mechanism

### Verb table

| Invocation | Does | Disk |
|---|---|---|
| `new <name>` | Mint `./<name>.md` — founding-shaped spec, empty of design content | that file only |
| `grill` / `spec` `[doc]` | If `[doc]` is founding-shaped: fill the six map H2s **in place**. Else: existing feature-spec behavior | the named file (founding) or a `design/` spec (feature) |
| `review <doc>` | If founding-shaped: six-H2 + leftover/gap rubric. Else: existing two-axis feature-spec review | context (+ needs-rework write-back) |
| `deploy <file>` | Project the spec into a repo + three founding docs | the new tree (not the working file) |

Bare `/blueprint` stays `brainstorm` (in-repo ideation). Genesis is explicit
`new`.

`SKILL.md` stays the router. Procedures live in `skills/blueprint/verbs/new.md`
and `skills/blueprint/verbs/deploy.md` (`deploy` is land-sized). `grill` /
`spec` / `review` / `brainstorm` stay inline **and gain a founding-shaped
branch** (see below).

### SKILL.md edits (required; not “just add two verb rows”)

Live lead says `/blueprint` never lands. Retract that for `deploy` only:
`deploy` materializes a **new** repository; it does not land onto a host
trunk. Building, trunk landing, and debrief stay out of blueprint.

**Probe exemption.** The environment probe’s records-mint / output-home path
applies to `brainstorm`, feature `spec`, and ADRs. It does **not** apply to
`new` or `deploy`, and it does **not** apply to `grill`/`spec` when the named
file is founding-shaped. Those stay on the cwd working file.

**Status.** Founding files stay `status: open`. They are working files, not
the living feature spec. Do not promote them to `status: current`.

**Founding-shaped `review`.** When the named file is founding-shaped, `review`
uses the six map H2s + leftover/gap rules. Groundedness is against the
**bundled** `templates/founding.md`, the deploy procedure (`verbs/deploy.md`
once it exists), and live behavior — not this library design doc (it does not
travel with a standalone install). It does **not** grade the file as
`templates/spec.md`. Do not promote `status`. Feature-spec `review` is
unchanged.

**Structure line.** S1 adds `templates/founding.md` and `verbs/new.md`. S2
adds `verbs/deploy.md`. Do not cite `verbs/deploy.md` from `SKILL.md` until S2
creates it (lint check 2). `skills/blueprint/docs/ideal-use.md` notes that the
feature-spec arc still ends at the accepted spec; genesis is `new` → in-place
`grill`/`spec` → `deploy`. None of those files name `bootstrap`.

### Founding spec shape

**One source of truth:** `skills/blueprint/templates/founding.md` owns the six
exact H2 strings. The table below is a pointer; if they drift, the template
wins and this spec is updated to match. `new` copies the template. Deploy
matches H2s by exact string.

| Spec section (exact H2; template owns the string) | Feeds |
|---|---|
| Problem & users | `README.md` |
| Scope & non-goals | `README.md` |
| Architecture (components, boundaries, interfaces) | `docs/ARCHITECTURE.md` |
| Rejected alternatives and why | `docs/ARCHITECTURE.md` |
| Working conventions & layout | `AGENTS.md` |
| Declared verification command (intended, not proven) | `AGENTS.md` |

`ARCHITECTURE.md` is the highest-value landing: settled design **and**
rejects. A reject without its reason is not worth recording.

Founding `AGENTS.md` is **agent conventions + intended gate**, not a workshop
door. The door arrives later, if ever, via workshop `setup` on the existing
repo (`integrate, never clobber` — founding conventions survive). README
links to `docs/ARCHITECTURE.md`.

**Parser (one grammar; deploy and founding `grill`/`spec`/`review` share it).**

1. **Front-matter.** If the file begins with a line `---`, YAML through the
   next line that is only `---`. `tags:` is a YAML sequence; `founding` is
   present iff that sequence contains the string `founding`.
2. **Structural H2.** A line matching `^##[ \t]+\S` that is **not** inside a
   fenced code block (`` ``` `` or `~~~`). A `##` line inside a fence is body
   content, not a heading.
3. **Body span** of an H2 = bytes after that heading line until the next
   structural H2 or EOF.
4. **Permitted chrome** (discarded, not leftover): the front-matter, one ATX
   H1 (`^#[ \t]+`), and blank lines around those.
5. **Leftover H2** = a structural H2 whose exact string is not in the
   template map. **Authored leftover** = any non-whitespace byte outside
   permitted chrome and outside a mapped body (pre-map prose, trailing
   prose). Either leftover class → refuse; no land-with-gaps. Everything in a
   mapped body (H3s, lists, tables, fences) copy-throughs.

Completeness compares those extracted body spans to the dest headings
byte-for-byte (modulo one trailing newline).

Minted front-matter (template):

```yaml
doctype: design
status: open
created: <date>
updated: <date>
tags: [spec, founding]
```

H1 is `<name>` (a working title). Grill may change H1. H1 does **not** rename
the repo (see *Project name*). H1 is discarded at project time (dest basename
is the project name).

### `new <name>`

1. `<name>` is required. Never invent one.
2. Strip one trailing `.md` if present (`new foo.md` → `foo.md` on disk, stem
   `foo`).
3. Reject if empty, `.`, `..`, or contains `/` or `\`.
4. Refuse if `./<name>.md` already exists. Do not overwrite.
5. Write only that file, from `templates/founding.md`: the six H2s, each
   once, and **empty** bodies (no coaching chrome). Do not interview.

`new` is legal inside an existing git repo. The working file is the
abort-costs-nothing rule; the repo is created only at `deploy`.

### Founding-shaped `grill` / `spec`

A file is **founding-shaped** iff it has `founding` in `tags:` **and** its H2
set is exactly the six map strings, each appearing once. A duplicate mapped
H2 or an extra unmapped H2 fails the shape.

- **Founding-shaped** → fill those six sections in place. Do not rewrite to
  `templates/spec.md`. Do not mint a `design/` record. Do not strip
  `founding`. Do not add an H2 that is not in the map. Who/when notes go
  **inside** the mapped section as a whole line in this exact form (roman,
  not italic): `Settled: YYYY-MM-DD.` Never a new H2. Do not promote
  `status`.
- **No `founding` tag and H2s are not the map** → existing feature-spec
  `grill`/`spec` (may reshape / records-mint).
- **Otherwise** (tag without the exact map, map without the tag, duplicate
  mapped H2) → refuse: restore the shape with `/blueprint new` or fix the H2
  set. Do not reshape. Do not deploy-path this file.

They never scan cwd for a founding file. The user names `[doc]`.

### `deploy <file>`

`<file>` is required and must exist. Physically canonicalize it (`realpath` —
the file exists, so this cannot fail) before any dest prompt. Missing file →
refuse.

**Founding-shaped gate.** Require the definition above (tag + exactly the six
map H2s, each once). Otherwise refuse in one line: not a founding spec; use
`/blueprint new`. Name a duplicate H2 if that is why. Do not dump a leftover
list for a feature spec. Do not enter the dest prompt.

**Inside a repo / forbidden git context** (one test, used everywhere —
suggestion legality, typed dest, cwd dest, and again immediately before
`git init`).

Run every `git` probe with discovery vars unset (`GIT_DIR`, `GIT_WORK_TREE`,
`GIT_COMMON_DIR`, `GIT_CEILING_DIRECTORIES`). Otherwise an inherited ceiling
can hide the enclosing checkout (`GIT_CEILING_DIRECTORIES=<root>` makes
`git -C <root>/docs rev-parse --show-toplevel` fail on this host).

1. Walk the candidate **upward to the first existing directory** (the
   candidate itself if it exists, else its nearest existing ancestor;
   filesystem root if nothing exists). One hop is not enough.
2. `realpath` **only that existing ancestor** (`realpath` of a missing dest
   exits 1). Build the candidate’s canonical path by appending the missing
   suffix to that ancestor, normalizing `.` / `..`. A symlink ancestor that
   resolves into a checkout counts as inside it.
3. Refuse if any of:
   - `git -C <ancestor> rev-parse --show-toplevel` succeeds **and** the
     canonical candidate is that toplevel or a path under it;
   - `git -C <ancestor> rev-parse --is-inside-git-dir` is `true`;
   - `git -C <ancestor> rev-parse --is-bare-repository` is `true`.

Do not test `test -d .git` (wrong at worktrees, silent on subdirs). After dest
exists (created or was empty), **re-run this test on dest itself** immediately
before `git init`.

**Destination — one prompt, once.**

**Empty** (one definition). A directory is empty iff every entry is a dotfile
(`name` starts with `.`) or is the working spec file — **except** a `.git`
entry (file or directory), which always refuses, even if git does not
recognize it. Use this for suggestion legality, typed dest, and cwd dest.

1. **Create a new directory** — confirm the path. Always confirm; never create
   silently. Suggestion: first legal candidate below, else no suggestion (ask
   for a path). A candidate is legal when `inside a repo` is false **and** it
   does not exist or is empty.
   Walk, in order:
   1. `cwd/<stem>`
   2. Then, starting at `dir = cwd` and walking `dir = parent(dir)` until
      filesystem root: `dir/../<stem>` (sibling of `dir`).
   Acceptance fixture only (do not copy this path into portable skill prose):
   from this stream’s worktree
   (`/Users/cscott/Repos/grimoire/.workstreams/grok`, stem `foo`) that walk
   yields `/Users/cscott/Repos/foo` — not `.workstreams/foo`.
2. **Use cwd** — allowed only if `inside a repo` is **false** for cwd and cwd
   is empty.

`<stem>` is the working file’s stem (`foo` from `./foo.md`). It is only the
**default** dest name. The confirmed dest may differ. No forced `mv` of the
working file.

**Refuse (do not prompt past these)** — typed dest **and** cwd dest:

- Dest is inside a git repository — name the enclosing toplevel, stop.
- Dest exists and is not empty. Never merge.
- Dest exists as a file.

An existing **empty** directory that is not inside a repo is allowed (then
`git init` inside it).

**Project name.** The dest directory’s basename (resolved absolute path) is
the project name that lands in README / AGENTS / ARCHITECTURE titles and in
the first-commit message. Spec H1 is the design title and may match or not.
File stem is only the working file. If dest is cwd, the project name is cwd’s
basename.

**Gaps confirm (mapped sections only).** After dest is accepted, walk the six
map H2s (the shape gate already refused a missing or duplicate H2):

- **Classify** each mapped body: strip whole lines matching
  `^Settled: [0-9]{4}-[0-9]{2}-[0-9]{2}\.$` and remaining whitespace.
  Remainder empty → **gap**. Any remaining byte (prose, list, table, fence,
  code) → **settled**. Who/when-only is a gap. No italic / `TBD` / `<>`
  special cases (founding template bodies are empty; those tokens, if a human
  types them, are settled content).
- **Leftover** cannot reach this walk if the shape gate held. If an H2 not in
  the map appears anyway, refuse, list them, stop. No confirm.

If any gap exists, list them by section → fed file and ask to **land with
open questions**. No → stop, go back to grill; dest is not created (or not
written). Yes → each fed file gets **one** `## Open questions` section
**after all of that file’s mapped sections**, listing every accepted gap that
feeds it (named, never inline `TODO:`). Do not interleave an Open questions
heading per gap. An empty-mint (all six empty) is this path with six gaps,
not a special case.

**Materialize — lossless copy-through.**

1. Create dest if needed. Track **every path this run creates** (dest itself
   if created; `docs/`; the three project files; `.git` if this run inits).
2. Write three **project** files (`README.md`, `AGENTS.md`,
   `docs/ARCHITECTURE.md`). `git init` also writes `.git` metadata — that is
   not a fourth project file. For each mapped H2 in **template/map order**:
   if settled, copy its extracted body span **verbatim** under a heading of
   that same H2 string; do not paraphrase. Two H2s that feed the same file
   concatenate in map order. Then, if that file has accepted gaps, one
   `## Open questions` section after those mapped sections. Front-matter,
   working-file H1, and permitted chrome are omitted. Each dest file’s only
   title line is `# <project-name>`.
3. After README’s mapped sections and its Open questions (if any), append one
   paragraph, not inside a copied body:
   `See [Architecture](docs/ARCHITECTURE.md).`
4. Re-run the forbidden-git-context test on dest (sanitized env). Then
   `git init`. Use the user’s `init.defaultBranch`; do not impose a branch
   name.
5. First commit: **exactly** those three project paths. Message:
   `Add founding documents for <project-name>`. No attribution trailers. Do
   not add `LICENSE` or `.gitignore`.
6. The working file is never staged and never in that commit. If dest is cwd,
   it may remain on disk as an untracked file.

**Materialize failure.** On any failure from the first mutation through
post-commit verification (including writing `docs/` or a project file),
delete **only run-owned paths**. If this run created dest, remove dest
entirely. If dest was a pre-existing empty directory, remove what this run
wrote. Never delete a pre-existing `.git` we refused to accept (we never
start in that case). Report the failure. Do not prompt to delete the working
file. Retry is then possible.

Completeness = every settled mapped body appears **byte-for-byte** (modulo a
single trailing newline) under its heading in the fed file. That is the
delete-safety proof.

**Confirm-to-delete (after a successful deploy, including a gappy land).**
Prompt: the working file is safe to delete; delete it? **Explicit yes**
required. Anything else leaves it. Delete only that file. A delete failure
is reported; deploy has already succeeded. No prompt if deploy refused.

**Remote — only on explicit request.** Never create one as a default. When
asked: confirm visibility (default **private**), owner/namespace, and
repository name; then create and push. Use `gh repo create` when `gh` is
available; otherwise print the commands and stop. Never invent a remote URL
or an owner.

**Re-deploy** is not a thing. Dest exists and is not empty → refuse. After a
successful deploy the dest tree is the source of truth. A later grill of the
working file cannot be re-projected; “safe to delete” is not “iterate
deploy.”

### What this library updates

Do **not** delete `skills/bootstrap/` until `new`, `deploy`, the founding
`grill`/`spec` branch, and the description triggers exist (S4 last). Genesis
must route before the old package disappears.

When that is true:

- Delete `skills/bootstrap/` in full (`SKILL.md`, `verbs/grill.md`,
  `verbs/land.md`).
- Drop the README inventory row for `bootstrap`.
- README pack minus-list: drop `bootstrap` from “minus `agent-council`,
  `bootstrap`, and `skill-builder`.”
- Retitle the README `blueprint` inventory row so it names genesis (`new` /
  `deploy`).
- Update the `skills/clankshop/PACK.md` helper blurb for blueprint
  (content-only; no `version:` bump — member set unchanged).
- **Boundary-audit:** leave dated tables that `expects:` the old skill as
  history (do not rewrite those winners). **Edit only the 2026-08-16 26-case
  “current baseline” sentence:** it becomes the historical **full-roster**
  baseline; genesis routing is superseded by the new battery. **Add a new
  dated genesis battery** (descriptions only) with the prompts in *Routing*.
  Do not re-run the 26-case roster expecting the old skill.

`install.sh` is a glob; no hardcoded skill name to edit. Host symlink
`~/.claude/skills/bootstrap` is an install concern
(`./install.sh --remove bootstrap`), not this tree.

Dated design docs that mention the old skill stay (history). The 2026-08-16
contractor plan’s “retirement is out of scope” is superseded by this spec.

### Routing

Blueprint `description:` gains genesis triggers (`new`, `deploy`, new project
/ no repo yet / founding spec) without naming the workshop face or
`bootstrap`. Discriminator vs workshop: **whether the user wants a new
repository** and **whether the object is a founding spec**. (`new` is legal
inside an existing repo, so “does a repo already exist?” is no longer
sufficient by itself.)

Keep the description under 750 characters (lint WARN above that; FAIL at
1024). Cite `verbs/new.md` and `verbs/deploy.md` from skill markdown so lint
**check 11** passes (orphan verb files). Cite `templates/founding.md` so
**check 2** (bundled ref → file) passes — that is not check 11.

New genesis battery (add; do not rewrite dated tables):

| prompt | expects |
|---|---|
| idea → think it through → get a repo | `blueprint` |
| start a new project from scratch; grill the design | `blueprint` |
| deploy this spec (founding file in cwd) | `blueprint` |
| deploy the workshop / set up the agent framework on this existing repo | `clankshop` |
| stand up the development system on this project | `clankshop` |

Do not name siblings in the description to draw that contrast.

### Pack / isolation / edges

`blueprint` is already a pack helper. `deploy` is the one verb that may create
a directory and `git init`. Feature `brainstorm`/`spec` still resolve a root;
`new` and founding `grill`/`spec` do not.

Patient-zero: `deploy` never targets this library’s real `AGENTS.md`. Cwd dest
requires `inside a repo` false, so a run from this checkout cannot land on it.

Typed edges: keep `produces: spec` and `handoff: spec` (the feature-spec
baton). Add `produces: founding-documents` and `handoff: git-repository`
(genesis baton: a fresh repo carrying three founding documents and no code).
Feature composition still ends at the accepted spec; genesis ends at the
repo. Do not name a successor skill. The new types will orphan-WARN (no
consumer); WARN ≠ FAIL.

### Decisions (who / when)

Settled in `/blueprint brainstorm` on stream `grok`, 2026-08-16 (human
confirmed): new/deploy, three docs, completeness map, no ROADMAP/RUNBOOK, no
`init`, no “seed,” no auto-delete, discriminator, patient-zero.

Settled in `/blueprint spec` grill, 2026-08-16 (human):

| # | Decision | Pick |
|---|---|---|
| 1 | Dest suggestion when cwd is a repo | Confirm always; prefer first legal outside-repo path |
| 2 | `<name>` vs dest | File stem is default dest only; dest may differ |
| 3 | Working file after success | Confirm-to-delete; explicit yes; no auto-delete |
| 4 | Incomplete spec | Explicit “land with open questions”; else stop |
| 5 | Suggested dest still inside a repo | Walk `parent(dir)/<stem>` until outside **every** git repo |
| 6 | Project name in the docs | Dest directory basename |

Settled by folding review passes 1–4 (author, 2026-08-16 / 2026-08-17):
leftover = unmapped H2 or authored leftover; copy-through; founding
`spec`/`review` in place; ancestor walk; sanitized git probes; ATX-H2-outside-
fences parser; unique H2s; dest H1 `# <project-name>` only; grouped Open
questions; working file never committed; founding review on
`templates/founding.md`; keep `handoff: spec`; full run-owned rollback;
genesis battery is the live genesis baseline. Declined: helper script as spec
blocker; per-guard mutation matrix. Human review 2026-08-17: spec names
`bootstrap` as library teardown; blueprint package stays green.

## Verification

Two populations. Do not mix them.

**Genesis works** (the capability):

- README `blueprint` inventory row names `new` / `deploy`
- PACK.md helper blurb for blueprint
- The **new** genesis battery (live genesis baseline)

**This library’s teardown** (`bootstrap` is gone) — live surfaces only, not
every historical mention:

- `skills/bootstrap/` (the three files)
- README inventory row + pack minus-list token `bootstrap`
- `./install.sh --list` does not show `bootstrap`

Dated `docs/design/*` and dated audit tables that name the old skill stay. A
grep that counts those as leftovers is the wrong class.

Checks:

- `/blueprint new foo` in an empty temp dir creates `./foo.md` with the six
  map H2s, the `founding` tag, and **empty** bodies. Second `new foo`
  refuses. `new foo/bar` refuses.
- `spec` / `grill` on that file leave the six H2s and the tag; they do not
  mint a `design/` record; they do not write Problem/Goal/Approach as H2s.
- `deploy` on a feature spec (no tag, or map H2s absent) refuses in one line;
  dest is not prompted.
- Tag XOR six H2s: `deploy` and founding `spec` refuse.
- Duplicate mapped H2: `deploy` refuses and names it; dest is not created.
- A filled founding spec plus one leftover H2: `deploy` refuses and names the
  leftover; dest is not created.
- A complete spec, dest = suggested new dir outside any git repo: directory
  exists; each settled body appears verbatim under its H2 in the fed file;
  `git` inited; first commit is exactly those three paths; working file still
  at the original path and **not** in the commit; project-name strings match
  dest basename, not the file stem, when those differ.
- Same spec, dest = cwd (empty dir **not** inside a git repo that already
  holds `foo.md`): three docs written; `foo.md` unstaged / uncommitted.
- Cwd = this worktree, dest = create new dir: suggestion is sibling of the
  **main** checkout (`…/Repos/<stem>`), never `.workstreams/<stem>`. A typed
  path inside the repo is refused. Cwd dest is refused (`inside a repo`).
- Typed dest `<main-checkout>/nope/<stem>` with `nope` absent: refuse, name
  the enclosing toplevel, dest not created (ancestor walk, not one hop).
- Typed dest `<checkout>/.git/nope/<stem>`: refuse (`--is-inside-git-dir`).
- Typed dest under a bare repo, or dest that `realpath`s into a checkout
  (symlink): refuse.
- Cwd = empty subdirectory of a checkout: cwd dest refused; no nested
  `git init`.
- `git init` or first commit fails after dest was created: dest is removed
  (or restored to empty); retry is possible; no delete prompt.
- Gaps: a spec with two empty mapped sections that feed the same file lists
  both, waits. On no, nothing is written. On yes, that file has one
  `## Open questions` after its mapped sections, with both items.
- Pre-map prose or a leftover H2: refuse before dest. A `##` line inside a
  fence is not a structural H2.
- Delete prompt fires after success; “no” leaves the file; “yes” removes
  only that file.
- Completeness: `diff` of each settled mapped body against the corresponding
  heading in the fed file is empty (modulo one trailing newline).
- Routing probe: the **new** genesis battery — genesis → `blueprint`;
  workshop setup → `clankshop`. Dated audit-table winners unchanged.
- After this slice, the genesis battery has exactly one expected winner
  (`blueprint`). `skills/bootstrap/` is absent. `./install.sh --list` does
  not show `bootstrap`. The README skill table has no `bootstrap` row.
- Lint: `skills/skill-builder/scripts/skills-lint.sh` `fails=0` on blueprint
  after the verb add + description change.

**Red-proof (absence / refuse guards).** Each refuse must be exercisable with
the guard deleted. A fixture that cannot contain the forbidden state does not
count.

- `new`: missing name; empty name; `.`; `..`; `/`; `\`; existing
  `./<name>.md`.
- `deploy`: missing file; feature spec; tag XOR H2s; duplicate mapped H2;
  leftover H2.
- Dest: inside a worktree/checkout; `<checkout>/nope/foo` with `nope` absent;
  `<checkout>/.git/nope/foo`; under a bare repo; symlink ancestor into a
  checkout; dest exists and is not empty; dest exists as a file; dest
  contains a `.git` entry; cwd dest inside a checkout;
  `GIT_CEILING_DIRECTORIES` set to the enclosing root (probe must still
  refuse).
- Prompts: blank dest confirmation (nothing created); blank delete response
  (file left); no remote request (no remote). Remote-confirm path uses a
  **stubbed** `gh`, not a live network create.

## Slices

Implement in this order. **One ship unit** — S1–S4 land together. Slices are
verify-gates inside that unit, not independently mergeable. Do not delete
`skills/bootstrap/` before S4.

| id | does | verify | paths |
|---|---|---|---|
| S1 | `templates/founding.md` + `verbs/new.md`; founding `grill`/`spec`/`review` branch; probe exemption; retract “never lands” for `deploy` only; ideal-use note. Do **not** cite `verbs/deploy.md` yet | temp-dir `new foo` / refuse-existing / refuse-slash; `spec` on that file stays map-shaped | `skills/blueprint/templates/founding.md`, `skills/blueprint/verbs/new.md`, `skills/blueprint/SKILL.md`, `skills/blueprint/docs/ideal-use.md` |
| S2 | `verbs/deploy.md`; dest ancestor-walk + sanitized git probes + git-dir/bare/symlink/`.git`-entry refuse; unique H2s; parser; completeness; copy-through; grouped Open questions; first commit; delete prompt; remote-on-request; full run-owned rollback; cite the verb file from `SKILL.md` | dest / leftover / duplicate-H2 / gaps / cwd / worktree-suggestion / missing-intermediate / `.git/nope` / ceiling-var / nested-repo checks | `skills/blueprint/verbs/deploy.md`, `skills/blueprint/SKILL.md` |
| S3 | Description genesis triggers; **new** genesis probe battery; retitle 26-case “current baseline” as full-roster history; lint green | new battery; 26-case sentence scoped; `skills-lint.sh` fails=0; historical winners untouched | `skills/blueprint/SKILL.md`, `docs/boundary-audit.md` |
| S4 | Delete `skills/bootstrap/`; README inventory + minus-list; PACK.md blurb | `test ! -e skills/bootstrap`; `./install.sh --list` has no `bootstrap`; README row names `new`/`deploy` | `skills/bootstrap/`, `README.md`, `skills/clankshop/PACK.md` |

## Review history

**2026-08-16 pass 1 — `/blueprint review` — `needs-rework`.** Eleven must-fixes
folded the same day. Finding list pruned.

**2026-08-16 pass 2 — `/blueprint review` — `needs-rework`.** Six must-fixes
folded the same day. Finding list pruned.

**2026-08-16 pass 3 — `/blueprint review` via Codex (`gpt-5.6-sol`, read-only)
— `needs-rework`.** Four must-fixes folded the same day. Finding list pruned.

**2026-08-16 pass 4 — `/blueprint review` via Codex (`gpt-5.6-sol`, read-only)
— `needs-rework`.** Accepted items folded 2026-08-17. Declined: helper script
as spec blocker; per-guard mutation matrix. Finding list pruned.

**2026-08-17 — human review.** Scope of work names `bootstrap` (teardown).
New `blueprint` package content stays green (no sibling name, no formerly).
This section stays until a later review approves.
