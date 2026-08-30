# `adjust` — confirmation-gated spine adjustment

Run the complete `audit` procedure first, even when the user directly asks to fix the repository.
The original request authorizes a proposal, not an unseen write.

## Bound the proposal

Select the smallest documentation/front-door change set that restores the affected important routes.
Separate mechanically safe reference corrections from authority choices. Group hunks by finding and
name each finding's evidence, target path, and hunk intent.

Before constructing the proposal:

1. Record `git status --short` and the current diff for every proposed tracked target; list untracked
   targets separately.
2. Verify every existing target is a readable regular non-symlink file inside the root. Verify every
   existing parent is a real directory inside the root, not a symlink. Refuse an escaping path.
3. Save an exact temporary preimage and content digest for each existing target. For every proposed
   new target, save an explicit absent preimage instead.
4. Construct results only in a newly created temporary directory. Do not edit the repository and then
   ask whether the change was acceptable.

Present every target, hunk intent, authority decision, and the exact unified diff. For a new small
file, complete contents may accompany the creation diff. Moves, deletions, new doors, source-of-truth
choices, and broader rewrites are distinct preview items. Never include scripts, workflows, manifests,
code, permissions, staging, commits, stashes, resets, or branches.

## Confirmation stop

Stop and wait for explicit approval of the whole displayed patch or named displayed subsets. Silence,
a prior general wish to improve docs, or the word `adjust` is not approval.

A named subset is approved only when its freshly rendered result is byte-identical to the displayed
hunks.
Immediately before writing, compare every existing target to its saved digest, verify every target
whose saved preimage was absent is still absent, and revalidate all paths and parents.
Any changed target, rebase, different rendered subset, new path, move, deletion, authority choice, or
broader rewrite invalidates approval: reread, recompute, display, and confirm again.

## Apply and verify

After valid confirmation:

- Apply only the approved documentation/front-door hunks against current bytes. Use surgical edits;
  do not mass-reflow or replace a dirty file wholesale.
- Preserve Claude-specific content. Replace only portable duplication with `@AGENTS.md`.
- Never repair a discovered script, workflow, manifest, or code file. Repairing a documentation
  reference to one is allowed.
- Compare every touched file with its saved preimage and separate this incremental edit from the
  user's pre-existing diff.

If establishing or reconciling the canonical door, apply only that confirmed door patch, rerun the
scanner from the new `AGENTS.md`, repeat the audit, and present a separately confirmed route-repair
patch. Door establishment can therefore require two deliberate confirmation points.

Otherwise rerun the scanner over the same root, repeat every affected task trace, and show the
incremental diff plus before/after facts. Success requires every approved route and touched reference
to resolve. An unresolved result produces a follow-up proposal; it never authorizes another write.
