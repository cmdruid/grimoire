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
#   2. Intra-skill refs: backticked scripts/|templates/|verbs/|references/|rules/
#      paths named in a skill's .md files resolve inside that skill dir (FAIL).
#      (docs/ is excluded -- verbs use it host-relative; check 3 covers bundled docs.)
#   3. foreman BOOTSTRAP <-> bundle: every `name.md` the foreman BOOTSTRAP's docs/ or
#      templates/ manifest lines name exists in the bundle (FAIL).
#   4. Consumption wiring: every skills/<name> has a ~/.claude/skills/<name>
#      symlink pointing at it (FAIL) and a README mention (WARN).
#   5. bash -n every scripts/*.sh (FAIL); shellcheck if installed (WARN).
#   6. Cross-skill name refs: a backticked `/name` slash-invocation that matches
#      no skill dir and no known generic term (WARN -- catches references to
#      external/plugin skills that break portability).
#   7. Sibling refs in descriptions: a `description:` naming another skill via a
#      `/name` that resolves to a sibling skill dir (WARN -- boundary-audit
#      candidate; the router/fragment exceptions are legitimate, so never FAIL.
#      See docs/boundary-audit.md).
#   8. Typed-edge blocks: the delimited `<!-- edges:<name> -->` block in a SKILL.md
#      (self-init model 2026-07-18-skill-self-init-model.md) is well-formed --
#      matched open/close delimiters naming the skill itself, edge kind in
#      produces|consumes|handoff, and a type token that is a plain string, never a
#      sibling `/name` or bare skill-dir name (FAIL -- edges name types, not
#      siblings; model 1 corollary 3). A type declared by exactly one skill across
#      the suite is a WARN (likely an orphan/typo -- or a consumer not yet wired;
#      expected to fire during rollout until Phase 5, model 2.2 "facts not verdicts").
set -euo pipefail

root="${1:-$(pwd)}"
skills_dir="$root/skills"
claude_skills="$HOME/.claude/skills"
fails=0 warns=0

fail() { echo "FAIL: $*"; fails=$((fails + 1)); }
warn() { echo "WARN: $*"; warns=$((warns + 1)); }

[ -d "$skills_dir" ] || { echo "FAIL: no skills/ under $root"; exit 1; }

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

# ---- 2. intra-skill refs -----------------------------------------------------
# Backticked tokens that look like a bundled-resource path. Single-path shape
# only (no spaces/flags), rooted at a known bundle dir.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  find "$sk" -name '*.md' -print0 | while IFS= read -r -d '' md; do
    grep -oE '`[^`]+`' "$md" 2>/dev/null | tr -d '`' \
      | grep -E '^(scripts|templates|verbs|references|rules)/[A-Za-z0-9._/-]+\.(md|sh)$' \
      | sort -u \
      | while IFS= read -r ref; do
          [ -e "$sk$ref" ] || echo "MISS $name ${md#"$sk"} -> $ref"
        done
  done
done > /tmp/skills-lint-refs.$$ || true
while IFS= read -r line; do
  set -- $line
  fail "$2: $3 references $5 (not in the bundle)"
done < <(awk '$1=="MISS"{print}' /tmp/skills-lint-refs.$$)
rm -f /tmp/skills-lint-refs.$$

# ---- 3. foreman BOOTSTRAP manifest vs bundle ---------------------------------
bs="$skills_dir/foreman/BOOTSTRAP.md"
if [ -f "$bs" ]; then
  # docs/ manifest rows look like: "      NAME.md    -- ..."; generic <content doc>
  # rows and host-authored slots are skipped (they ship no bundled file).
  while IFS= read -r doc; do
    case "$doc" in ARCHITECTURE.md|GOTCHAS.md|DIAGNOSTICS.md|PERFORMANCE.md|SYNC.md) continue ;; esac
    [ -f "$skills_dir/foreman/docs/$doc" ] || fail "foreman: BOOTSTRAP manifest names docs/$doc but the bundle lacks it"
  done < <(sed -n 's/^      \([A-Z]*\.md\).*/\1/p' "$bs")
fi

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
# violation (co-mingling) -- WARN so the maintainer judges it against
# docs/boundary-audit.md. Self-invocations (`/<own-name>`) are fine; the
# router/fragment exceptions are legitimate, so this never FAILs. Keys on a
# *backticked* `/name` (the convention for an invocation, per check 6) so bare
# separators/paths (`bug/patch/feature`, `.agents/foreman/`) don't false-positive.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
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
  warn "$2: description names sibling \`/$3\` -- boundary candidate (self-scope it, or confirm a router/fragment exception per docs/boundary-audit.md)"
done < <(awk '$1=="SIB"{print}' /tmp/skills-lint-sib.$$)
rm -f /tmp/skills-lint-sib.$$

# ---- 8. typed-edge blocks (self-init model 1-2) ------------------------------
# Parse the delimited `<!-- edges:<name> -->` block in each SKILL.md. An edge line
# is `- <kind>: <type>[, <type>...] [<emdash> <note>]`; an empty edge is
# `- <kind>: <emdash> (none...)`. We check delimiter well-formedness, the edge
# kind, and the type-not-sibling invariant, and collect types for the orphan WARN.
# BSD/macOS-safe: no multi-line `awk -v` (BL-3) -- single-line -v (the skill name)
# only; the em-dash split is bash parameter expansion, not awk.
emdash="—"
edge_types="$(mktemp "${TMPDIR:-/tmp}/skills-lint-edges.XXXXXX")"
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
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
      printf '%s\t%s\n' "$t" "$name" >> "$edge_types"
    done
  done < <(printf '%s\n' "$block")
done
# Orphan WARN: a type declared by exactly one skill across the suite.
if [ -s "$edge_types" ]; then
  while IFS=$'\t' read -r t who; do
    warn "edge type \`$t\` is declared by only one skill (\`$who\`) -- orphan/typo, or a consumer not yet wired (expected during rollout)"
  done < <(sort -u "$edge_types" | awk -F'\t' '{c[$1]++; who[$1]=$2} END{for(t in c) if(c[t]==1) print t"\t"who[t]}' | sort)
fi
rm -f "$edge_types"

# ---- summary -----------------------------------------------------------------
echo "fails=$fails warns=$warns"
[ "$fails" -eq 0 ] || exit 1
