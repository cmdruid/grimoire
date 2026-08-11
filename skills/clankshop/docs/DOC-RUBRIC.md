# The doc rubric — the 12-dimension spine reference

This document is the scoring reference for the `/clankshop docs` diagnosis. Each
dimension is self-contained: it states what the scanner measures, which scanner
fact keys inform the score, and what solid/drift/gap looks like in practice.

Scanner facts come from `scripts/spine-scan.sh` as `key=value` or list output.
Dimensions marked "read-only judgment" have no machine facts — the agent reads
the docs and decides.

Score tiers:
- **solid** — the dimension is healthy; no adjustment needed.
- **drift** — degradation has started; a targeted fix will restore health.
- **gap** — the dimension is broken or absent; structural repair is needed.

---

# Cluster A — Structural Integrity

Docs are reachable, current, and internally consistent.

## 1. Reachability/Coverage

**What it checks:** Every doc and directory in the spine is reachable from the
entry door, and no directories are stranded outside the graph.

**Facts that inform it:** `orphan_docs`, `unreachable_dirs`

Score on orphans **outside** any intentional dated archive or store (date-prefixed files, or a
directory the index references as a glob/store rather than per-file — e.g. a completed-work
archive); such a store is reached by convention, not navigation, so do not read the tiers literally
against an archive-inflated `orphan_docs_count`.

- **solid** — `orphan_docs` is empty and `unreachable_dirs` is empty; every
  file and directory is reachable from the declared entry door.
- **drift** — 1-3 orphan docs or one unreachable directory; the graph covers
  most of the spine but has edge nodes that have become disconnected.
- **gap** — 4+ orphan docs or multiple unreachable directories; significant
  portions of the doc tree are dark and agents cannot discover them.

**Example adjustments:**
- Add a link from the nearest parent doc to each orphan file, or delete the
  orphan if it has been superseded.
- Move stranded directories under a linked parent, or add an index entry that
  pulls them into the graph.

---

## 2. Currency

**What it checks:** Links resolve and cross-references point to content that
still exists and matches the text that references it.

**Facts that inform it:** `broken_links`, `stale_refs`, `escaping_refs`, `xroot_refs`
(and, for context only, `broken_links_archived` / `stale_refs_archived`)

Score the tiers against the **live** facts only — `broken_links` and `stale_refs` already
exclude historical records (the scanner routes those to `broken_links_archived` /
`stale_refs_archived`, which cite past states by design; do not fold them into the score).
Also exclude `xroot_refs` (refs resolving inside a nested repo root — cross-root citations,
not staleness). The archived counts can be large and healthy; a big `stale_refs_archived_count`
next to an empty `stale_refs` is a solid spine, not a gap.

**Self-containment (nested repos).** When the scanned root is a repo meant to stand alone — any
nested repo in a superproject, scanned standalone — an outward reference is a hard defect, not
cosmetic drift: a standalone clone has no parent and no siblings, so the ref is dead and the agent
is stranded. Any non-empty `escaping_refs` (a doc referencing above its own root), or a
`stale_ref` that resolves only in the parent/sibling, is a **gap** for that repo regardless of
count — even one strands the reader. Report it with the file and offending ref. (For the
superproject's *own* outer spine, an `escaping_ref` may be benign — e.g. a code-span quoting a
symlink target — so judge those by reading; the hard gate is for the nested repos.)

- **solid** — live `broken_links` is empty and live `stale_refs` is empty; every link
  resolves and every cross-reference matches live content (archived counts may be large). For a
  nested repo, additionally `escaping_refs` is empty and no ref points outward.
- **drift** — 1-5 live broken links or stale refs; most references are live but a
  handful have rotted since the last refactor or rename.
- **gap** — 6+ live broken links or stale refs, or a key entrypoint doc has broken links, or
  (nested repo) any outward reference at all; the spine is unreliable as a navigation aid or
  does not survive a standalone clone.

**Example adjustments:**
- Run the scanner after each rename/move and update all `broken_links` in the
  same commit that moves the file.
- Replace stale section anchors with links to the new location and remove the
  dead anchor.

---

## 3. Consistency

