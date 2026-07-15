# Codex executor -- the mechanics

The Codex branch of `/delegate`: hand **mechanical coding** to the `codex` CLI, which writes a reviewable
diff you gate and commit. This file is the executor detail; the delegate-or-not decision, the route gate,
the return contract, and the trust principle live in `SKILL.md`. Reach here only once you've decided to
route a coding task to Codex.

**Core principle:** Codex writes code; you decide what's correct. It executes **literally** -- it has no
judgment to refuse a scope instruction that would break working code. So the *instruction* must be correct
before you delegate, and when Codex faithfully produces something wrong, suspect your prompt, not Codex.

## Preflight

1. `command -v codex` -- confirm it's installed (a checkable fact -- verify it, don't ask). If absent, do
   the work yourself.
2. `codex exec --help` once per session -- confirm the flag surface for the installed version; flags drift
   between versions, so don't trust a memorized command.
3. Capture a **whole-repo** baseline (`git status` across the entire tree, not just the target paths) so
   any change -- including files outside the named scope -- is isolable. Don't ask Codex to work on top of
   unrelated dirty files you can't separate.
4. Have a plan file or a clearly-scoped task statement in hand.

## The loop

```
choose granularity → prompt Codex → review diff + run gates → commit (you) → next
```

### 1. Choose granularity (risk-adaptive)

| Mode | Use for | What you do |
|------|---------|-------------|
| **Checkpoint per unit** | logic/protocol changes, cross-file edits, anything that changes test meaning, ambiguous specs, new behavior | Codex does ONE unit → you review + run its gate → only then resume |
| **Batch then verify** | renames, file moves, dead-stub deletion, doc edits, manifest/string changes -- low ambiguity, low blast radius | Codex runs several units → you review the whole diff + gates at the end |

Default to **checkpoint** when unsure. Batch the mechanical runs rather than one-call-per-task -- but
**don't batch a destructive unit** (deletions / scrubs / renames) with unrelated doc rewrites: the
regression hides in the larger diff. Keep destructive units narrow, whole-tree review after every batch.

### 2. Prompt Codex

Canonical invocation -- non-interactive, sandboxed, **no model flag** unless the human's confirmed route
named one (otherwise use Codex's own configured default; don't guess a model id). `-c
approval_policy="never"` stops a headless run hanging on an approval it can't receive; `-o <file>`
captures Codex's final message so you read its file-touched report deterministically instead of scraping
stdout (also the source of truth if the run is backgrounded):

```bash
codex exec --sandbox workspace-write -c approval_policy="never" -C /ABS/REPO/PATH -o /tmp/codex-unit.txt "<prompt>"
```

For a multi-unit plan, prefer a **fresh `codex exec` per unit** pointing at the plan file by path -- Codex
re-reads the plan and working tree each time, so no context is lost. (`codex exec resume --last` exists but
rejects `--sandbox`/`-C` and infers sandbox/cwd from config -- easy to get wrong; use it only for a
same-session correction.)

In the prompt: name exactly what's in scope (the task, or the file list), point at the plan file by path,
and state what's out of scope (no drive-by refactors, no dependency bumps, no submodule pointer changes).
Tell Codex **not to commit** and not to run stack/network verifications (see gotcha). Ask it to report the
files it touched, any gate output, **and any byproducts it hit** (follow-ups / bugs / friction) for your
return contract.

**Before delegating a deletion / scrub / rename, verify the targets are actually dead** against the
current codebase yourself -- Codex will execute a wrong "remove X" faithfully (e.g. scrubbing a string
that's still a live path). Instruct Codex to **report-and-stop, not act**, when a removal would touch
referenced or live code.

### 3. Review (re-establish trust)

- **Diff the entire working tree** against your pre-delegation baseline -- not just the in-scope paths.
  Codex, and the commands it runs, can create or modify files *outside* the named scope (e.g. a generated
  config dir). Flag anything out of scope.
- Run the unit's verification gate **yourself** -- evidence before assertion. Do not accept "all checks
  pass" from Codex's output.
- **If Codex wrote validation code** (a checker, a test, a lint rule), confirm it **fails on injected
  drift** -- passing clean only proves it doesn't error, not that it catches what it should.
- For risky units, escalate to a code-review pass on the diff.
- On drift/failure: re-prompt with a fresh, specific `codex exec` ("the X gate failed with <paste>; fix
  only that"). If it thrashes twice on the same unit, or keeps violating scope, take that unit over
  yourself -- cheaper than a third round-trip.

### 4. Commit (you, never Codex)

After review passes, you commit, in the repo's commit style. Stage by path, not `git add -A`, so Codex's
work doesn't sweep in unrelated drift.

## Guardrails (hard rules)

- **Codex never commits.** It writes to the working tree; you review and commit. State this in every
  prompt, regardless of any project memory.
- **Always `--sandbox workspace-write`.** Never `--dangerously-bypass-approvals-and-sandbox` or
  `danger-full-access` unless the human explicitly says so.
- **No `-m`/model pin unless the confirmed route named one.** Otherwise use Codex's configured default;
  don't guess model ids.
- Worktree isolation is optional -- reach for it only for large or parallel runs, not by default.

## Gotcha: the sandbox can't reach Docker/network

`workspace-write` blocks network and outside-workspace access, so Codex cannot run stack-dependent or
container-backed verifications (anything that spins up services, hits the network, or needs Docker). Let
Codex write the *code* for those units, but **run those gates yourself** outside Codex. Tell Codex to run
only the non-stack checks and skip the rest.

Note: even the non-stack commands you *do* let Codex run can write files (generated profiles, caches,
fixtures). That's why review diffs the whole tree (§3), not just the sources Codex edited.

## Common mistakes

- Trusting Codex's "tests pass" instead of running the gate yourself.
- Reviewing only the in-scope paths -- missing files Codex created elsewhere.
- Relaying a destructive instruction without checking the targets are really dead -- Codex executes it
  literally and breaks live code.
- Accepting a Codex-written checker/test because it passes -- without confirming it *fails on drift*.
- One-call-per-task for purely mechanical work (wasteful) -- batch it; but don't batch destructive units
  with doc rewrites.
- Handing Codex a stack/Docker verification its sandbox can't run, then reading the failure as a code bug.
