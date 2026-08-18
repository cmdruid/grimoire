# `deploy <file>` · project a founding spec into a git repository

Materialize only. Reads a founding-shaped working file and writes a git
repository carrying three founding documents — a **new directory**, or
**in place** in an existing non-git folder that does not already hold
those documents. Does not land onto a host trunk. Does not reshape the
working file. The working file is **never committed**.

The environment probe's records-mint / output-home path does not apply
(SKILL.md *Probe exemption*). Shape, leftover, and gap classification use
the one grammar in SKILL.md *Founding-shaped* — do not invent a second
parser. Map H2 strings come from `templates/founding.md`.

Patient-zero: never target this skill library's own `AGENTS.md`. Cwd dest
requires `inside a repo` false, so a run from a checkout cannot land on it.

Re-deploy is not a thing. Dest that already holds a deploy-owned path
(`README.md`, dest `ARCHITECTURE.md` under dest `docs/`, or an
`AGENTS.md` that already carries a mapped H2) → refuse. After a successful deploy the dest tree
is the source of truth. Other pre-existing files stay untracked and are not in the first
commit. A pre-existing `AGENTS.md` with no mapped H2 is composed by
**append** only (step 7).

## Procedure

### 1. Resolve `<file>`

`<file>` is required and must exist. Missing or absent → refuse. Physically
canonicalize it (`realpath` — the file exists, so this cannot fail) before
any dest prompt. Stem = that path's filename with one trailing `.md`
stripped. Stem is only the **default** dest name; the confirmed dest may
differ. No forced `mv` of the working file.

### 2. Founding-shaped gate

Classify with SKILL.md *Founding-shaped*. Require the tag **and** exactly
the six map H2s, each once. Otherwise refuse in **one line**: not a
founding spec; use `/blueprint new`. Name a duplicate H2 if that is why.
Do not dump a leftover list for a feature spec. Do not enter the dest
prompt.

A leftover H2 on an otherwise founding-tagged file fails the shape (extra
unmapped H2). Name the leftover; dest is not created. No confirm.

### 3. Forbidden git context (one test, used everywhere)

Use this for suggestion legality, typed dest, cwd dest, and again
immediately before `git init`. Do **not** test `test -d .git` (wrong at
worktrees, silent on subdirs).

Run every `git` probe with discovery vars unset:

```
env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_CEILING_DIRECTORIES \
  git -C <ancestor> rev-parse --show-toplevel
```

(and the same `env -u` prefix on `--is-inside-git-dir` and
`--is-bare-repository`). An inherited ceiling can hide the enclosing
checkout.

Against a dest **candidate**:

1. Walk **upward to the first existing directory** (the candidate itself if
   it exists, else its nearest existing ancestor; filesystem root if
   nothing exists). One hop is not enough.
2. `realpath` **only that existing ancestor** (`realpath` of a missing dest
   exits 1). Build the candidate's canonical path by appending the missing
   suffix to that ancestor, normalizing `.` / `..`. A symlink ancestor that
   resolves into a checkout counts as inside it.
3. Refuse if any of:
   - `git -C <ancestor> rev-parse --show-toplevel` succeeds **and** the
     canonical candidate is that toplevel or a path under it — name the
     enclosing toplevel;
   - `git -C <ancestor> rev-parse --is-inside-git-dir` is `true`;
   - `git -C <ancestor> rev-parse --is-bare-repository` is `true`.

After dest exists (created, empty, or in-place), **re-run this test on dest
itself** immediately before `git init`.

### 4. Empty and in-place (two predicates)

**Empty.** A directory is empty iff every entry is a dotfile (`name`
starts with `.`) or is the working spec file — **except** a `.git` entry
(file or directory), which always refuses, even if git does not recognize
it.

**In-place legal.** Dest exists as a directory, *Forbidden git context* is
false, there is no `.git` entry, `README.md` is absent, dest
`ARCHITECTURE.md` (under dest `docs/`) is absent, and `AGENTS.md` is either absent or contains **none** of the
AGENTS-fed mapped H2 strings (`Working conventions & layout`, `Declared
verification command (intended, not proven)`). Pre-existing `docs/` or
sibling files do not disqualify.

Use both predicates for suggestion legality, typed dest, and cwd dest.

### 5. Destination — one prompt, once

Always confirm; never create silently. Two options:

**Use cwd.** Allowed when cwd is empty **or** in-place legal. Suggest this
first when it is allowed — that is the in-folder genesis path.

**Create a new directory.** Confirm the path. Suggestion: first legal
candidate below, else no suggestion (ask for a path). A candidate is legal
when *Forbidden git context* is false **and** it does not exist, is empty,
or is in-place legal.

Walk, in order:

1. `cwd/<stem>`
2. Then, starting at `dir = cwd` and walking `dir = parent(dir)` until
   filesystem root: `dir/../<stem>` (sibling of `dir`).

Do not bake a host path into this walk.

**Refuse (do not prompt past these)** — typed dest **and** cwd dest:

