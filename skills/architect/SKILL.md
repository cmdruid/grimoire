---
name: architect
description: "Use when the user runs `/architect`, asks to brainstorm, grill, or write a spec for a feature or design, starts a new project (`new`, `deploy`), or deploys Architect's optional project templates with `/architect setup`. Does not write roadmaps or implementation plans and does not build. For a one-line patch, skip it."
---

# architect — the specification spine

`/architect <verb> [args]` runs the specification spine: divergent ideation
(`brainstorm`), the interview that resolves every open decision (`grill`), the
argued specification (`spec`). Genesis is two verbs around that
spine: `new` mints a founding-shaped working file; `grill`/`spec` fill it in
place; `deploy` materializes a git repository (new directory, or in place
in a non-git folder). **Building is not
architect's job**, and neither is sequencing implementation. Trunk landing
and the debrief sweep stay with the orchestrator. `deploy` does not land
onto a host trunk.

This `SKILL.md` is a **thin router**: the dispatch table, the
Founding-shaped grammar the spine and genesis verbs share, and the typed
edges. Each verb's procedure lives in `verbs/` (see the dispatch table).
When a verb is selected, **read its file and follow it**.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

**Brief the human.** The conversation leads with the decision or the draft,
not the machinery. "Here are two approaches; I recommend A because…" /
"The spec is at `<path>`. Please read it before we sequence work."
`founding-shaped` and `status: draft` stay in the files.

**Destination is not stamped.** Feature `spec` / `brainstorm` / ADR artifacts
land in `<agent-records>/specs/` and `<agent-records>/adr/` on every host
(first `agent-records:` or `records-root:` in `AGENTS.md` then `CLAUDE.md`,
else `.records/`). Resolve `specs.md` / `adr.md` only from
`<agent-workspace>/architect/templates/`; when absent, read the bundled body scaffold without a
project write. Only `/architect setup` deploys a fresh project copy. Recognized legacy locations
require `/architect migrate <path>`.
Mint specs with `records.sh --root <root> --records-root <records-root-relative> new specs --schema architect/spec@1 --template <resolved>`
and ADRs with `new adr --schema architect/adr@1 --template <resolved>` when the tool exists;
else synthesize the same four-key front matter in file mode, naming the
file `YYYY-MM-DD-<slug>.md` — an undated filename is not a record, so the tool
will not see it. Templates supply bodies only and cannot select schemas. Never write the flat
`<agent-records>/templates/<doctype>.md`. Mint stays `status: draft`.
The caller writes `published` after a passing host's review they accept.
Closure through `records.sh --root <root> --records-root <records-root-relative> done` when the tool exists; else
file-mode stamp. Founding-shaped `grill` / `spec` stay on the named file
(no records mint). `new` / `deploy` unchanged.

**Probe exemption.** The records-mint / output-home path above applies to
`brainstorm`, feature `spec`, and ADRs. It does **not** apply to `new` or
`deploy`, and it does **not** apply to `grill`/`spec` when the named file is
founding-shaped (*Founding-shaped* below). Those stay on the cwd working file.

**Status vocabulary.** Mint stays `draft`. The caller writes
`published` after a passing host's review they accept (one `published` spec
per subject, as writer prose). This skill does not use `stage`.
Founding-shaped working files stay `status: draft`. They are not the living
feature spec. They carry `schema: architect/founding@1`; do not write `published` on them.

**Record contract.** Current records require `doctype`, `status`, `schema`, and `tags`.
Architect owns `architect/spec@1`, `architect/adr@1`, and `architect/founding@1`. The filename is
`YYYY-MM-DD-<slug>.md`; record links use `→ <store>/<file>.md`. Generic timestamps and revisions are
not stamped. Optional extra keys remain legal.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| (none) | `verbs/brainstorm.md` | divergent ideation → `specs/` doc (`status: draft`) |
| `brainstorm [topic]` | `verbs/brainstorm.md` | divergent ideation → a draft design doc |
| `new <name>` | `verbs/new.md` | mint `./<name>.md` — founding-shaped, empty of design content |
| `grill [doc]` | `verbs/grill.md` | interview until every decision branch resolves; founding-shaped → fill the six map H2s **in place** |
| `spec [doc]` | `verbs/spec.md` | synthesize → grill the gaps → the argued spec; founding-shaped → fill the map **in place** (no records mint, no reshape) |
| `deploy <file>` | `verbs/deploy.md` | project a founding spec into a git repo + three founding docs (new dir or in-place) |
| `setup [<root>]` | `verbs/setup.md` | deploy active project templates absent-only |
| `migrate <source-path>` | `verbs/migrate.md` | preview and upgrade owned records/templates, including in place |

