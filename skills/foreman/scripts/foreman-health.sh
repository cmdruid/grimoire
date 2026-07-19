#!/usr/bin/env bash
# foreman-health.sh <subcommand> <root> [args...]
#
# Read-only state analysis for a project's .agents/foreman/ docs-system, for the
# /foreman verbs (calibrate, check). Each subcommand emits compact `key=value` facts +
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
# Portable over the standardized .agents/foreman/ + .records/ layout (`/foreman init` creates it) and
# bash-3.2 safe (macOS default). Read-only; never mutates.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: foreman-health.sh <subcommand> <root> [args...]

  inventory        <root>                        tracker sizes + bug/done/archive counts + quiet
  stale-refs       <root> [<file>...]             path / file:line refs that no longer resolve
                                                  (default: trackers + spine + index docs)
  coverage         <root>                         top-level dirs not reachable from the spine docs
  derive-seams     <skills-root>                  match installed skills' `## Edges` blocks into
                                                  seams (handoff<->consumes) / deps (produces<->consumes)
  check-projection <front-door> <skills-root>     diff the front door's registered `skill:*` blocks
                                                  against what's installed (drift facts only)

Each prints `key=value` facts then evidence. Read-only; emits no recommendation.
EOF
}

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
  [ "$#" -eq 1 ] || { echo "usage: foreman-health.sh inventory <root>" >&2; exit 2; }
  local root="$1" porcelain t f b l mod
  porcelain="$(git -C "$root" status --porcelain 2>/dev/null || true)"
  echo "tree_quiet=$([ -z "$porcelain" ] && echo true || echo false)"
  echo "linked_worktrees=$(( $(git -C "$root" worktree list 2>/dev/null | wc -l | tr -d ' ') - 1 ))"
  for t in tasks issues feedback; do
    f="$root/.records/$t.md"
    if [ -f "$f" ]; then
      b="$(grep -cE '^[-*] ' "$f" || true)"
      l="$(wc -l < "$f" | tr -d ' ')"
      mod="$(git -C "$root" log -1 --format=%cr -- ".records/$t.md" 2>/dev/null || echo unknown)"
      echo "${t}_bullets=$b"
      echo "${t}_lines=$l"
      echo "${t}_last_change=$mod"
    else
      echo "${t}=absent"
    fi
  done
  echo "bugs_open=$(count_files "$root/.records/bugs")"
  echo "bugs_archived=$(find "$root/.records/bugs/archive" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  echo "done_records=$(count_files "$root/.records/archive")"
}

