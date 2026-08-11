#!/usr/bin/env bash
# skills-lint.sh [<agents-root>]   (default: the current directory)
#
# The lint gate for a skills library -- bundled with `skill-builder` so it
# travels with the skill wherever installed, checked against whatever
# <agents-root> (a directory containing a skills/ subdir) it's pointed at.
# Run it from the library's own root BEFORE committing there (grimoire's own
# copy: README -> Contributing).
#
# DOCTRINE: facts, not verdicts. Emits `FAIL:`/`WARN:` lines with evidence and a
# summary count; exit 1 on any FAIL, 0 otherwise. It never fixes anything.
#
# Checks:
#   1. SKILL.md frontmatter: description present, <=1024 chars (FAIL), >750 (WARN),
#      quoted when it contains ": " (FAIL -- strict-YAML nested-mapping trap).
#   2. Intra-skill refs: backticked scripts/|templates/|verbs/|references/|rules/|
#      roles/|doctrine/ paths named in a skill's .md files resolve inside that
#      skill dir (FAIL). docs/ refs resolve two-stage: <skill-dir>/docs/<path>,
#      then (if absent) <repo-root>/docs/<path> -- FAIL when neither exists AND
#      <repo-root>/docs/ itself exists (a genuinely dangling ref, this clone);
#      WARN instead when <repo-root>/docs/ doesn't exist at all (a foreign
#      library this portable skill was copied into, so a grimoire-only
#      provenance citation can't be checked -- the portability claim up top).
#   3. (retired -- the foreman BOOTSTRAP manifest lost its subject; numbering held.)
#   4. Consumption wiring: every skills/<name> has a ~/.claude/skills/<name>
#      symlink pointing at it (FAIL) and a README mention (WARN).
#   5. bash -n every scripts/*.sh (FAIL); shellcheck if installed (WARN).
#   6. Cross-skill name refs: a backticked `/name` slash-invocation that matches
#      no skill dir and no known generic term (WARN -- catches references to
#      external/plugin skills that break portability).
#   7. Sibling refs in descriptions: a `description:` naming another skill via a
#      `/name` that resolves to a sibling skill dir (WARN -- boundary-audit
#      candidate; the router/fragment exceptions are legitimate, so never FAIL.
#      See docs/BOUNDARY-AUDIT.md, this skill's own bundled copy).
#   8. Typed-edge blocks: the delimited `<!-- edges:<name> -->` block in a SKILL.md
#      (self-init model 2026-07-18-skill-self-init-model.md) is well-formed --
#      matched open/close delimiters naming the skill itself, edge kind in
#      produces|consumes|handoff, and a type token that is a plain string, never a
#      sibling `/name` or bare skill-dir name (FAIL -- edges name types, not
#      siblings; model 1 corollary 3). A type declared by exactly one skill across
#      the suite is a WARN (likely an orphan/typo -- or a consumer not yet wired;
#      expected to fire during rollout until Phase 5, model 2.2 "facts not verdicts").
#   9. Sibling verb-roster enumeration (BL-1): a skill's BODY (not its description --
#      check 7 covers that) naming 3+ distinct verbs of the SAME sibling skill via
#      backticked `/sibling verb` tokens looks like an enumerated roster of that
#      sibling's verb set (WARN -- boundary-audit candidate; the exact rot pattern
#      that once bit `foreman`, whose body listed `architect`'s verbs stale long
#      after `architect` gained new ones). Self-references are excluded -- a skill
#      enumerating its OWN verbs is normal. Known limitation: only the
#      backticked-per-verb-token shape is caught; a prose-listed roster ("its verbs
#      are init, brainstorm, plan...") needs the manual boundary-audit scan, the
#      same class of gap check 7 already documents for description-level refs.
#  10. Section citations: a backticked `.md` path immediately followed (same
#      sentence) by a `§ Heading` reference must name a file with a matching
#      `#`-heading (FAIL -- evidence: citing file, cited file, the heading text
#      that didn't resolve). Path resolution reuses check 2's two-stage docs/ rule
#      (bundle, then repo root) -- an unresolved path is check 2's FAIL or WARN, not this
#      one's. Heading match is lenient: backticks and trailing punctuation
#      stripped, case-insensitive, and a real heading need only CONTAIN the cited
#      text (citations legitimately abbreviate: `§ Cheap health, deep reconcile`
#      cites the real `## Cheap \`health\`, deep \`reconcile\``). A bare
#      `§ Heading` with no backticked path nearby is out of scope -- it cites the
#      current file or is prose, not a cross-file pointer.
#
# Core-member exemption (clankshop rollout, Task 4.1): a pack manifest
# (PACK.md, spec format 1) may carry a `core:` frontmatter line -- a grimoire
# author extension key (spec §2: unknown keys, tool-ignored) naming the members
# written for the pack's authored composition rather than standalone use. Core
# members are exempt from the independence checks (7: sibling-in-description,
# 8: typed-edge blocks, 9: sibling verb-roster); helpers and skill-builder
# itself keep the full discipline. Discovery mirrors install.sh's resolve walk.
set -euo pipefail

