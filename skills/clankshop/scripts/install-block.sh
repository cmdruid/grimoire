#!/bin/sh
# install-block.sh -- the installation block (plan Appendix F): read/write/validate, plus
# the resolver walk (mechanics section 7). Facts only, one key=value per line; judgment
# (what to do about an unstamped or mismatched root) stays with the calling verb.
#
#   install-block.sh read <root>
#     door=<file>|none  stamped=0|1  layout= / pack= / pack-version= (when valid)
#     malformed=<reason> | unknown-version=<n> | missing-key=layout | unknown-key=<name>
#     Malformed / duplicate / invalid => stamped=0 (the root is treated as unstamped).
#
#   install-block.sh write <root> <layout> [<pack> <pack-version>]
#     Idempotent create-or-adopt (self-init-no-floor). Absent block => append the
#     deterministic block to the door (creating AGENTS.md only when no door exists);
#     emits created=1. Present + every requested key equal => adopted=1 (extra existing
#     keys are fine -- a bare self-init adopts a pack-stamped root). Present + a
#     requested key differs => mismatch=<key> <existing>!=<requested>, nothing written.
#     Malformed => the malformed fact, nothing written.
#
#   install-block.sh resolve <path>
#     Filesystem walk up from <path>: the nearest door carrying an installation block
#     wins (root=<dir> + that door's read facts); a malformed/invalid door is treated as
#     unstamped (skipped-door=<path> <reason>) and the walk continues; at an unstamped
#     repo root, `git rev-parse --show-superproject-working-tree` continues across the
#     repo boundary (nested submodule); no superproject => unmanaged=1 (a linked
#     worktree therefore terminates at its own root). All other machinery takes the
#     emitted root as an explicit parameter.
set -eu

