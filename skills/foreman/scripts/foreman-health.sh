#!/usr/bin/env bash
# foreman-health.sh <subcommand> <root> [args...]
#
# Read-only state analysis for the foreman verbs. Each subcommand emits compact
# `key=value` facts + evidence so the agent spends turns DECIDING (is this
# drift real?), not scanning ten files to find the candidates.
#
# DOCTRINE: facts, not verdicts. Nothing here decides to remove, archive, or
# route anything -- it reports the variables the verb prose consumes.
#
# Transferred out during the clankshop rollout (fact-by-fact, destinations
# landed first): `check-projection` (registration + routing-target facts) ->
# clankshop's check-facts.sh; `inventory` (tree/worktree facts -> the migrate
# preflight; tracker sizes -> backlog-health.sh). `derive-seams` remains until
# the independence machinery retires. Bash-3.2 safe; read-only; never mutates.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: foreman-health.sh <subcommand> <root> [args...]

  derive-seams     <skills-root>                  match installed skills' `## Edges` blocks into
                                                  seams (handoff<->consumes) / deps (produces<->consumes)

Each prints `key=value` facts then evidence. Read-only; emits no recommendation.
EOF
}

# `stale-refs` + `coverage` were absorbed into the docs-quality scanner
# (chiropractor's spine-scan.sh: fileline_overruns + uncovered_dirs facts).

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
  # ORPHAN note (mirrors skills-lint.sh check 8's orphan WARN, kept in sync
  # per BL-4/BL-5: a type already EXCLuded as a same-skill produces/handoff x
  # consumes pair is a stated intra-skill chain, not an orphan, even though
  # only one skill's name appears -- suppress ORPH for it). Tagged rows to
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
          if (a==b) { print "EXCL\t" t "\t" a "\thandoff-consumes-same-skill"; excluded[t]=1; continue }
          print "SEAM\t" t "\t" a "\t" b
          seamed[t SUBSEP a SUBSEP b]=1
        }
        for (i=1;i<=np;i++) for (j=1;j<=nc;j++) {
          a=ps[i]; b=cs[j]; if (a=="" || b=="") continue
          if (a==b) { print "EXCL\t" t "\t" a "\tproduces-consumes-same-skill"; excluded[t]=1; continue }
          if ((t SUBSEP a SUBSEP b) in seamed) continue
          print "DEP\t" t "\t" a "\t" b
        }
        if (cnt[t]==1 && !(t in excluded)) print "ORPH\t" t "\t" who[t]
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

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    derive-seams)      cmd_derive_seams "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
