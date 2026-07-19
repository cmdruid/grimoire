---
name: mailbox
description: "The worktree-safe TRANSPORT for a delegated file-work result -- the slot protocol `/delegate` reaches for once it has decided to dispatch. A sub-agent writes its output to a git-excluded scratch file (a 'mailbox slot') and returns only a handle + one-line summary; the parent applies the patch (tokenless) or consumes the doc. Removes the two hazards of handing file-work back: a sub-agent editing a shared worktree directly silently corrupts it (its cwd is the repo ROOT, not the worktree), and a pasted artifact is paid through context repeatedly. The delegate-or-not call, the model/route choice, and the return contract live upstream -- mailbox is HOW the artifact crosses back safely, not WHETHER to delegate. Harness-agnostic (Claude or Codex). Keywords: mailbox slot, scratch file, git apply, single-writer, worktree corruption, out-of-band result, pass-by-reference, absolute slot path."
---

# mailbox -- out-of-band sub-agent handoff

## Overview

The **mailbox pattern**: dispatch a sub-agent that completes by **writing its result to a scratch
file** (a "mailbox slot") and returns only a short **handle + one-line summary**; the parent collects
the slot. Two payoffs, both load-bearing:

- **Safety -- the single-writer invariant holds.** The delegate never touches the working tree, so it
  cannot silently corrupt a shared git worktree (a dispatched sub-agent's cwd is the repo ROOT, not
  the worktree, so a stray relative-path edit lands on the wrong checkout and the build sees nothing).
  Only the parent writes the tree.
- **Cost -- bulk moves by path, not through context.** The artifact is generated once and travels as a
  file the parent applies with git; it is never re-paid as parent input + re-emitted output. **Pass by
  reference, not by value.**

## When to use / when not

Use when:
- delegating file-work (plan / implement / remediate / test / review) and you want the result back
  **without** the delegate's exploration polluting your context;
- **routing work to a different model** than the orchestrator (cheap for grunt work, strong for hard
  reasoning) while keeping the orchestrator lean;
- working in a **git worktree** where a sub-agent editing the tree directly would corrupt it.

Don't use when:
- the task is trivial and doing it **inline** is cheaper than a dispatch;
- the delegate must run a **tight live build/test (red-green) loop** -- mailbox delegates are
  tree-read-only and don't iterate against the tree; give that task its **own isolated worktree**
  instead (heavier, but it can build/commit safely on its own branch);
- you only need a parallel READ whose result you want in context anyway -- a normal read-only
  sub-agent returning a summary is simpler (no slot needed).

## The protocol

1. **Mint a slot.** Run `scripts/mailbox-slot.sh <root> [ext]` (resolve `scripts/` from this skill's
   own base directory). It creates `<root>/.mailbox/`, git-excludes it, and prints an **absolute** slot
   path; its basename is the unique handle. `ext` = `patch` for an apply-only artifact, `md`/`json`
   for a consume artifact. **The path is absolute on purpose** -- that is what makes it cwd-proof for
   the dispatched sub-agent.
2. **Dispatch** a sub-agent on the chosen model (see *Realizing the spawn*), handing it the
   **absolute slot path** + a **self-contained** task, under one hard contract:
   > "Do your work, then write your result to `<abs slot path>` and nothing else. Do **not** edit any
   > file in the tree. Return only the slot handle and a one-line summary."
3. **The delegate completes** by writing the slot and returning the handle + summary -- the only thing
   that crosses into the parent's context.
4. **Collect the slot** -- by artifact type:
   - **apply-only** (a patch): `scripts/mailbox-apply.sh <root> <slot>` runs `git apply` + reaps it.
     The content **never enters the parent's context** -- tokenless integration. (Use `--check` first
     if you want a dry run.)
   - **consume** (a plan / analysis / verdict): **read the slot into context once**, deliberately.
     That is the intended transfer; the delegate's exploration still never reached you.
5. **Reap.** `mailbox-apply.sh` reaps on success; for a consumed slot, delete it when done. `.mailbox/`
   is git-excluded so nothing strays into a commit.

## The load-bearing rules (don't break these)

- **Absolute slot path, always.** Relative paths land in the root checkout, not the worktree. The
  mint script gives you an absolute path -- pass it through verbatim.
- **Delegate is read-only on the tree; the parent is the sole writer.** The delegate writes *only* its
  slot. This is the entire safety guarantee -- a delegate that edits the tree reintroduces the
  corruption hazard the pattern exists to remove.
- **Return tiny; bulk in the slot.** The sub-agent's return message is a handle + one line. If it
  returns the whole diff/doc as its message, you have paid the content through context -- the thing
  this pattern avoids.
- **Apply-only vs consume.** Never read a patch into context to apply it (pays the content 2-3x);
  `git apply` it. Do read a plan/analysis once.
- **Concurrency.** Slots are unique, so parallel dispatches don't collide; but the parent must
  **serialize applies + gates** (apply one patch, gate, then the next). `git apply` fails **loudly**
  on tree drift / fuzz (e.g. after a sync) -- re-roll the dispatch or apply by hand; it never corrupts.

## Realizing the spawn (the one harness-specific step)

The protocol above is harness-neutral. Only *how you spawn the sub-agent on the named model* differs,
and it is the single place a harness is named:

- **Claude agents** -> use the native sub-agent / Task tool with a **model override** (e.g. a Sonnet
  delegate from an Opus orchestrator). The harness notifies the parent when the delegate completes;
  the delegate's final message is the handle + summary. Lightest, integrated -- prefer it.
- **Codex agents** -> run `codex exec --model <model> "<self-contained task incl. the abs slot path>"`
  as a subprocess; it returns when done (its stdout / the slot is the result). Codex has no native
  model-routed sub-agent, so the headless subprocess is the equivalent.

"Model" is an **opaque per-harness string** (`sonnet`/`opus`/... for Claude; a `gpt-...` id for Codex)
-- mailbox passes it to the spawn, never interprets it.

## Quick reference

| Step | Command / action |
|---|---|
| mint a slot | `scripts/mailbox-slot.sh <root> [patch\|md\|json]` -> absolute slot path |
| dispatch | spawn a sub-agent on the model; pass the abs slot path + self-contained task + the read-only contract |
| apply a patch slot | `scripts/mailbox-apply.sh <root> <slot>` (add `--check` to dry-run) |
| consume a doc slot | read the slot into context once, then delete it |

**Phase -> model routing:** which model tier fits which phase (and hence which slot type) is
delegation doctrine, owned by the `delegate` skill's model-routing table — the short of it: strong
tiers produce consume-slots (plans/verdicts), cheaper tiers produce apply-only patches and
findings. Route per that table; mailbox just carries the artifact.

## Common mistakes

- **Relative slot path** -> the delegate writes the wrong checkout; the parent never finds it. Always
  pass the absolute path the mint script prints.
- **Letting the delegate edit the tree** -> silent worktree corruption -- the exact failure this skill
  removes. Tree-read-only; it writes only the slot.
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
names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). **Pure-mechanism
plumbing**: `.mailbox/` is gitignored scratch, no typed artifact edges (a slot's patch/verdict is
ephemeral and consumed inline by the applying parent), and no registration -- transport, not a
capture home. All three edges are a *stated* empty (model §2.3), not an omission.

<!-- edges:mailbox -->
- produces: — (a slot's patch/verdict is consumed inline by the applying parent, not a typed artifact)
- handoff: — (none; a slot is applied and gated by the parent, it doesn't terminate a workflow)
- consumes: — (none; it reads the delegate's task description, not another skill's typed output)
<!-- /edges:mailbox -->
