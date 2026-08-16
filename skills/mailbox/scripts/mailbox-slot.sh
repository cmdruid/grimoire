#!/usr/bin/env bash
# Mint a mailbox slot: an ABSOLUTE scratch-file path under <root>/.mailbox/ for an
# out-of-band sub-agent handoff. Ensures the dir exists and is git-excluded, then prints
# the absolute slot path (its basename is the unique handle). Facts only -- no dispatch,
# no judgment; the caller hands this path to the sub-agent it spawns.
#
# Usage: mailbox-slot.sh <root> [ext]    (ext default: md; e.g. patch, json, md)
# Why absolute: a dispatched sub-agent's cwd is the repo ROOT, not the worktree, so a
# relative slot would land in the wrong checkout. An absolute path is cwd-proof.
set -euo pipefail

root="${1:?usage: mailbox-slot.sh <root> [ext]}"
ext="${2:-md}"
ext="${ext#.}" # tolerate a leading dot

[ -d "$root" ] || { echo "mailbox-slot: <root> is not a directory: $root" >&2; exit 1; }
root="$(cd "$root" && pwd -P)" # physical path -- must be comparable to git's canonical toplevel

# <root> must BE the target checkout's toplevel -- the canonical `git rev-parse
# --show-toplevel` of the tree the artifact targets. A subdirectory would mint a stray
# .mailbox/ the collect step never looks in; a non-repo dir cannot be a patch target at
# all. Reject both rather than mint a slot the protocol cannot verify.
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$top" ] || { echo "mailbox-slot: <root> is not inside a git worktree: $root" >&2; exit 1; }
[ "$root" = "$top" ] || { echo "mailbox-slot: <root> is not the worktree toplevel (want: $top): $root" >&2; exit 1; }

mkdir -p "$root/.mailbox"

# Git-exclude .mailbox/ from inside the (work)tree, idempotently. rev-parse --git-path
# resolves the shared common-dir exclude for a linked worktree, so one line covers every
# worktree; the grep guard makes re-runs a no-op (a blind >> would accrete duplicates).
exclude="$(git -C "$root" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$root/$exclude" ;; esac
mkdir -p "$(dirname "$exclude")"
grep -qxF '.mailbox/' "$exclude" 2>/dev/null || printf '.mailbox/\n' >>"$exclude"

# Unique handle: uuidgen if available (macOS/Linux), else urandom hex.
if command -v uuidgen >/dev/null 2>&1; then
  id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
else
  id="$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
fi

printf '%s/.mailbox/%s.%s\n' "$root" "$id" "$ext"
