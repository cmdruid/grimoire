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
#      skill dir (FAIL). docs/ refs are gated ONLY for a skill that bundles its
#      own docs/ dir -- such a skill's docs/ refs resolve two-stage:
#      <skill-dir>/docs/<path>, then (if absent) <repo-root>/docs/<path> (a
#      provenance citation, e.g. docs/design/2026-...md); FAIL when neither
#      resolves. A skill with no bundled docs/ dir cannot be citing a bundle
#      doc, so its docs/ refs are host- or repo-relative (a verb naming a
#      document it creates/reads in a CONSUMING project, e.g. docs/ROADMAP.md)
#      and are entirely out of this check's scope -- not even attempted. This
#      also carries the portability property: a portable skill with no bundled
#      docs/ is simply never gated on docs/, in any library it's copied into.
#   3. (retired -- the foreman BOOTSTRAP manifest lost its subject; numbering held.)
#   4. README inventory: every skills/<name> is mentioned in README.md (WARN).
#      (The ~/.claude/skills wiring probe that shared this slot was deleted --
#      installation state, not repo content; it made the warn count depend on
#      which checkout you linted from.)
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
#      siblings; model 1 corollary 3). A missing block is a WARN (BL-17 --
#      doctrine requires a block of every portable skill; an all-empty block
#      is a stated disposition). A type declared by exactly one skill across
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
#      (bundle, then repo root) for any skill (unlike check 2's per-skill gating) --
#      an unresolved path is check 2's problem, not this one's. Heading match
#      is lenient: backticks and trailing punctuation
#      stripped, case-insensitive, and a real heading need only CONTAIN the cited
#      text (citations legitimately abbreviate: `§ Cheap health, deep reconcile`
#      cites the real `## Cheap \`health\`, deep \`reconcile\``). A bare
#      `§ Heading` with no backticked path nearby is out of scope -- it cites the
#      current file or is prose, not a cross-file pointer.
#  11. Orphan verb files: the inverse of check 2. Check 2 gates a `verbs/...`
#      ref against a missing file (a phantom route); this gates a real
#      `verbs/**/*.md` file on disk against a missing ref -- what an abandoned
#      rename leaves behind, invisible. Every `verbs/**/*.md` in a skill must be
#      cited by some `.md` in that SAME skill, either directly (a backticked
#      `verbs/x/y.md`) or via a backticked directory citation that is a prefix
#      of its path (`verbs/design/` covers `verbs/design/plan.md`) (FAIL --
#      names the skill and the orphan file).
#  12. Journal-floor phrase (FAIL). A non-exempt skill's .md matches the
#      case-sensitive phrases `Requires a stood-up records layer` or
#      `stop and point at `/journal setup``. Evidence: skill, file, line.
#      Does not match a prohibition ("journal standup is never a
#      precondition"). Journal, skill-builder, and pack faces are exempt.
#  13. Project-templates heading (FAIL). A skill that has templates/*.md
#      must have a `## Project templates` heading in SKILL.md. A skill
#      with no templates/ dir is out of scope. Pack faces are exempt.
#  14. Doctrine home not resolved (FAIL). A skill declaring a `doctrine` typed
#      edge must carry a sanctioned doctrine-home resolution literal. Fenced
#      and indented blocks are stripped first (a quoted example must not
#      satisfy it) and whitespace is normalized across newlines (the phrase
#      members wrap in real skills; a line-based match would fail conforming
#      ones). Edge-gated, so check 15 is the unconditional net beside it.
#      skill-builder and pack faces are exempt. NARROWED: the retired
#      `agent-doctrine` family is no longer accepted -- the consumers are
#      flipped, so accepting it would let a regression back in silently.
#  15. Off-home doctrine literal. Any non-exempt skill's .md naming a
#      `.handbook/{test,build,design,review}/` path -- doctrine that should be
#      reached through the resolved home (FAIL). Unconditional: this is what
#      catches a skill that hardcodes and never declares an edge. No per-skill
#      exemption table; `docs/audit/` is deliberately not matched (see the
#      block comment). `.records/doctrine/` is also matched (FAIL): it stopped
#      being any home's default when doctrine moved under `<agent-workspace>`,
#      which is what made it decidable.
#  16. Retired doctrine variable + workspace declaration guards. Three arms,
#      three severities, staged PER ARM (see the block comment): the retired
#      `agent-doctrine` literal anywhere under a non-exempt skill (FAIL -- the
#      carriers are flipped, so this is the standing retirement guard); a
#      front-door `agent-workspace: .`
#      (FAIL always); and a front-door `agent-workspace:` restating the current
#      default (WARN always -- advisory by design). Unconditional in SCOPE, not
#      severity: unlike 14 it is not edge-gated and reads .sh as well as .md,
#      comments included. Authoring-time half only — `seed.sh` is the runtime
#      half that sees a consuming project's resolved `--workspace` (BL-30).
#  17. Bare `records.sh new` mint (FAIL). Two arms: (a) a backticked
#      invocation carrying `records.sh new` and `--title` but no
#      `--template`; (b) `records.sh new` immediately followed by a
#      flag (`new --<anything>` is never valid — the doctype is the
#      first positional). `--template` is required, so a bare call
#      hard-errors at runtime and skips the lock-in copy. Arm (b)
#      catches the BL-32 shape that arm (a) cannot see (no `--title`).
#      Whitespace-normalized (real invocations wrap mid-span) and
#      fence-stripped. Prose naming the tool without `--title` and
#      without a following flag is out of scope. skill-builder and
#      pack faces are exempt.
#
# Pack-face exemption (clankshop v2): the one skill dir that carries a PACK.md
# is the pack's FACE -- it composes the pack, so naming its members is its job,
# not a boundary leak. Faces are exempt from the independence checks
# (7: sibling-in-description, 8: typed-edge blocks, 9: sibling verb-roster);
# every non-face member -- helper, utility, and skill-builder itself -- keeps
# the full discipline. (Replaces v1's `core:`-key exemption: v2 packs declare
# dependency as manifest data, and members are standalone by design.)
set -euo pipefail

