# `anchor` — propose guarded recovery instructions

Resolve `templates/recovery-anchor.md` and `scripts/anchor-status.sh` from this package. The template
is package-only; this verb may edit only a human-selected always-loaded project front door and only
after approval.

1. Classify each actual front door with
   `scripts/anchor-status.sh <template> <front-door>`:
   - `current` — exact block; report and stop.
   - `absent` or `missing` — no block.
   - `drifted-current`, `obsolete-versioned`, or `obsolete-unversioned` — one replaceable block;
     use the emitted `anchor_begin_line` and `anchor_end_line` as its exact extent. A versioned
     block spans its ordered markers. An unversioned block spans the unique
     `## Checkpoint recovery` H2 section through the byte before the next H2, or through EOF.
   - `duplicate`, `malformed`, `invalid`, or `invalid-template` — refuse without guessing.
2. For a replaceable block, show the exact bounded old and new content and ask approval. Replace only
   that emitted extent, preserving every byte before and after it. If the reported extent cannot be
   isolated exactly, refuse rather than expanding it.
3. When absent everywhere, show the exact block and ask which front door should receive it. Append
   only after approval.

Anchor never reads any save-state file, self-installs, edits committed ignore rules, or commits the
front-door change. Ordinary `save` only reports anchor status and points here.

**Done when:** every candidate was classified and current was reported, an unsafe state refused, or
the exact approved block was installed/replaced without changing surrounding content.
