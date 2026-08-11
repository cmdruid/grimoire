# `/bootstrap land` — create the repository and write the founding documents

Take a settled design and land it: create the directory, write the five founding documents, initialise
git, and commit. Optionally create a remote, only when explicitly asked.

## When to use

- Following `/bootstrap grill`, once the design is confirmed.
- Directly, when the shape is already known and no interview is wanted.

Run directly with no prior grill, gather the minimum in one short exchange — name, location, one-line
purpose, language/runtime, intended verification command — then land. Do not silently run a full
interview under this verb; if the idea needs interrogating, say so and offer `grill`.

## Preconditions

1. **A name and a location.** Both are decisions, not guesses. Never invent a project name.
2. **The target directory must not already exist**, or must be empty. A non-empty target → stop and
   report. This verb creates a project; it never merges into one.
3. **The target must not be inside another git repository.** Check before creating — a repo nested in
   a working tree is almost never intended, and is confusing to unpick later. Found one → stop, name
   the enclosing repository, and ask.

## Incomplete designs

If branches are still open, **report exactly what is unsettled and ask** whether to proceed. Never
land silently over gaps.

Anything the user accepts as unsettled becomes a visible **`## Open questions`** section in the
document that branch feeds — never an inline `TODO:` marker. The distinction is the point:

- **Deferred by choice** — a named decision with a stated reason to postpone. Belongs in the document.
- **Unsettled by omission** — a gap nobody decided about. Must look different on the page.

Five documents quietly full of `TODO:` markers are founding documents nobody trusts, which is the
outcome this skill exists to prevent.

## Procedure

1. **Create the directory** at the decided location and name.

2. **Write the five documents.** Content comes from the settled design — never from a bundled
   template, and never generic filler. A section with nothing real to say is either an open question
   (say so, per above) or should not exist.

   | file | carries |
   |---|---|
   | `README.md` | problem, users, scope, non-goals; links to the three `docs/` files |
   | `AGENTS.md` | agent-facing conventions, layout, and the **declared verification command** |
   | `<project>/docs/ARCHITECTURE.md` | components, boundaries, interfaces, **rejected alternatives and why** |
   | `<project>/docs/ROADMAP.md` | sequencing, then per phase: goal, scope (in/out), definition of done, risks |
   | `<project>/docs/RUNBOOK.md` | how to work on this project — the day-to-day working conventions |

   **The declared verification command** is recorded in `AGENTS.md` as a *decision, not a proven
   fact*: what "green" is intended to mean once code exists. This verb neither writes nor runs it.
   Mark it plainly as intended, so nobody mistakes it for something that currently passes.

   **`<project>/docs/ARCHITECTURE.md` carries the rejected alternatives.** This is the highest-value output of a
   grill and the reasoning most likely to be re-litigated in six months. A rejected option without its
   reason is not worth recording.

3. **`git init`.** Use the user's configured default branch; do not impose one.

4. **First commit.** Stage the five documents and commit with a plain message naming the project and
   what the commit contains (founding documents). Do not add attribution trailers.

5. **Remote — only on explicit request.** Never create one as a default or as a helpful extra.
   When asked:
   - Confirm **visibility before running**; default to private unless the user states otherwise.
   - Confirm the owner/namespace and the repository name.
   - Then create it and push.

   Creating a public repository claims a namespace, is immediately indexable, and is not meaningfully
   reversible. It is always a confirmed, explicit act.

6. **Report** what was created: the path, the files, the branch, the commit, and the remote URL if one
   was made. State plainly anything left as an open question.

## Done when

The directory exists with all five documents written from the settled design; `git init` has run and
the founding commit is in place; any accepted gaps appear as `## Open questions` sections rather than
inline markers; a remote exists only if it was explicitly requested and confirmed; the user has been
told what was created and where.