root="${1:-$(pwd)}"
skills_dir="$root/skills"
claude_skills="$HOME/.claude/skills"
fails=0 warns=0

fail() { echo "FAIL: $*"; fails=$((fails + 1)); }
warn() { echo "WARN: $*"; warns=$((warns + 1)); }

[ -d "$skills_dir" ] || { echo "FAIL: no skills/ under $root"; exit 1; }

# ---- pack core members (the core-member exemption; header comment) -----------
core_members=" "
for pm in "$root/PACK.md" "$root"/skills/*/PACK.md; do
  [ -f "$pm" ] || continue
  pfm="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$pm")"
  pcore="$(printf '%s\n' "$pfm" | sed -n 's/^core:[[:space:]]*//p' | head -1 | tr ',' ' ')"
  [ -n "$pcore" ] && core_members="$core_members$pcore "
done
is_core() { case "$core_members" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ---- 1. frontmatter ----------------------------------------------------------
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  f="$sk/SKILL.md"
  [ -f "$f" ] || { fail "$name: no SKILL.md"; continue; }
  # frontmatter block = lines between the first two `---` lines
  fm="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f")"
  desc_line="$(printf '%s\n' "$fm" | grep -c '^description:' || true)"
  if [ "$desc_line" -eq 0 ]; then fail "$name: frontmatter has no description:"; continue; fi
  # full value: description may wrap? (we author single-line) -- take the line.
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  len=${#desc}
  [ "$len" -le 1024 ] || fail "$name: description ${len} chars (>1024, Codex rejects)"
  [ "$len" -le 750 ]  || { [ "$len" -le 1024 ] && warn "$name: description ${len} chars (>750 aim)"; }
  case "$desc" in
    \"*\") ;;                       # quoted -- fine
    *": "*) fail "$name: description contains ': ' but is unquoted (strict-YAML nested-mapping trap)" ;;
  esac
done

# ---- shared: bundle-ref resolution (checks 2 & 10) ---------------------------
# One prefix alternation and one resolver, used by both checks so "what counts as
# a bundled-resource path" and "how does docs/ resolve" can't drift apart.
bundle_prefixes='scripts|templates|verbs|references|rules|docs|roles|doctrine'
has_root_docs=0
[ -d "$root/docs" ] && has_root_docs=1

