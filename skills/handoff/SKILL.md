---
name: handoff
description: Save the current conversation as a temporary, self-contained hand-off a future agent (any vendor) can resume from, or resume one. `/handoff save` writes the root HANDOFF.md (gitignored scratch, the single active root session); `/handoff resume` loads and consumes it (one-shot). `/handoff save <name>` / `/handoff load <name>` use `.sessions/<name>.md` for concurrent root-level (non-worktree) sessions that would collide on the one root file -- these are rolling and re-loadable, removed with `/handoff close <name>`; `/handoff list` shows what exists. Use when asked to save/snapshot context before a reset or pick up where you left off. For isolated worktree streams use /workstream instead.
---

# Hand-off skill

Save work-in-progress as a **temporary** hand-off that a future agent — of any vendor — can read as
the entry point of a new session, and resume from it. A hand-off is **gitignored per-machine
scratch, overwritten each save** — never merged, never a durable record.

Three layers, by isolation — pick by where the session lives:
- **Worktree** streams → `/workstream` (its own worktree-local `WORKSTREAM.md`). Not this skill.
- **The single active root session** → vanilla `/handoff` → root `HANDOFF.md`.
- **Concurrent root-level (non-worktree) sessions** → **named** `/handoff`s → `.sessions/<name>.md`,
  one file per session, so they don't collide on the single root file.

A *durable* record of *finished* work is a `.records/archive/` entry, not a hand-off. (The retired
`.agents/dev/sessions/` layer is not revived: named hand-offs are gitignored scratch, not a tracked store.)

Verbs:
- **save** / **save `<name>`** — synthesize the current conversation into the hand-off file.
- **resume** — load the root `HANDOFF.md` and continue; it is **consumed** (deleted) on load, so
  the file's presence is its state (present = unresumed context; absent = nothing pending).
- **load `<name>`** / **resume `<name>`** — load a *named*, **rolling** hand-off and continue; it is
  **kept** (re-loadable across resets). `resume <name>` is a lenient alias for `load <name>`.
- **close `<name>`** — delete a named hand-off when its rolling work is done.
- **list** — show the hand-offs that exist (named ones plus the root `HANDOFF.md`).

## When to use

- **save:** "save this context", "create a handoff", "I want to come back to this later",
  "write this up for a future session", "/handoff save" — snapshot before a reset.
- **save `<name>`:** same, but when a **second** root-level session is (or may be) live and would
  collide on the root file — "/handoff save dev", "save this as a named hand-off".
- **resume:** "resume our work", "read `HANDOFF.md` and let me know when you're ready", "pick up
  where we left off", "/handoff resume".
- **load `<name>`:** "resume the `dev` hand-off", "/handoff load dev", "pick up `<name>` where we
  left off".
- **close `<name>`:** "I'm done with the `dev` hand-off", "/handoff close dev", "clean up that
  named hand-off".
- **list:** "what hand-offs are there?", "/handoff list".

Do not invoke for routine status updates within the same session, or for memory entries. For a
long-running feature in an isolated **worktree**, use `/workstream`, not this.

## Where it writes

First classify the trailing argument, then resolve the target:

- **No argument** → the root `HANDOFF.md`.
- **A bare slug** (`<name>` matching `[a-z0-9-]+` — no `/`, no `.md`) → a **named** hand-off at
  `.sessions/<name>.md`. A bare word always means a named hand-off, never a relative path. (This
  reinterprets the old "bare arg = relative path" behavior — intentional; a literal path is still
  reachable via the path-like form below.)
- **A path-like argument** (contains `/` or ends in `.md`) → that literal path, verbatim.

Reject an invalid name (a path separator, `..`, or characters outside `[a-z0-9-]`): say so and
suggest a valid slug — never silently sanitize. The slug rule keeps a name inside `.sessions/` (no
traversal) and the directory tidy.

