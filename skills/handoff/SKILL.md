---
name: handoff
description: Save the current conversation as a temporary, self-contained hand-off a future agent (any vendor) can resume from, or resume one. `/handoff save` writes the root HANDOFF.md (gitignored scratch, the single active root session); `/handoff resume` loads and consumes it (one-shot). An explicit path argument saves/resumes that file instead (unmanaged escape hatch). Use when asked to save/snapshot context before a reset or pick up where you left off. Scoped to the single root, non-worktree session.
---

# Hand-off skill

Save work-in-progress as a **temporary** hand-off that a future agent — of any vendor — can read as
the entry point of a new session, and resume from it. A hand-off is **gitignored per-machine
scratch, overwritten each save** — never merged, never a durable record.

Two layers, by isolation — pick by where the session lives:
- **Worktree streams** → `/workstream` (its own worktree-local `WORKSTREAM.md`). Not this skill.
- **The single active root session** → `/handoff` → root `HANDOFF.md`.

**There is no named-session layer.** The former `.sessions/<name>.md` feature (concurrent
root-level hand-offs) is removed: concurrent or long-lived parallel sessions are `/workstream`'s
job — worktree streams isolate properly, and in-place streams manage the shared tree with custody —
whereas parallel root sessions sharing one tree and index are the hazard, not a workflow to make
comfortable. The rare legitimate "second hand-off file" is still reachable via an **explicit path**
(below), with no managed lifecycle around it.

A *durable* record of *finished* work is a `.records/archive/` entry, not a hand-off. (The retired
`.records/sessions/` and `.sessions/` layers are not revived: a hand-off is gitignored scratch, not
a tracked store.)

Verbs:
- **save** — synthesize the current conversation into the hand-off file.
- **resume** — load the root `HANDOFF.md` and continue; it is **consumed** (deleted) on load, so
  the file's presence is its state (present = unresumed context; absent = nothing pending).

## When to use

- **save:** "save this context", "create a handoff", "I want to come back to this later",
  "write this up for a future session", "/handoff save" — snapshot before a reset.
- **resume:** "resume our work", "read `HANDOFF.md` and let me know when you're ready", "pick up
  where we left off", "/handoff resume".

Do not invoke for routine status updates within the same session, or for memory entries. For a
long-running feature in an isolated **worktree**, use `/workstream`, not this.

## Where it writes

First classify the trailing argument, then resolve the target:

- **No argument** → the root `HANDOFF.md`.
- **A path-like argument** (contains `/` or ends in `.md`) → that literal path, verbatim — the
  unmanaged escape hatch for a deliberate second hand-off file.
- **A bare word** (`dev`, `research`, …) → **reject and explain**: named hand-offs no longer
  exist. Suggest the caller pick one of: the root hand-off (no argument), an explicit path, or —
  if the real need is a concurrent/parallel session — a `/workstream` stream. Never silently
  reinterpret a bare word as a path.

Resolving the **root** `HANDOFF.md` (the no-argument case), in order:
1. If the conversation references an obvious project directory, write `<that-dir>/HANDOFF.md`.
2. Else `./HANDOFF.md` in the current working directory.
3. If still unsure, ask the user before generating.

## Save procedure

Steps 2-4 are the **Save discipline** — the reusable core: scan/elide secrets, synthesize don't
transcribe (reconcile against `git log`), resolve dates to absolute. Another skill may apply this
discipline to its *own* hand-off: target an explicit path, use its own document structure (not the
default below), and honor its post-write rule — e.g. `/workstream save` regenerates an ignored
`WORKSTREAM.md` from its own template, reconciling against `git -C <worktree> log`, and never stages
it. Steps 1, 5-6 are this skill's default flow.

1. **Sanity-check the request, and resolve the target.** If the conversation has been short,
   contains no concrete work to hand off, or is purely Q&A with nothing to resume, push back. Ask
   what specifically to preserve. Then resolve the target per *Where it writes* — the root
   `HANDOFF.md`, or a literal path.

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
   directory surface it.

## Resume procedure

`resume` loads a hand-off so you can continue the work. The file is already a synthesized summary —
**do not re-summarize it.** Steps 2-3 are the **Resume discipline** — read in full + load as
context, echo the single next action, and **rewrite nothing** — reusable by any skill resuming a
hand-off (e.g. `/workstream load`, which adds its own worktree guard and never consumes its file).
The discipline is non-destructive; step 4's consume is a root-only post-step layered on top.

1. **Locate the file** (per *Where it writes*): the root `HANDOFF.md` for a bare `resume`; the
   literal path for `resume <path>`. If it doesn't exist, say so.
2. **Read it in full** and load it as the working context for the session.
3. **Confirm ready — briefly.** Reply that you've read it and are ready. Do NOT summarize its
   contents; at most echo the one-line *Suggested first action* verbatim. Then wait for direction.
4. **Consume — root only.** The root `HANDOFF.md` is a **one-shot baton**: once the load has
   succeeded (step 2 done, content in context), **delete it** and say so ("consumed `HANDOFF.md`").
   Its presence then means "unresumed context exists"; its absence, "nothing pending". An
   **explicit-path** hand-off has no managed lifecycle — leave it in place; its owner deletes it.
   (The Resume discipline itself never deletes; only the root flow does, which is why
   `/workstream load` is unaffected.)

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
10. **Pointers.** Links to the project's other entry docs — `AGENTS.md`, `README`, `.agents/foreman/README.md`,
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

- **save:** the written file alone (root `HANDOFF.md`, or the explicit path) lets a fresh agent of
  any vendor resume the work — current state, next action, and repo baseline all present — with no
  recourse to the original conversation.
- **resume:** the hand-off is loaded into context, you've confirmed ready, and — root only — the
  file has been **consumed** (deleted); an explicit-path file is left in place.

## Edges

Handoff's **typed edges** -- its place in a workflow declared as artifact *types*, never as sibling
names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). A real
**self-chain**: `save` produces the doc, `resume` consumes it back -- the second intra-skill
produces↔consumes pair after feature's `design -> plan -> build` (a composer must exclude this pair
from seam derivation, same F2 rule). No durable home (the root `HANDOFF.md` is gitignored scratch,
lazily created) -- registration is optional and not implemented in v0.

<!-- edges:handoff -->
- produces: handoff-doc — the written save file (root `HANDOFF.md`, or an explicit-path file)
- handoff: — (none; the doc is picked up by *resume*, not handed to another skill)
- consumes: handoff-doc — resume reads the doc back (intra-skill: same skill on both ends)
<!-- /edges:handoff -->

**`handoff-doc` is used by exactly one skill**, so `skills-lint.sh` check 8 legitimately WARNs
(single-use type) even though the pair is correctly matched -- a known false-positive for an
intra-skill artifact (BL-4), not a fix to make here.
