#!/usr/bin/env bash
# backlog-health.sh <subcommand> <root> [args...]
#
# Read-only state analysis for a project's `.records/trackers/` stores, for the
# backlog verbs. Each subcommand emits compact `key=value` facts + evidence so
# the agent spends turns DECIDING (did this really surface?), not scanning ten
# files to find the candidates.
#
# DOCTRINE: facts, not verdicts. Nothing here decides to remove, archive, or
# route anything -- it reports the variables the verb prose consumes. Drift and
# assembly validation belong to the deployed check chain (clankshop check /
# the docs-quality role), not here.
#
# Portable over the standardized `.records/` layout and bash-3.2 safe (macOS
# default). Read-only; never mutates.
set -euo pipefail

# Front-door variable `records-root` (default `.records`) -- see the
# front-door-variables doctrine. Prints the resolved repo-relative path.
resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

count_files() {  # markdown files directly in <dir>, READMEs and archive/ excluded
  find "$1" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l | tr -d ' '
}

usage() {
  cat >&2 <<'EOF'
usage: backlog-health.sh <subcommand> <root> [args...]

  inventory     <root>                tracker entry counts + sizes + last-change + done-log length
  debrief-scan  <root> [<trunk-ref>]  uncommitted store writes, new TODO/FIXME, recent completions

Prints `key=value` facts then evidence. Read-only; emits no recommendation.
EOF
}

# ---- inventory: tracker sizes (ID-aware entry counts, the store dirs, the done log) ----
cmd_inventory() {
  [ "$#" -eq 1 ] || { echo "usage: backlog-health.sh inventory <root>" >&2; exit 2; }
  local root="$1" rec_rel trk t f pat n l mod
  rec_rel="$(resolve_records_root "$root")"
  trk="$root/$rec_rel/trackers"
  echo "records-root=$rec_rel"
  for t in tasks issues feedback; do
    f="$trk/$t.md"
    case "$t" in
      tasks)    pat='^- T-[0-9]+ ' ;;
      issues)   pat='^### I-[0-9]+ ' ;;
      feedback) pat='^### F-[0-9]+ ' ;;
    esac
    if [ -f "$f" ]; then
      n="$(grep -cE "$pat" "$f" || true)"
      l="$(wc -l < "$f" | tr -d ' ')"
      mod="$(git -C "$root" log -1 --format=%cr -- "$rec_rel/trackers/$t.md" 2>/dev/null || echo unknown)"
      echo "${t}_entries=$n"
      echo "${t}_lines=$l"
      echo "${t}_last_change=$mod"
    else
      echo "${t}=absent"
    fi
  done
  echo "bugs_open=$(count_files "$trk/bugs")"
  echo "bugs_archived=$(find "$trk/bugs/archive" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  echo "notes_live=$(count_files "$trk/notes")"
  if [ -d "$root/$rec_rel/tickets" ]; then
    echo "tickets_live=$(count_files "$root/$rec_rel/tickets")"
  fi
  if [ -f "$root/$rec_rel/done/log.md" ]; then
    echo "done_log_lines=$(grep -cE '^- [0-9]{4}-' "$root/$rec_rel/done/log.md" || true)"
  else
    echo "done_log=absent"
  fi
}

# ---- debrief-scan: working-tree byproduct signals the sweep consumes ----
cmd_debrief_scan() {
  [ "$#" -ge 1 ] || { echo "usage: backlog-health.sh debrief-scan <root> [<trunk-ref>]" >&2; exit 2; }
  local root="$1" trunk="${2:-}" dirty todos done_recent rec_rel rec_re
  rec_rel="$(resolve_records_root "$root")"
  rec_re="${rec_rel//./\\.}"
  echo "records-root=$rec_rel"

  echo "dirty_backlog:"
  dirty="$(git -C "$root" status --porcelain 2>/dev/null | grep -E "$rec_re/(trackers|tickets|done)/" || true)"
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

  # Most-recent completions -- informational context only: the last done-log lines
  # plus any full done-record files in .records/done/.
  echo "recent_done:"
  if [ -f "$root/$rec_rel/done/log.md" ]; then
    tail -3 "$root/$rec_rel/done/log.md" | grep -E '^- [0-9]{4}-' | sed 's/^/  /' || true
  fi
  # shellcheck disable=SC2012,SC2010  # ls -t sorts by mtime (find can't portably on macOS); names are controlled dated slugs
  done_recent="$(ls -t "$root/$rec_rel"/done/*.md 2>/dev/null | grep -v '/log\.md$' | head -3 || true)"
  if [ -n "$done_recent" ]; then printf '%s\n' "$done_recent" | sed "s#^$root/#  #"; fi
}

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    inventory) cmd_inventory "$@" ;;
    debrief-scan) cmd_debrief_scan "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