cmd_stale_refs() {
  [ "$#" -ge 1 ] || { echo "usage: foreman-health.sh stale-refs <root> [<file>...]" >&2; exit 2; }
  local root="$1"; shift
  local tlds; tlds="$(top_level_dirs "$root")"
  if [ "$#" -ge 1 ]; then
    report_stale "$root" "$tlds" "$@"
  else
    # default set: trackers + index + spine docs that exist
    local f docs=()
    for f in .records/tasks.md .records/issues.md .records/feedback.md .agents/foreman/MEMORY.md .agents/foreman/README.md AGENTS.md README.md; do
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
  [ "$#" -eq 1 ] || { echo "usage: foreman-health.sh coverage <root>" >&2; exit 2; }
  local root="$1" d name s found any=0 tick='`'
  echo "spine_uncovered:"
  for d in "$root"/*/; do
    name="$(basename "$d")"
    case "$name" in .*) continue;; esac
    found=0
    for s in "$root/AGENTS.md" "$root/.agents/foreman/README.md" "$root/README.md"; do
      # Fixed-string, dir-shaped match ("name/" or a backticked mention): an
      # unanchored regex match on the bare name false-covers short names
      # (substring hits) and breaks on regex metachars.
      [ -f "$s" ] && { grep -qF "$name/" "$s" || grep -qF "${tick}${name}${tick}" "$s"; } && { found=1; break; }
    done
    [ "$found" -eq 0 ] && { echo "  $name/"; any=1; }
  done
  [ "$any" -eq 0 ] && echo "  (none)"
}

# parse_edges <skills-root> <out-tuples-file> -- extract every skill's `## Edges`
# block into `<kind>\t<type>\t<skill>` tuples (one row per declared type). Same
# delimiter/line format `scripts/skills-lint.sh` check 8 parses (kept in sync by
# convention, not shared code -- dev-time gate vs. shipped runtime composer, see
# docs/design/2026-07-19-phase4-foreman-rescope.md #4.2). Malformed blocks are
# reported, not parsed -- skills-lint.sh FAILs those at grimoire's own gate; this
# script only ever sees an already-gated skill, but a mid-edit/uninstalled one is
# still possible, so it degrades to a fact, never a crash. BSD/macOS-safe: no
# multi-line `awk -v` (BL-3); single-line -v (the skill name) only.
parse_edges() {
  local skills_root="$1" out="$2" emdash="—"
  local sk name f opens closes block line kind value types_part tok
  : > "$out"
  for sk in "$skills_root"/*/; do
    name="$(basename "$sk")"
    f="$sk/SKILL.md"
    [ -f "$f" ] || continue
    opens="$(grep -oE '^<!-- edges:[a-z][a-z-]* -->$' "$f" | sed 's/^<!-- edges://; s/ -->$//' || true)"
    closes="$(grep -oE '^<!-- /edges:[a-z][a-z-]* -->$' "$f" | sed 's|^<!-- /edges:||; s/ -->$//' || true)"
    if [ -z "$opens" ] && [ -z "$closes" ]; then continue; fi   # no block yet -- Phase 5 rollout, not an error
    if [ "$(printf '%s\n' "$opens" | grep -c .)" -ne 1 ] || [ "$(printf '%s\n' "$closes" | grep -c .)" -ne 1 ] \
       || [ "$opens" != "$name" ] || [ "$closes" != "$name" ]; then
      printf 'MALFORMED\t-\t%s\n' "$name" >> "$out"
      continue
    fi
    block="$(awk -v n="$name" '$0=="<!-- edges:"n" -->"{b=1;next} $0=="<!-- /edges:"n" -->"{b=0} b' "$f")"
    while IFS= read -r line; do
      case "$line" in "- "*) ;; *) continue ;; esac
      kind="$(printf '%s' "$line" | sed -n 's/^- \([a-z]*\):.*/\1/p')"
      case "$kind" in produces|consumes|handoff) ;; *) continue ;; esac
      value="$(printf '%s' "$line" | sed 's/^- [a-z]*:[[:space:]]*//')"
      types_part="${value%%"$emdash"*}"
      IFS=',' read -ra toks <<< "$types_part" || true
      for tok in ${toks[@]+"${toks[@]}"}; do
        tok="$(printf '%s' "$tok" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -z "$tok" ] && continue
        case "$tok" in /*) continue ;; esac    # sibling name, not a type -- skills-lint.sh FAILs this at gate time
        printf '%s\t%s\t%s\n' "$kind" "$tok" "$name" >> "$out"
      done
    done < <(printf '%s\n' "$block")
  done
}

cmd_derive_seams() {
  [ "$#" -eq 1 ] || { echo "usage: foreman-health.sh derive-seams <skills-root>" >&2; exit 2; }
  local skills_root="$1"
  [ -d "$skills_root" ] || { echo "FAIL: skills-root $skills_root is not a directory" >&2; exit 2; }
  local tuples rows
  tuples="$(mktemp "${TMPDIR:-/tmp}/foreman-health-edges.XXXXXX")"
  rows="$(mktemp "${TMPDIR:-/tmp}/foreman-health-rows.XXXXXX")"
  parse_edges "$skills_root" "$tuples"

  # One pass: for each type, cross handoff x consumes (SEAM) and produces x
  # consumes (DEP, unless already a SEAM pair), excluding same-skill pairs
  # (model doc #2.1 + Phase 3 F2 intra-skill-chain rule), plus a single-skill
  # ORPHAN note (mirrors skills-lint.sh check 8's orphan WARN). Tagged rows to
  # $rows; the shell below prints them grouped, matching this script's existing
  # section style (a header + indented evidence + `(none)` fallback).
  awk -F'\t' '
    $1=="MALFORMED" { print "MALFORMED\t" $3; next }
    { H[$2]=$1=="handoff"  ? H[$2]" "$3 : H[$2]
      P[$2]=$1=="produces" ? P[$2]" "$3 : P[$2]
      C[$2]=$1=="consumes" ? C[$2]" "$3 : C[$2]
      k=$2 SUBSEP $3
      if (!(k in seenpair)) { seenpair[k]=1; cnt[$2]++; who[$2]=(who[$2]==""?$3:who[$2]" "$3) }
      seen[$2]=1
    }
    END {
      for (t in seen) {
        nh=split(H[t], hs, " "); nc=split(C[t], cs, " "); np=split(P[t], ps, " ")
        for (i=1;i<=nh;i++) for (j=1;j<=nc;j++) {
          a=hs[i]; b=cs[j]; if (a=="" || b=="") continue
          if (a==b) { print "EXCL\t" t "\t" a "\thandoff-consumes-same-skill"; continue }
          print "SEAM\t" t "\t" a "\t" b
          seamed[t SUBSEP a SUBSEP b]=1
        }
        for (i=1;i<=np;i++) for (j=1;j<=nc;j++) {
          a=ps[i]; b=cs[j]; if (a=="" || b=="") continue
          if (a==b) { print "EXCL\t" t "\t" a "\tproduces-consumes-same-skill"; continue }
          if ((t SUBSEP a SUBSEP b) in seamed) continue
          print "DEP\t" t "\t" a "\t" b
        }
        if (cnt[t]==1) print "ORPH\t" t "\t" who[t]
      }
    }
  ' "$tuples" > "$rows"

  local n
  echo "seams:"
  n=0; while IFS=$'\t' read -r tag t a b; do [ "$tag" = SEAM ] || continue; echo "  $a -> $b ($t)"; n=$((n+1)); done < "$rows"
  [ "$n" -eq 0 ] && echo "  (none)"
  echo "deps:"
  n=0; while IFS=$'\t' read -r tag t a b; do [ "$tag" = DEP ] || continue; echo "  $b reads $a's $t"; n=$((n+1)); done < "$rows"
  [ "$n" -eq 0 ] && echo "  (none)"
  echo "excluded:"
  n=0; while IFS=$'\t' read -r tag t a why; do [ "$tag" = EXCL ] || continue; echo "  $a $t ($why)"; n=$((n+1)); done < "$rows"
  [ "$n" -eq 0 ] && echo "  (none)"
  echo "orphans:"
  n=0; while IFS=$'\t' read -r tag t who; do [ "$tag" = ORPH ] || continue; echo "  $t (declared only by: $who)"; n=$((n+1)); done < "$rows"
  [ "$n" -eq 0 ] && echo "  (none)"
  echo "malformed:"
  n=0; while IFS=$'\t' read -r tag name; do [ "$tag" = MALFORMED ] || continue; echo "  $name"; n=$((n+1)); done < "$rows"
  [ "$n" -eq 0 ] && echo "  (none)"
  echo "skills_scanned=$(find "$skills_root" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
  echo "skills_with_edges=$(cut -f3 "$tuples" | sort -u | wc -l | tr -d ' ')"
  rm -f "$tuples" "$rows"
}

cmd_check_projection() {
  [ "$#" -eq 2 ] || { echo "usage: foreman-health.sh check-projection <front-door> <skills-root>" >&2; exit 2; }
  local front="$1" skills_root="$2"
  [ -f "$front" ] || { echo "FAIL: front-door $front does not exist" >&2; exit 2; }
  [ -d "$skills_root" ] || { echo "FAIL: skills-root $skills_root is not a directory" >&2; exit 2; }

  local reg inst sk name ba
  reg="$(mktemp "${TMPDIR:-/tmp}/foreman-health-reg.XXXXXX")"
  inst="$(mktemp "${TMPDIR:-/tmp}/foreman-health-inst.XXXXXX")"

  grep -oE '^<!-- skill:[a-z][a-z-]* BEGIN built-against:[^ ]* -->$' "$front" \
    | sed -E 's/^<!-- skill:([a-z-]+) BEGIN built-against:(.*) -->$/\1\t\2/' > "$reg" || true

  for sk in "$skills_root"/*/; do
    name="$(basename "$sk")"
    [ -f "$sk/SKILL.md" ] || continue
    # Path-scoped (log -1 -- .), not rev-parse HEAD: the whole-repo tip collapses
    # every skill to one value on a monorepo skills-root (BL-7); this tracks the
    # last commit that actually touched THIS skill's own directory.
    ba="$(git -C "$sk" log -1 --format=%h -- . 2>/dev/null || echo unknown)"
    printf '%s\t%s\n' "$name" "$ba" >> "$inst"
  done

  echo "registered:"
  local n=0
  while IFS=$'\t' read -r name ba; do [ -n "$name" ] || continue; echo "  $name (built-against:$ba)"; n=$((n+1)); done < "$reg"
  [ "$n" -eq 0 ] && echo "  (none)"

  echo "unregistered:"
  n=0
  while IFS=$'\t' read -r name ba; do
    [ -n "$name" ] || continue
    grep -qF "$(printf '%s\t' "$name")" "$reg" && continue
    echo "  $name"; n=$((n+1))
  done < "$inst"
  [ "$n" -eq 0 ] && echo "  (none)"

  echo "orphaned:"
  n=0
  while IFS=$'\t' read -r name ba; do
    [ -n "$name" ] || continue
    grep -qF "$(printf '%s\t' "$name")" "$inst" && continue
    echo "  $name"; n=$((n+1))
  done < "$reg"
  [ "$n" -eq 0 ] && echo "  (none)"

  echo "stale-stamp:"
  n=0
  while IFS=$'\t' read -r name ba; do
    [ -n "$name" ] || continue
    iba="$(awk -F'\t' -v nm="$name" '$1==nm{print $2}' "$inst")"
    [ -n "$iba" ] || continue
    [ "$iba" = "$ba" ] && continue
    echo "  $name built-against=$ba now=$iba"; n=$((n+1))
  done < "$reg"
  [ "$n" -eq 0 ] && echo "  (none)"
  rm -f "$reg" "$inst"
}

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    inventory)         cmd_inventory "$@" ;;
    stale-refs)        cmd_stale_refs "$@" ;;
    coverage)          cmd_coverage "$@" ;;
    derive-seams)      cmd_derive_seams "$@" ;;
    check-projection)  cmd_check_projection "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
