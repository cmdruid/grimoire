# grimoire repurpose — umbrella design

**Status:** approved direction (2026-08-07). This is the umbrella decision record for repurposing
this repo from a pure skills library into three things in one: the **grimoire TUI application**,
the **pack format spec**, and the **flagship content** (clankshop + future packs). Each of the
three sub-projects it decomposes into gets its own design → plan cycle; this doc records the
decisions those cycles build on and must not relitigate.

## Context

- Backend research (2026-08-07, this session): `qntx/skill` is a Rust reimplementation of the
  Vercel `skills` CLI — library-first (`skill` crate on crates.io, 0.8.x), lock-file-compatible
  with the TS CLI (`skill-lock.json` v3 global, `skills-lock.json` v1 project), symlink-first.
  Hands-on evaluation (discover → install → list → lock I/O → remove, sandboxed) passed; 159
  upstream tests green. Gaps a frontend fills: skills.sh search is CLI-only (~50 lines of HTTP),
  the `add` choreography is CLI-side (library exposes all the pieces), no file-watching. Risk:
  single maintainer, 0.8.x — pin the version; MIT/Apache-2.0 keeps vendoring/forking open.
- GUI landscape: five existing skill managers, all GUIs (two Tauri at 2.2k/3.6k stars, two
  SwiftUI, one Electron). **No skills TUI exists.** No open cross-agent pack standard exists
  either — closest prior art: Claude Code plugins (Claude-centric), Vercel-format repos (de facto
  collections, no named-subset/version/install-as-unit semantics), GUI apps' app-local
  collections.
- This repo already carries a proto-pack-format (`packs/clankshop.md` frontmatter + pack lock +
  `install.sh --pack`) and a mid-flight clankshop restructure (Phases 0–1 done).

## Decisions (settled in brainstorm, binding on sub-projects)

1. **Ambition:** personal now, ecosystem later — the format is designed adoption-grade from day
   one; build and evangelize at personal-tool pace, prove it on our own packs first.
2. **Existing content:** the steward/operator skills and clankshop remain the **flagship
   content**; the clankshop restructure continues in parallel (coordination rule below).
3. **Pack semantics:** the spec covers **manifest + lifecycle hook** — skill list, roles,
   versioning, lock semantics, plus an optional declared `setup:` entrypoint a tool may offer to
   run post-install. Runbook prose stays pack-author territory, outside the spec.
4. **Interop (hard requirement):** a pack is an **overlay** — a pack repo remains a plain
   Vercel-format skills repo; plain CLIs degrade gracefully to installing atoms.
5. **TUI v0.1 scope:** (a) library → machine installs (the `install.sh` dogfood loop, visual);
   (b) project-scope management (per-agent, lock-aware). Registry search and pack authoring are
   later milestones.
6. **Theme:** Frieren-inspired flair, expressed as **themed verbs + plain aliases** at the app
   layer only — `learn`/`install`, `forget`/`remove`, `peruse`/`list`, `bind`/`pack new`; plain
   help text; spec vocabulary strictly conventional (`pack`, `skills`, `setup`); no character
   names or show assets in the public identity (inspired-by + easter eggs only — active
   commercial IP).

## 1. Identity

