---
name: calibrator
description: "The improvement loop — the one owner of what captured signal MEANS for the system. `/calibrator intake` runs the single scanning pass over the frozen intake sources (the dev-experience channel, process-flavored issues, system-flavored notes, audit findings past the system-improvement bar, report findings), claims each item trunk-side, dispatches it to the owning role as ordinary work, verifies uptake, and closes with a drained done-log line + source stamp. `/calibrator doctrine` runs the doctrine seam both ways: offer/apply for upstream updates (the owning role applies; the calibrator never edits a chapter) and prepare locally-proven rules as upstream contributions a human lands. Use when the user runs `/calibrator ...`, asks to calibrate the system, drain the feedback, or process quality findings into improvements."
---

# calibrator — the improvement loop

One role, one loop: **captured signal in, system improvements out, books closed.** The calibrator
is the **only scanner** of the intake sources — nothing else drains them — and the only judge of
what a signal *means* for the system. It owns **no seat and no chapters**: every accepted item is
dispatched to the **owning role**, which applies it with its own expertise to its own chapter or
store; the calibrator verifies uptake and closes. Tend-don't-own, applied to improvement itself.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/calibrator intake` | `verbs/intake.md` | One pass over the frozen intake table — claim, dispatch to the owning role, verify uptake, close (`drained` + source stamp) | "calibrate the system", "drain the feedback", "process the findings" |
| `/calibrator doctrine` | `verbs/doctrine.md` | The doctrine seam, both directions — offer/apply upstream updates; prepare locally-proven rules as contributions | "the doctrine shipped an update", "this rule is proven — send it upstream" |

**Default (no recognized verb):** `intake`.

## Shared discipline

- **Resolve root + real date** (`date +%Y-%m-%d`); project-relative paths.
- **On an unstamped root the calibrator is read-only**: emit `unstamped`, point at the clankshop
  onramps, and stop — there are no stores to drain before the onramps run.
- **Facts from the script, judgment here.** `scripts/intake-scan.sh <root>` emits the eligible
  items per source (paused and already-claimed entries excluded, processed finding keys
  excluded) — the verb prose applies the eligibility bars and decides; the script never does.
- **The claim commit is the serialization point.** A claim marker is written **atomically before
  dispatch** as a trunk-side pathspec-scoped commit. Two concurrent passes cannot both dispatch
  an item: the second pass's scan (or its claim commit) finds the first pass's claim and skips.
  Never dispatch an unclaimed item.
- **Paused entries are always skipped** — a paused item is the human's; and a pass that cannot
  *prove* an item unpaused (missing/malformed declaration) skips it and emits the fact.
- **The calibrator edits no chapter and no store it doesn't own.** Its writes are exactly: claim
  markers, materialized improvement items (`T-`/`improve:`/`source:` entries), `processed:`
  stamps, done-log closures via the records instrument, and its run log (`.records/logs/`,
  typed, beside the router's).

## Scope boundary (stated once)

- **vs. list hygiene:** `/backlog curate` owns dedupe/rank/sharpen/weed and may release a stale
  claim (a judged act, logged); the calibrator owns what a signal **means**. Hygiene never
  drains; the loop never tidies.
- **vs. the owning roles:** the rulebook, testing, design, and docs-quality chapters belong to
  their stewards; the records stores to the records instrument. The calibrator routes work *to*
  them and verifies it landed — it never applies a chapter edit itself.
- **vs. the human:** an item that needs a human call routes through the promotion bar like any
  other work; upstream doctrine patches are prepared here and **landed by a human**, never
  pushed.