# resolve_bundle_ref <skill-dir> <ref>
# <ref> is a path like "verbs/foo.md" or "docs/x.md", relative to a skill bundle
# ($sk, trailing slash). Non-docs/ prefixes resolve bundle-local only; docs/
# resolves two-stage: bundle-local first, then (if absent) the repo root's docs/
# tree (check 2's header entry). On success prints the resolved path and returns
# 0; on failure prints nothing and returns 1.
resolve_bundle_ref() {
  local sk="$1" ref="$2"
  if [ -f "$sk$ref" ]; then printf '%s' "$sk$ref"; return 0; fi
  case "$ref" in
    docs/*) [ -f "$root/$ref" ] && { printf '%s' "$root/$ref"; return 0; } ;;
  esac
  return 1
}

# ---- 2. intra-skill refs -----------------------------------------------------
# Backticked tokens that look like a bundled-resource path. Single-path shape
# only (no spaces/flags), rooted at a known bundle dir ($bundle_prefixes). docs/
# resolves two-stage via resolve_bundle_ref, above -- a verb may point at either
# its skill's own bundled docs/ or the library's shared docs/ tree. A ref that
# still misses is a FAIL, unless it's a docs/ ref AND this root has no docs/
# tree at all -- then it's a WARN (a portable-skill copy into a foreign library
# can't check a grimoire-only provenance citation; header entry above).
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  find "$sk" -name '*.md' -print0 | while IFS= read -r -d '' md; do
    grep -oE '`[^`]+`' "$md" 2>/dev/null | tr -d '`' \
      | grep -E "^($bundle_prefixes)/[A-Za-z0-9._/-]+\.(md|sh)\$" \
      | sort -u \
      | while IFS= read -r ref; do
          resolve_bundle_ref "$sk" "$ref" >/dev/null || echo "MISS $name ${md#"$sk"} -> $ref"
        done
  done
done > /tmp/skills-lint-refs.$$ || true
while IFS= read -r line; do
  set -- $line
  ref="$5"
  case "$ref" in
    docs/*)
      if [ "$has_root_docs" -eq 1 ]; then
        fail "$2: $3 references $5 (not in the bundle)"
      else
        warn "$2: $3 references $5 (not in the bundle -- no docs/ tree at $root; can't check a foreign library's provenance citation)"
      fi
      ;;
    *) fail "$2: $3 references $5 (not in the bundle)" ;;
  esac
done < <(awk '$1=="MISS"{print}' /tmp/skills-lint-refs.$$)
rm -f /tmp/skills-lint-refs.$$

# ---- 3. (retired) ------------------------------------------------------------
# The foreman BOOTSTRAP manifest check lost its subject when the pack doctrine
# absorbed BOOTSTRAP.md (clankshop rollout, Task 2.5). Numbering retained so the
# header comment's check list stays stable.

# ---- 4. consumption wiring (advisory: installation state, not repo content) --
# WARN-only: a public clone isn't necessarily wired into any harness. Physical-
# path compare so links that resolve through intermediate symlinks still pass.
if [ -d "$claude_skills" ]; then
  for sk in "$skills_dir"/*/; do
    name="$(basename "$sk")"
    link="$claude_skills/$name"
    if [ ! -L "$link" ]; then
      warn "$name: not wired into ~/.claude/skills on this machine (./install.sh $name)"
    else
      want="$(cd -P "${sk%/}" 2>/dev/null && pwd)"
      got="$(cd -P "$link" 2>/dev/null && pwd || true)"
      [ "$got" = "$want" ] || warn "$name: ~/.claude/skills/$name resolves to ${got:-nothing}, not this clone"
    fi
  done
else
  echo "note: ~/.claude/skills absent -- skipping wiring check"
fi
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  grep -q "\`$name\`" "$root/README.md" 2>/dev/null || warn "$name: not mentioned in README's skill inventory"
done

# ---- 5. script syntax --------------------------------------------------------
find "$root" -path '*/scripts/*.sh' -print0 | while IFS= read -r -d '' sh; do
  bash -n "$sh" 2>/dev/null || echo "SYNTAX $sh"
done > /tmp/skills-lint-sh.$$ || true
while IFS= read -r line; do
  fail "bash -n failed: ${line#SYNTAX }"
done < <(awk '$1=="SYNTAX"{print}' /tmp/skills-lint-sh.$$)
rm -f /tmp/skills-lint-sh.$$
if command -v shellcheck >/dev/null 2>&1; then
  sc_out="$(find "$root" -path '*/scripts/*.sh' -exec shellcheck -S warning {} + 2>/dev/null || true)"
  [ -z "$sc_out" ] || warn "shellcheck findings (informational):
$sc_out"
fi

# ---- 6. cross-skill slash refs ----------------------------------------------
# `/name` tokens in skill prose should name a real skill dir or a known generic.
known_generic="code-review|model|clear|loop"
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  find "$sk" -name '*.md' -print0 | while IFS= read -r -d '' md; do
    grep -oE '`[^`]+`' "$md" 2>/dev/null | tr -d '`' | sed -n 's|^/\([a-z][a-z-]*\).*|\1|p' | sort -u \
      | while IFS= read -r ref; do
          [ -d "$skills_dir/$ref" ] && continue
          printf '%s\n' "$ref" | grep -qE "^($known_generic)$" && continue
          echo "XREF $name $ref"
        done
  done
done | sort -u > /tmp/skills-lint-xref.$$ || true
while IFS= read -r line; do
  set -- $line
  warn "$2: references \`/$3\` which is not a skill in this suite (external dependency?)"
done < <(awk '$1=="XREF"{print}' /tmp/skills-lint-xref.$$)
rm -f /tmp/skills-lint-xref.$$

# ---- 7. sibling refs in descriptions (boundary-audit candidate) --------------
# A `description:` naming another skill via `/name` is a candidate boundary
# violation (co-mingling) -- WARN so the maintainer judges it against this
# skill's own bundled docs/BOUNDARY-AUDIT.md. Self-invocations (`/<own-name>`) are fine; the
# router/fragment exceptions are legitimate, so this never FAILs. Keys on a
# *backticked* `/name` (the convention for an invocation, per check 6) so bare
# separators/paths (`bug/patch/feature`, `.agents/foreman/`) don't false-positive.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  is_core "$name" && continue     # core-member exemption (header comment)
  f="$sk/SKILL.md"
  [ -f "$f" ] || continue
  fm="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f")"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  printf '%s\n' "$desc" | grep -oE '`[^`]+`' | tr -d '`' \
    | sed -n 's|^/\([a-z][a-z-]*\).*|\1|p' | sort -u \
    | while IFS= read -r ref; do
        [ "$ref" = "$name" ] && continue          # self-invocation -- fine
        [ -d "$skills_dir/$ref" ] && echo "SIB $name $ref"
      done
