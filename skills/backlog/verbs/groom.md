# `/backlog groom` — tidy the backlog: dedupe, rank, sharpen, weed

Keep `.agents/dev/BACKLOG.md` sharp. This verb **reshapes** the existing list — it does not capture new
items (that's the sibling `/backlog backlog`). Grooming is the anytime, BACKLOG-only tidy; the
periodic drain/audit across the whole `.agents/dev/` system is `/foreman tune`.

## When to use

- "/backlog groom", "triage the backlog", "reprioritize / weed what's left", "the backlog is getting
  messy — sharpen it".

**Do NOT use** for: adding a new follow-up (`/backlog backlog`), the end-of-work multi-tracker sweep
(`/backlog debrief`), or the periodic system-wide drain (`/foreman tune`). Don't invoke it mid-task
for routine status checks.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Backlog: `<root>/.agents/dev/BACKLOG.md`. If it doesn't exist, there's nothing to groom — say so and stop.

## Procedure

1. **Read** `BACKLOG.md`. Scan each item's `file:line` reference: an item whose referenced code no
   longer resolves (the code shipped or moved) is a prime **weed** (done) or **sharpen** (fix the ref)
   candidate. Judge each — facts, not verdicts; don't auto-remove. (The system-wide stale-ref pass
   over *all* trackers + spine docs is `/foreman check`; this verb grooms BACKLOG by reading it.)
2. **Re-order** within each group by priority/relevance — most actionable near the top. Preserve the
   file's group headings and heading level; don't restructure the groups.
3. **Sharpen** vague items: split a broad item, fill a missing `file:line` / why / effort.
4. **Weed** dead items — already done, obsolete, or decided against. Remove them; if *why* it's dead
   isn't obvious, drop a one-line note in the removal commit (or `.agents/dev/done/`) so the rationale
   survives.
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit the groomed list via
   `scripts/scoped-commit.sh <root> "Backlog: groom" .agents/dev/BACKLOG.md`, then run the host doc-linter.
   Invoked **inside a `/foreman tune` sweep**, do **not** commit — only write; the sweep makes the
   single atomic commit.
6. **Report** what moved, split, and got removed.

Grooming is visible — never silently delete a substantive item. When unsure whether an item is dead,
leave it and flag it.

## Relationship to neighboring verbs

- **`/backlog backlog`** — the capture sibling: adds a well-formed item. `groom` reshapes what's
  already there; it never adds.
- **`/foreman tune`** — the periodic system-wide drain/audit; it can invoke `groom` on BACKLOG as part
  of a broader pass. `groom` itself is the anytime, BACKLOG-only tidy.
- **`/backlog debrief`** — the end-of-work sweep; it captures byproducts, it doesn't reshape the list.

## Style notes

- Items are forward-looking action descriptions, not past-tense recaps.
- Plain `-` bullets — no checkboxes. Quote paths exactly; omit a line number rather than guess.

## Done when

`.agents/dev/BACKLOG.md` is sharper — reordered by relevance, vague items split/filled, dead items weeded with
their rationale preserved — and the chat names what moved, split, and got removed. To *add* a new
item, run `/backlog backlog`.