**What it checks:** Terminology, heading style, and structural conventions are
uniform across all docs in the spine — no doc uses a conflicting convention
that would confuse a reader moving between files.

**Facts that inform it:** read-only judgment

- **solid** — Heading capitalization, list style, and key terms are used the
  same way in every doc; a reader can move between files without reorienting.
- **drift** — One or two docs use a different heading style or a synonym for a
  defined term; inconsistency is visible but does not block comprehension.
- **gap** — Multiple conflicting conventions coexist (e.g., some docs use
  title-case headings, others sentence-case; the same concept has 3+ names);
  a new agent cannot tell which convention is authoritative.

**Example adjustments:**
- Pick one heading capitalization style and apply it uniformly in a single
  clean-up commit.
- Add the canonical term to the glossary (dimension 8) and do a search-replace
  pass to retire synonyms.

---

# Cluster B — Agent Ergonomics

An agent (or human) can orient fast, stay at the right altitude, and spend
tokens efficiently.

## 4. Read-Path

**What it checks:** The sequence of documents an agent must read from the entry
door to any useful working doc is short and logically ordered.

**Facts that inform it:** `max_depth` (the scanner's BFS hop distance from
`entry_door` to the farthest reached doc) + judgment on the path's clarity

- **solid** — `max_depth` <= 3; working docs an agent must act on are
  reachable in <= 2 actions from the entry door; the critical path is obvious
  from the entry doc's own prose.
- **drift** — `max_depth` 4-5, or the critical path requires following more
  than one ambiguous branch before reaching actionable content.
- **gap** — `max_depth` >= 6, or the entry door requires reading several large
  files before the agent can locate the right one; the read-path is a maze.

**A menu-only intermediary is a Read-Path defect.** A doc whose sole content is
pointers to other docs adds a hop with no payload; fold its table into the
entry door (menus are free where context is already loaded) or into its
parent, and let each leaf carry real procedure.

**Example adjustments:**
- Promote the most-visited working docs to a direct link in the entry door.
- Split a deep intermediary into a short router doc + detailed leaf docs so
  the path shortens.

---

## 5. Altitude & Non-Duplication

**What it checks:** Each doc operates at one altitude (overview vs. reference
vs. how-to); no doc paraphrases content from another doc it could link instead.

**Facts that inform it:** read-only judgment

- **solid** — Every doc has a clear altitude; the entry door is pure
  orientation; detail lives only in leaf docs; nothing is repeated across files.
- **drift** — One or two docs blur altitude (e.g., a reference doc that
  re-explains a concept the overview already covers), or a single duplicated
  block exists but does not yet mislead.
- **gap** — Content duplication is widespread (the same procedure in 3+ docs),
  or overview and reference content are mixed throughout; an agent cannot know
  which copy is authoritative.

**Example adjustments:**
- Extract duplicated content into a single canonical doc and replace each copy
  with a link + one-line summary.
- Split a mixed-altitude doc into an overview stub (kept short) and a reference
  leaf (all the detail).

---

## 6. Token Economy

**What it checks:** Auto-loaded and frequently-read docs are appropriately
compact; large docs are leaf docs that are only read when needed.

**Facts that inform it:** `always_loaded_bytes`, `doc_sizes`

- **solid** — `always_loaded_bytes` is under a reasonable threshold (e.g.,
  20 KB total for always-loaded docs); `doc_sizes` shows large docs are leaf
  references, not entrypoints.
- **drift** — `always_loaded_bytes` is 20-50 KB, or one large doc is linked
  close to the entry door and pulled in on most sessions even when unnecessary.
- **gap** — `always_loaded_bytes` exceeds 50 KB, or a single doc in
  `doc_sizes` is so large that loading it dominates agent context on every run.

**Triage `doc_sizes` outliers by job count, not size alone.** A large doc that
is one coherent job (a reference read end-to-end) is healthy; a large doc
bundling many independent how-tos makes every reader pay for the jobs they are
not doing — a split candidate. The converse also holds: two small docs that
are only ever read together are one job paying two read overheads — a merge
candidate.