Resolving the **root** `HANDOFF.md` (the no-argument case), in order:
1. If the conversation references an obvious project directory, write `<that-dir>/HANDOFF.md`.
2. Else `./HANDOFF.md` in the current working directory.
3. If still unsure, ask the user before generating.

Named hand-offs always live in `.sessions/` under the repo/working root (already gitignored);
create the directory if it is missing.

Both kinds are **gitignored scratch** — never merged, overwritten in place each save. They differ
only in isolation: root `HANDOFF.md` is the single active session; `.sessions/<name>.md` lets
concurrent **root-level** sessions each keep their own. (Worktree streams are `/workstream`'s
worktree-local `WORKSTREAM.md`; a durable record of finished work is a `.records/archive/` entry.)

## Save procedure

Steps 2-4 are the **Save discipline** — the reusable core: scan/elide secrets, synthesize don't
transcribe (reconcile against `git log`), resolve dates to absolute. Another skill may apply this
discipline to its *own* hand-off: target an explicit path, use its own document structure (not the
default below), and honor its post-write rule — e.g. `/workstream save` regenerates an ignored
`WORKSTREAM.md` from its own template, reconciling against `git -C <worktree> log`, and never stages
it. Steps 1, 5-6 are this skill's default flow.

1. **Sanity-check the request, and resolve the target.** If the conversation has been short,
   contains no concrete work to hand off, or is purely Q&A with nothing to resume, push back. Ask
   what specifically to preserve. Then resolve the target per *Where it writes* — root
   `HANDOFF.md`, a named `.sessions/<name>.md` (validate the slug first; create `.sessions/` if
   missing), or a literal path.

2. **Scan for sensitive material.** Look for secrets, credentials, API tokens, private keys, or PII.
   Do NOT include them; in your reply, mention what you elided so the user can re-supply it securely.

3. **Synthesize, do not transcribe.** The document is for a future agent, not a chat log. Reframe
   past discussion as forward-looking instructions. In a git repo, cross-reference `git log` — it's
   the source of truth for what shipped; reconcile it against the conversation rather than memory.

4. **Resolve relative time references.** Convert "yesterday", "last week", etc. into absolute dates
   using the real current date — the document outlives the conversation.

5. **Write the file** to the target path using the structure below (overwriting in place).

6. **Confirm to the user.** Report the path written. For the **root** hand-off, offer to also save
   a memory pointer (if the harness supports persistent memory) so future sessions in this
   directory surface it. For a **named** hand-off, do **not** auto-offer a memory pointer — named
   hand-offs are concurrent, ephemeral scratch; point the user at `/handoff list` instead.

## Resume procedure

`resume` (root) and `load <name>` (named) both load a hand-off so you can continue the work —
`resume <name>` is a lenient alias for `load <name>`. The file is already a synthesized summary —
**do not re-summarize it.** Steps 2-3 are the **Resume discipline** — read in full + load as
context, echo the single next action, and **rewrite nothing** — reusable by any skill resuming a
hand-off (e.g. `/workstream load`, which adds its own worktree guard and never consumes its file).
The discipline is non-destructive; step 4's consume is a vanilla-root-only post-step layered on top.

1. **Locate the file** (per *Where it writes*): root `HANDOFF.md` for `resume` with no name;
   `.sessions/<name>.md` for `load <name>` / `resume <name>` (validate the slug). If it doesn't
   exist, say so — and for a missing named file, suggest `/handoff list`.
2. **Read it in full** and load it as the working context for the session.
3. **Confirm ready — briefly.** Reply that you've read it and are ready. Do NOT summarize its
   contents; at most echo the one-line *Suggested first action* verbatim. Then wait for direction.
4. **Consume — root only.** A root `HANDOFF.md` is a **one-shot baton**: once the load has
   succeeded (step 2 done, content in context), **delete it** and say so ("consumed `HANDOFF.md`").
   Its presence then means "unresumed context exists"; its absence, "nothing pending". A **named**
   hand-off is **rolling** — do **not** delete it; it stays re-loadable until `/handoff close
   <name>`. (The Resume discipline itself never deletes; only this root flow does, which is why
   `/workstream load` is unaffected.)

