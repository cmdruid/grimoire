#!/usr/bin/env bash
# dev-health.sh <subcommand> <root> [args...]
#
# Read-only state analysis for a project's dev/ docs-system, for the /backlog
# verbs (debrief). The subcommand emits compact `key=value` facts + evidence so
# the agent spends turns DECIDING (did this really surface?), not scanning ten
# files to find the candidates.
#
# DOCTRINE: facts, not verdicts. Nothing here decides to remove, archive, or
# route anything -- it reports the variables the verb prose consumes. It also
# COMPLEMENTS the host doc-linter rather than duplicating it: the linter owns
# markdown-link resolution, enumerable-series indexing, and store-dir
# frontmatter; this surfaces what the linter can't see -- the working-tree
# byproduct signals a sweep consumes.
#
# Portable over the standardized dev/ layout (`/foreman init` creates it) and
# bash-3.2 safe (macOS default). Read-only; never mutates.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: dev-health.sh <subcommand> <root> [args...]

  debrief-scan  <root> [<trunk-ref>]  uncommitted .records/ writes, new TODO/FIXME, recent done-records

Prints `key=value` facts then evidence. Read-only; emits no recommendation.
EOF
}

cmd_debrief_scan() {
  [ "$#" -ge 1 ] || { echo "usage: dev-health.sh debrief-scan <root> [<trunk-ref>]" >&2; exit 2; }
  local root="$1" trunk="${2:-}" dirty todos done_recent

  echo "dirty_backlog:"
  dirty="$(git -C "$root" status --porcelain 2>/dev/null | grep -E '\.records/(tasks|issues|feedback|bugs|notes)' || true)"
  if [ -n "$dirty" ]; then printf '%s\n' "$dirty" | sed 's/^/  /'; else echo "  (none)"; fi

  # New TODO/FIXME/XXX/HACK markers added vs <trunk-ref> (or the working tree if omitted).
  # A bad ref must be a loud fact, not a silent empty diff -- a typo'd trunk would
  # otherwise yield a confidently-wrong "new_todos: (none)".
  if [ -n "$trunk" ] && ! git -C "$root" rev-parse --verify --quiet "$trunk" >/dev/null; then
    echo "trunk_ref=invalid ($trunk does not resolve)"
    trunk=""
  fi
  echo "new_todos:"
  if [ -n "$trunk" ]; then
    todos="$(git -C "$root" diff --unified=0 "$trunk" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E '\b(TODO|FIXME|XXX|HACK)\b' || true)"
  else
    todos="$(git -C "$root" diff --unified=0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E '\b(TODO|FIXME|XXX|HACK)\b' || true)"
  fi
  if [ -n "$todos" ]; then printf '%s\n' "$todos" | sed 's/^\+/  +/'; else echo "  (none)"; fi

  # Most-recent .records/archive records -- informational context only (debrief does not
  # verify a shipped-record's existence; that check was dropped).
  echo "recent_done:"
  # shellcheck disable=SC2012  # ls -t sorts by mtime (find can't portably on macOS); names are controlled dated slugs
  done_recent="$(ls -t "$root"/.records/archive/*.md 2>/dev/null | head -3 || true)"
  if [ -n "$done_recent" ]; then printf '%s\n' "$done_recent" | sed "s#^$root/#  #"; else echo "  (none)"; fi
}

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    debrief-scan) cmd_debrief_scan "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
