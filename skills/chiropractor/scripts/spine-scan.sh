#!/bin/sh
# spine-scan.sh <repo-root> -- read-only doc-spine fact scanner. Facts only; never a verdict.
set -eu
ROOT=${1:-.}
ROOT=$(CDPATH= cd "$ROOT" && pwd)
cd "$ROOT"

# emit_capped <key> <cap>: read a newline-delimited item list on stdin and emit two
# DIGESTIBLE facts -- "<key>_count=<true total>" and "<key>=<first cap items, comma-joined>"
# with a trailing " ...(+<M> more)" marker when the list was truncated. The COUNT is always
# the true total; the value line is a capped sample. Pure awk -- single pass, no subprocess
# per item, no temp files. (Used for the single-line comma-joined list facts.)
emit_capped() {
  awk -v key="$1" -v cap="$2" '
    $0 != "" { n++; if (n <= cap) s = (s == "" ? $0 : s "," $0) }
    END {
      print key "_count=" n+0
      if (n > cap) s = s " ...(+" n-cap " more)"
      print key "=" s
    }'
}

# strip_fences <file>: the file minus fenced code blocks -- a fenced `@AGENTS.md`
# example is a deliberate example, not a live import (same rationale as emit_edges).
strip_fences() {
  awk 'FNR==1{in_fence=0} /^[ ]*(```|~~~)/{in_fence=!in_fence; next} in_fence{next} {print}' "$1"
}