## List procedure

`list` reports the hand-offs that exist; it writes nothing.

1. **Collect** the root `HANDOFF.md` (if present) and every `.sessions/*.md`.
2. **Read the title + "last updated" line** from each (the first heading and the date line near the
   top — the default structure puts both there).
3. **Print a short table:** name (`HANDOFF` for the root, the slug for named ones) and its
   last-updated date. If nothing exists, say there are no hand-offs.
4. **Touch no files.**

## Close procedure

`close <name>` ends a named hand-off's life — delete `.sessions/<name>.md` when its rolling work is
done. It is **named-only**: there is no bare `close` (a root `HANDOFF.md` is consumed by `resume`,
not closed).

1. **Validate the name** and resolve `.sessions/<name>.md`.
2. **If it doesn't exist,** say so (suggest `/handoff list`) and stop.
3. **Delete it** and confirm ("closed `<name>`").

## Document structure

This is the **default** hand-off structure. A skill delegating only the Save discipline (e.g.
`/workstream`) supplies its own structure instead — apply the discipline, fill that structure.

A saved hand-off must include these sections, in this order. Use Markdown headings. Omit a section
only if it would be empty.

1. **Title and "last updated" date.** Use the actual current date, not a placeholder.
2. **Read-this-first preamble.** One line declaring this file as the entry point for the work.
3. **TL;DR.** One paragraph: what the work is, where it stands, what comes next.
4. **The user.** Their role, technical level, and preferences relevant to collaboration.
5. **The project.** What it is. Key facts known. Key unknowns still open.
6. **What's been done.** Artifacts with exact file paths; decisions + brief rationale. In a code
   repo, pull the shipped list from `git log`, not just memory.
7. **Repo state** *(code projects).* Current branch; build/tests green as of this hand-off (run them
   if cheap); working tree clean or dirty (and with what). `scripts/repo-snapshot.sh <root>` emits
   the branch, dirty state + counts, recent commits, and the date in one read — it fills this section
   and grounds #6's `git log` reconciliation (build/tests green stays your call: that needs the
   host's gate, not a snapshot).
8. **What's pending.** Numbered list of next steps in priority order.
9. **Critical considerations.** Constraints, gotchas, easy-to-miss context — always with the WHY.
10. **Pointers.** Links to the project's other entry docs — `AGENTS.md`, `README`, `.agents/dev/README.md`,
    relevant plans/roadmaps — so the next agent finds the wider doc set.
11. **Suggested first action.** A concrete first move, specific enough to act on immediately.
    (Resume echoes this line, so keep it sharp and self-contained.)

## Style guidance

- Write FOR a fresh agent who has never seen this work. Spell things out.
- Include exact file paths for every referenced artifact.
- Quote concrete decisions verbatim where possible — don't paraphrase nuance away.
- Capture WHY behind decisions and constraints, not just what was decided.
- Omit chat-room artifacts: greetings, dead-end debugging, side chatter.
- Call out irreversible deadlines/freezes/external dependencies with absolute dates.
- Keep it as short as it can be while still complete — typically 1–3 pages of Markdown.

## Done when

- **save / save `<name>`:** the written file alone (root `HANDOFF.md` or `.sessions/<name>.md`)
  lets a fresh agent of any vendor resume the work — current state, next action, and repo baseline
  all present — with no recourse to the original conversation.
- **resume:** the root `HANDOFF.md` is loaded into context, you've confirmed ready, and the file
  has been **consumed** (deleted).
- **load / resume `<name>`:** the named hand-off is loaded into context, you've confirmed ready,
  and the file is **left in place** (rolling).
- **close `<name>`:** the named file is deleted and confirmed.
- **list:** the existing hand-offs (named + root) are reported, nothing written.
