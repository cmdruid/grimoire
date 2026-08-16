# `save` — synthesize the session into the checkpoint file

Steps 2–4 are the **Save discipline** (`references/disciplines.md` — exportable). Steps 1, 5–6
are this skill's flow.

1. **Sanity-check the request, and resolve the target.** If the conversation has been short,
   contains no concrete work to checkpoint, or is purely Q&A with nothing to resume, push back —
   ask what specifically to preserve. Resolve the target per SKILL.md *Where it writes*. In a
   git repo, read `scripts/save-guard.sh <dir>` (resolve `scripts/` from this skill's own base
   directory) — one read emits every mechanical pre-save fact; the decisions stay here:
   - **Stream guard** (SKILL.md *Two layers* refusal): `worktree_stream=true` **or**
     `inplace_branch_match=true` → this session's tree belongs to a workstream — **refuse and
     point to `/workstream save`**; do not write.
   - **Tracked-file guard**: `checkpoint_tracked=true` → STOP and surface (the ignore
     mechanism below).
   - **Ignore check**: `checkpoint_ignored=false` → establish the ignore (the mechanism below;
     the emitted `exclude_file=` is the resolved target).
   Then run the **foreign-checkpoint guard** (SKILL.md, the one-owner rules: an existing
   `CHECKPOINT.md` this session does not own by those rules → stop and surface; never
   overwrite — resume's transition clause and Recovery's reconcile both confer ownership).
2. **Scan for sensitive material.** Look for secrets, credentials, API tokens, private keys, or
   PII. Do NOT include them; in your reply, mention what you elided so the user can re-supply it
   securely.
3. **Synthesize, do not transcribe.** Reframe past discussion as forward-looking instructions.
   In a git repo, cross-reference `git log` — reconcile it against the conversation rather than
   memory.
4. **Resolve relative time references.** Convert "yesterday", "last week", etc. into absolute
   dates using the real current date — the document outlives the conversation.
5. **Write the file** to the target path using the structure below (overwriting in place — a
   refresh rewrites the whole file, it does not append).
6. **Confirm to the user.** Report the path written. **Managed root saves only:** note whether a
   front door at this root carries a **recovery anchor** (`verbs/anchor.md`) — warn (without
   mutating anything) if none is found, since a save that succeeds while recovery stays
   undiscoverable is a silent hole — and end the warning with: run **`/checkpoint anchor`** to
   install it. *Front door* = the files the harness actually always-loads at this root
   (`AGENTS.md`, `CLAUDE.md`, or the host's equivalent); any one carrying the block satisfies
   the check — name which. Offer a memory pointer if the harness supports persistent memory.

## The ignore mechanism — checked, never assumed; a tracked file beats an ignore

In a git repo, before writing the root file (`save-guard.sh` emits all three facts —
`checkpoint_tracked=`, `checkpoint_ignored=`, `exclude_file=`):

1. **Tracked-file guard:** `checkpoint_tracked=true` (`git ls-files --error-unmatch`) — STOP
   and surface. An exclude line cannot untrack a file, and a deleted-but-tracked
   `CHECKPOINT.md` would be silently recreated over content that belongs to history; the human
   decides (untrack it, or pick another root).
2. `checkpoint_ignored=false` → append `CHECKPOINT.md` to the emitted `exclude_file=` (the
   `info/exclude` path already resolved absolute; from a linked worktree it lands in the shared
   common dir, so one line covers every checkout). Per-machine, never committed.
3. **Re-check** (`git -C <root> check-ignore CHECKPOINT.md`) after appending — the append is
   only done when the re-check passes.

(A stale `HANDOFF.md` exclusion line from the pre-rename era is left alone.)

## Document structure

The **default** structure for a saved checkpoint — a skill borrowing only the disciplines (e.g.
`/workstream`) supplies its own structure instead, and **synthesize-don't-transcribe governs
over completeness**: the headings are a menu shaped by the save's weight, not a form to fill.
Two tiers:

- **Core (every save):** 1 Title + "last updated" date (the real current date) · 2
  Read-this-first preamble (one line: a living save-state, rewritten at each save, ended by
  `/checkpoint done`) · 3 TL;DR (what the work is, where it stands, what comes next) · 6 What's
  been done (artifacts with exact paths; decisions + rationale; in a code repo pull the shipped
  list from `git log`, not memory) · 7 Repo state *(code projects — `scripts/repo-snapshot.sh
  <root>` emits branch, detached flag, dirty state + counts, recent commits, and the date in
  one read; build/tests green stays your call: that needs the host's gate)* · 8 What's pending
  (numbered, priority order) · 12 Suggested first action (concrete enough to act on
  immediately; resume echoes this line).
- **Full-save additions (first save of a work-body, or when the checkpoint will outlive several
  resets — skip on a quick mid-session refresh):** 4 The user (role, level, preferences) · 5
  The project (what it is; key facts; open unknowns) · 9 Critical considerations (constraints,
  gotchas — always with the WHY) · 10 Cheat sheet *(judgment call: an orientation map with a
  `built-against:` baseline and repo-relative pointer paths, refreshed at each save; carries
  the verify-before-trust rule — a pointer is a snapshot, check it still resolves)* · 11
  Pointers (the project's other entry docs).

Keep the numbering and order when a section appears.

## Style guidance

- Write FOR a fresh agent who has never seen this work. Spell things out.
- Include exact file paths for every referenced artifact.
- Quote concrete decisions verbatim where possible — don't paraphrase nuance away.
- Capture WHY behind decisions and constraints, not just what was decided.
- Omit chat-room artifacts: greetings, dead-end debugging, side chatter.
- Call out irreversible deadlines/freezes/external dependencies with absolute dates.
- Keep it as short as it can be while still complete — typically 1–3 pages of Markdown.

**Done when:** the written file alone lets a fresh agent of any vendor resume the work —
current state, next action, and repo baseline all present — with no recourse to the original
conversation; the root file is verifiably gitignored; the anchor check reported.