done | sort -u > /tmp/skills-lint-sib.$$ || true
while IFS= read -r line; do
  set -- $line
  warn "$2: description names sibling \`/$3\` -- boundary candidate (self-scope it, or confirm a router/fragment exception per this skill's docs/BOUNDARY-AUDIT.md)"
done < <(awk '$1=="SIB"{print}' /tmp/skills-lint-sib.$$)
rm -f /tmp/skills-lint-sib.$$

# ---- 8. typed-edge blocks (self-init model 1-2) ------------------------------
# Parse the delimited `<!-- edges:<name> -->` block in each SKILL.md. An edge line
# is `- <kind>: <type>[, <type>...] [<emdash> <note>]`; an empty edge is
# `- <kind>: <emdash> (none...)`. We check delimiter well-formedness, the edge
# kind, and the type-not-sibling invariant, and collect (type,skill,kind) triples
# for the orphan WARN. BL-4: kind is recorded (not just type+skill) so a type
# declared by exactly one skill that has BOTH a produces/handoff line AND a
# consumes line for it (a stated intra-skill chain, e.g. handoff's save->resume,
# feature's design->plan->build) is excluded -- only a true single-direction
# single-skill type (no consumer, or no producer, anywhere) still WARNs.
# BSD/macOS-safe: no multi-line `awk -v` (BL-3) -- single-line -v (the skill name)
# only; the em-dash split is bash parameter expansion, not awk.
emdash="—"
edge_types="$(mktemp "${TMPDIR:-/tmp}/skills-lint-edges.XXXXXX")"
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  is_core "$name" && continue     # core-member exemption (header comment)
  f="$sk/SKILL.md"
  [ -f "$f" ] || continue
  # Extract the delimiter names present (open + close). `|| true`: grep exits 1 on
  # no match and `pipefail`+`set -e` would kill the assignment otherwise.
  opens="$(grep -oE '^<!-- edges:[a-z][a-z-]* -->$' "$f" | sed 's/^<!-- edges://; s/ -->$//' || true)"
  closes="$(grep -oE '^<!-- /edges:[a-z][a-z-]* -->$' "$f" | sed 's|^<!-- /edges:||; s/ -->$//' || true)"
  # No block at all is fine -- not every skill has declared edges yet (Phase 5).
  # (An `if` guard, not an `&&`-list -- a false `&&`-list at statement level trips set -e.)
  if [ -z "$opens" ] && [ -z "$closes" ]; then continue; fi
  # Well-formedness: exactly one open + one close, both naming this skill.
  if [ "$(printf '%s\n' "$opens" | grep -c .)" -ne 1 ] || [ "$(printf '%s\n' "$closes" | grep -c .)" -ne 1 ] \
     || [ "$opens" != "$name" ] || [ "$closes" != "$name" ]; then
    fail "$name: malformed \`## Edges\` delimiters (need one \`<!-- edges:$name -->\` + one \`<!-- /edges:$name -->\`; found open='$opens' close='$closes')"
    continue
  fi
  # Body between the delimiters (single-line -v is BSD-safe).
  block="$(awk -v n="$name" '$0=="<!-- edges:"n" -->"{b=1;next} $0=="<!-- /edges:"n" -->"{b=0} b' "$f")"
  while IFS= read -r line; do
    case "$line" in "- "*) ;; *) continue ;; esac      # only edge bullets
    kind="$(printf '%s' "$line" | sed -n 's/^- \([a-z]*\):.*/\1/p')"
    case "$kind" in
      produces|consumes|handoff) ;;
      "") fail "$name: edge line is not \`- <kind>: ...\` (\"$line\")"; continue ;;
      *)  fail "$name: unknown edge kind \`$kind\` (expected produces|consumes|handoff)"; continue ;;
    esac
    value="$(printf '%s' "$line" | sed 's/^- [a-z]*:[[:space:]]*//')"
    types_part="${value%%"$emdash"*}"                  # strip the em-dash note, if any
    IFS=',' read -ra toks <<< "$types_part" || true    # read hits EOF -> nonzero; set -e safe
    for t in ${toks[@]+"${toks[@]}"}; do               # bash-3.2 + set -u safe empty expansion
      t="$(printf '%s' "$t" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -z "$t" ] && continue                          # empty edge (`<kind>: —`)
      case "$t" in
        /*) fail "$name: edge \`$kind: $t\` names a slash-invocation, not a type (edges name types, not siblings -- model 1 corollary 3)"; continue ;;
      esac
      if [ -d "$skills_dir/$t" ]; then
        fail "$name: edge \`$kind: $t\` names sibling skill \`$t\`, not a type (edges name types, not siblings -- model 1 corollary 3)"
        continue
      fi
      printf '%s\t%s\t%s\n' "$t" "$name" "$kind" >> "$edge_types"
    done
  done < <(printf '%s\n' "$block")
done
# Orphan WARN: a type declared by exactly one DISTINCT skill across the suite,
# AND that skill does not itself pair a producer-side kind (produces/handoff)
# with a consumer-side kind (consumes) for it (BL-4 -- an intra-skill chain is
# not an orphan, even though only one skill's name appears).
if [ -s "$edge_types" ]; then
  while IFS=$'\t' read -r t who; do
    warn "edge type \`$t\` is declared by only one skill (\`$who\`) -- orphan/typo, or a consumer not yet wired (expected during rollout)"
  done < <(sort -u "$edge_types" | awk -F'\t' '
    {
      type=$1; skill=$2; kind=$3
      pair = type SUBSEP skill
      if (!(pair in seenpair)) { seenpair[pair]=1; skillcount[type]++ }
      if (kind=="produces" || kind=="handoff") isprod[pair]=1
      if (kind=="consumes") iscons[pair]=1
      if (!(type in ordered)) { order[++n]=type; ordered[type]=1 }
      lastskill[type]=skill
    }
    END {
      for (i=1;i<=n;i++) {
        type=order[i]
        if (skillcount[type]==1) {
          skill=lastskill[type]
          pair = type SUBSEP skill
          if ((pair in isprod) && (pair in iscons)) continue
          print type"\t"skill
        }
      }
    }' | sort)
fi
rm -f "$edge_types"

# ---- 9. sibling verb-roster enumeration in a body (BL-1) ---------------------
# Body-only (frontmatter excluded -- check 7 covers descriptions). Extract every
# backticked `/sibling verb` two-word token, drop self-references and anything
# not naming a real sibling dir, tagged with a **paragraph index** (bumped on
# every blank line) so a wrapped multi-line roster still counts as one unit but
# two unrelated pointers elsewhere in the same file never merge -- a real false
# positive this check hit on its first run against this very tree (workstream's
# `/backlog bug`, `/backlog task`, and an unrelated `/backlog debrief` ~80 lines
# away are three separate legitimate pointers, not a roster). WARN per (skill,
# sibling) pair with 3+ DISTINCT verbs in the SAME paragraph.
roster="$(mktemp "${TMPDIR:-/tmp}/skills-lint-roster.XXXXXX")"
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  is_core "$name" && continue     # core-member exemption (header comment)
  f="$sk/SKILL.md"
  [ -f "$f" ] || continue
  awk -v self="$name" '
    /^---$/ { c++; next }
    c<2 { next }
    /^[[:space:]]*$/ { p++; next }
    {
      line=$0
      while (match(line, /`\/[a-z][a-z-]* [a-zA-Z][a-zA-Z-]*`/)) {
        tok=substr(line, RSTART, RLENGTH)
        line=substr(line, RSTART+RLENGTH)
        gsub(/`/,"",tok)
        split(tok, parts, " ")
        sib=substr(parts[1],2)
        verb=parts[2]
        if (sib != self) print sib"\t"verb"\t"p
      }
    }
  ' "$f" | while IFS=$'\t' read -r sib verb p; do
      [ -d "$skills_dir/$sib" ] || continue    # not a real sibling dir
      printf '%s\t%s\t%s\t%s\n' "$name" "$sib" "$verb" "$p"
    done
done > "$roster" || true
if [ -s "$roster" ]; then
  while IFS=$'\t' read -r name sib n; do
    warn "$name: names $n distinct verbs of sibling \`/$sib\` in one paragraph -- looks like an enumerated roster (boundary-audit candidate, BL-1; a roster rots when \`$sib\` gains/loses verbs -- point at it, don't enumerate it. See this skill's docs/BOUNDARY-AUDIT.md)"
  done < <(sort -u "$roster" | awk -F'\t' '
    {
      pk = $1 SUBSEP $2 SUBSEP $4
      vk = pk SUBSEP $3
      if (!(vk in seenverb)) { seenverb[vk]=1; pcount[pk]++ }
      nk = $1 SUBSEP $2
      if (pcount[pk] > best[nk]) best[nk] = pcount[pk]
    }
    END {
      for (nk in best) {
        if (best[nk] < 3) continue
        split(nk, arr, SUBSEP)
        print arr[1]"\t"arr[2]"\t"best[nk]
      }
    }
  ' | sort)
fi
rm -f "$roster"

# ---- 10. section citations (§) resolve to a real heading ---------------------
# A backticked `.md` path immediately followed by a `§ <Heading>` reference, in
# the same sentence, must name a file with a matching `#`-heading. Files are
# joined into one line first (ORS=" ") because this prose wraps near 100 cols --
# the dominant real shape splits the path and its `§` across a line break. Blank
# lines are replaced with a paragraph-marker token (not just collapsed to a
# space like every other line) before flattening, so paragraph boundaries
# survive the join.
#
# Pairing is paragraph-scoped: hitting the marker resets the pending path and
# the distance counter, so a path in one paragraph can never pair with a `§` in
# a later one -- a stale path otherwise persists past a blank line and can pull
# in an unrelated `§` two paragraphs away, FAILing by naming the wrong file.
# Within a paragraph, pairing still uses a bounded character window -- shrunk to
# 100 (was 250; the widest real same-sentence gap measured in this corpus is 72
# chars, so this keeps a safety margin while more than halving how far
# unrelated text could still pair). Heading-text capture also stops at the
# paragraph marker itself (excluded from the capture class), so a citation with
# no closing punctuation before a blank line no longer swallows the next
# paragraph's prose into its heading needle -- the other half of the same
# false-positive class. Heading-text extraction otherwise stops at the first
# `.` `;` `)` `:` `,` or the connector words " for "/" and " -- real headings in
# this corpus never legitimately continue past one of these, so stopping early
# only under-captures (safe: a true prefix is still CONTAINED by the real
# heading). Precision over reach: an exotic citation shape going unpaired is
# fine; a FAIL naming the wrong heading or the wrong file is not.
#
# Path resolution reuses resolve_bundle_ref (shared with check 2, above); an
# unresolved path is check 2's problem (a FAIL, or a WARN in a foreign library
# without a docs/ tree) -- this check only fires once a target file is
# confirmed to exist.
section="§"
para_marker="@@PARA@@"
window=100
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  find "$sk" -name '*.md' -print0 | while IFS= read -r -d '' md; do
    rel="${md#"$sk"}"
    awk -v para="$para_marker" 'BEGIN{ORS=" "} /^[[:space:]]*$/ { print para; next } { print }' "$md" \
      | awk -v sec="$section" -v name="$name" -v rel="$rel" -v para="$para_marker" -v win="$window" -v prefixes="$bundle_prefixes" '
      BEGIN {
        pathre = "`(" prefixes ")/[A-Za-z0-9._/-]+\\.md`"
        headre = sec " [A-Z][^.;):,@]*"
        full = pathre "|" headre "|" para
      }
      {
        text = $0
        curpath = ""
        dist = 999999
        while (match(text, full)) {
          dist += RSTART - 1
          tok = substr(text, RSTART, RLENGTH)
          if (tok == para) {
            curpath = ""
            dist = 999999
          } else if (substr(tok, 1, 1) == "`") {
            curpath = tok
            gsub(/`/, "", curpath)
            dist = 0
          } else {
            if (curpath != "" && dist <= win) {
              head = substr(tok, length(sec) + 2)
              fi = index(head, " for ")
              ai = index(head, " and ")
              if (fi > 0 && (ai == 0 || fi < ai)) head = substr(head, 1, fi - 1)
              else if (ai > 0) head = substr(head, 1, ai - 1)
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", head)
              if (head != "") print name "\t" rel "\t" curpath "\t" head
            }
            dist += RLENGTH
          }
          text = substr(text, RSTART + RLENGTH)
        }
      }
    '
  done
done > /tmp/skills-lint-sec.$$ || true
while IFS=$'\t' read -r sname rel ref headtext; do
  sk="$skills_dir/$sname/"
  target="$(resolve_bundle_ref "$sk" "$ref" || true)"
  [ -n "$target" ] || continue                # check 2 already flags an unresolved path
  case "$target" in *.md) ;; *) continue ;; esac
  needle="$(printf '%s' "$headtext" | tr -d '`' | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:].,;:)]+$//')"
  [ -n "$needle" ] || continue
  found=0
  while IFS= read -r htext; do
    hnorm="$(printf '%s' "$htext" | tr -d '`' | tr '[:upper:]' '[:lower:]')"
    case "$hnorm" in *"$needle"*) found=1; break ;; esac
  done < <(grep -E '^#+[[:space:]]' "$target" | sed -E 's/^#+[[:space:]]+//')
  [ "$found" -eq 1 ] || fail "$sname: $rel cites \`$ref\` § $headtext -- no heading in that file contains it"
done < /tmp/skills-lint-sec.$$
rm -f /tmp/skills-lint-sec.$$

# ---- summary -----------------------------------------------------------------
echo "fails=$fails warns=$warns"
[ "$fails" -eq 0 ] || exit 1