**grimoire** = the app + the format + the content, one repo. The app embeds the `skill` crate
(qntx) as a library — it does not shell out to `skills-cli` — and may additionally offer
CLI-passthrough sugar (`grimoire add owner/repo` behaving like `npx skills add`). The
skills-are-spells / pack-is-a-grimoire vocabulary carries the theme: a pack is a bound, curated
book of spells, which is exactly the existing doctrine ("a pack is a curated manifest, not a
directory" — now: not *merely* a directory).

## 2. Repo topology

```
grimoire/
├── crates/
│   ├── grimoire-pack/    # pack format: parse/validate/resolve manifests (canonical impl)
│   ├── grimoire-core/    # operations: wraps skill::SkillManager + pack ops; no UI imports
│   └── grimoire/         # the TUI + CLI verbs (ratatui; binary `grimoire`)
├── skills/               # the shared atoms — generic skills (Vercel-format, as today)
├── packs/
│   └── clankshop/
│       ├── PACK.md       # manifest: frontmatter for tools, runbook body for humans
│       └── skills/       # optional pack-specific skills (each <name>/SKILL.md)
├── docs/spec/            # the pack format spec (versioned document)
├── docs/design/          # design docs (as today)
├── install.sh            # stays: zero-dependency shell bootstrap + shell reference impl
└── repos/skill-rs        # gitignored reading reference (the dep comes from crates.io, pinned)
```

**Hard seam rule:** crates never read `packs/` or `skills/` at build time — content appears in
the workspace only as integration-test fixtures. This preserves the mechanism/composition
doctrine (the tool never depends on the pack) and keeps future extraction of `crates/` to its own
repo a `git mv`, which is the escape hatch the "ecosystem later" ambition relies on.

**Pack layout (amended from single-file `packs/<name>.md`):** a pack is a **named directory
marked by a `PACK.md` at its root**, mirroring the `<skill>/SKILL.md` idiom. Frontmatter is the
machine surface; the body is the runbook. A pack directory may carry a `skills/` folder of
**pack-specific skills** (e.g. clankshop's own executable-face skill belongs there, not among the
generic atoms). Degenerate case that falls out for free: `PACK.md` at a repo's root makes the
whole repo one distributable pack (pack-as-repo).

## 3. Pack format (boundaries; details are sub-project ①)

Formalizes the existing frontmatter: `name`, `description`, `skills`, roles
(`core`/`helpers`/`optional`), `pack-version`, `layout`, plus new optional `setup:` (lifecycle
entrypoint). `grimoire-pack` becomes the canonical parser; `install.sh` remains the shell
reference implementation.

Open questions owned by ① (recorded here so they aren't lost):

- **Skill reference resolution:** a manifest's `skills:` list draws from the pack's own
  `skills/` and the repo's shared `skills/` — resolution order (pack-local first?) and explicit
  reference syntax to be specified.
- **Name uniqueness:** pack-local skills are valid Vercel-format skills, so plain CLIs discover
  them as ordinary atoms (graceful degradation working as intended — but pack-local ≠ hidden).
  The spec needs a collision rule across a repo's packs and shared library.
- **Lock semantics** for pack-as-unit installs (extending the existing pack-lock work).
- **`setup:` contract:** what a tool is allowed to assume about the entrypoint (a slash-command
  string it offers to run — never auto-executes).

## 4. TUI application (boundaries; details are sub-project ③)

Two-crate split under the app: `grimoire-core` holds app state and operations (pack resolution
via `grimoire-pack`, install choreography reassembled from `skill`'s public pieces, the skills.sh
search client when that milestone lands) with no UI imports; `grimoire` renders it (ratatui).
Backend policy: pin `skill` 0.8.x; vendor/fork is the documented fallback. A future GUI is a
second frontend over `grimoire-core`, not a rewrite.

## 5. Sequencing & coordination

**① pack format spec → ② repo restructure → ③ TUI v0.1**, each with its own design → plan →
build cycle. The format is load-bearing and small; the restructure is thin once the format names
the layout; the TUI builds against a settled format.

**Clankshop coordination (freeze rule):** the clankshop restructure proceeds in parallel, but
`packs/clankshop.md` (→ `packs/clankshop/PACK.md`), the pack frontmatter/lock format, and
`install.sh --pack` are owned by sub-project ① — clankshop phases touching those surfaces wait
for ① so they land on the new format once. Moving `skills/clankshop/` into
`packs/clankshop/skills/` is part of that same coordinated landing.

## 6. Testing & risk (umbrella altitude)

- `grimoire-pack`: golden tests with `packs/clankshop/PACK.md` as fixture (fixture use only —
  the seam rule).
- `grimoire-core`: sandboxed integration tests against throwaway fixture repos/projects (the
  harness pattern proven in the backend evaluation).
- `grimoire` (TUI): ratatui `TestBackend` smoke tests.
- Risks: qntx bus-factor (pinned version + fork option, permissive dual license); crates.io
  name availability for `grimoire` (check at ②; binary name unaffected); upstream `@filter`
  URL-parsing quirk (file an issue when it matters to us).
