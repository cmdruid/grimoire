# `/dev backlog` — capture & groom product/feature follow-ups

Capture follow-up work into `dev/BACKLOG.md`, and tidy it. BACKLOG is the one tracker with a
**human producer** — "put this in the backlog" is something *you* say — alongside agents. This verb
is the quick, anytime way to add an item and to keep the list sharp.

It is **not** a maintenance tool. Removing shipped/dead items and the periodic backlog audit are
`/dev upkeep`'s job; the end-of-work sweep that routes byproducts across *all* trackers is
`/dev debrief`. This verb only **adds to** and **grooms** `BACKLOG.md`.

Two modes, selected by the argument:
- **Capture (default, no arg or a path arg)** — add item(s) to the backlog.
- **Groom (`groom` / `triage`)** — reorder, sharpen, and weed the existing list.

## When to use

- **Capture:** "put this in the backlog", "add a backlog item: X", "remind me to …", "/dev backlog",
  or "any follow-ups worth capturing from this?" — anytime, by you or an agent.
- **Groom:** "/dev backlog groom", "triage the backlog", "reprioritize / weed what's left".

**Do NOT use** for: a defect (`/dev bug` → `dev/bugs/`), dev-experience friction (`/dev issue` →
`dev/ISSUES.md`), qualitative observations (`/dev feedback` → `dev/FEEDBACK.md`), the end-of-work
multi-tracker sweep (`/dev debrief`), or draining shipped/stale items (`/dev upkeep`). Don't invoke
it mid-task for routine status checks.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Backlog: `<root>/dev/BACKLOG.md`. Create it if missing (`# Backlog` header + a one-line note that
  an item is *removed when it ships*, recorded in `dev/done/`).

## Backlog structure

`dev/BACKLOG.md` is a single **living** list — one top-level header, one section per group. Items
are plain `-` bullets (**no checkboxes**): an item is *open* while it's listed and simply **removed
when it ships** — the commit, plus any `dev/done/` stream digest, is the record (the drain is
`/dev upkeep`, not a checkbox).

**Follow the file's existing groups.** If `BACKLOG.md` exists, adopt its group headings and heading
level exactly — extend them, don't restructure. Add a new group only when nothing fits. A long-lived
backlog is organized by durable **domain / milestone groups** (e.g. `Performance`, `Tooling / CI`, a
milestone, `Known limitations`), so let the project's shape lead. Seed a *fresh* file with these
buckets only, skipping any that's empty:

1. **Loose ends** — in-scope work that didn't get done.
2. **Issues discovered, not fixed** — real problems observed but out of the original scope.
3. **Adjacent improvements** — cleanups/polish in code that was touched (optional).
4. **Open questions** — decisions deferred to the user, or clarifications the next agent needs.
5. **Future scope** — larger items discussed but explicitly out of the current batch.

**Per-item:** concrete description (with `file:line` where it applies) · **why** (one line) ·
**effort** `(S/M/L)` · trailing `· added YYYY-MM-DD`. Mark a genuine maybe `(unsure)` and say why.

## Capture mode

Two paths — the first is the headline:

1. **Direct (common case).** You or an agent *names* an item — "put X in the backlog." Turn it into
   a well-formed item and add it. Keep it quick; don't over-ceremony a single add.
2. **Sweep (secondary).** "Any follow-ups from this?" — scan the conversation for backlog-worthy
   items and add them. (The end-of-work sweep across *all* trackers is `/dev debrief`; this is the
   BACKLOG-only, invoke-anytime version.)

Procedure:
1. **Sanity check.** If there's nothing real to capture, write nothing and say so.
2. **Form each item** (description · why · effort · added-date). **Grounding:** every item ties to
   something real — named by the user, or that actually came up. Do **not** pad with pattern-matched
   generics ("add tests", "add logging") unless they specifically surfaced.
3. **Categorize** into the file's groups (or the seed buckets for a fresh file). If an item fits
   several, pick the most actionable.
4. **Merge.** Append under the right group heading (creating it if absent), preserving group order.
   **Dedupe** against existing items — skip a near-duplicate rather than add it. Never edit or
   remove existing items in capture; you only add.
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit the backlog change via
   `scripts/scoped-commit.sh <root> "Backlog: <short what>" dev/BACKLOG.md`, then run the host doc-linter.
   Invoked **inside `/dev debrief`/`upkeep`**, do **not** commit — only write; the sweep makes the
   single atomic commit. (This standalone self-commit is a deliberate refinement: a `/dev backlog`
   add now lands on its own rather than waiting for an unrelated commit.)
6. **Report** what you added and the path.

## Groom mode

Triggered by `groom` or `triage`. Tidies the list; does not capture new items.

1. **Read** `BACKLOG.md`. Run `scripts/dev-health.sh stale-refs <root> dev/BACKLOG.md` first: it
   flags items whose `file:line` no longer resolves — the referenced code usually shipped or moved,
   so those are prime weed (done) or sharpen (fix the ref) candidates. Facts, not verdicts: judge
   each, don't auto-remove.
2. **Re-order** within each group by priority/relevance — most actionable near the top.
3. **Sharpen** vague items: split a broad item, fill a missing `file:line` / why / effort.
4. **Weed** dead items — already done, obsolete, or decided against. Remove them; if *why* it's dead
   isn't obvious, drop a one-line note in the removal commit (or `dev/done/`) so the rationale
   survives.
5. **Commit** the groomed list via `scripts/scoped-commit.sh` (standalone only — invoked inside an
   `upkeep` sweep, **write only**; the sweep makes the single atomic commit), then report what
   moved, split, and got removed.

Grooming is visible — never silently delete a substantive item. When unsure whether an item is
dead, leave it and flag it.

## Removal — a pointer, not a mode

A shipped or abandoned item is **removed**, not checked off: delete the bullet (in the commit that
ships the work, or when groom weeds a dead one). There is no `prune` step and no `[x]` — the commit
history plus any `dev/done/` stream digest are the record, and the periodic drain/audit is
`/dev upkeep` (its `backlog` pass). **This verb never writes `dev/done/`.**

## Relationship to neighboring verbs

- **`/dev debrief`** — the completion sweep across *all* trackers; it defers BACKLOG item-format to
  this verb. `backlog` is the anytime, BACKLOG-only, direct add.
- **`/dev upkeep`** — drains and audits BACKLOG (removes shipped/dead items; the done/relevance
  pass); it can invoke `backlog groom`. `backlog` itself no longer prunes.
- **`/dev bug`**, **`/dev issue`**, **`/dev feedback`** — the other capture homes; this verb is
  `BACKLOG.md` only.

## Style notes

- Items are forward-looking action descriptions, not past-tense recaps.
- Plain `-` bullets — no checkboxes. Quote paths exactly; omit a line number rather than guess.
- This is a record, not a commitment — don't promise to do the items yourself afterward.

## Done when

The named follow-up(s) are in `dev/BACKLOG.md` as well-formed, deduped, grouped bullets (capture),
or the list is sharper / reordered / weeded (groom) — and nothing shipped is left lingering (that
removal is on-ship + `/dev upkeep`, never this verb).