root="${1:-$(pwd)}"
skills_dir="$root/skills"
claude_skills="$HOME/.claude/skills"
fails=0 warns=0

fail() { echo "FAIL: $*"; fails=$((fails + 1)); }
warn() { echo "WARN: $*"; warns=$((warns + 1)); }

[ -d "$skills_dir" ] || { echo "FAIL: no skills/ under $root"; exit 1; }

# ---- pack faces (the pack-face exemption; header comment) --------------------
pack_faces=" "
for pm in "$root"/skills/*/PACK.md; do
  [ -f "$pm" ] || continue
  pack_faces="$pack_faces$(basename "$(dirname "$pm")") "
done
is_pack_face() { case "$pack_faces" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

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
# refs are gated only for a skill that bundles its own docs/ dir -- resolved
# two-stage via resolve_bundle_ref, above (bundle-local, then repo-root
# provenance citations). A skill with no bundled docs/ dir cannot be referring
# to a bundle doc, so its docs/ refs are skipped entirely here -- not resolved,
# not FAILed (host- or repo-relative, e.g. a verb naming a document it
# creates/reads in a consuming project; header entry above).
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  has_skill_docs=0
  [ -d "${sk}docs" ] && has_skill_docs=1
  find "$sk" -name '*.md' -print0 | while IFS= read -r -d '' md; do
    grep -oE '`[^`]+`' "$md" 2>/dev/null | tr -d '`' \
      | grep -E "^($bundle_prefixes)/[A-Za-z0-9._/-]+\.(md|sh)\$" \
      | sort -u \
      | while IFS= read -r ref; do
          case "$ref" in
            docs/*) [ "$has_skill_docs" -eq 1 ] || continue ;;
          esac
          resolve_bundle_ref "$sk" "$ref" >/dev/null || echo "MISS $name ${md#"$sk"} -> $ref"
        done
  done
done > /tmp/skills-lint-refs.$$ || true
while IFS= read -r line; do
  set -- $line
  fail "$2: $3 references $5 (not in the bundle)"
done < <(awk '$1=="MISS"{print}' /tmp/skills-lint-refs.$$)
rm -f /tmp/skills-lint-refs.$$

# ---- 3. (retired) ------------------------------------------------------------
# The foreman BOOTSTRAP manifest check lost its subject when the pack doctrine
# absorbed BOOTSTRAP.md (clankshop rollout, Task 2.5). Numbering retained so the
# header comment's check list stays stable.

# ---- 4. README inventory -----------------------------------------------------
# The wiring arm that used to live here (does ~/.claude/skills/<name> symlink
# back to this clone?) was DELETED: it tested this machine's installation state,
# not repo content, so its result depended on which checkout you linted from.
# The symlinks point at the root clone, so linting a WORKTREE made every skill
# warn "resolves to <root>/skills/<name>, not this clone" -- measured: warns=23
# from a worktree vs warns=8 from the root, a 15-warning delta with an identical
# tree. That forced every gate instruction to say "gate on fails=0; the warn bar
# is checkout-specific and will mislead you." A linter whose output depends on
# where you run it teaches people to ignore its output. `./install.sh` manages
# wiring; that is not a lint. Post-deletion both checkouts report warns=7.
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
  is_pack_face "$name" && continue  # pack-face exemption (header comment)
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
  is_pack_face "$name" && continue  # pack-face exemption (header comment)
  f="$sk/SKILL.md"
  [ -f "$f" ] || continue
  # Extract the delimiter names present (open + close). `|| true`: grep exits 1 on
  # no match and `pipefail`+`set -e` would kill the assignment otherwise.
  opens="$(grep -oE '^<!-- edges:[a-z][a-z-]* -->$' "$f" | sed 's/^<!-- edges://; s/ -->$//' || true)"
  closes="$(grep -oE '^<!-- /edges:[a-z][a-z-]* -->$' "$f" | sed 's|^<!-- /edges:||; s/ -->$//' || true)"
  # Missing block: WARN (BL-17). Doctrine requires a block of every portable
  # skill; an all-empty block is the stated "none" disposition. Pack faces
  # are already skipped above. (An `if` guard, not an `&&`-list -- a false
  # `&&`-list at statement level trips set -e.)
  if [ -z "$opens" ] && [ -z "$closes" ]; then
    warn "$name: SKILL.md has no typed-edge block (required of every portable skill; an all-empty block is a stated disposition)"
    continue
  fi
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
# `/backlog task` and an unrelated `/backlog debrief` ~80 lines
# away are three separate legitimate pointers, not a roster). WARN per (skill,
# sibling) pair with 3+ DISTINCT verbs in the SAME paragraph.
roster="$(mktemp "${TMPDIR:-/tmp}/skills-lint-roster.XXXXXX")"
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  is_pack_face "$name" && continue  # pack-face exemption (header comment)
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
# Path resolution reuses resolve_bundle_ref (shared with check 2, above); check 10
# resolves paths unconditionally for any skill (not gated on bundled docs/), so it
# fires on genuinely dangling citations regardless. An unresolved path is check 2's
# problem; this check only fires once a target file is confirmed to exist.
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

# ---- 11. orphan verb files ----------------------------------------------------
# The inverse of check 2: check 2 goes ref -> file (a phantom route FAILs when
# the file is missing); this goes file -> ref (an orphan FAILs when no citation
# names it). resolve_bundle_ref isn't the right tool here -- it resolves a
# single ref to a file, not a file to whichever citation(s) might cover it --
# but the extraction reuses check 2's same verbs/ path shape (one of
# $bundle_prefixes), just matched against files on disk instead of against a
# ref pulled from prose. A file is covered if some backticked token in the
# skill's OWN .md files either names it directly (`verbs/x/y.md`) or names an
# enclosing directory as a prefix of its path (`verbs/x/`).
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  vdir="${sk}verbs"
  [ -d "$vdir" ] || continue
  cited="$(find "$sk" -name '*.md' -print0 | xargs -0 grep -ohE '`[^`]+`' 2>/dev/null \
    | tr -d '`' | grep -E '^verbs/[A-Za-z0-9._/-]+/?$' | sort -u || true)"
  while IFS= read -r -d '' vf; do
    rel="${vf#"$sk"}"
    covered=0
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      if [ "$ref" = "$rel" ]; then covered=1; break; fi
      case "$ref" in
        */) case "$rel" in "$ref"*) covered=1; break ;; esac ;;
      esac
    done <<< "$cited"
    [ "$covered" -eq 1 ] || fail "$name: $rel is not cited by any .md in this skill (orphan verb file)"
  done < <(find "$vdir" -name '*.md' -print0)
