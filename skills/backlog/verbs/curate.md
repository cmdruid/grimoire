# `/backlog curate` — keep the trackers tidy: dedupe, rank, sharpen, weed

Keep the `.records/trackers/` stores sharp. This verb **reshapes** what's already filed — it does
not capture new items (that's the capture verbs). Curating is **hygiene**: dedupe, re-rank,
sharpen vague items, weed the genuinely dead (logged `dropped`), stamp pending IDs, repair
duplicates with aliases, and age resolved tickets and store-dir files into their `archive/`. It is
a tidy pass over backlog's own stores, **never a drain** — list hygiene is this verb's; what a
captured signal *means for the system* belongs to the improvement loop, not here.

## When to use

- "/backlog curate", "tidy the backlog", "reprioritize / weed what's left", "the backlog is getting
  messy — sharpen it".

**Do NOT use** for: adding a new follow-up (`/backlog task`), the end-of-work multi-tracker sweep
(`/backlog debrief`), or deciding what a signal means for the system (the improvement loop’s job). Don't invoke
it mid-task for routine status checks.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- The stores: `<root>/.records/trackers/` (`tasks.md`, `issues.md`, `feedback.md`, `bugs/`,
  `notes/`) and `<root>/.records/tickets/`. If none exist, there's nothing to curate — say so and
  stop. On an **unstamped root** this verb refuses: report `unstamped` and point at the clankshop
  onramps.

## Procedure

1. **Read** `tasks.md`. Scan each item's `file:line` reference: an item whose referenced code no
   longer resolves (the code shipped or moved) is a prime **weed** (done) or **sharpen** (fix the ref)
   candidate. Judge each — facts, not verdicts; don't auto-remove. (The system-wide stale-ref pass
   over *all* stores + spine docs is the deployed check chain; this verb curates by reading its facts.)
2. **Re-order** within each group by priority/relevance — most actionable near the top. Preserve the
   file's group headings and heading level; don't restructure the groups.
3. **Sharpen** vague items: split a broad item, fill a missing `file:line` / why / effort.
4. **Weed** dead items — already done, obsolete, or decided against. A weeded entry is completed
   with the `dropped` outcome — `scripts/done-entry.sh <root> <id> dropped "<why it's dead>"` —
   never silently deleted; the done-log line preserves the rationale. Judge each — facts, not
   verdicts; when unsure, leave it and flag it.
5. **Stamp pending IDs (curation is the ID landing point).** Any `((pending: <slug>))` placeholder
   (flat trackers) or pending `id:` (store dirs) left by a branch-side capture gets its real
   counter ID now — the next free number scanning the live store *and* the done log. This runs on
   the trunk checkout only; an ID is immutable once published.
6. **Repair duplicate IDs with aliases.** The whole-installation duplicate scan (clankshop
   `check`) is the backstop; on a duplicate, the entry that published later takes the next free
   ID and keeps its old identifier per the store's alias encoding (`(alias <old>)` on the line /
   heading, or a frontmatter `alias:` key) so existing citations still resolve.
7. **Ticket hygiene (facts from the check chain, judged here).** Flag stale `open`/`answered`
   tickets by unanswered age to the human — a ticket is the human's; curation never answers or
   closes one. Age **resolved** tickets into `.records/tickets/archive/` (`git mv`; the file, its
   ID, and its done-log line stay valid — report IDs and `TK-` citations never rename).
8. **Commit (standalone only).** Invoked **standalone**, scoped-commit everything curation touched
   via `scripts/scoped-commit.sh <root> "Trackers: curate" <paths…>`. Invoked **inside a sweep**,
   do **not** commit — only write; the sweep makes the single atomic commit.
9. **Report** what moved, split, got stamped, got aliased, got archived, and got removed.

Curating is hygiene, not draining — it tidies backlog's lists in place. It is also visible: never
silently delete a substantive item. When unsure whether an item is dead, leave it and flag it.

## Relationship to neighboring verbs

- **`/backlog task`** — the capture sibling: adds a well-formed item. `curate` reshapes what's
  already there; it never adds.
- **`/backlog done` / `/backlog close`** — completion writers; `curate` only logs `dropped` weeds
  and never resolves tickets (a ticket is the human's — hygiene flags its age, nothing more).
- **`/backlog debrief`** — the end-of-work sweep; it captures byproducts, it doesn't reshape the list.

## Style notes

- Items are forward-looking action descriptions, not past-tense recaps.
- Plain `-` bullets — no checkboxes. Quote paths exactly; omit a line number rather than guess.

## Done when

The stores are sharper — reordered by relevance, vague items split/filled, dead items weeded with
their `dropped` rationale logged, pending IDs stamped, duplicates aliased, stale tickets flagged
and resolved ones aged — and the chat names what changed. To *add* a new item, run the capture
verbs.