usage() { echo "usage: install-block.sh read|write|resolve ..." >&2; exit 2; }
[ $# -ge 2 ] || usage
cmd=$1

# parse_door <file>: tagged stream for one file --
#   present=0 | present=1 + version=<n> [+ malformed=<reason>] [+ kv:<key>=<value> ...]
# Same comment-block syntax as Appendix A; fence-aware outside the block (a fenced
# example block in door prose is an example, not a stamp -- spine-scan precedent).
parse_door() {
  awk '
    /^[ ]*(```|~~~)/ && state != 1 { fence = !fence; next }
    fence { next }
    state != 1 && /^<!-- installation v[0-9]+$/ {
      if (state == 2) { bad = "duplicate-block"; state = 3; next }
      version = $0; sub(/^.* v/, "", version); state = 1; next
    }
    state == 1 {
      if ($0 == "-->") { state = 2; next }
      if (match($0, /^[A-Za-z0-9-]+:/)) {
        key = substr($0, 1, RLENGTH - 1)
        val = substr($0, RLENGTH + 1); sub(/^ /, "", val)
        if (key in kv) { bad = "duplicate-key " key; state = 3; next }
        kv[key] = val; order[++nk] = key; next
      }
      bad = "bad-line " FNR; state = 3; next
    }
    { next }
    END {
      if (state == 0) { print "present=0"; exit }
      if (state == 1 && bad == "") bad = "unclosed"
      print "present=1"
      print "version=" version
      if (bad != "") { print "malformed=" bad; exit }
      for (i = 1; i <= nk; i++) print "kv:" order[i] "=" kv[order[i]]
    }
  ' "$1"
}

# read_facts <dir>: the read-command fact set for one root (also resolve's terminal form).
# Emits stamped=1 only for a well-formed v1 block carrying layout:.
read_facts() {
  dir=$1
  door=""
  fallback=""
  parsed=""
  for f in AGENTS.md CLAUDE.md; do
    [ -f "$dir/$f" ] || continue
    [ -n "$fallback" ] || fallback=$f
    p=$(parse_door "$dir/$f")
    if [ "$p" != "present=0" ]; then door=$f; parsed=$p; break; fi
  done
  if [ -z "$door" ]; then
    echo "door=${fallback:-none}"
    echo "stamped=0"
    return
  fi
  echo "door=$door"
  version=$(printf '%s\n' "$parsed" | sed -n 's/^version=//p')
  malformed=$(printf '%s\n' "$parsed" | sed -n 's/^malformed=//p')
  if [ -n "$malformed" ]; then
    echo "stamped=0"
    echo "malformed=$malformed"
    return
  fi
  if [ "$version" != 1 ]; then
    echo "stamped=0"
    echo "unknown-version=$version"
    return
  fi
  printf '%s\n' "$parsed" | sed -n 's/^kv://p' | while IFS= read -r pair; do
    key=${pair%%=*}
    case "$key" in
      layout|pack|pack-version) echo "$pair" ;;
      *) echo "unknown-key=$key" ;;
    esac
  done
  layout=$(printf '%s\n' "$parsed" | sed -n 's/^kv:layout=//p')
  if [ -n "$layout" ]; then
    echo "stamped=1"
  else
    echo "stamped=0"
    echo "missing-key=layout"
  fi
}

case "$cmd" in

read)
  root=$(CDPATH='' cd "$2" && pwd)
  read_facts "$root"
  ;;

write)
  [ $# -eq 3 ] || [ $# -eq 5 ] || usage
  root=$(CDPATH='' cd "$2" && pwd)
  layout=$3
  pack=${4:-}
  packver=${5:-}
  facts=$(read_facts "$root")
  door=$(printf '%s\n' "$facts" | sed -n 's/^door=//p')
  malformed=$(printf '%s\n' "$facts" | sed -n 's/^malformed=//p')
  unknownv=$(printf '%s\n' "$facts" | sed -n 's/^unknown-version=//p')
  # A door whose parse found no block at all reports only door= + stamped=0 with no
  # block facts: detect block presence via the raw parse.
  has_block=1
  if [ "$door" = none ] || [ "$(parse_door "$root/$door" 2>/dev/null || echo present=0)" = "present=0" ]; then
    has_block=0
  fi
  if [ "$has_block" = 1 ] && [ -n "$malformed" ]; then
    echo "door=$door"; echo "wrote=0"; echo "malformed=$malformed"; exit 0
  fi
  if [ "$has_block" = 1 ] && [ -n "$unknownv" ]; then
    echo "door=$door"; echo "wrote=0"; echo "unknown-version=$unknownv"; exit 0
  fi
  if [ "$has_block" = 1 ]; then
    ok=1
    check_key() {  # <key> <wanted> -- every requested key must equal; extras are fine
      have=$(printf '%s\n' "$facts" | sed -n "s/^$1=//p")
      if [ "$have" != "$2" ]; then
        echo "mismatch=$1 ${have:-<absent>}!=$2"; ok=0
      fi
    }
    check_key layout "$layout"
    [ -n "$pack" ] && check_key pack "$pack"
    [ -n "$packver" ] && check_key pack-version "$packver"
    echo "door=$door"
    if [ "$ok" = 1 ]; then echo "adopted=1"; else echo "adopted=0"; echo "wrote=0"; fi
    exit 0
  fi
  # No block anywhere: append the deterministic block (create AGENTS.md when no door).
  [ "$door" = none ] && door=AGENTS.md
  target=$root/$door
  block="<!-- installation v1
layout: $layout"
  [ -n "$pack" ] && block="$block
pack: $pack"
  [ -n "$packver" ] && block="$block
pack-version: $packver"
  block="$block
-->"
  if [ -s "$target" ]; then
    printf '\n%s\n' "$block" >> "$target"
  else
    printf '%s\n' "$block" > "$target"
  fi
  echo "door=$door"
  echo "created=1"
  ;;

resolve)
  start=$2
  if [ -f "$start" ]; then start=$(dirname "$start"); fi
  dir=$(CDPATH='' cd "$start" && pwd)
  while :; do
    facts=$(read_facts "$dir")
    door=$(printf '%s\n' "$facts" | sed -n 's/^door=//p')
    stamped=$(printf '%s\n' "$facts" | sed -n 's/^stamped=//p')
    unknownv=$(printf '%s\n' "$facts" | sed -n 's/^unknown-version=//p')
    if [ "$stamped" = 1 ] || [ -n "$unknownv" ]; then
      # Nearest door carrying a block wins. An unknown-version door still stops the
      # walk (never silently re-root a newer installation); stamped=0 surfaces it.
      echo "root=$dir"
      printf '%s\n' "$facts"
      exit 0
    fi
    reason=$(printf '%s\n' "$facts" | grep -E '^(malformed|missing-key)=' | head -1 || true)
    [ -n "$reason" ] && echo "skipped-door=$dir/$door $reason"
    if [ -e "$dir/.git" ]; then
      super=$(git -C "$dir" rev-parse --show-superproject-working-tree 2>/dev/null || true)
      if [ -n "$super" ]; then dir=$super; continue; fi
      echo "unmanaged=1"
      exit 0
    fi
    if [ "$dir" = / ]; then echo "unmanaged=1"; exit 0; fi
    dir=$(dirname "$dir")
  done
  ;;

*) usage ;;
esac