done

# ---- 12. journal-floor phrase (FAIL) -----------------------------------------
# Case-sensitive exact phrases. Exemptions: journal, skill-builder, pack faces.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  case "$name" in journal|skill-builder) continue ;; esac
  is_pack_face "$name" && continue
  while IFS= read -r -d '' f; do
    rel="${f#"$sk"}"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      fail "$name: $rel:$line: journal-floor phrase"
    done < <(grep -nF -e 'Requires a stood-up records layer' \
                      -e 'stop and point at `/journal setup`' "$f" || true)
  done < <(find "$sk" -name '*.md' -print0)
done

# ---- 13. project-templates heading (FAIL) ------------------------------------
# A skill that ships templates/*.md must declare ## Project templates.
# Pack faces exempt (same as the independence checks).
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  is_pack_face "$name" && continue
  has_tpl=0
  for t in "$sk"/templates/*.md; do
    [ -f "$t" ] || continue
    has_tpl=1
    break
  done
  [ "$has_tpl" -eq 1 ] || continue
  if ! grep -q '^## Project templates' "$sk/SKILL.md" 2>/dev/null; then
    fail "$name: templates/*.md present but SKILL.md has no ## Project templates heading"
  fi
done

# ---- 14. doctrine home not resolved (FAIL) -----------------------------------
# A skill declaring a `doctrine` typed edge must carry a sanctioned resolution
# literal (front-door-variables doctrine -> "Use a sanctioned resolution
# literal"). Three members; the angle-bracket form is preferred because it is a
# single token and cannot straddle a line wrap.
#
# Two deliberate properties, both learned the hard way:
#   * NORMALIZE whitespace across newlines before matching. These bodies wrap
#     near 95 columns and the phrase members demonstrably break across lines in
#     the live tree, so a line-based grep would FAIL conforming skills purely on
#     where their text happened to wrap.
#   * STRIP fenced and indented blocks first, so a skill cannot satisfy the
#     check by merely quoting the literal inside an example.
#
# Scope: the doctrine home only. `doctrine` is the one coarse home-typed edge,
# so it is the only home whose touchers can be identified mechanically; records
# and templates conformance is already carried by the records-writer checks and,
# for the semantic half, by skill review. Exemptions: skill-builder (authors this
# doctrine), pack faces.
strip_code() { # strip fenced and indented blocks, then flatten whitespace
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence                    { next }
    /^(    |\t)/             { next }
    { print }
  ' "$1" | tr '\n' ' ' | tr -s ' '
}
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  case "$name" in skill-builder) continue ;; esac
  is_pack_face "$name" && continue
  [ -f "$sk/SKILL.md" ] || continue
  edges="$(sed -n '/<!-- edges:/,/edges:.* -->/p' "$sk/SKILL.md")"
  case "$edges" in
    *doctrine*) ;;
    *) continue ;;
  esac
  found=0
  # NARROWED: the retired `agent-doctrine` family was accepted transitionally
  # while the consumers were flipped, and is not accepted any more. Check 16's
  # absence arm proves no carrier still uses it; leaving the family here would
  # let a skill satisfy this check with the literal that check 16 bans.
  while IFS= read -r -d '' f; do
    if strip_code "$f" | grep -qF -e '<agent-workspace>' \
                                 -e 'the agent-workspace home' \
                                 -e 'declared `agent-workspace:`'; then
      found=1
      break
    fi
  done < <(find "$sk" -name '*.md' -print0)
  [ "$found" -eq 1 ] || \
    fail "$name: declares a doctrine edge but carries no sanctioned doctrine-home resolution literal"
done

# ---- 15. off-home doctrine literal (FAIL) ------------------------------------
# Unconditional by design: check 14 is edge-gated, so a skill that hardcodes a
# doctrine path and simply never declares the edge would be invisible to it.
# This is the net that catches that, in check 12's shape (FAIL-on-presence of
# fixed literals, name-based exemptions).
#
# There is NO exemption table. One was built as a burn-down while the consumers
# were flipped, and it emptied -- so it is gone rather than left as dead code.
# Pack faces are exempt (clankshop legitimately owns the handbook), as is
# skill-builder (this doctrine documents the literals it bans elsewhere); that is
# the same name-based exemption check 12 uses, and it is the whole of it.
#
# `docs/audit/` is deliberately NOT a matched literal. It is auditor-specific --
# no other skill would write it -- so matching it caught nothing generalizable
# while forcing an exemption broad enough to blanket that skill's real
# violations. Auditor's legacy-home detection is sanctioned; the fix was to stop
# calling it a violation, not to excuse it.
#
# STILL NOT attempted: a check on a home's canonical DEFAULT path. Skill prose is
# required to name default paths literally, so a hardcoded default is textually
# identical to a documented one. Only OFF-home literals are decidable. For the
# same reason there is no check on "prose that directs creating .handbook/": the
# only occurrences in the corpus are prohibitions ("Do not create `.handbook/`"),
# which a naive matcher would flag as violations -- compliant and violating text
# differ only by a preceding negation. That rule lives in doctrine prose and in
# skill review.
#
# `.records/doctrine/` USED to be excluded by exactly that argument, and no
# longer is: once doctrine resolves through `<agent-workspace>/doctrine`, that
# path stops being any home's default, so it becomes decidable and is the
# strongest guard this retirement buys. It shipped WARN while the five consumer
# skills still carried it in their resolution prose, and is now FAIL -- they are
# flipped, so any reappearance is a regression, not a leftover.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  case "$name" in skill-builder) continue ;; esac
  is_pack_face "$name" && continue
  while IFS= read -r -d '' f; do
    rel="${f#"$sk"}"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      fail "$name: $rel:$line: off-home doctrine literal (resolve <agent-workspace>/doctrine instead)"
    done < <(grep -nF -e '`.handbook/test/' -e '`.handbook/build/' \
                     -e '`.handbook/design/' -e '`.handbook/review/' "$f" || true)
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      fail "$name: $rel:$line: stale doctrine default \`.records/doctrine/\` (resolve <agent-workspace>/doctrine instead)"
    done < <(grep -nF -e '`.records/doctrine/' "$f" || true)
  done < <(find "$sk" -name '*.md' -print0)
done

# ---- 16. retired doctrine variable + workspace declaration guards ------------
# THREE ARMS, THREE SEVERITIES -- staged per arm, not per check. Only one arm has
# a transitional population; staging the other two would be cargo-culting the
# carve-out.
#
#   a. retired-literal absence -- FAIL. It shipped WARN while the twelve
#      carriers were being flipped (failing then would have reddened the trunk
#      gate for the whole window) and is now promoted: the flip is complete, so
#      any occurrence is a regression. THIS ARM IS THE RETIREMENT PROOF -- it is
#      what makes "the variable is retired" a verifiable fact.
#   b. `agent-workspace: .` forbidden -- FAIL from the start. The variable is
#      NEW, so nothing can have declared it before this change: there is no
#      population to protect and no reason to soften it. `.` would place doctrine
#      at `./doctrine`, colliding with real project directories.
#   c. declared value equal to the current default -- WARN, always advisory. A
#      deliberate `.dev` declaration is legal. This arm exists because the
#      prescribed migration for a legacy host whose records already sit at `dev/`
#      is `agent-workspace: dev` (UNDOTTED), and `.dev` is one keystroke away,
#      syntactically valid, and a silent no-op that leaves the host degraded in
#      exactly the way the migration is supposed to fix.
#
# UNCONDITIONAL describes its SCOPE, not its severity: unlike check 14 this is
# not edge-gated, and it reads .sh as well as .md. Comments count -- a textual
# absence guard cannot tell a comment from code, so every occurrence of the
# literal is a carrier regardless of syntactic role. That inclusiveness is the
# point: it is what makes "the variable is retired" a verifiable fact rather than
# an assertion. skill-builder (this doctrine documents the literal it bans
# elsewhere) and pack faces are exempt -- the same name-based exemption checks 12
# and 15 use.
#
# Arm (a) reports ONE line per file, with the occurrence count and line numbers,
# rather than one per occurrence: a regression is fixed file-at-a-time, so the
# per-file roll-up is the actionable unit.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  case "$name" in skill-builder) continue ;; esac
  is_pack_face "$name" && continue
  while IFS= read -r -d '' f; do
    rel="${f#"$sk"}"
    hits="$(grep -nE 'agent[-_]doctrine|AGENT_DOCTRINE' "$f" | cut -d: -f1 | tr '\n' ',' \
            | sed 's/,$//' || true)"
    [ -n "$hits" ] || continue
    n="$(printf '%s' "$hits" | tr ',' '\n' | grep -c . || true)"
    fail "$name: $rel: $n occurrence(s) of the retired \`agent-doctrine\` literal (line(s) $hits) -- resolve <agent-workspace>/doctrine instead"
  done < <(find "$sk" \( -name '*.md' -o -name '*.sh' \) -print0)
done

# Arms (b) and (c): the front door itself. Same precedence as every front-door
# resolver -- AGENTS.md then CLAUDE.md, first declaration wins.
for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
  [ -f "$fd" ] || continue
  ws_decl="$(sed -n -E 's/^agent-workspace:[[:space:]]*//p' "$fd" \
             | head -n 1 | sed 's/[[:space:]]*$//')"
  [ -n "$ws_decl" ] || continue
  case "$ws_decl" in
    .)
      fail "front door ($(basename "$fd")): \`agent-workspace: .\` is forbidden -- it places doctrine at ./doctrine, colliding with real project directories"
      ;;
    .dev)
      warn "front door ($(basename "$fd")): \`agent-workspace: .dev\` restates the current default -- probable no-op; a legacy host whose records sit at \`dev/\` needs the UNDOTTED \`dev\`"
      ;;
  esac
  break