**The door diet (the adjust technique for an over-heavy entry door).** When the
always-loaded set is over budget because the entry door *restates* its leaf
docs — a per-subsystem index whose sections carry the mechanism — compress
each section to its **tripwires**: the fact that would surprise an agent, and
the constraint they must not break (keep every "never do X" clause verbatim),
plus the leaf link. Shed the mechanism — paths, symbol names, rationale —
which lives one read away in the leaf and is then paid only by agents who
actually need it. The test for a surviving line: it tells the reader *when to
open the leaf*, never *what the leaf says*.

**Example adjustments:**
- Move boilerplate (changelogs, full schemas) out of always-loaded docs into
  dedicated leaf docs linked by reference.
- Split a monolithic reference file into topic-scoped files so agents load only
  what they need.

---

## 7. Signposting

**What it checks:** Every doc tells the reader what it is for, what to read
next, and when to stop reading — so an agent can skip docs that are not
relevant to its current task.

**Facts that inform it:** read-only judgment

- **solid** — Every doc opens with a one-line purpose statement; router docs
  list their branches with a clear "when to follow each"; leaf docs end with
  a next-step or back-reference.
- **drift** — Most docs are signposted but one or two have no opening purpose
  statement or no guidance on when to stop reading.
- **gap** — Docs have no signposting; an agent must read the entire file to
  determine whether it is relevant, and has no guidance on what to read next.

**Example adjustments:**
- Add a single-sentence "When to read this" blurb at the top of each doc that
  currently lacks one.
- Add "See also: X" or "Next: X" links at the bottom of leaf docs.

---

## 8. Terminology

**What it checks:** All domain terms used across the doc spine are defined in a
glossary; docs use those definitions consistently.

**Facts that inform it:** `has_glossary` + read-only judgment

- **solid** — `has_glossary` is true; the glossary covers all terms that appear
  in more than one doc; docs link to the glossary rather than re-defining terms
  inline.
- **drift** — `has_glossary` is true but 1-3 domain terms used across docs are
  missing from it, or a doc re-defines a term differently than the glossary.
- **gap** — `has_glossary` is false, or the glossary exists but is so sparse
  that agents must infer meaning from context; synonyms proliferate across docs.

**Example adjustments:**
- Create a `GLOSSARY.md` at the spine root if one does not exist, and seed it
  with all terms that appear in 2+ docs.
- Audit the first occurrence of each term in every doc and replace inline
  definitions with a link to the glossary entry.

---

# Cluster C — Affordances & Durability

The spine remains useful over time and supports tooling.

## 9. Taxonomy

**What it checks:** The directory and file structure maps visibly to logical
categories; a new contributor can predict where to add a new doc without asking.

**Facts that inform it:** read-only judgment

- **solid** — Directory names are noun-based and self-explanatory; there is at
  most one plausible location for any new doc; the taxonomy scales without
  rename churn.
- **drift** — One or two directories are ambiguously named (e.g., `misc/`,
  `stuff/`) or the taxonomy has grown an outlier that does not fit any category,
  requiring ad-hoc placement.
- **gap** — The directory structure is flat or ad-hoc; a new contributor cannot
  predict where a doc belongs; additions pile up in the root or a catch-all dir.

**Example adjustments:**
- Rename ambiguous directories to noun-category names that match the content
  they hold.
- Introduce a clear split (e.g., `reference/` vs. `guides/`) and move files to
  match.

---

## 10. Machine-Legibility

**What it checks:** The spine can be enumerated and categorized without reading
body text — via **either** an index that lists docs with their kind/purpose
**or** frontmatter on the docs themselves. Both are valid mechanisms; the
dimension scores the outcome (enumerability), not one specific mechanism.

**Facts that inform it:** `has_stewardship_map`, `decl_docs`, `frontmatter_coverage`

Frontmatter is one mechanism, not the goal. A repo that deliberately enumerates via
current, complete index files is fully machine-legible with `frontmatter_coverage=0` —
score that solid, not drift. `frontmatter_coverage` only pulls a score down when the
repo has *no* working enumeration to lean on. On a framework installation the stewardship
map + declaration blocks are that mechanism (`has_stewardship_map`, `decl_docs`); confirm
the map is current rather than assuming its presence means healthy.

