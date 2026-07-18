# `/backlog curate` — keep the trackers tidy: dedupe, rank, sharpen, weed

Keep `.records/tasks.md` sharp. This verb **reshapes** the existing list — it does not capture new
items (that's the sibling `/backlog task`). Curating is **hygiene**: dedupe, re-rank, sharpen vague
items, and weed the genuinely dead. It is a tidy pass over backlog's own lists, **never a drain** —
folding captured signal back into doctrine, or the periodic system-wide relevance audit, is
`/foreman calibrate`'s job, not this verb's.

## When to use

- "/backlog curate", "tidy the backlog", "reprioritize / weed what's left", "the backlog is getting
  messy — sharpen it".

**Do NOT use** for: adding a new follow-up (`/backlog task`), the end-of-work multi-tracker sweep
(`/backlog debrief`), or draining system-relevant signal into doctrine (`/foreman calibrate`). Don't invoke
it mid-task for routine status checks.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Tasks: `<root>/.records/tasks.md`. If it doesn't exist, there's nothing to curate — say so and stop.

## Procedure

1. **Read** `tasks.md`. Scan each item's `file:line` reference: an item whose referenced code no
   longer resolves (the code shipped or moved) is a prime **weed** (done) or **sharpen** (fix the ref)
   candidate. Judge each — facts, not verdicts; don't auto-remove. (The system-wide stale-ref pass
   over *all* trackers + spine docs is `/foreman check`; this verb curates TASKS by reading it.)
2. **Re-order** within each group by priority/relevance — most actionable near the top. Preserve the
   file's group headings and heading level; don't restructure the groups.
3. **Sharpen** vague items: split a broad item, fill a missing `file:line` / why / effort.
4. **Weed** dead items — already done, obsolete, or decided against. Remove them; if *why* it's dead
   isn't obvious, drop a one-line note in the removal commit (or `.records/archive/`) so the rationale
   survives.
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit the curated list via
   `scripts/scoped-commit.sh <root> "Tasks: curate" .records/tasks.md`, then run the host doc-linter.
   Invoked **inside a `/foreman calibrate` sweep**, do **not** commit — only write; the sweep makes the
   single atomic commit.
6. **Report** what moved, split, and got removed.

Curating is hygiene, not draining — it tidies backlog's lists in place. It is also visible: never
silently delete a substantive item. When unsure whether an item is dead, leave it and flag it.

## Relationship to neighboring verbs

- **`/backlog task`** — the capture sibling: adds a well-formed item. `curate` reshapes what's
  already there; it never adds.
- **`/foreman calibrate`** — the periodic system-wide drain/audit that folds captured signal into
  doctrine; it can invoke `curate` on TASKS as part of a broader pass. `curate` itself is the anytime,
  TASKS-only tidy — hygiene, never a drain.
- **`/backlog debrief`** — the end-of-work sweep; it captures byproducts, it doesn't reshape the list.

## Style notes

- Items are forward-looking action descriptions, not past-tense recaps.
- Plain `-` bullets — no checkboxes. Quote paths exactly; omit a line number rather than guess.

## Done when

`.records/tasks.md` is sharper — reordered by relevance, vague items split/filled, dead items weeded with
their rationale preserved — and the chat names what moved, split, and got removed. To *add* a new
item, run `/backlog task`.