# is_historical <doc-path>: true when the doc is a historical RECORD rather than live
# guidance -- a changelog, a file in an archive/history/logs/done store, or a dated
# (YYYY-MM-DD) file. Broken/stale refs inside such docs cite a PAST state by design, so
# they are records, not rot; callers route them to the *_archived list facts. Portable,
# zero-config, conservative: it keys off path shape only (no per-repo glob wiring).
is_historical() {
  case "$1" in
    CHANGELOG.md|*/CHANGELOG.md) return 0 ;;
    */archive/*|*/history/*|*/logs/*|*/done/*) return 0 ;;
    *[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) return 0 ;;  # dated segment anywhere in the path
  esac
  return 1
}

# Entry door: first existing in priority order.
ENTRY=""
for c in AGENTS.md CLAUDE.md README.md .cursorrules; do
  [ -f "$c" ] && { ENTRY=$c; break; }
done
# If CLAUDE.md imports AGENTS.md (@AGENTS.md / @./AGENTS.md), CLAUDE.md is the true door.
# Fence-aware: a fenced example import must not flip the door.
if [ -f CLAUDE.md ] && strip_fences CLAUDE.md | grep -Eq '@\.?/?AGENTS\.md'; then ENTRY=CLAUDE.md; fi
echo "entry_door=$ENTRY"

# Import chain: @-imports declared in the entry door (one hop; Claude-style; fence-aware).
chain=""
if [ -n "$ENTRY" ] && [ -f "$ENTRY" ]; then
  chain=$(strip_fences "$ENTRY" | grep -Eo '@[A-Za-z0-9_./-]+\.md' | sed 's/^@\.\{0,1\}\/\{0,1\}//' | paste -sd, - || true)
fi
echo "import_chain=$chain"

# ----- Task 3: link graph, reachability, orphans, unreachable dirs -----

# All markdown files that belong to the doc spine. When the root is a git repo, list TRACKED
# markdown via `git ls-files` -- this respects .gitignore, so scratch dirs (.superpowers/,
# .sessions/), gitignored worktrees, caches and build output are excluded automatically (a
# more correct, zero-config replacement for a hardcoded prune list). When there is no .git,
# fall back to find with the prune list. Both paths emit root-relative paths, sorted/deduped.
find_md() {
  if [ -e "$ROOT/.git" ]; then
    # --others --exclude-standard: a NEW not-yet-committed doc is part of the spine
    # too. The existence filter drops deleted-but-still-indexed entries, which would
    # otherwise abort the awk batch mid-stream (BWK awk exits on an unopenable file).
    git -C "$ROOT" ls-files --cached --others --exclude-standard -- '*.md' 2>/dev/null \
      | sort -u | while IFS= read -r mf; do [ -f "$mf" ] && printf '%s\n' "$mf"; done
  else
    find . \
      \( -name .git -o -name .workstreams -o -name node_modules -o -name target \
         -o -name build -o -name dist -o -name vendor -o -name .venv -o -name venv \) -prune \
      -o -name '*.md' -print \
      | sed 's|^\./||' | sort -u
  fi
}

# Emit edges: extract local .md link targets (markdown links + @-imports) from EVERY md
# file in a SINGLE awk pass (FILENAME gives the source; per-link path math is pure in-process
# -- no grep/sed/cd subprocess per file or per link, which is pathological at repo scale).
# Output: "edge <src> <normalised-target>".
emit_edges() {
  files=$(find_md)
  [ -z "$files" ] && return 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 awk '
    # normpath(base,target): join base + "/" + target, resolve "." (skip) and ".." (pop),
    # strip leading "./", rejoin. Matches the old cd-subshell resolution for in-repo paths.
    # A ".." that pops BELOW the scanned root returns "" -- the ref escapes the root (it
    # would break on a standalone clone of this tree); callers emit an "escape"-typed edge
    # carrying the RAW target instead of silently clamping it to a phantom in-repo path.
    function normpath(base, target,   combined, n, parts, i, top, stack, out, j) {
      combined = base "/" target
      n = split(combined, parts, "/")
      top = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] == ".") continue
        if (parts[i] == "..") { if (top > 0) top--; else return ""; continue }
        stack[++top] = parts[i]
      }
      out = ""
      for (j = 1; j <= top; j++) out = (out == "" ? stack[j] : out "/" stack[j])
      return out
    }
    # Source dir of FILENAME, via split (avoid "/"-in-regex; some awks choke on it).
    # Also reset the fenced-code-block flag at the start of each file (a file that ends
    # mid-fence must not bleed into the next file in the batch).
    FNR == 1 { in_fence = 0
               dn = split(FILENAME, dp, "/"); dir = "."
               if (dn > 1) { dir = dp[1]; for (di = 2; di < dn; di++) dir = dir "/" dp[di] } }
    # Fenced code blocks are deliberate examples, not real references: skip their content.
    # A line whose FIRST non-space content is 3+ backticks (with an optional language tag,
    # e.g. ```markdown) or 3+ tildes toggles the fence. Toggle only on such block-fence
    # lines -- an inline ` `code` ` span mid-prose-line never starts with 3 backticks, so
    # intentional inline-code .md refs on ordinary lines are unaffected (Fix A holds).
    /^[ ]*(```|~~~)/ { in_fence = !in_fence; next }
    in_fence { next }
    {
      # Each edge carries a TYPE in field 4: "link" for explicit links (markdown + @import),
      # "code" for informal backtick code-span refs. Reachability/orphans/count consume all
      # edges; broken_links counts only "link" edges (a broken backtick ref is a stale_ref,
      # not a broken link -- the same split the brief draws for backtick `src/foo.rs`).
      # Standard markdown links: ](target.md) or ](target.md#anchor)
      s = $0
      while (match(s, /\]\([^)]+\.md(#[^)]*)?\)/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^\]\(/, "", t); sub(/\)$/, "", t); sub(/#.*$/, "", t)
        if (t !~ /^https?:/ && substr(t, 1, 1) != "/") {
          np = normpath(dir, t)
          if (np == "") print "edge", FILENAME, t, "escape"
          else print "edge", FILENAME, np, "link"
        }
      }
      # @-style imports (Claude / Cursor entry-door convention). String regexes: a "/" inside
      # a "/.../ " literal terminates it in the one-true-awk shipped on macOS.
      s = $0
      while (match(s, "@[A-Za-z0-9_./-]+\\.md")) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub("^@\\.?/?", "", t)
        if (t != "") {
          np = normpath(dir, t)
          if (np == "") print "edge", FILENAME, t, "escape"
          else print "edge", FILENAME, np, "link"
        }
      }
      # Inline-code doc paths: `path.md` or `path.md#anchor`. Agent-facing docs (AGENTS.md,
      # etc.) cite other docs as backtick code spans in prose rather than markdown links, so
      # without this the reference graph misses almost everything. ONLY .md targets become
      # reachability edges (a backtick `src/foo.rs` is a code ref, handled by stale_refs). The
      # path char class ([A-Za-z0-9_./-], like @import/stale_refs) naturally excludes glob and
      # template tokens (`*.md`, `.records/archive/<YYYY-MM-DD>-<slug>.md`) -- the bracket chars break
      # the run. These edges are typed "code" so they grow reachability without inflating
      # broken_links: a backtick ref that does not resolve surfaces under stale_refs instead.
      s = $0
      while (match(s, "`[A-Za-z0-9_./-]+\\.md(#[^`]*)?`")) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        gsub(/`/, "", t); sub(/#.*$/, "", t)
        if (t !~ /^https?:/ && substr(t, 1, 1) != "/") {
          np = normpath(dir, t)
          if (np == "") print "edge", FILENAME, t, "escape"
          else print "edge", FILENAME, np, "code"
        }
      }
    }
  '
}
EDGES=$(emit_edges || true)
# edges is a MULTI-LINE fact (one "edges=src->tgt" line per edge); cap to 20 lines + a count.
printf '%s\n' "$EDGES" | awk '
  NF { n++; if (n <= 20) lines[n] = "edges="$2"->"$3 }
  END {
    print "edges_count=" n+0
    cap = (n < 20 ? n : 20)
    for (i = 1; i <= cap; i++) print lines[i]
    if (n > 20) print "edges= ...(+" n-20 " more)"
  }'

# ----- Entry-door audit: presence + front-door coherence -----
am=0; [ -f AGENTS.md ] && am=1; echo "agents_md=$am"
cm=0; [ -f CLAUDE.md ] && cm=1; echo "claude_md=$cm"
# Cross-reference is derived from $EDGES, counting ONLY intentional-pointer edges ($4=="link":
# markdown link or @-import). An incidental backtick `CLAUDE.md` code-span mention ($4=="code")
# is NOT a coherence back-reference, so it does not register here. front_door_link=n/a unless
# BOTH exist.
if [ "$am" = 1 ] && [ "$cm" = 1 ]; then
  c2a=$(printf '%s\n' "$EDGES" | awk '$1=="edge" && $2=="CLAUDE.md" && $3=="AGENTS.md" && $4=="link"{f=1} END{print f+0}')
  a2c=$(printf '%s\n' "$EDGES" | awk '$1=="edge" && $2=="AGENTS.md" && $3=="CLAUDE.md" && $4=="link"{f=1} END{print f+0}')
  if [ "$c2a" = 1 ] && [ "$a2c" = 1 ]; then fdl=bidirectional
  elif [ "$c2a" = 1 ]; then fdl='claude->agents'
  elif [ "$a2c" = 1 ]; then fdl='agents->claude'
  else fdl=none; fi
else
  fdl=n/a
fi
echo "front_door_link=$fdl"

# ----- Entry-door audit: content-door outline + hub links -----
# The CONTENT door is AGENTS.md when present (a thin-pointer CLAUDE.md that imports AGENTS.md
# has no substantive outline -- the content lives in the imported AGENTS.md), else the entry door.
DOOR=$ENTRY; [ -f AGENTS.md ] && DOOR=AGENTS.md
# Outline: heading lines (# .. ######) of the content door, in order, fence-aware, capped.
if [ -n "$DOOR" ] && [ -f "$DOOR" ]; then
  awk '
    FNR==1 { in_fence=0 }
    /^[ ]*(```|~~~)/ { in_fence = !in_fence; next }
    in_fence { next }
    /^(#|##|###|####|#####|######)[ ]/ { print }   # no {1,6}: brace intervals are unreliable on old BWK awks
  ' "$DOOR" | emit_capped entry_outline 25
else
  echo "entry_outline_count=0"; echo "entry_outline="
fi
# Hub links: distinct docs the content door directly references, from $EDGES. Counts ALL
# navigational-edge types (markdown links, @-imports, AND backtick inline-code doc refs) --
# agent-facing docs (e.g. AGENTS.md) often cite their repo-map via backtick refs, so
# restricting to link-type only would collapse hub counts to near-zero on real repos.
# Contrast: front_door_link above counts ONLY intentional-pointer edges ($4=="link").
hub=$(printf '%s\n' "$EDGES" | awk -v d="$DOOR" '$1=="edge" && $2==d && $4!="escape" { t[$3]=1 } END { n=0; for (k in t) n++; print n }')
echo "entry_hub_links=$hub"

# ----- Sub-roots: nested git repos (submodules / embedded repos) -----
# A nested repo is its own doc spine -- its files are ALREADY excluded from this scan
# (git ls-files does not descend into gitlinks; the find fallback detects them here so
# the agent knows sub-spines exist and can scan each root separately). Each sub_root is
# annotated ":<front-door>" with its own entry door (empty when it has none).
if [ -e "$ROOT/.git" ]; then
  SUB_PATHS=$(git -C "$ROOT" ls-files --stage 2>/dev/null | awk -F'\t' '$1 ~ /^160000 / {print $2}' | sort -u)
else
  SUB_PATHS=$(find . -mindepth 2 \
    \( -name .workstreams -o -name node_modules -o -name target \
       -o -name build -o -name dist -o -name vendor -o -name .venv -o -name venv \) -prune \
    -o -name .git -print 2>/dev/null | sed 's|/\.git$||; s|^\./||' | sort -u)
fi
printf '%s\n' "$SUB_PATHS" | while IFS= read -r sr; do
  [ -n "$sr" ] || continue
  door=""
  for c in AGENTS.md CLAUDE.md README.md; do
    [ -f "$sr/$c" ] && { door=$c; break; }
  done
  printf '%s:%s\n' "$sr" "$door"
done | emit_capped sub_roots 20

# Reachability BFS from entry door over EDGES (awk associative arrays -- POSIX portable).
# Escape-typed edges carry a raw out-of-root target, not a spine path -- they never feed BFS.
REACH_D=$(printf '%s\n' "$EDGES" | awk -v start="$ENTRY" '
  $4 == "escape" { next }
  { e[$2]=e[$2] " " $3 }
  END {
    n=0; q[n++]=start; seen[start]=1; d[start]=0
    for (i=0; i<n; i++) {
      split(e[q[i]], a, " ")
      for (k in a) { if (a[k]!="" && !seen[a[k]]) { seen[a[k]]=1; d[a[k]]=d[q[i]]+1; q[n++]=a[k] } }
    }
    for (s in seen) print s "\t" d[s]
  }')
REACH=$(printf '%s\n' "$REACH_D" | awk -F'\t' 'NF{print $1}')
# max_depth: longest hop distance from the entry door over the same BFS -- the
# Read-Path rubric dimension consumes this (the capped edges sample cannot yield it).
printf '%s\n' "$REACH_D" | awk -F'\t' 'NF{if ($2+0>m) m=$2+0} END{print "max_depth=" m+0}'

# Orphans = md files not reachable from the entry door (entry door itself is implicitly
# reachable). Single awk pass: load REACH into a set, then stream ALL against it -- no
# grep-per-file O(n^2). REACH and ALL are concatenated with a "---" sentinel.
ALL=$(find_md)
printf '%s\n---\n%s\n' "$REACH" "$ALL" | awk -v entry="$ENTRY" '
  $0 == "---" { phase = 1; next }
  phase == 0 { if ($0 != "") reached[$0] = 1; next }
  { if ($0 == "" || $0 == entry) next
    if (!($0 in reached)) print $0 }
' | sort | emit_capped orphan_docs 20

# Unreachable dirs = top-level dirs no reached md file lives under. Same single-pass set op:
# collect top-level dirs of reached files, then top-level dirs of ALL files, diff them.
printf '%s\n---\n%s\n' "$REACH" "$ALL" | awk '
  $0 == "---" { phase = 1; next }
  phase == 0 { if ($0 != "" && split($0, p, "/") > 1) reachdir[p[1]] = 1; next }
  { if ($0 != "" && split($0, p, "/") > 1) alldir[p[1]] = 1 }
  END { for (d in alldir) if (!(d in reachdir)) print d }
' | sort | emit_capped unreachable_dirs 20

# ----- Task 4: broken links + stale refs -----

# Broken links: explicit-link edge targets that don't exist on disk. EDGES format:
# "edge <src> <tgt> <type>". Count ONLY type=="link" (markdown + @import) edges -- a broken
# backtick code-span ref is reported under stale_refs, not here. Dedup so a target linked from
# the same source on several lines counts once.
# Partition by SOURCE-doc kind: a broken link in a historical-record doc (changelog,
# archive, dated file) points at a target that existed when the record was written --
# routed to broken_links_archived, not the live broken_links the agent acts on.
BROKEN=$(printf '%s\n' "$EDGES" | awk '$1=="edge" && $4=="link"{print $2"#->#"$3}' | sort -u | while IFS= read -r pair; do
  tgt=${pair##*#->#}; src=${pair%%#->#*}
  # The "#->#" separator is internal (paths cannot contain it); emit the documented "src->tgt" form.
  [ -f "$tgt" ] && continue
  if is_historical "$src"; then echo "H	${src}->${tgt}"; else echo "L	${src}->${tgt}"; fi
done)
printf '%s\n' "$BROKEN" | awk -F'\t' '$1=="L"{print $2}' | emit_capped broken_links 20
printf '%s\n' "$BROKEN" | awk -F'\t' '$1=="H"{print $2}' | emit_capped broken_links_archived 20

# Escaping refs come from TWO sources, both self-containment violations that break on a
# standalone clone: (1) markdown-link / @import / code-span .md EDGE targets that climb
# above the root (typed "escape" by emit_edges), and (2) backtick code-span path refs to
# ANY file (surfaced by the stale-ref pass below). They are combined into one escaping_refs
# fact after the stale pass. Capture the edge-sourced ones here; reported raw (as written).
EDGE_ESCAPES=$(printf '%s\n' "$EDGES" | awk '$1=="edge" && $4=="escape"{print $2"->"$3}')

# Stale refs: inline `path` or `path:line` mentions (in code-spans) whose path doesn't exist.
# Conservative: only flag tokens that contain a slash (real repo paths); bare words / short names ignored.
# Extract candidate (src, path-token) pairs in ONE awk pass over all files (no per-file grep),
# keeping only slash-bearing tokens (real repo paths). Each token is doc-relative-resolved: one
# whose ".." climbs ABOVE the root is tagged ESC (an escape -> escaping_refs, raw token); the
# rest are tagged CAND and carry the RAW token unchanged into the existence/xroot/stale logic
# (so non-escaping behavior is identical to before). The existence check then runs only over
# that bounded candidate set -- not once per file.
REFS=$({ files=$(find_md); [ -n "$files" ] && printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 awk '
  # normpath(base,target): resolve "." / ".." against base; return "" when ".." pops below
  # the root (the ref escapes the repo). Same resolution emit_edges uses for link targets.
  function normpath(base, target,   combined, n, parts, i, top, stack, out, j) {
    combined = base "/" target
    n = split(combined, parts, "/")
    top = 0
    for (i = 1; i <= n; i++) {
      if (parts[i] == "" || parts[i] == ".") continue
      if (parts[i] == "..") { if (top > 0) top--; else return ""; continue }
      stack[++top] = parts[i]
    }
    out = ""
    for (j = 1; j <= top; j++) out = (out == "" ? stack[j] : out "/" stack[j])
    return out
  }
  # Skip fenced code blocks (deliberate examples) -- see emit_edges for the toggle rationale.
  # Track the source docs directory (for normpath) at the start of each file.
  FNR == 1 { in_fence = 0
             dn = split(FILENAME, dp, "/"); dir = "."
             if (dn > 1) { dir = dp[1]; for (di = 2; di < dn; di++) dir = dir "/" dp[di] } }
  /^[ ]*(```|~~~)/ { in_fence = !in_fence; next }
  in_fence { next }
  {
    s = $0
    while (match(s, "`[A-Za-z0-9_./-]+\\.[A-Za-z]+(:[0-9]+)?`")) {
      t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      gsub(/`/, "", t); sub(/:[0-9]+$/, "", t)
      if (!index(t, "/")) continue                    # only slash-bearing tokens look like repo paths
      if (substr(t, 1, 1) == "/") continue            # absolute tokens are runtime/OS paths, never repo-relative (BL-14)
      dr = normpath(dir, t)
      if (dr == "") print "ESC\t" FILENAME "\t" t     # climbs above root -> escape (raw token)
      else print "CAND\t" FILENAME "\t" t "\t" dr     # raw token + doc-relative resolution (BL-14)
    }
  }
'; } | sort -u)

# Code-span escapes join the edge escapes in the single escaping_refs fact.
CODESPAN_ESCAPES=$(printf '%s\n' "$REFS" | awk -F'\t' '$1=="ESC"{print $2"->"$3}')
printf '%s\n%s\n' "$EDGE_ESCAPES" "$CODESPAN_ESCAPES" | awk 'NF' | sort -u | emit_capped escaping_refs 20

# CAND tokens (non-escaping) flow into the existence / cross-root / staleness classification.
printf '%s\n' "$REFS" | awk -F'\t' '$1=="CAND"{print $2"\t"$3"\t"$4}' | {
  # Classify each unresolved candidate. A token that resolves INSIDE a nested repo root
  # (as "<sub_root>/<token>", or "<sub_root parent>/<token>" for tokens that name the
  # sub-repo by its directory name) is a CROSS-ROOT CITATION -- a doc deliberately citing
  # another repo's file, context-relative -- not staleness. Only tokens that resolve
  # nowhere are stale_refs. Both lists are facts; the agent judges either.
  SUB_PARENTS=$(printf '%s\n' "$SUB_PATHS" | awk 'NF { n=split($0,p,"/"); if (n>1) { o=p[1]; for(i=2;i<n;i++) o=o"/"p[i]; print o } }' | sort -u)
  while IFS="$(printf '\t')" read -r f p dr; do
    [ -n "$p" ] || continue
    [ -e "$p" ] && continue
    # BL-14: a token that resolves doc-relative is a legitimate sibling ref, not stale.
    [ -n "$dr" ] && [ "$dr" != "$p" ] && [ -e "$dr" ] && continue
    hit=0
    for sr in $SUB_PATHS; do
      [ -e "$sr/$p" ] && { hit=1; break; }
    done
    if [ "$hit" = 0 ]; then
      for pd in $SUB_PARENTS; do
        [ -e "$pd/$p" ] && { hit=1; break; }
      done
    fi
    if [ "$hit" = 1 ]; then echo "X	$f:$p"; else echo "S	$f:$p"; fi
  done
} | {
  # Split the classified stream into the list facts. Buffer in the shell (the script's
  # variable-capture pattern) -- the emit_capped passes need the stream more than once.
  CLASSIFIED=$(cat)
  # Unresolved refs (S) split further by SOURCE-doc kind: a stale ref in a historical
  # record (changelog, archive, dated plan/report) cites a past state by design and goes
  # to stale_refs_archived; only refs in LIVE docs stay in stale_refs (real rot to judge).
  STALE_SPLIT=$(printf '%s\n' "$CLASSIFIED" | awk -F'\t' '$1=="S"{print $2}' | while IFS= read -r item; do
    [ -n "$item" ] || continue
    src=${item%%:*}   # item is "<src-doc>:<path-token>"; src-doc has no colon
    if is_historical "$src"; then echo "H	$item"; else echo "L	$item"; fi
  done)
  printf '%s\n' "$STALE_SPLIT" | awk -F'\t' '$1=="L"{print $2}' | emit_capped stale_refs 20
  printf '%s\n' "$STALE_SPLIT" | awk -F'\t' '$1=="H"{print $2}' | emit_capped stale_refs_archived 20
  printf '%s\n' "$CLASSIFIED" | awk -F'\t' '$1=="X"{print $2}' | emit_capped xroot_refs 20
}

# ----- Task 5: token economy + affordance flags -----

# Always-loaded bytes = entry door + each import-chain file.
# Use awk to strip leading whitespace from wc -c output (portable across macOS/Linux).
bytes=0
for f in "$ENTRY" $(printf '%s' "$chain" | tr ',' ' '); do
  [ -f "$f" ] || continue
  sz=$(wc -c < "$f" | awk '{print $1+0}')
  bytes=$(( bytes + sz ))
done
echo "always_loaded_bytes=$bytes"

# Per-doc sizes (all md files). One batched `wc -c` over the whole list (a process per file
# is needless overhead at repo scale); skip wc's trailing "total" line. Re-sort to restore
# find_md order (wc's multi-file total can reorder the tail).
# doc_sizes is a list fact: emit the true count + the TOP 15 LARGEST docs by bytes (a capped
# sample). Sort by byte size desc, then cap in-process (awk, no per-item subprocess).
printf '%s\n' "$ALL" | tr '\n' '\0' | xargs -0 wc -c 2>/dev/null | awk '
  { b = $1; $1 = ""; sub(/^ /, ""); if ($0 == "total") next; print b "\t" $0 }
' | sort -rn -k1,1 | awk -F'\t' '
  { n++; if (n <= 15) s = (s == "" ? $2 ":" $1 : s "," $2 ":" $1) }
  END {
    print "doc_sizes_count=" n+0
    if (n > 15) s = s " ...(+" n-15 " more)"
    print "doc_sizes=" s
  }'

# Affordance flags.
gl=0; for g in GLOSSARY.md docs/GLOSSARY.md dev/GLOSSARY.md .agents/foreman/GLOSSARY.md; do [ -f "$g" ] && gl=1; done
echo "has_glossary=$gl"
ix=0; for i in INDEX.md docs/INDEX.md dev/README.md docs/README.md .agents/foreman/README.md .agents/foreman/INDEX.md; do [ -f "$i" ] && ix=1; done
echo "has_index=$ix"

# Frontmatter coverage over reached docs.
# Drive with awk: for each reached doc, open it and check if the first line is exactly "---".
# No subshell-accumulator trap, no temp files -- awk accumulates tot/fm in its own process.
frontmatter_coverage=$(printf '%s\n' "$REACH" | awk '
  $0 == "" { next }
  {
    f = $0
    ret = (getline line < f)
    close(f)
    if (ret < 0) next
    tot++
    if (line == "---") fm++
  }
  END { print fm+0 "/" tot+0 }
')
echo "frontmatter_coverage=$frontmatter_coverage"
