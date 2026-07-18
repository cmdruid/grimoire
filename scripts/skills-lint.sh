#!/usr/bin/env bash
# skills-lint.sh [<agents-root>]   (default: the repo this script lives in)
#
# The lint gate for the skills home itself -- the mechanical backstop for the
# rot-prone parts of ~/.agents (the same class of check the skills deploy onto
# other repos, applied to the toolmaker). Run it BEFORE committing here
# (README -> Editing/adding a skill).
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
set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
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

# ---- summary -----------------------------------------------------------------
echo "fails=$fails warns=$warns"
[ "$fails" -eq 0 ] || exit 1
