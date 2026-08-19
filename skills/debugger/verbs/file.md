# `file` — capture a standing repro

Capture, not diagnosis. Mint a `bugs` record that stands cold. Do **not**
append a tracker line. Do **not** enter Phases 1–4. There is **no
write-only arm**.

1. Resolve both homes (SKILL.md). Locate `scripts/bug-mint.sh` from this
   skill's own directory.
2. **Mint**: `scripts/bug-mint.sh mint <agent-records> <templates-home>
   "<symptom, specific>"`. Fill Repro, Expected vs actual (paste the real
   error/trace in full), and Notes so a fresh session can reproduce it
   from the record alone.
3. **Always commit itself** on the tree the SKILL.md commit-tree probe
   selects: `scripts/scoped-commit.sh <root> "Debugger: file — <slug>"`
   over exactly the minted path. Commit-tree STOP (detached, non-git,
   unheld `stream/*`/`feature/*`) → no commit; the record stays on disk.

## Done when

- Bug record minted and filled so it stands cold; no tracker file created
  or edited.
- Standalone scoped commit landed, or commit-tree STOP with no commit.
