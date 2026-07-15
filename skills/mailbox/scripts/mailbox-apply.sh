#!/usr/bin/env bash
# Apply a mailbox PATCH slot to <root>'s working tree via `git apply`, then reap the slot.
# A fuzz / non-apply failure exits non-zero LOUDLY (tree drifted -- e.g. a sync landed),
# so the caller can re-roll the dispatch -- unlike a silent stray worktree edit. The
# parent (sole writer of the tree) runs this; the sub-agent only ever wrote the slot.
#
# Usage: mailbox-apply.sh <root> <slot> [--check]
#   --check : dry-run (git apply --check) -- report whether it WOULD apply, change nothing.
# For a non-patch slot (a plan / analysis / verdict) do NOT use this: read it into context
# once instead (the "consume" path). This script is the "apply-only" path.
set -euo pipefail

root="${1:?usage: mailbox-apply.sh <root> <slot> [--check]}"
slot="${2:?usage: mailbox-apply.sh <root> <slot> [--check]}"
mode="${3:-}"

[ -d "$root" ] || { echo "mailbox-apply: <root> is not a directory: $root" >&2; exit 1; }
[ -f "$slot" ] || { echo "mailbox-apply: slot not found: $slot" >&2; exit 1; }

if [ "$mode" = "--check" ]; then
  if git -C "$root" apply --check "$slot"; then
    echo "mailbox-apply: would apply cleanly: $(basename "$slot")"
    exit 0
  fi
  echo "mailbox-apply: would NOT apply (tree drift / fuzz): $slot" >&2
  exit 1
fi

if git -C "$root" apply "$slot"; then
  rm -f "$slot"
  echo "mailbox-apply: applied and reaped $(basename "$slot")"
else
  echo "mailbox-apply: FAILED to apply $slot (tree drift / fuzz) -- slot kept for inspection" >&2
  exit 1
fi
