# `/architect brainstorm` — foundation-altitude ideation on the seed

Explores a **radical** change to the durable seed — a `PHILOSOPHY.md` tenet, a system's
`CONTRACT`, a seam in `MAP.md`'s seam graph, or `VISION.md` itself. This is the direct antidote to
incremental context-bias: a project's usual working mode is forward, additive, feature-scoped, and
that mode structurally under-weights "what if the foundation itself is wrong." `brainstorm` is the
verb licensed to ask that question and act on the answer. See `docs/DOCTRINE.md` for the
durability gradient this verb edits along.

## The altitude discriminator

`brainstorm` is one of the two verb names `/architect` shares with `/feature` — the one collision
risk in the whole system. Hold this line before starting any session:

> `/feature brainstorm|plan` mutate **code** (a change you build against the seed).
> `/architect brainstorm|plan` mutate **the seed itself** (the foundation you later regenerate code
> from). *Changing the foundation → `/architect`. Building on it → `/feature`.*

If the question in front of you is "how should we build feature X" — even a gnarly, cross-cutting
X — that's `/feature brainstorm`. If the question is "is the tenet/contract/seam X *builds on*
still correct" — that's here. When in doubt, ask: *does the answer to this question change what
`.agents/architect/` says is durably true, or does it only change what gets built on top of what's already
durably true?* The former is this verb; the latter is `/feature`'s.

## Explicitly licensed: alpha, hard-cut

A standing spec is not a museum piece. `brainstorm` is explicitly licensed to propose replacing a
tenet outright, breaking a contract's existing invariant, redrawing a seam, or reversing a
`VISION.md` commitment — with no obligation to preserve backward compatibility, deprecate
gracefully, or leave the old shape reachable behind a flag. (Whether a *project's* code actually
gets to hard-cut this way is that project's own alpha/stability posture — carry it, don't
override it: a project past 1.0 may still ask `brainstorm` to name the tenet change and then let
`/feature` plan a migration, rather than a clean break.) The candidate a `brainstorm` session
should reject is a *safe* one — a tweak dressed up as foundational. If the proposal wouldn't
reshape anything below it in the durability gradient (per `docs/DOCTRINE.md` § The durability
gradient), it's feature-scope, not this verb.

## It may borrow the dialogue engine; it may not borrow the destination

`brainstorm` MAY reuse `superpowers:brainstorming` (or an equivalent open-ended-exploration
technique) as its **dialogue engine** — the back-and-forth that surfaces the real question, tests
the candidate change against counter-examples, and pressure-tests whether it's actually durable
rather than a one-off preference. What it must not borrow is that skill's terminal artifact: a
generic brainstorming session ends in a feature idea or a design write-up handed off for planning.
`/architect brainstorm` ends in an **edited standing spec** — a diff to a file already living under
`.agents/architect/` (or a new `.agents/architect/src/<system>.md` if the session concludes a system needs to exist that
doesn't yet). If a session's conclusion is "here's a feature to build," that conclusion belongs to
`/feature brainstorm`, not here — don't let this verb's report stand in for that one.

## Procedure

1. **Name the altitude target before opening the dialogue.** One of: a `PHILOSOPHY.md` tenet
   (add, revise, or retire one), a system's `CONTRACT` tier in `.agents/architect/src/<system>.md`, a seam
   recorded in `MAP.md`'s seam graph, or `VISION.md`'s north star / pillars / non-goals. Read the
   current text of that target and its immediate neighbors (a tenet's sibling tenets; a contract's
   `MAP.md` row and the systems it depends on) before proposing a change to it — you cannot judge
   "is this actually durable" without seeing what it would sit alongside.

2. **Run the dialogue.** Explore the candidate change adversarially: what does it break, what
   does it simplify, is it actually recurring/durable or a one-off preference dressed up as one
   (per `PHILOSOPHY.md`'s own promotion doctrine — recurrence across ≥2 systems is a *candidate
   signal*, not an automatic promotion), and what would a project have to hard-cut to adopt it.
   This is where `superpowers:brainstorming` earns its keep as the dialogue technique, if the
   host has it — but keep steering back to the seed-altitude question above, not "how would we
   build this."

3. **Land the terminal artifact as a seed edit.** Write the change directly into the target file:
   a revised tenet line in `PHILOSOPHY.md`, a revised `## Contract (BINDING)` section in
   `.agents/architect/src/<system>.md`, an updated seam-graph entry in `MAP.md`, or a revised section of
   `VISION.md`. This is a document edit, performed directly, same as `init`'s Step 5 — not a
   proposal handed elsewhere for someone else to make. If the target file doesn't exist yet (a
   brand-new system the brainstorm concluded should exist), create it from
   `templates/system-spec.md` with the contract tier filled and the reference-architecture tier
   left empty — there is no code yet to snapshot.

4. **Surface the blast radius, but don't chase it.** A tenet or contract change usually
   invalidates more than the one file edited — sibling systems that depended on the old shape, a
   `MAP.md` row that now points at a stale seam. Name what else looks affected in the report (Step
   5 below), but resist the urge to cascade-edit every downstream file in the same session:
   sequencing that cascade is `/architect plan`'s job, not this verb's. `brainstorm` changes the one
   thing it was asked about and hands off the ripple.

5. **Stop at the edit — this verb never touches code.** `brainstorm` doesn't validate the change
   against `check`, doesn't scope prep, and doesn't queue `/feature` work. If the human wants the
   change sequenced into reality next, that's `/architect plan`; if they want the seed's structural
   health re-verified, that's `/architect check`.

## Report

Close `brainstorm` with: the altitude target named at Step 1, a summary of the dialogue's key
turns (what was rejected and why, not just the winning idea), the file(s) actually edited (a
diff-shaped summary, not the full new text), and the blast-radius list from Step 4 — flagged
explicitly as *unactioned*, for the human to route to `/architect plan` if they want it sequenced.