- **solid** — The spine is enumerable without body-text parsing: a current
  stewardship map + declaration blocks cover the live stores, a current index does,
  **or** `frontmatter_coverage` is ~100%. A well-maintained enumeration convention
  with no frontmatter is solid.
- **drift** — The primary mechanism has gaps: the index exists but omits a live
  area, or frontmatter is the intended convention yet coverage is partial (70-99%).
  Enumeration mostly works but misses a corner.
- **gap** — No mechanism works: no current map/index (or a stale, misleading one)
  **and** `frontmatter_coverage` is low; automated tools must parse body text to
  identify docs.

**Example adjustments:**
- Add a minimal frontmatter block (`---\ntitle: X\nkind: Y\n---`) to each doc
  that currently lacks one.
- Create an `INDEX.md` (or equivalent) at the spine root that enumerates all
  top-level docs with their kind and purpose.

---

## 11. Drift Resistance

**What it checks:** The spine has structural features that make it easy to keep
current — checklists, ownership hints, or update prompts — so it does not
silently rot between active maintenance passes.

**Facts that inform it:** read-only judgment

- **solid** — Key docs carry a "last verified against" stamp or an explicit
  "update when X changes" note; there is a clear convention for which docs must
  be updated when a specific artifact changes.
- **drift** — Some docs have update notes but others do not; the spine is mostly
  self-documenting but a few docs could go stale without anyone noticing.
- **gap** — No docs carry any update prompts or ownership; the spine can become
  arbitrarily stale because nothing signals when a doc needs attention.

**Example adjustments:**
- Add a one-line "Update this doc when: X" note to each doc that describes a
  frequently-changing subsystem.
- Record a "built against: <ref>" stamp in each generated or derived doc so
  staleness is detectable.

---

## 12. Actionability

**What it checks:** A reader (agent or human) who arrives at a doc for a
specific task can complete that task without leaving the doc to infer missing
steps or locate implicit prerequisites.

**Facts that inform it:** read-only judgment

- **solid** — Every how-to doc lists its prerequisites explicitly; steps are
  concrete commands or file paths, not prose descriptions of intent; expected
  outcomes are stated so the reader can verify success.
- **drift** — Most docs are actionable but one or two steps rely on implicit
  context (e.g., "run the usual build" without naming the command) or omit a
  prerequisite that a new reader would need.
- **gap** — Docs describe what to do at a high level but omit the commands,
  paths, or conditions needed to actually do it; a reader must cross-reference
  multiple docs or reverse-engineer the procedure.

**Example adjustments:**
- Replace prose-intent steps ("build the project") with literal commands
  (`cargo build --features dev`).
- Add a "Prerequisites" section listing any tools, env vars, or prior steps
  that must be in place before the doc's procedure will work.

---

# Entry-Door Audit (focused pass)

The five checks below examine the project entry door (CLAUDE.md, AGENTS.md, or
equivalent) as a standalone artifact. They are a focused pass, not additional
dimensions — the `## ` dimension count stays at 12.

For checks 3 and 4 (ordering and presentation), the content door examined is
`AGENTS.md` if present (else the entry door itself); read it (and any
`@`-imported source) to judge those checks.

---

### Check 1. Front-Door Coherence

**What it checks:** Whether the project's entry-door files are structured as a
clean source-of-truth + thin-pointer pair, or whether they duplicate or ignore
each other.

**Facts that inform it:** `agents_md`, `claude_md`, `front_door_link`

(`front_door_link` values: `none` | `claude->agents` | `agents->claude` |
`bidirectional` | `n/a`)

- **solid** — A single front-door exists (`agents_md` or `claude_md` but not
  both), OR both exist with a clean source-of-truth + thin-pointer relationship
  (`front_door_link` is `claude->agents`, `agents->claude`, or `bidirectional`);
  no substantial prose is duplicated between them.
- **drift** — Both files exist but one file references the other only in a vague or informal way (not a clean `@`-import or markdown-link pointer), or
  there is minor prose duplication that does not yet mislead.
- **gap** — Both files exist and `front_door_link=none`, OR substantial prose
  is duplicated across them; an agent cannot tell which is authoritative.

Soft low-severity nudge (never a hard fail): a CLAUDE.md-only project with no
AGENTS.md is fine, but the agent may suggest adopting AGENTS.md as a
vendor-neutral source of truth.

