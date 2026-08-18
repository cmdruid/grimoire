---
name: mailbox
description: "Use when a sub-agent must return a file-work artifact without writing the shared tree: mint a git-excluded mailbox slot, pass its absolute path, collect a handle + one-line summary, then apply the patch or consume the doc. Transport only — not whether to delegate. Keywords: mailbox slot, absolute slot path, pass-by-reference, tokenless apply."
---

# mailbox -- out-of-band sub-agent handoff

## Overview

The **mailbox pattern**: dispatch a sub-agent that completes by **writing its result to a scratch
file** (a "mailbox slot") and returns only a short **handle + one-line summary**; the parent collects
the slot. Two payoffs, both load-bearing:

- **Safety -- the single-writer invariant holds.** The delegate never touches the working tree, so it
  cannot silently corrupt a shared git worktree (a dispatched sub-agent's cwd is harness-dependent --
  often the repo ROOT, not the worktree you meant -- so a stray relative-path edit lands on the wrong
  checkout and the build sees nothing). Only the parent writes the tree.
- **Cost -- bulk moves by path, not through context.** The artifact is generated once and travels as a
  file the parent applies with git; it is never re-paid as parent input + re-emitted output. **Pass by
  reference, not by value.**

## When to use / when not

Use when:
- delegating file-work (plan / implement / remediate / test / review) and you want the result back
  **without** the delegate's exploration polluting your context;
- working in a **git worktree** where a sub-agent editing the tree directly would corrupt it.

Don't use when:
- the task is trivial and doing it **inline** is cheaper than a dispatch;
- the delegate must run a **tight live build/test (red-green) loop** -- mailbox delegates are
  tree-read-only and don't iterate against the tree; give that task its **own isolated worktree**
  instead (heavier, but it can build/commit safely on its own branch);
- you only need a parallel READ whose result you want in context anyway -- a normal read-only
  sub-agent returning a summary is simpler (no slot needed).

## The protocol