done

# ---- 17. bare `records.sh new` mint (FAIL) -----------------------------------
# A minting skill must pass `--template <resolved>` (the agent-templates rule).
# `--template` is REQUIRED by `records.sh new`: the tool knows no taxonomy, so it
# cannot guess a template path from a doctype name, and the flat
# `$RR/templates/<doctype>.md` fallback it once had is gone. A bare call
# therefore hard-errors at runtime AND skips the lock-in copy into
# `<agent-templates>/<skill>/`. This check is what turns that runtime failure
# into a lint failure, so it is caught while authoring rather than mid-verb.
#
# DECIDABILITY: two shapes are invocations. (a) a backticked span
# containing `records.sh new` and `--title` (the mint form). (b) the
# first token after `new` starts with `--` (`new --<flag>` is never
# valid, with or without `--title`). Prose merely NAMING the tool
# ("records minted by `records.sh new`") carries neither and is
# correctly out of scope; so is the deliberate documentation of the
# brownfield form, which discusses `--template` by name.
#
# Reuses check 14's `strip_code`, for the same two reasons and a third:
#   * a quoted example inside a fence must not TRIP the check (the inverse of
#     14's anchoring property -- here stripping prevents false FAILs);
#   * real invocations demonstrably wrap mid-span in the live tree
#     (`debugger/SKILL.md` breaks one across `new` / `reports`), so the match
#     must survive a line break;
#   * flattening is what makes a whole backticked span extractable at all.
#
# Evidence is the offending span, not a line number: flattening loses the line,
# and the span text is what you grep for anyway. Exemptions are the usual
# name-based pair -- skill-builder (this comment names the banned shape) and
# pack faces.
for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  case "$name" in skill-builder) continue ;; esac
  is_pack_face "$name" && continue
  while IFS= read -r -d '' f; do
    rel="${f#"$sk"}"
    while IFS= read -r span; do
      case "$span" in *'records.sh new'*) ;; *) continue ;; esac
      tok="$(printf '%s\n' "$span" | awk '
        {
          s = $0
          sub(/.*records\.sh new[[:space:]]+/, "", s)
          sub(/`.*/, "", s)
          n = split(s, a, /[[:space:]]+/)
          if (n >= 1) print a[1]
        }')"
      case "$tok" in
        --*)
          fail "$name: $rel: new --flag ${span} -- doctype is the first positional (\`records.sh new <doctype> ...\`)"
          continue
          ;;
      esac
      case "$span" in *--title*) ;; *) continue ;; esac
      case "$span" in *--template*) continue ;; esac
      fail "$name: $rel: bare mint ${span} -- pass \`--template <resolved>\` (the agent-templates rule)"
    done < <(strip_code "$f" | grep -o '`[^`]*`' || true)
  done < <(find "$sk" -name '*.md' -print0)
done

# ---- summary -----------------------------------------------------------------
echo "fails=$fails warns=$warns"
[ "$fails" -eq 0 ] || exit 1