```
spec  →  (host's review)  →  (caller publishes)  →  (host sequences)
```

Each arrow is a stop. No verb invokes the next.

`brainstorm → spec` is the linear spine; `grill` is a primitive
callable at any point. Bare `/architect` stays `brainstorm`. Genesis is
explicit `new`. Weight scales with the work: a **small feature** may stop
at the accepted spec (the spec doubles as its plan — slices live **in**
`templates/specs.md`, not a separate job artifact). For a **patch**, architect
is not used at all.

## Founding-shaped

A file is **founding-shaped** iff it has `founding` in `tags:` **and** its
structural H2 set is exactly the six map strings in `templates/founding.md`,
each appearing once. That template owns the H2 strings; if they drift, the
template wins. A duplicate mapped H2 or an extra unmapped H2 fails the shape.

**Parser** (one grammar; founding `grill` / `spec`
and `deploy` share it):

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
   prose). Either leftover class refuses `deploy` and is a critique finding.

**Gap vs settled** (mapped bodies only). Strip whole lines matching
`^Settled: [0-9]{4}-[0-9]{2}-[0-9]{2}\.$` and remaining whitespace.
Remainder empty → **gap**. Any remaining byte → **settled**. Who/when-only
is a gap. No italic / `TBD` / `<>` special cases.

**Branch** (on a named `[doc]`; never scan cwd for a founding file):

- **Founding-shaped** → stay on that file. Fill the six map H2s in place.
  Do not rewrite to `templates/specs.md`. Do not mint a `specs/` record.
  Do not strip `founding`. Do not add an H2 that is not in the map. Do not
  promote `status`. Who/when notes go **inside** the mapped section as a
  whole line in this exact form (roman, not italic): `Settled: YYYY-MM-DD.`
- **No `founding` tag and no structural H2 is in the map** → existing
  feature-spec `grill` / `spec` (may reshape / records-mint).
- **Otherwise** (tag without the exact map; any map H2 without being
  founding-shaped, including a duplicate mapped H2) → refuse: restore the
  shape with `/architect new` or fix the H2 set. Do not reshape. Do not
  deploy-path this file.

## Shared discipline (every verb)

- **Read the verb file.** Do not reconstruct a procedure from this router.
- **Scripts from this package.** `scripts/ground-check.sh` is this
  skill's copy — resolve it from this skill's own base directory,
  never a host path.
- Mint stays `draft`. Do not write `published`.

## State between verbs = the artifacts

There is no separate architect state file. Each verb consumes the previous
verb's artifact by path: `brainstorm`'s draft → `spec` argues it — and each
doc's front-matter `status` tracks its lifecycle. `grill` writes
no new file.

## Composition (the orchestrator owns building, landing, capture)

- **Standalone** — the user runs the spine; the host's build lane consumes the
  accepted spec. The close-the-books sweep is the project's own convention.
- **Project routing** — a host's routing convention may dispatch design-at-stake
  work here. The orchestrator / host lane consumes the spec.

Do not name a successor skill. Feature composition ends at the accepted
spec; genesis ends at the repo. The accepted spec is the feature baton.

## Structure, portability

- A self-contained skill directory: `SKILL.md` + `templates/` (`specs.md`,
  `adr.md`, `founding.md` — the bundled body shapes) + `verbs/brainstorm.md` +
  `verbs/grill.md` + `verbs/spec.md` + `verbs/new.md` +
  `verbs/deploy.md` + `verbs/migrate.md` + `scripts/ground-check.sh` (the
  re-grounding fact-checker) + `docs/ideal-use.md` (a worked arc).
- **Portable:** no workshop dependency, no host paths baked in, travels as one
  unit wherever the skills are installed.

## Project templates

- `adr.md`
- `specs.md`

`founding.md` is package-only.

## Edges

<!-- edges:architect -->
- produces: spec — an argued specification; deploy's repository is the terminal direct result of genesis, not a composition edge
- handoff: spec — the accepted spec is the feature baton; genesis ends at the repository
- consumes: — (a conversation or named draft is direct input, not a typed project artifact)
<!-- /edges:architect -->

## Done when

- **Bare `/architect`:** `brainstorm` — that verb file's Done when.
- **A named verb ran:** that verb file's Done when.
