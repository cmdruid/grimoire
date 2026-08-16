# `resume` — load the checkpoint and continue

Steps 2–3 are the **Resume discipline** (`references/disciplines.md` — exportable). The file is
already a synthesized summary — **do not re-summarize it**, and never consume it.

1. **Locate the file** (per SKILL.md *Where it writes*): the root `CHECKPOINT.md` for a bare
   `resume`; the literal path for `resume <path>`. **Legacy discovery:** a bare `resume` that
   finds no `CHECKPOINT.md` checks for a `HANDOFF.md` at the same root and reports it if
   present — without consuming or migrating it (it may be a pre-rename baton from an old
   session; the human decides). If neither exists, say so.
2. **Read it in full** and load it as the working context for the session.
3. **Confirm ready — briefly.** Reply that you've read it; at most echo the one-line *Suggested
   first action* verbatim. A resuming session **confirms before continuing** (contrast Recovery,
   which continues without a round-trip — it inherits the compacted session's standing
   confirmation; a fresh session must earn one). While reconciling, apply the Lifecycle
   discipline's qualified states — resume itself stays read-only in both:
   - a **stale** file → **report** the discrepancy (what the file claims vs what disk shows);
     on the human's confirm, transition into a separate **`save`** that refreshes it. Completing
     resume steps 1–2 plus that confirm **confers ownership** (SKILL.md, the one-owner rules) —
     the transition carries it, so save's foreign-checkpoint guard cannot fire against the
     session mid-resume. If the save is refused anyway (stream guard; tracked file), **report
     the refusal and leave the file stale** — disk remains truth for this session; a refused
     refresh is a surfaced state, not a dead-end.
   - work already landed → propose **`done`** instead of resuming ghost work.

**Done when:** the checkpoint is loaded into context, you've confirmed ready, and the file is
untouched **by resume itself** — a confirmed stale-refresh is a separate `save` with its own
done-when.
