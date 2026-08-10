# `/clankshop docs` — audit and tune the documentation spine

Hat: `roles/chiropractor.md` — read the hat first; you operate this verb wearing that hat.

Audit and tune a repository's documentation **spine** -- the tree of links/references rooted at the
agent entry door -- for agent performance. Framework-aware (it knows the deployed layout --
`.handbook/`, `.records/`, the front door -- directly), while the
spine machinery still runs on any markdown tree. Adaptive `scan -> diagnose -> adjust` flow;
read-only by default. On a root with no installation block the audit and report run freely as
ever, but **Adjust's framework-layout surgery** stays within whatever doc conventions the host
actually has -- never scaffold `.handbook/`/`.records/` where none exist.

**The fact partition (who checks what).** This verb owns the **document side**: entry-shape
conformance, within-scope citation resolution, budgets (the declaration-driven checks), link/path
health, navigability, read-cost, and affordance -- what documents *declare and say*. **Assembly
facts** -- installation stamps, projections vs their inputs, cross-store foreign keys, door
registration -- are `check`'s, never duplicated here. One validator per fact.

Bare `/clankshop docs` (a `<scope>` path as the optional arg) runs the adaptive flow below.
Captured doc-flavored dev-experience signal reaches this hat as **improvement items routed by
`calibrate`** (accepted doc-drift findings, doc-flavored tracker entries the loop dispatches);
each is applied as a focused diagnosis + a normal Adjust with the usual confirmation gate.

## When to Use
- Auditing docs for drift (broken links, stale paths, contradictions) or agent-friendliness.
- Tuning an existing doc system; introducing GLOSSARY/INDEX/read-first ordering.
- NOT for source-code-comment review, and NOT a code-quality audit.

---

## The Spine Model

The **spine** is the transitive reference tree rooted at the repository's **entry door** -- the first
of `AGENTS.md`, `CLAUDE.md`, `README.md`, `.cursorrules` that exists, biased toward whichever one
imports the others via `@`-style directives (that file is the true door).

From the entry door, the spine grows via two link types:

- **Import chain** -- `@`-style directives in the entry door that pull other docs into every session
  as always-loaded context (one hop; these docs cost tokens on every run).
- **Reference tree** -- standard markdown links (`[text](path.md)`) anywhere in the spine; docs
  reachable by BFS from the entry door are **on-spine**; everything else is **off-spine** (dark to
  agents unless reached by another path).

**Scope is docs only.** The spine is markdown files. Source code, config, and assets are out of
scope -- this is a doc-ergonomics audit, not a code-quality audit.

---

## The Adaptive Flow

```
scan -> diagnose -> adjust
```

**Read-only by default.** The scan and diagnosis steps never write anything. Adjust requires
explicit confirmation before any file is modified.

**Adapts to repo state:**

- **No entry door** -- the scan will report `entry_door=` empty. Stop and propose a front-door
  before diagnosing; the rest of the flow is undefined without one.
- **Minimal spine** (a single README, no import chain) -- the diagnosis focuses on presence of
  signposting, read-path, and token economy. Score a structural dimension solid (N/A -- no structure
  to drift yet) only when the repo is genuinely minimal; on a maturing repo a missing structure is a
  gap, not solid -- judge against repo maturity.
- **Rich spine** (deep import chain, many docs) -- the full 12-dimension diagnosis applies; fan out
  for heavy docs (see Diagnose).
- **Healthy spine** -- diagnose returns mostly solid; tune minor drift and propose pruning rather
  than restructuring.
- **Multi-root repo** (`sub_roots_count` > 0) -- the scanned tree is a superproject of nested
  spines; scope the audit with the user before diagnosing (see Multi-Root Repos).

---

## Scan

Resolve `scripts/spine-scan.sh` from the skill's own base directory (not a host-specific path),
then run:

```
scripts/spine-scan.sh <repo-root>
```

The scanner is read-only and emits `key=value` facts to stdout. Facts you will receive:

| Fact | What it captures |
|------|-----------------|
| `entry_door` | The resolved entry-door filename (empty if none found) |
| `import_chain` | Comma-separated list of `@`-imported docs from the entry door |
| `edges` / `edges_count` | One `src->tgt` pair per link (capped sample); count is the true total. NOTE: unlike the other list facts, `edges` emits one `edges=` line PER EDGE (up to the cap) rather than a single comma-joined line |
| `max_depth` | Longest BFS hop distance from the entry door to any reached doc (feeds Read-Path) |
| `orphan_docs` / `orphan_docs_count` | Docs not reachable from the entry door (capped sample + true count) |
| `unreachable_dirs` / `unreachable_dirs_count` | Top-level dirs with no reachable docs (capped sample + count) |
| `broken_links` / `broken_links_count` | Link edges in **live** docs whose target file does not exist (capped sample + count) -- the actionable rot |
| `broken_links_archived` / `broken_links_archived_count` | Broken link edges in **historical-record** docs (changelog, archive/history/logs/done store, or dated file); the target existed when the record was written -- records, not rot |
| `stale_refs` / `stale_refs_count` | Inline code-span path refs in **live** docs that resolve nowhere -- neither root-relative nor doc-relative in this repo, and not inside any nested repo root (capped sample + count) |
| `stale_refs_archived` / `stale_refs_archived_count` | Same, but in **historical-record** docs -- a past state cited by design; weigh lightly |
| `sub_roots` / `sub_roots_count` | Nested git repos (submodules / embedded repos) under the scanned root, each annotated `path:front-door` (door empty if none). Their docs are excluded from this scan -- each nested root is its own spine (see Multi-Root Repos) |
| `xroot_refs` / `xroot_refs_count` | Code-span path refs that do not resolve in this repo but DO resolve inside a nested repo root -- **superproject -> submodule** citations (the orchestrator's job), not staleness. The benign direction |
| `escaping_refs` / `escaping_refs_count` | Refs (markdown links, `@`-imports, OR backtick code-span paths to any file) whose target climbs above the scanned root via `..` (reported raw, never clamped). Inside a nested repo these break on a standalone clone -- the **submodule -> outward** self-containment violation |
| `always_loaded_bytes` | Byte total of the entry door + import chain (token-cost proxy) |
| `doc_sizes` / `doc_sizes_count` | Top-15-largest docs by bytes (capped sample); count is total doc count |
| `has_glossary` | `1` if a GLOSSARY.md exists at the root or `docs/`, else `0` |
| `has_front_door` | `1` if an `AGENTS.md`/`CLAUDE.md` front door exists at the root, else `0` |
| `has_stewardship_map` | `1` if `.handbook/README.md` carries a spine-index declaration plus steward blocks -- a **map** (ownership regions), never an index/TOC |
| `fileline_overruns` / `fileline_overruns_count` | Live-doc `path:line` refs whose path exists but whose line number runs past EOF -- the code moved under the citation (capped sample + count) |
| `uncovered_dirs` / `uncovered_dirs_count` | Non-hidden top-level dirs mentioned nowhere in the door docs (`AGENTS.md`, `.handbook/README.md`, `README.md`) |
| `decl_docs` / `decl_docs_count` | Spine docs carrying a declaration block (`path:kind`), parsed via the shared parser (`scripts/spine-parse.sh`) |
| `decl_malformed` / `decl_malformed_count` | Declaration blocks that do not parse (duplicate keys, unclosed, bad line) -- facts, never guessed through |
| `decl_budget_over` / `decl_budget_over_count` | Declared budgets exceeded (`file (usage/cap unit)`) -- budgets are curation triggers, not split triggers; the steward judges |
| `decl_unresolved_citations` / `decl_unresolved_citations_count` | Typed-ID citations found in a store's declared refs scope with no definition in the declaring store (`src:ID`) |
| `frontmatter_coverage` | Fraction of reached docs that have a frontmatter block (`fm/total`) |
| `agents_md` | `1` if an `AGENTS.md` exists at the repo root, else `0` |
| `claude_md` | `1` if a `CLAUDE.md` exists at the repo root, else `0` |
| `front_door_link` | Cross-reference relationship between the two front-door files (`none|claude->agents|agents->claude|bidirectional|n/a`). Counts only intentional pointers (`@`-import or markdown link); an incidental backtick mention of the other file does not register as a cross-reference |
| `entry_outline` / `entry_outline_count` | Capped ordered list of top-level headings from the content door (AGENTS.md if present, else the entry door -- so a thin-pointer CLAUDE.md that `@`-imports AGENTS.md draws these from AGENTS.md); `_count` is the true total (capped list fact) |
| `entry_hub_links` | Distinct docs the content door (AGENTS.md if present, else the entry door) references via ANY navigational ref -- markdown links, `@`-imports, AND backtick inline-code doc refs (agent docs often link their repo-map via backtick refs). A measure of navigational connectedness |

**List facts are capped samples with a true count.** Each list fact (`edges`, `orphan_docs`,
`unreachable_dirs`, `broken_links`, `broken_links_archived`, `stale_refs`, `stale_refs_archived`,
`sub_roots`, `xroot_refs`, `escaping_refs`, `doc_sizes`, `entry_outline`, `fileline_overruns`,
`uncovered_dirs`, `decl_docs`, `decl_malformed`, `decl_budget_over`, `decl_unresolved_citations`) emits two keys: a `<key>_count=<N>`
line carrying the true total, and a `<key>=` line carrying only the first N entries (the top 15
largest for `doc_sizes`), suffixed with a ` ...(+M more)` marker when truncated. This keeps the
scanner output small on large repos. Read the `_count` for magnitude, the sample for examples --
do not assume the sample is the whole list. The scalar facts (`entry_door`, `import_chain`, `max_depth`,
`always_loaded_bytes`, `has_glossary`, `has_front_door`, `has_stewardship_map`,
`frontmatter_coverage`, `agents_md`, `claude_md`, `front_door_link`, `entry_hub_links`) are reported in full.

**Facts, not verdicts -- you judge.** The scanner reports what it measured; interpreting whether a
count is healthy or problematic is your job, not the scanner's.

---

## Multi-Root Repos

When `sub_roots_count` > 0, the scanned tree is a **superproject**: each nested git repo under it
(submodule or embedded repo) is its own spine with its own entry door, and its docs are
deliberately excluded from the outer scan.

**A nested repo must be self-contained.** Each submodule can be cloned on its own, with no parent
and no siblings present, and its docs must still orient an agent. So a submodule doc may not
reference *outward* -- not up to the superproject, not sideways to another repo. Those references
are dead on a standalone clone and strand the agent. This is a hard rule, and enforcing it is a
**required** part of auditing a superproject, not optional.

- **Scope with the user.** Report the `sub_roots` list (with each root's front door). The outer
  spine plus a **standalone self-containment scan of every nested root is the default scope**;
  only a full 12-dimension diagnosis of each nested spine is opt-in (it is one more full pass per
  root). Confirm which the user wants, but run the self-containment scan regardless.
- **Scan each nested root standalone and gate self-containment.** Run the scanner separately on
  each nested root (`scripts/spine-scan.sh <sub_root>`). For each, require `escaping_refs` empty
  and no `stale_ref` that points at a superproject or sibling path. Any such outward reference is
  a self-containment **gap** for that repo (see DOC-RUBRIC Currency) -- report it with the file and
  the offending ref so it can be fixed. Fan out parallel subagents per root for scale.
- **One diagnosis per in-scope spine.** When a nested spine is in scope for full diagnosis, score
  it on its own terms -- its own entry door, its own maturity. Keep per-spine scores separate: a
  full report for the primary spine, plus a compact per-root table for the others.
- **Direction decides whether a cross-root ref is a defect.** *Submodule -> outward* (up or
  sideways) is a violation -- caught standalone as `escaping_refs` (relative climbs) or unresolved
  `stale_refs` (paths that exist only in the parent/sibling). *Superproject -> submodule* is the
  orchestrator doing its job: the outer scan's `xroot_refs` are legitimate context-relative
  citations that resolve when the submodule is checked out -- note them, do not penalize them, and
  exclude them from staleness. The scanner catches *path/link* escapes only; a submodule doc that
  depends on superproject context in **prose** (no link) will not trip a fact -- judge that by
  reading.

---

## Entry-Door Audit

After scanning, run a focused pass on the project's entry-door files before proceeding to the full
12-dimension diagnosis. Consume the five entry-door facts (`agents_md`, `claude_md`,
`front_door_link`, `entry_outline` / `entry_outline_count`, `entry_hub_links`), then read the
relevant files directly to judge the five checks in docs/DOC-RUBRIC.md's "Entry-Door Audit" section.

**Content-door rule.** The file you examine for ordering and presentation (checks 3 and 4) is
`AGENTS.md` if it is present at the root; otherwise use the entry door itself. A CLAUDE.md that is
a thin pointer importing AGENTS.md via `@` carries no substantive outline of its own -- read the
imported source, not the pointer.

Read the content door and any `@`-imported source it references; also read BOTH front-door files (AGENTS.md and CLAUDE.md) when both exist, since check 1 (coherence) compares them for duplication and pointer direction. Score each of the five checks
(`solid | drift | gap`) per the criteria in docs/DOC-RUBRIC.md. Record a one-line rationale and any
specific adjustment for each check. Feed these findings into Section 0 of the report (below) and
let them inform the full diagnosis where the 12 dimensions overlap (e.g., hub connectedness informs
Read-Path; coherence informs Consistency).

---

## Diagnose

Score the spine against all 12 dimensions in `docs/DOC-RUBRIC.md`. Each dimension maps to scanner facts
and/or read-only judgment; the rubric specifies which. Scoring is three-tier per dimension:
**solid** (healthy), **drift** (degradation started, targeted fix needed), **gap** (broken or
absent, structural repair needed).

**Archive/store orphans are not a coverage gap.** When `orphan_docs_count` is high, check where the
orphans concentrate before scoring. A large **dated archive or store** -- a directory of
date-prefixed files (e.g. `.records/done/<YYYY-MM-DD>-*.md`, a store's `archive/`), or any directory the map references as a
glob/store rather than per-file (logs, completed-work archives, per-record notes) -- is reached by
convention or glob, not by navigation, so it is *legitimately* not link-reachable. That is
intentional, not drift. Score reachability/coverage on the orphans **outside** such stores; report
the store separately as "intentional archive (N docs)" rather than folding it into the gap count.

**Score Currency on the live counts, not the raw totals.** The scanner already separates broken/
stale refs in historical-record docs into `broken_links_archived` / `stale_refs_archived` -- those
cite past states by design and are not rot. Judge Currency from `broken_links` / `stale_refs` (the
live subset), and treat a large archived count next to a small live count as a healthy spine. Note
the archived magnitude for context; never fold it into the score.

**Fan out for scale.** When the spine has many docs or a deep import chain, fan out parallel
subagents -- one per rubric cluster (Cluster A: Structural Integrity; Cluster B: Agent Ergonomics;
Cluster C: Affordances & Durability) or one per heavy doc. Collect their scored findings and
merge into a single report. If the harness offers a workflow engine, you may use it to drive the
heavy-doc pass -- but the fan-out and merge are the same regardless of mechanism.

Produce the report (see Report Format below) after all dimensions are scored.

---

## Report Format

Print the report to the conversation. **On a framework installation, also write the durable
record**: `.records/reports/doc-drift-<YYYY-MM-DD>-<slug>.md` from this skill's
`templates/doc-drift.md` -- frontmatter floor (`type: doc-drift`, `id` = the filename stem
verbatim, `date`, `source`, optional `processed:`) and one keyed `#### <key> -- <title>` heading
per finding (keys match `[a-z0-9-]+`, unique within the report -- the stable handles the
improvement loop drains). On a filename collision, suffix the slug deterministically (`-2`, `-3`,
...) before first publication; never rename after. Outside a framework installation the
conversational report alone is the output, as before.

**Declaration-led pause.** Where a store declares a pause encoding, a paused entry is the
human's: audit it, count it, but never propose an Adjust that mutates it -- and when a pass
cannot *prove* an entry unpaused (missing/malformed declaration), skip it and say so.

The entry door is the highest-leverage node in the spine -- every agent session starts there, so
any drift or gap here multiplies across every run.

**Section 0 -- Entry-Door**

State which front-door files were found (`agents_md` / `claude_md`) and which one is the entry
door. Give the `front_door_link` verdict in one line. Then score each of the five checks:

```
check 1. Front-Door Coherence -- solid | drift | gap -- <one-line rationale>
check 2. Hub Connectedness    -- solid | drift | gap -- <one-line rationale>
check 3. Information Ordering -- solid | drift | gap -- <one-line rationale>
check 4. Presentation         -- solid | drift | gap -- <one-line rationale>
check 5. Routing Affordance   -- solid | drift | gap -- <one-line rationale>
```

Follow with a short list of specific entry-door adjustments (if any checks are drift or gap).

**Section 1 -- Spine-health profile (12-dim scorecard)**

One line per dimension: `dim N. <name> -- solid | drift | gap -- <one-line rationale>`.
Group by cluster.

**Section 2 -- Severity-ranked findings**

Table with columns: `dimension | location | severity | issue | adjustment`.
Sort by severity (gap first, then drift). Omit solid dimensions.

**A raw count is not a finding until you triage it.** The scanner reports magnitudes
(`stale_refs_count=812`); many will be intentional (historical records, cross-root citations,
dated archives). Before a count becomes a finding, reduce it to the subset that is genuinely
wrong and cite *that* number. A finding that quotes the raw count without partitioning it is a
scoring error -- e.g. Currency on this repo is judged from the 3 live broken links, not the 26
total, and the ~130 live stale refs, not the 812. If the triaged subset is small, the dimension
is closer to solid than the raw count suggests -- say so.

**Section 3 -- Verdict, split by who acts**

Split the highest-leverage adjustments into two lists so the reader knows what needs no decision
versus what needs theirs:

- **Ready to apply (mechanical)** -- fixes with one correct outcome: broken links, stale refs,
  frontmatter stubs, routing an orphan. These need no judgment call, only confirmation to run.
- **Decisions for the maintainer** -- choices only the owner can make: adopt frontmatter or
  declare index-based enumeration the convention, widen a docs gate, split a monolith, rename a
  taxonomy. State the trade-off in one line each; do not pre-decide.

Be concrete in both: name the file, the change, the expected improvement. Cap the two lists
together at ~5 items; when findings cluster, prune to the top 3.

**Close with the handoff.** End the report with a one-line next step that branches into Adjust:
state how many mechanical findings can be auto-fixed now and that the decisions await the
maintainer -- e.g. "Next: 4 mechanical fixes ready to apply on confirmation; 2 decisions await
you." A read-only audit that dead-ends at a findings table leaves the reader asking "now what?" --
the handoff answers it.

---

## Adjust

Adjust runs only after the user confirms. Two modes:

- **Mechanical fixes** (broken links, frontmatter stubs, stale refs) -- apply directly; show a
  diff or file list before writing.
- **Structural changes** (new router doc, splitting a monolith, reorganizing taxonomy) -- propose
  the plan first, describe the before/after layout, wait for confirmation before touching any file.

**Never delete content without surfacing it.** If a doc is an orphan and the right action is
deletion, show the doc's content or a summary and confirm before removing it.

**Re-scan to verify.** After applying adjustments, run `scripts/spine-scan.sh` again on the same
root and confirm the target facts improved (e.g., `orphan_docs` is empty, `broken_links` is
empty). Report any findings that did not resolve.

---

## Boundaries

- **A role of the pack, still spine-generic.** The scanner consumes the pack face's shared
  declaration parser and knows the deployed layout directly; everything else references only this
  skill's own `scripts/spine-scan.sh`, `docs/DOC-RUBRIC.md`, and `templates/doc-drift.md`. Generic
  concepts ("fan out parallel subagents", "a workflow engine if the harness offers one") are used
  in place of any named tool.
- **Docs only.** Source code, test files, build configs, and binary assets are out of scope.
  The spine is markdown; the audit is ergonomics and navigability, not correctness of code or
  comments.
- **Not a code-quality audit.** Logic errors, test coverage, and API design are out of scope.
  If you encounter a code quality concern while reading a doc, note it as out of scope and move on.
