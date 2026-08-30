# `anchor` — propose guarded lifecycle and recovery instructions

Resolve `templates/recovery-anchor.md` and `scripts/anchor-status.sh` from this package. The template
is package-only; this verb may edit only a human-selected always-loaded project `AGENTS.md` and only
after approval.

1. Classify the selected `AGENTS.md` with `scripts/anchor-status.sh <template> <front-door>`:
   - `current` — exact block; report and stop.
   - `absent` — no reserved anchor marker or Checkpoint H2; show the selected target and exact
     version-2 block, then offer to append it.
   - `drifted-current` or `conflict` — one marker-bounded replaceable extent. `conflict` is an
     opaque reserved-namespace collision, not a recognized version or migration source.
   - any `anchor_error` — refuse without an extent or replacement offer.
2. For `drifted-current` or `conflict`, show the selected `AGENTS.md` path, the exact bounded current
   content that would be removed, and the exact version-2 replacement, then offer the wholesale
   replacement. Do not interpret or carry forward any content from a conflict.
3. After approval, classify again and require the same replaceable status, extent, and exact shown
   bytes. If any differ, touch nothing; reclassify and re-propose. Otherwise replace only that
   extent, preserving every byte before and after it. For an approved append, likewise reclassify
   and require `absent` before writing.

Anchor never reads any save-state file, self-installs, edits committed ignore rules, or commits the
front-door change. It never touches grimoire's real `AGENTS.md`; package verification uses only
throwaway project fixtures. Ordinary `save` only reports anchor status and points here.

**Done when:** every candidate was classified and current was reported, an unsafe state refused, or
the exact approved block was installed/replaced without changing surrounding content.