**Example adjustments:**
- Add `@AGENTS.md` to CLAUDE.md so the import chain is explicit.
- Collapse the duplicated half of one file into a single pointer to the other.

---

### Check 2. Hub Connectedness

**What it checks:** Whether the entry door links to the major subsystems and
working docs so agents can navigate to them in one hop.

**Facts that inform it:** `entry_hub_links`, reachability facts from the scanner

- **solid** — Major subsystem docs are reachable in one hop from the entry
  door; `entry_hub_links` covers the key areas (build, architecture, workflow,
  conventions).
- **drift** — Most subsystems are linked but one or two major areas require
  following an intermediary before reaching the relevant doc.
- **gap** — The entry door links few or no working docs; major subsystems are
  unreachable from it without prior knowledge of the directory layout.

**Example adjustments:**
- Add a repo-map section or direct links to the key subsystem docs in the entry
  door.
- Promote a buried index link to a top-level navigation item.

---

### Check 3. Information Ordering

**What it checks:** Whether load-bearing information (e.g., build/run commands)
appears early, before philosophy, history, or expansive prose.

**Facts that inform it:** `entry_outline`, `entry_outline_count`, plus judgment

Reference heuristic (not a mandate): what-this-is -> build/run -> repo map ->
conventions -> workflow -> gotchas. Apply as a guide, not a template — a project
that reorders for legitimate reasons is not penalized.

- **solid** — Priority order holds: an agent scanning the outline finds
  build/run commands and the repo map before philosophy or long prose; the
  structure serves a reader who needs to act, not one who needs to be convinced.
- **drift** — Mostly well-ordered but one load-bearing section (e.g., build
  commands) is displaced below a long introductory passage.
- **gap** — Load-bearing information (build/run, key commands) is buried at the
  bottom or middle; an agent must read past substantial philosophy or prose to
  reach actionable content.

**Example adjustments:**
- Move the buried build/run section above the philosophy or narrative sections.
- Hoist a key command block into an earlier section or summary.

---

### Check 4. Presentation

**What it checks:** Whether the content door is structured and scannable, or a
dense prose monolith that requires linear reading.

**Facts that inform it:** `entry_outline`, plus judgment

- **solid** — Content is sectioned with clear headers that telegraph each
  section's purpose; lists and/or tables are used where appropriate; the reader
  can jump to the relevant section without reading top-to-bottom; "where to go
  next" signposts are present.
- **drift** — Mostly scannable but one section is a wall of prose that could be
  broken into a list, or one transition point lacks a signpost.
- **gap** — The content door is a dense prose monolith with few or no headers;
  a reader must read linearly to locate any specific piece of information.

**Example adjustments:**
- Break a wall of prose into a bulleted or numbered list with a clear header.
- Add a "See also" or "Next steps" signpost at the end of a major section.

---

### Check 5. Routing Affordance

**What it checks:** Whether the content door tells a cold agent where work
starts — a compact task-routing affordance (a "making a change?" table or
section) whose rows dispatch directly to a lane's entry point (a doc or a
runnable command), with a stated fallback for readers who cannot use the
primary dispatch mechanism.

**Facts that inform it:** `entry_outline`, `entry_hub_links`, plus judgment

- **solid** — The door carries a routing affordance: an agent can classify
  "I'm about to do X" and reach the owning instruction chunk in one action,
  without reading any intermediary; rows point at entry points, not at menu
  documents; a fallback is stated.
- **drift** — An affordance exists but is incomplete (a common change class
  is missing), displaced below long prose, or a row targets an intermediary
  menu rather than an entry point.
- **gap** — No routing affordance: a cold agent must already know the layout,
  read several documents, or guess where a change starts.

**Form only, never fidelity.** This check judges that a routing affordance
exists and dispatches cleanly. Whether the routes are the *right* routes is
the owning workflow system's own validation concern — out of scope for a
doc-ergonomics audit.

**Example adjustments:**
- Add a "where a change starts" table to the content door: one row per change
  class, each pointing at the owning entry point.
- Replace a row that targets an index/menu doc with the leaf it meant.
