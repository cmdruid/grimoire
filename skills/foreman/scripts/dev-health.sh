#!/usr/bin/env bash
# dev-health.sh <subcommand> <root> [args...]
#
# Read-only state analysis for a project's dev/ docs-system, for the /foreman
# verbs (tune, check). Each subcommand emits compact `key=value` facts +
# evidence so the agent spends turns DECIDING (is this entry really done? is
# this drift real?), not scanning ten files to find the candidates.
#
# DOCTRINE: facts, not verdicts. Nothing here decides to remove, archive, or
# route anything -- it reports the variables the verb prose consumes. It also
# COMPLEMENTS the host doc-linter rather than duplicating it: the linter owns
# markdown-link resolution, enumerable-series indexing, and store-dir
# frontmatter; this surfaces what the linter can't see -- tracker inventory,
# code `file:line` references in tracker prose, and spine coverage.
#
# Portable over the standardized dev/ layout (`/foreman init` creates it) and
# bash-3.2 safe (macOS default). Read-only; never mutates.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: dev-health.sh <subcommand> <root> [args...]

  inventory     <root>                tracker sizes + bug/done/archive counts + quiet
  stale-refs    <root> [<file>...]    path / file:line refs that no longer resolve
                                      (default: trackers + spine + index docs)
  coverage      <root>                top-level dirs not reachable from the spine docs

Each prints `key=value` facts then evidence. Read-only; emits no recommendation.
EOF
}

# lower <STR> -- lowercase without bash-4 ${x,,}.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# count_files <dir> -- *.md directly under <dir> (0 if absent), whitespace-trimmed.
count_files() { find "$1" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }

# top_level_dirs <root> -- space-padded list of top-level dir names (dotless),
# e.g. " src dev docs tests ". Used to gate refs to genuine repo-root paths.
top_level_dirs() {
  local d name out=" "
  for d in "$1"/*/; do
    name="$(basename "$d")"; case "$name" in .*) continue;; esac
    out="$out$name "
  done
  printf '%s' "$out"
}

# extract_refs <file...> -- backticked, unambiguous repo-ROOT path tokens only:
# multi-segment (has `/`), path chars + optional `:line`, no spaces/globs/URLs.
# This deliberately drops the prose noise (bare filenames, frontmatter examples,
# globs, doc-relative mentions) that makes a path-resolution fact unreliable.
extract_refs() {
  # shellcheck disable=SC2016  # literal backticks are intentional (markdown code spans)
  grep -hoE '`[^`]+`' "$@" 2>/dev/null \
    | tr -d '`' \
    | sed -E 's/[),.;]+$//' \
    | grep -E '^[A-Za-z0-9._/-]+(:[0-9]+)?$' \
    | grep -E '/' \
    | sort -u || true
}

# report_stale <root> <tlds> <file...> -- emit `stale_refs:` evidence + counts.
# Only a ref whose first segment is a real top-level dir is checked (so it is
# unambiguously root-relative); others are skipped, not guessed.
report_stale() {
  local root="$1" tlds="$2"; shift 2
  local refs r path line first n total=0 stale=0
  refs="$(extract_refs "$@")"
  echo "stale_refs:"
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    path="${r%%:*}"; line=""
    case "$r" in *:[0-9]*) line="${r##*:}";; esac
    first="${path%%/*}"
    case "$tlds" in *" $first "*) ;; *) continue;; esac
    total=$((total + 1))
    if [ ! -e "$root/$path" ]; then
      stale=$((stale + 1)); echo "  $r  (missing)"
    elif [ -n "$line" ] && [ -f "$root/$path" ]; then
      n="$(wc -l < "$root/$path" | tr -d ' ')"
      if [ "$line" -gt "$n" ]; then stale=$((stale + 1)); echo "  $r  (file has $n lines)"; fi
    fi
  done <<< "$refs"
  [ "$stale" -eq 0 ] && echo "  (none)"
  echo "checked=$total"
  echo "stale=$stale"
}

cmd_inventory() {
  [ "$#" -eq 1 ] || { echo "usage: dev-health.sh inventory <root>" >&2; exit 2; }
  local root="$1" porcelain t f tl b l mod
  porcelain="$(git -C "$root" status --porcelain 2>/dev/null || true)"
  echo "tree_quiet=$([ -z "$porcelain" ] && echo true || echo false)"
  echo "linked_worktrees=$(( $(git -C "$root" worktree list 2>/dev/null | wc -l | tr -d ' ') - 1 ))"
  for t in BACKLOG ISSUES FEEDBACK; do
    f="$root/dev/$t.md"; tl="$(lower "$t")"
    if [ -f "$f" ]; then
      b="$(grep -cE '^[-*] ' "$f" || true)"
      l="$(wc -l < "$f" | tr -d ' ')"
      mod="$(git -C "$root" log -1 --format=%cr -- "dev/$t.md" 2>/dev/null || echo unknown)"
      echo "${tl}_bullets=$b"
      echo "${tl}_lines=$l"
      echo "${tl}_last_change=$mod"
    else
      echo "${tl}=absent"
    fi
  done
  echo "bugs_open=$(count_files "$root/dev/bugs")"
  echo "bugs_archived=$(find "$root/dev/bugs/archive" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  echo "done_records=$(count_files "$root/dev/done")"
}

cmd_stale_refs() {
  [ "$#" -ge 1 ] || { echo "usage: dev-health.sh stale-refs <root> [<file>...]" >&2; exit 2; }
  local root="$1"; shift
  local tlds; tlds="$(top_level_dirs "$root")"
  if [ "$#" -ge 1 ]; then
    report_stale "$root" "$tlds" "$@"
  else
    # default set: trackers + index + spine docs that exist
    local f docs=()
    for f in dev/BACKLOG.md dev/ISSUES.md dev/FEEDBACK.md dev/MEMORY.md dev/README.md AGENTS.md README.md; do
      [ -f "$root/$f" ] && docs+=("$root/$f")
    done
    if [ "${#docs[@]}" -gt 0 ]; then
      report_stale "$root" "$tlds" "${docs[@]}"
    else
      echo "stale_refs:"; echo "  (no tracker/spine docs found)"; echo "checked=0"; echo "stale=0"
    fi
  fi
}

cmd_coverage() {
  [ "$#" -eq 1 ] || { echo "usage: dev-health.sh coverage <root>" >&2; exit 2; }
  local root="$1" d name s found any=0 tick='`'
  echo "spine_uncovered:"
  for d in "$root"/*/; do
    name="$(basename "$d")"
    case "$name" in .*) continue;; esac
    found=0
    for s in "$root/AGENTS.md" "$root/dev/README.md" "$root/README.md"; do
      # Fixed-string, dir-shaped match ("name/" or a backticked mention): an
      # unanchored regex match on the bare name false-covers short names
      # (substring hits) and breaks on regex metachars.
      [ -f "$s" ] && { grep -qF "$name/" "$s" || grep -qF "${tick}${name}${tick}" "$s"; } && { found=1; break; }
    done
    [ "$found" -eq 0 ] && { echo "  $name/"; any=1; }
  done
  [ "$any" -eq 0 ] && echo "  (none)"
}

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    inventory)    cmd_inventory "$@" ;;
    stale-refs)   cmd_stale_refs "$@" ;;
    coverage)     cmd_coverage "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