1. **Mint a slot.** `<root>` is the parent's **target checkout** -- the canonical path
   `git rev-parse --show-toplevel` prints for the tree the artifact targets (the worktree, when you
   work in one -- NOT the common checkout, not a subdirectory). Run
   `scripts/mailbox-slot.sh <root> [ext]` (resolve `scripts/` from this skill's own base directory).
   It **rejects a `<root>` that is not a worktree toplevel**, creates `<root>/.mailbox/`, git-excludes
   it, and prints an **absolute** slot path; its basename is the unique handle. `ext` = `patch` for an
   apply-only artifact, `md`/`json` for a consume artifact. **The path is absolute on purpose** --
   that is what makes it cwd-proof for the dispatched sub-agent.
2. **Dispatch** a sub-agent on the caller-chosen model (see *Realizing the spawn*), handing it the
   **absolute slot path** + a **self-contained** task, under one hard contract — use this phrasing,
   not a paraphrase:
   > "**Author your result as text in your own context**, then write it to `<abs slot path>` — you
   > may write **exactly that one file** and nothing else. **Never use a file-edit tool on any tree
   > path** — not even to 'edit then diff': compose the diff as text. A patch slot must be a
   > **unified diff exactly as `git diff` would emit from `<root>`** (paths prefixed `a/`/`b/`); do
   > not target a named base revision — `git apply` applies to the working tree. Leave the tree as
   > you found it: `git status --short` must be **unchanged from dispatch** when you finish.
   > Return: the slot's basename on the first line, then one summary sentence."
   The core of the phrasing is load-bearing, measured: under a "write only the slot" contract, 2 of
   ~11 dispatches edited the tree anyway — both began as *edit-then-diff*; every dispatch under the
   author-as-text phrasing completed cleanly.
   **Prefer a clean tree at dispatch.** Either way, snapshot now: `git -C <root> status --short`,
   and if the tree is dirty also `git -C <root> diff HEAD | shasum` — step 4 verifies against
   these. The hash catches content edits to already-dirty *tracked* paths (a status line cannot
   show those). Two blind spots remain — accepted, and named so you know what the check does NOT
   prove: untracked file *bodies* (`git diff HEAD` ignores `??` content) and ignored files (which
   cannot ride a commit).
   **Write the slot last-step-first:** tell the delegate to write the slot *before* its final
   verify pass and re-write it after — a transport drop mid-completion then always leaves a usable
   slot artifact instead of stranding verified work in the delegate's scratch. A tree-read-only
   delegate's verify pass is **bounded**: a self-check of the slot text against what it read,
   plus — patch slots — `git -C <root> apply --check <abs slot path>` (read-only). The `-C <root>`
   is load-bearing: the delegate's cwd is the very hazard this skill exists for; a bare
   `git apply --check` resolving against that cwd is a false green.
3. **The delegate completes** by writing the slot and returning **one parseable shape**: the slot's
   basename (the handle) on the first line, one summary sentence after. That return is the only
   thing that crosses into the parent's context — "only" bounds the **artifact payload**: the
   deliverable travels in the slot, never in the message (a pasted artifact in the message is
   ignored in favor of the slot); protocol fields the caller's own delegation contract requires
   (status, byproducts) are unaffected.
4. **Collect the slot — VERIFY, then apply/consume.** A slot is trusted only after the delegate's
   **completion return**; a slot salvaged from a delegate that died mid-task is suspect — dry-run a
   patch (`--check`), read a doc skeptically. First the tree check, required (prompt discipline
   alone is measured-insufficient — see step 2): compare `git status --short` (and the diff hash,
   if taken) against the dispatch-time snapshot. **Any drift → refuse the collect and PRESERVE the
   tree.** The snapshot can *detect* drift but cannot *attribute* it — the edits may be your own or
   the user's legitimate concurrent work, so never revert, discard, or "clean up" from this
   evidence. Surface the mismatch, reconcile the tree state by hand, and only then re-dispatch **to
   a fresh slot**. Then, by artifact type:
   - **apply-only** (a patch): first list the touched paths read-only — `git apply --numstat <slot>`
     — *before* applying (the slot is reaped on success). Then `scripts/mailbox-apply.sh <root>
     <slot>` runs `git apply` + reaps it; it **refuses a slot outside `<root>/.mailbox/`** and a
     non-toplevel `<root>`. The content **never enters the parent's context** -- tokenless
     integration. (Use `--check` first if you want a dry run.) **After applying a code patch, run
     the host's cheap formatter/lint on the touched files** before the big gate — a delegate can't
     run the host toolchain, so its hand-formatting otherwise surfaces as a red full gate a cycle
     later. No applicable host formatter/lint → **skip this explicitly**; the full gate still covers it.
   - **consume** (a plan / analysis / verdict): **read the slot into context once**, deliberately.
     That is the intended transfer; the delegate's exploration still never reached you.
5. **Reap.** `mailbox-apply.sh` reaps on success; for a consumed slot, delete it when done. A
   **refused or failed** slot is *kept* for inspection — never reuse or overwrite it: every
   re-dispatch mints a **fresh** slot, and abandoned slots are reaped when the episode closes.
   `.mailbox/` is git-excluded so nothing strays into a commit either way.

## The load-bearing rules (don't break these)

- **Absolute slot path, always.** A relative path resolves against whatever cwd the delegate happens
  to hold -- usually not the tree you meant. The mint script gives you an absolute path -- pass it
  through verbatim.
- **Delegate is read-only on the tree; the parent is the sole writer.** The delegate writes *only* its
  slot. This is the entire safety guarantee -- a delegate that edits the tree reintroduces the
  corruption hazard the pattern exists to remove. And it is a guarantee you **verify, not trust**:
  the step-4 tree check is part of the protocol, not optional hardening — and when it fails you
  **preserve, never purge** (the evidence cannot attribute the drift).
- **Never commit in the target tree while a delegate is live.** A pathspec-scoped commit selects
  *paths*, not *authors* — if a contract-breaching delegate has co-written a path you are
  committing, the foreign hunks ride your commit silently. Dispatch, collect, verify, *then*
  commit.
- **Return tiny; bulk in the slot.** The sub-agent's return message is a handle + one line. If it
  returns the whole diff/doc as its message, you have paid the content through context -- the thing
  this pattern avoids.
- **Apply-only vs consume.** Never read a patch into context to apply it (pays the content 2-3x);
  `git apply` it. Do read a plan/analysis once.
- **Concurrency.** Slots are unique, so parallel dispatches don't collide; but the parent must
  **serialize applies + gates** (apply one patch, gate, then the next). `git apply` fails **loudly**
  on tree drift / fuzz (e.g. after a sync) -- it never corrupts; re-roll the dispatch to a fresh
  slot against the current tree (hand-applying a stale patch from context pays the content the
  pattern exists to avoid).

## Realizing the spawn (the one harness-specific step)

The protocol above is harness-neutral. Only *how you spawn the sub-agent on the named model* differs,
and it is the single place a harness is named:

- **Claude agents** -> use the native sub-agent / Task tool with a **model override** (e.g. a Sonnet
  delegate from an Opus orchestrator). The harness notifies the parent when the delegate completes;
  the delegate's final message is the handle + summary. Lightest, integrated -- prefer it.
- **Codex agents** -> run `codex exec --model <model> "<self-contained task incl. the abs slot path>"`
  as a subprocess; it returns when done (its stdout / the slot is the result). Codex has no native
  model-routed sub-agent, so the headless subprocess is the equivalent.

**The delegate's cwd is an assumption, never a given.** A natively-spawned sub-agent often starts at
the repo root; a spawn with an explicit working directory will not. The protocol survives either
way — the absolute slot path makes the slot write cwd-proof, and the `-C <root>` prefix makes the
delegate's git commands cwd-proof — but confirm (or force, where the harness allows) the cwd at
spawn rather than relying on it.

"Model" is an **opaque per-harness string** (`sonnet`/`opus`/... for Claude; a `gpt-...` id for Codex)
-- the **caller** chooses it; mailbox passes it to the spawn, never interprets it. Which model fits
which work is delegation doctrine, not transport.

## Quick reference

| Step | Command / action |
|---|---|
| mint a slot | `scripts/mailbox-slot.sh <root> [patch\|md\|json]` -> absolute slot path |
| dispatch | spawn a sub-agent on the caller-chosen model; pass the abs slot path + self-contained task + the read-only contract |
| apply a patch slot | `scripts/mailbox-apply.sh <root> <slot>` (add `--check` to dry-run) |
| consume a doc slot | read the slot into context once, then delete it |

## Common mistakes

- **Relative slot path** -> the delegate writes the wrong checkout; the parent never finds it. Always
  pass the absolute path the mint script prints.
- **Letting the delegate edit the tree** -> silent worktree corruption -- the exact failure this skill
  removes. Tree-read-only; it writes only the slot.
- **"Cleaning up" a failed drift check** -> the status diff cannot tell delegate edits from your own
  or the user's concurrent work; a discard here can destroy legitimate WIP. Preserve + surface.
- **Reading a patch into context to apply it** -> pays the content 2-3x. `git apply` instead.
- **Returning the artifact as the sub-agent's message** -> defeats the cost win. Return the handle.
- **Skipping the gitignore** -> stray `.mailbox/` files risk a commit. `mailbox-slot.sh` excludes it
  for you (idempotently, common-dir aware for worktrees) -- don't hand-roll it.

## Why this works (one line)

It is the agent-tooling "pointer-heavy, not pasted content" principle applied to inter-agent handoffs:
a pasted artifact is paid for repeatedly and a delegate that writes the tree is unsafe; a **path** is
paid once and a delegate that writes only its slot can't corrupt anything.

## Edges

Mailbox's **typed edges** -- its place in a workflow declared as artifact *types*, never as sibling
names (the typed-edge tenet — portable home: skill-builder's `docs/DOCTRINE.md` § *Typed edges*;
library history: `docs/design/2026-07-18-skill-self-init-model.md` §2). **Pure-mechanism
plumbing**: `.mailbox/` is gitignored scratch, no typed artifact edges (a slot's patch/verdict is
ephemeral and consumed inline by the applying parent), and no registration -- transport, not a
capture home. All three edges are a *stated* empty (model §2.3), not an omission.

<!-- edges:mailbox -->
- produces: — (a slot's patch/verdict is consumed inline by the applying parent, not a typed artifact)
- handoff: — (none; a slot is applied and gated by the parent, it doesn't terminate a workflow)
- consumes: — (none; it reads the delegate's task description, not another skill's typed output)
<!-- /edges:mailbox -->

## Done when

Slot minted; collected only after a completion return; tree snapshot matched; apply-or-consume
finished; slot reaped on success or kept on refuse. Drift → tree preserved, no apply. Salvaged
mid-task slot → dry-run / read skeptically, never trusted as a completion.