- Dest is inside a git repository — name the enclosing toplevel, stop.
- Dest exists as a file.
- Dest exists, is not empty, and is not in-place legal — name the
  colliding deploy-owned path (`README.md`, dest `ARCHITECTURE.md` under
  dest `docs/`, or `AGENTS.md` already carrying a mapped H2). Do not overwrite. Do not
  merge those files.

An existing **empty** or **in-place legal** directory that is not inside
a repo is allowed (then `git init` inside it). Blank dest confirmation →
nothing created.

Project name = the dest directory's basename (resolved absolute path).
That string lands in README / AGENTS / ARCHITECTURE titles and in the
first-commit message. Spec H1 is the design title and may match or not.
If dest is cwd, the project name is cwd's basename.

### 6. Gaps confirm (mapped sections only)

After dest is accepted, walk the six map H2s in template order (the shape
gate already refused a missing or duplicate H2). Classify each body
(SKILL.md *Gap vs settled*).

If any gap exists, list them by section → fed file and ask to **land with
open questions**. No → stop, go back to grill; dest is not created (or not
written). Yes → each fed file gets **one** `## Open questions` section
**after all of that file's mapped sections**, listing every accepted gap
that feeds it (named, never inline `TODO:`). Do not interleave an Open
questions heading per gap. An empty-mint (all six empty) is this path with
six gaps, not a special case.

Map → fed file (template owns the H2 strings):

| Spec section | Feeds |
|---|---|
| Problem & users | `README.md` |
| Scope & non-goals | `README.md` |
| Architecture (components, boundaries, interfaces) | dest `ARCHITECTURE.md` (under dest `docs/`) |
| Rejected alternatives and why | dest `ARCHITECTURE.md` (under dest `docs/`) |
| Working conventions & layout | `AGENTS.md` |
| Declared verification command (intended, not proven) | `AGENTS.md` |

If an H2 not in the map appears anyway, refuse, list them, stop. No
confirm.

### 7. Materialize — lossless copy-through

1. Create dest if needed. Track **every path this run creates** (dest
   itself if created; `docs/` if this run created it; any of the three
   project files this run created; `.git` if this run inits). A
   pre-existing `docs/` or `AGENTS.md` is **not** run-owned.
2. Write three **project** files: `README.md`, `AGENTS.md`, and
   `ARCHITECTURE.md` under dest `docs/`. `git init` also writes `.git`
   metadata — that is not a fourth project file. For each mapped H2 in **template/map
   order**: if settled, copy its extracted body span **verbatim** under a
   heading of that same H2 string; do not paraphrase. Two H2s that feed
   the same file concatenate in map order. Then, if that file has accepted
   gaps, one `## Open questions` section after those mapped sections.
   Front-matter, working-file H1, and permitted chrome are omitted.
   - **New file:** its only title line is `# <project-name>`.
   - **Pre-existing `AGENTS.md` (in-place compose):** keep the existing
     H1 and body. Append the AGENTS-fed mapped sections (then Open
     questions, if any) after that body. Do not add a second H1. Keep a
     copy of the original bytes for rollback. `README.md` and dest
     `ARCHITECTURE.md` (under dest `docs/`) are never composed over — in-place legal
     already refused if they exist.
3. After README's mapped sections and its Open questions (if any), append
   one paragraph, not inside a copied body:
   `See [Architecture](docs/ARCHITECTURE.md).`
4. Re-run *Forbidden git context* on dest (sanitized env). Then `git init`.
   Use the user's `init.defaultBranch`; do not impose a branch name.
5. First commit: **exactly** those three project paths. Message:
   `Add founding documents for <project-name>`. No attribution trailers.
   Do not add `LICENSE` or `.gitignore`. Pre-existing siblings stay
   untracked.
6. The working file is never staged and never in that commit. If dest is
   cwd, it may remain on disk as an untracked file.

Completeness = every settled mapped body appears **byte-for-byte** (modulo
a single trailing newline) under its heading in the fed file. That is the
delete-safety proof. Verify it before the delete prompt.

### 8. Materialize failure

On any failure from the first mutation through post-commit verification
(including writing `docs/` or a project file), delete **only run-owned
paths**. If this run created dest, remove dest entirely. If dest was
pre-existing, remove what this run wrote and, if `AGENTS.md` was
composed, restore the original bytes. Never delete a pre-existing
`.git` we refused to accept (we never start in that case). Never delete
pre-existing siblings or an existing `docs/` tree. Report the failure. Do not prompt to delete the working file.
Retry is then possible.

### 9. Confirm-to-delete

After a **successful** deploy (including a gappy land): the working file
is safe to delete; delete it? **Explicit yes** required. Anything else
(including blank) leaves it. Delete only that file. A delete failure is
reported; deploy has already succeeded. No prompt if deploy refused.

### 10. Remote — only on explicit request

Never create one as a default. When asked: confirm visibility (default
**private**), owner/namespace, and repository name; then create and push.
Use `gh repo create` when `gh` is available; otherwise print the commands
and stop. Never invent a remote URL or an owner. No remote request → no
remote.

## Done when

Dest exists; three project files written by copy-through; `git init` has
run; first commit is exactly those three paths; completeness holds;
working file is unstaged / uncommitted (deleted only on explicit yes); a
remote exists only if requested and confirmed.
