#!/usr/bin/env bash
# Read-only documentation-spine facts. Judgment belongs to the invoking agent.
set -euo pipefail

usage() {
  echo "usage: spine-scan.sh <root> [--candidates]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
case "${2:-}" in ""|--candidates) ;; *) usage ;; esac
[ -d "$1" ] || { echo "error=root-not-directory" >&2; exit 2; }
ROOT="$(CDPATH='' cd -P "$1" && pwd)"
MODE="${2:-facts}"
CAP=20
TMP="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-scan.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

export LC_ALL=C
cd "$ROOT"

FILES="$TMP/files"
DIRTY_ALL="$TMP/dirty-all"
CANDIDATES="$TMP/candidates"
DOCS="$TMP/markdown-docs"
NESTED_ROOTS="$TMP/nested-roots"
NESTED_DOORS="$TMP/nested-doors"
DIRTY="$TMP/dirty"
RAW_EDGES="$TMP/raw-edges"
EDGES="$TMP/edges"
BROKEN="$TMP/broken"
ESCAPES="$TMP/escapes"
ANCHOR_UNVERIFIED="$TMP/anchor-unverified"
ANCHORS="$TMP/anchors"
ANCHOR_UNCERTAIN="$TMP/anchor-uncertain"
NESTED_REFS="$TMP/nested-root-references"
SYMLINK_REFS="$TMP/symlink-references"
: >"$FILES"; : >"$DIRTY_ALL"; : >"$CANDIDATES"; : >"$DOCS"; : >"$NESTED_ROOTS"; : >"$NESTED_DOORS"
: >"$DIRTY"; : >"$RAW_EDGES"; : >"$EDGES"; : >"$BROKEN"; : >"$ESCAPES"
: >"$ANCHOR_UNVERIFIED"; : >"$ANCHORS"; : >"$ANCHOR_UNCERTAIN"; : >"$NESTED_REFS"; : >"$SYMLINK_REFS"

has_git=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then has_git=1; fi

# find does not follow symlinked directories without -L. Both .git directories and worktree
# .git files identify nested roots; their contents belong to a separate scan.
find "$ROOT" -mindepth 2 \( -type d -o -type f \) -name .git -print 2>/dev/null \
  | while IFS= read -r marker; do
      parent="${marker%/.git}"
      rel="${parent#"$ROOT"/}"
      [ "$rel" != "$parent" ] && printf '%s\n' "$rel"
    done | sort -u >"$NESTED_ROOTS"

if [ "$has_git" -eq 1 ]; then
  git -C "$ROOT" ls-files -c -z >"$TMP/tracked.z"
  git -C "$ROOT" ls-files -o --exclude-standard -z >"$TMP/untracked.z"
  {
    git -C "$ROOT" diff --name-only -z
    git -C "$ROOT" diff --cached --name-only -z
    cat "$TMP/untracked.z"
  } | tr '\0' '\n' | sort -u >"$DIRTY_ALL"
else
  find "$ROOT" \( -type f -o -type l \) -print0 >"$TMP/files.z"
fi

in_nested_root() {
  local rel="$1" nr
  while IFS= read -r nr; do
    [ -n "$nr" ] || continue
    case "$rel" in "$nr"|"$nr"/*) return 0 ;; esac
  done <"$NESTED_ROOTS"
  return 1
}

path_has_symlink_component() {
  local remaining="$1" component current="$ROOT"
  while [ -n "$remaining" ]; do
    case "$remaining" in
      */*) component="${remaining%%/*}"; remaining="${remaining#*/}" ;;
      *) component="$remaining"; remaining="" ;;
    esac
    [ -n "$component" ] || continue
    current="$current/$component"
    [ -L "$current" ] && return 0
  done
  return 1
}

if [ "$has_git" -eq 1 ]; then
  for pair in "tracked:$TMP/tracked.z" "untracked:$TMP/untracked.z"; do
    origin="${pair%%:*}"; source_file="${pair#*:}"
    while IFS= read -r -d '' rel; do
      [ -n "$rel" ] || continue
      in_nested_root "$rel" && continue
      [ -e "$ROOT/$rel" ] || [ -L "$ROOT/$rel" ] || continue
      printf '%s\t%s\n' "$origin" "$rel" >>"$FILES"
    done <"$source_file"
  done
else
  while IFS= read -r -d '' item; do
    rel="${item#"$ROOT"/}"; [ -n "$rel" ] || continue
    case "$rel" in .git|.git/*) continue ;; esac
    in_nested_root "$rel" && continue
    printf 'untracked\t%s\n' "$rel" >>"$FILES"
  done <"$TMP/files.z"
fi
sort -t $'\t' -k2,2 -k1,1 "$FILES" -o "$FILES"

is_markdown() { case "$1" in *.md|*.markdown|*.mdx) return 0 ;; *) return 1 ;; esac; }

while IFS=$'\t' read -r origin rel; do
  [ -n "$rel" ] || continue
  base="${rel##*/}"
  kinds="" evidence=""

  case "$rel" in
    AGENTS.md|CLAUDE.md|*/AGENTS.md) kinds="${kinds:+$kinds,}front-door"; evidence="${evidence:+$evidence,}conventional-door" ;;
  esac
  case "$rel" in
    *.md|*.markdown|*.mdx|*.rst|*.rest|*.adoc|*.asciidoc|*.MD|*.MDX|*.RST|*.ADOC)
      kinds="${kinds:+$kinds,}documentation"; evidence="${evidence:+$evidence,}documentation-extension" ;;
  esac
  case "$base" in
    README|README.*|CONTRIBUTING|CONTRIBUTING.*|SECURITY|SECURITY.*|CODE_OF_CONDUCT|CODE_OF_CONDUCT.*|CHANGELOG|CHANGELOG.*|LICENSE|LICENSE.*)
      kinds="${kinds:+$kinds,}documentation"; evidence="${evidence:+$evidence,}conventional-name" ;;
  esac
  case "$rel" in
    scripts/*|*/scripts/*|bin/*|*/bin/*)
      kinds="${kinds:+$kinds,}script"; evidence="${evidence:+$evidence,}script-path" ;;
  esac
  if [ -f "$ROOT/$rel" ] && [ -x "$ROOT/$rel" ]; then
    kinds="${kinds:+$kinds,}executable"; evidence="${evidence:+$evidence,}executable-bit"
  fi
  case "$base" in
    Makefile|makefile|GNUmakefile|Justfile|justfile|Taskfile|Taskfile.yml|Taskfile.yaml)
      kinds="${kinds:+$kinds,}task-entry"; evidence="${evidence:+$evidence,}task-filename" ;;
    package.json|pyproject.toml|Cargo.toml|go.mod|Gemfile|composer.json|pom.xml|build.gradle|build.gradle.kts|settings.gradle|settings.gradle.kts)
      kinds="${kinds:+$kinds,}manifest"; evidence="${evidence:+$evidence,}manifest-filename" ;;
  esac
  case "$rel" in
    .github/workflows/*|.gitlab-ci.yml|.circleci/*|azure-pipelines.yml|*/release/*|release/*)
      kinds="${kinds:+$kinds,}workflow"; evidence="${evidence:+$evidence,}ci-release-path" ;;
  esac
  case "/$rel/" in
    */operations/*|*/runbooks/*|*/playbooks/*|*/OPERATIONS/*|*/RUNBOOKS/*|*/PLAYBOOKS/*)
      kinds="${kinds:+$kinds,}operation"; evidence="${evidence:+$evidence,}operation-path" ;;
  esac
  case "/$rel/" in
    */archive/*|*/archives/*|*/history/*|*/logs/*|*/done/*|*/ARCHIVE/*|*/HISTORY/*)
      kinds="${kinds:+$kinds,}historical"; evidence="${evidence:+$evidence,}historical-path" ;;
  esac
  case "$base" in CHANGELOG|CHANGELOG.*|*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*)
      kinds="${kinds:+$kinds,}historical"; evidence="${evidence:+$evidence,}historical-name" ;;
  esac
  case "/$rel/" in
    */vendor/*|*/node_modules/*|*/third_party/*|*/third-party/*)
      kinds="${kinds:+$kinds,}vendor"; evidence="${evidence:+$evidence,}vendor-path" ;;
    */generated/*|*/gen/*|*/dist/*|*/build/*|*/target/*)
      kinds="${kinds:+$kinds,}generated"; evidence="${evidence:+$evidence,}generated-path" ;;
  esac

  [ -n "$kinds" ] || continue
  printf 'candidate\t%s\t%s\t%s\t%s\n' "$rel" "$kinds" "$origin" "$evidence" >>"$CANDIDATES"
  if is_markdown "$rel" && [ -f "$ROOT/$rel" ] && [ -r "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ]; then printf '%s\n' "$rel" >>"$DOCS"; fi
  case "$rel" in */AGENTS.md) printf '%s\n' "$rel" >>"$NESTED_DOORS" ;; esac
done <"$FILES"
awk -F'\t' 'BEGIN{OFS="\t"}
  function csvsort(s, a,n,i,j,t,out){n=split(s,a,",");for(i=1;i<=n;i++)for(j=i+1;j<=n;j++)if(a[j]<a[i]){t=a[i];a[i]=a[j];a[j]=t};out="";for(i=1;i<=n;i++)if(i==1||a[i]!=a[i-1])out=(out==""?a[i]:out "," a[i]);return out}
  {$3=csvsort($3);$5=csvsort($5);print}
' "$CANDIDATES" | sort -u >"$TMP/candidates.sorted"
mv "$TMP/candidates.sorted" "$CANDIDATES"
sort -u "$DOCS" -o "$DOCS"
sort -u "$NESTED_DOORS" -o "$NESTED_DOORS"
awk -F'\t' 'NR==FNR{dirty[$1]=1;next} ($2 in dirty){print $2}' "$DIRTY_ALL" "$CANDIDATES" | sort -u >"$DIRTY"

candidate_count="$(wc -l <"$CANDIDATES" | awk '{print $1+0}')"
if [ "$MODE" = "--candidates" ]; then
  cat "$CANDIDATES"
  printf 'candidate_count=%s\n' "$candidate_count"
  exit 0
fi

digest_file() {
  if [ ! -f "$1" ] || [ ! -r "$1" ] || [ -L "$1" ]; then printf '%s' ''; return; fi
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else cksum "$1" | awk '{print "cksum:"$1":"$2}'
  fi
}

door_state() {
  local p="$1"
  if [ -L "$p" ]; then echo symlink
  elif [ -d "$p" ]; then echo directory
  elif [ ! -e "$p" ]; then echo missing
  elif [ ! -f "$p" ]; then echo incompatible
  elif [ ! -r "$p" ]; then echo unreadable
  else echo regular
  fi
}

strip_fences() {
  awk '
    function run_length(s, ch,  n) {
      n=0
      while(substr(s,n+1,1)==ch) n++
      return n
    }
    BEGIN { fence=""; fence_len=0 }
    {
      t=$0
      indent=0
      while(indent<3 && substr(t,1,1)==" ") { t=substr(t,2); indent++ }
      ch=substr(t,1,1)
      n=((ch=="`" || ch=="~") ? run_length(t,ch) : 0)
      tail=substr(t,n+1)
      if(fence=="" && n>=3) { fence=ch; fence_len=n; next }
      if(fence!="" && ch==fence && n>=fence_len && tail ~ /^[ \t]*$/) {
        fence=""; fence_len=0; next
      }
      if (fence=="") print
    }
  ' "$1"
}

strip_inline_code_spans() {
  awk '
    function tick_run(s,pos,  n) {
      n=0
      while(substr(s,pos+n,1)=="`") n++
      return n
    }
    function spaces(n,  out) {
      out=""
      while(length(out)<n) out=out " "
      return out
    }
    function escaped_at(s,pos,  n) {
      n=0; pos--
      while(pos>0 && substr(s,pos,1)=="\\") { n++; pos-- }
      return n%2
    }
    function mask(s,  out,i,open_len,j,close_len,close_pos,span_len) {
      out=""; i=1
      while(i<=length(s)) {
        if(substr(s,i,1)!="`" || escaped_at(s,i)) { out=out substr(s,i,1); i++; continue }
        open_len=tick_run(s,i); j=i+open_len; close_pos=0
        while(j<=length(s)) {
          if(substr(s,j,1)=="`") {
            close_len=tick_run(s,j)
            if(close_len==open_len) { close_pos=j; break }
            j+=close_len
          } else j++
        }
        if(close_pos==0) { out=out substr(s,i,open_len); i+=open_len; continue }
        span_len=close_pos+open_len-i
        out=out spaces(span_len); i=close_pos+open_len
      }
      return out
    }
    { print mask($0) }
  '
}

agents_state="$(door_state "$ROOT/AGENTS.md")"
claude_state="$(door_state "$ROOT/CLAUDE.md")"
claude_imports_agents=0
if [ "$claude_state" = regular ] && strip_fences "$ROOT/CLAUDE.md" | strip_inline_code_spans | grep -Eq '(^|[^A-Za-z0-9._/-])@\.?/?AGENTS\.md([^A-Za-z0-9._/-]|$)'; then
  claude_imports_agents=1
fi

printf 'root=%s\n' "$ROOT"
printf 'git=%s\n' "$has_git"
printf 'agents_state=%s\n' "$agents_state"
printf 'claude_state=%s\n' "$claude_state"
printf 'claude_imports_agents=%s\n' "$claude_imports_agents"
printf 'agents_digest=%s\n' "$(digest_file "$ROOT/AGENTS.md")"
printf 'claude_digest=%s\n' "$(digest_file "$ROOT/CLAUDE.md")"
imported_bytes=0
if [ "$claude_imports_agents" -eq 1 ] && [ "$agents_state" = regular ]; then
  imported_bytes="$(wc -c <"$ROOT/AGENTS.md" | awk '{print $1+0}')"
fi
printf 'imported_bytes=%s\n' "$imported_bytes"

OUTLINE="$TMP/outline"
: >"$OUTLINE"
if [ "$agents_state" = regular ]; then
  strip_fences "$ROOT/AGENTS.md" | awk '/^#{1,6}[ \t]+/{print}' >"$OUTLINE"
fi

emit_capped() {
  local key="$1" file="$2" cap="$3" total shown
  total="$(awk 'NF{n++} END{print n+0}' "$file")"
  printf '%s_count=%s\n' "$key" "$total"
  shown=0
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    shown=$((shown + 1)); [ "$shown" -le "$cap" ] || break
    printf '%s=%s\n' "$key" "$value"
  done <"$file"
  if [ "$total" -gt "$cap" ]; then printf '%s_truncated=%s\n' "$key" "$((total-cap))"; fi
}

emit_capped root_door_outline "$OUTLINE" 25
emit_capped nested_agents "$NESTED_DOORS" "$CAP"
emit_capped nested_git_roots "$NESTED_ROOTS" "$CAP"

CANDIDATE_FACTS="$TMP/candidate-facts"
awk -F'\t' 'BEGIN{OFS="\t"} {print $2,$3,$4,$5}' "$CANDIDATES" >"$CANDIDATE_FACTS"
emit_capped candidate "$CANDIDATE_FACTS" "$CAP"
CANDIDATE_KINDS="$TMP/candidate-kinds"
awk -F'\t' '
  {n=split($3,a,",");for(i=1;i<=n;i++)if(a[i]!="")count[a[i]]++}
  END{for(k in count)print k "\t" count[k]}
' "$CANDIDATES" | sort >"$CANDIDATE_KINDS"
emit_capped candidate_kind "$CANDIDATE_KINDS" 100

# Build a finite anchor inventory for Markdown targets. This is an ASCII-portable approximation of
# GitHub ATX slugging: lowercase, remove markup/punctuation, convert whitespace to hyphens, and suffix
# duplicate slugs with -1, -2, ... . Explicit id="..."/id='...' values are also accepted.
while IFS= read -r doc; do
  if strip_fences "$ROOT/$doc" | grep -Eq '^#{1,6}[[:space:]]+.*([^ -~]|[<>&]|\[|\])'; then
    printf '%s\n' "$doc" >>"$ANCHOR_UNCERTAIN"
  fi
  strip_fences "$ROOT/$doc" | awk -v file="$doc" '
    function slug(s,  i,c,out,prev) {
      s=tolower(s); sub(/^#{1,6}[ \t]+/, "", s); sub(/[ \t]+#+[ \t]*$/, "", s)
      out=""; prev=0
      for(i=1;i<=length(s);i++) {
        c=substr(s,i,1)
        if(c ~ /[a-z0-9_-]/) { out=out c; prev=0 }
        else if(c ~ /[ \t]/ && out!="" && !prev) { out=out "-"; prev=1 }
      }
      sub(/-+$/, "", out); return out
    }
    {
      line=$0
      if(line ~ /^#{1,6}[ \t]+/) {
        s=slug(line); if(s!="") { n=count[s]++; a=(n==0?s:s "-" n); print file "\t" a }
      }
      rest=line
      while(match(rest, /id=["\047][A-Za-z0-9._:-]+["\047]/)) {
        x=substr(rest,RSTART,RLENGTH); sub(/^id=["\047]/,"",x); sub(/["\047]$/,"",x)
        print file "\t" x; rest=substr(rest,RSTART+RLENGTH)
      }
    }
  ' >>"$ANCHORS"
done <"$DOCS"
sort -u "$ANCHORS" -o "$ANCHORS"
sort -u "$ANCHOR_UNCERTAIN" -o "$ANCHOR_UNCERTAIN"

# Extract the deliberately finite grammar from fence-stripped Markdown. Output kind/raw/fragment;
# normalization and filesystem checks stay in shell so escaping paths are never opened.
while IFS= read -r doc; do
  strip_fences "$ROOT/$doc" | awk -v source="$doc" '
    function emit(k,t,  f,p) {
      if(t=="") return
      f=""; p=index(t,"#"); if(p>0){f=substr(t,p+1);t=substr(t,1,p-1)}
      print k "\t" source "\t" t "\t" f
    }
    function tick_run(s,pos,  n) {
      n=0
      while(substr(s,pos+n,1)=="`") n++
      return n
    }
    function spaces(n,  out) {
      out=""
      while(length(out)<n) out=out " "
      return out
    }
    function escaped_at(s,pos,  n) {
      n=0; pos--
      while(pos>0 && substr(s,pos,1)=="\\") { n++; pos-- }
      return n%2
    }
    function mask_code_spans(s,  out,i,open_len,j,close_len,close_pos,x,pathlike,span_len) {
      out=""; i=1
      while(i<=length(s)) {
        if(substr(s,i,1)!="`" || escaped_at(s,i)) { out=out substr(s,i,1); i++; continue }
        open_len=tick_run(s,i); j=i+open_len; close_pos=0
        while(j<=length(s)) {
          if(substr(s,j,1)=="`") {
            close_len=tick_run(s,j)
            if(close_len==open_len) { close_pos=j; break }
            j+=close_len
          } else j++
        }
        if(close_pos==0) { out=out substr(s,i,open_len); i+=open_len; continue }
        x=substr(s,i+open_len,close_pos-i-open_len)
        pathlike=(index(x,"/") || index(x,".") || x ~ /^(AGENTS.md|CLAUDE.md|README|Makefile|Justfile|Taskfile)$/)
        if(pathlike && x!="." && x!=".." && x ~ /^[A-Za-z0-9._\/-]+(:[0-9]+|#[A-Za-z0-9._-]+)?$/ && substr(x,1,1)!="/" && x !~ /:\/\//) emit("code",x)
        span_len=close_pos+open_len-i
        out=out spaces(span_len); i=close_pos+open_len
      }
      return out
    }
    {
      line=mask_code_spans($0); pos=1
      while(pos<=length(line)) {
        off=index(substr(line,pos), "]("); if(!off) break
        start=pos+off-1; j=start+2; target=""; ok=0
        if(substr(line,j,1)=="<") {
          j++; k=j; while(k<=length(line) && substr(line,k,1)!=">") k++
          if(k<=length(line)) { target=substr(line,j,k-j); tail=substr(line,k+1)
            if(tail ~ /^[ \t]*\)/ || tail ~ /^[ \t]*["\047][^"\047]*["\047][ \t]*\)/) ok=1 }
        } else {
          esc=0; k=j
          while(k<=length(line)) {
            c=substr(line,k,1)
            if(esc){target=target c;esc=0;k++;continue}
            if(c=="\\"){esc=1;k++;continue}
            if(c==")"){ok=1;break}
            if(c=="(" ){ok=0;break}
            if(c ~ /[ \t]/){ tail=substr(line,k); if(tail ~ /^[ \t]+["\047][^"\047]*["\047][ \t]*\)/) ok=1; break }
            target=target c; k++
          }
        }
        if(ok) emit("markdown",target)
        pos=start+2
      }
      rest=line
      while(match(rest, /(^|[^A-Za-z0-9._\/-])@[A-Za-z0-9._\/-]+/)) {
        x=substr(rest,RSTART,RLENGTH); at=index(x,"@"); x=substr(x,at+1)
        emit("import",x); rest=substr(rest,RSTART+RLENGTH)
      }
    }
  ' >>"$RAW_EDGES"
done <"$DOCS"

NORMALIZED="$TMP/normalized-edges"
awk -F'\t' '
  function norm(base,raw,  p,n,a,i,top,s,out) {
    p=(base==""?raw:base "/" raw); n=split(p,a,"/"); top=0
    for(i=1;i<=n;i++) {
      if(a[i]=="" || a[i]==".") continue
      if(a[i]==".."){if(top==0)return "ESCAPE";top--;continue}
      s[++top]=a[i]
    }
    out="";for(i=1;i<=top;i++)out=(out==""?s[i]:out "/" s[i]);return out
  }
  {
    kind=$1;source=$2;raw=$3;fragment=$4
    if(raw ~ /^\// || raw ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) next
    if(kind=="markdown") {base=source;sub(/\/[^\/]*$/, "", base);if(base==source)base=""}
    else if(kind=="import" || kind=="code") base=""; else next
    if(kind=="code") sub(/:[0-9]+$/, "", raw)
    target=(raw=="" && fragment!=""?source:norm(base,raw))
    if(target=="ESCAPE") print "escape\t" source "\t" kind "\t" raw
    else if(target!="") print "edge\t" kind "\t" source "\t" target "\t" fragment
  }
' "$RAW_EDGES" >"$NORMALIZED"

while IFS=$'\t' read -r tag one two three four; do
  if [ "$tag" = escape ]; then printf '%s\t%s\t%s\n' "$one" "$two" "$three" >>"$ESCAPES"; continue; fi
  [ "$tag" = edge ] || continue
  kind="$one"; source="$two"; target="$three"; fragment="$four"
  if path_has_symlink_component "$target"; then
    printf '%s\t%s\t%s\n' "$source" "$kind" "$target" >>"$SYMLINK_REFS"
    continue
  fi
  if in_nested_root "$target"; then
    printf '%s\t%s\t%s\n' "$source" "$kind" "$target" >>"$NESTED_REFS"
    continue
  fi
  printf '%s\t%s\t%s\n' "$kind" "$source" "$target" >>"$EDGES"
  if [ ! -e "$ROOT/$target" ] && [ ! -L "$ROOT/$target" ]; then
    printf '%s\t%s\t%s\n' "$source" "$kind" "$target" >>"$BROKEN"
  elif [ -n "$fragment" ]; then
    case "$target" in
      *.md|*.markdown|*.mdx)
        if ! grep -Fqx "$target"$'\t'"$fragment" "$ANCHORS"; then
          if grep -Fqx "$target" "$ANCHOR_UNCERTAIN"; then
            printf '%s\t%s\t%s#%s\n' "$source" "$kind" "$target" "$fragment" >>"$ANCHOR_UNVERIFIED"
          else
            printf '%s\t%s\t%s#%s\n' "$source" "$kind" "$target" "$fragment" >>"$BROKEN"
          fi
        fi ;;
      *) printf '%s\t%s\t%s#%s\n' "$source" "$kind" "$target" "$fragment" >>"$ANCHOR_UNVERIFIED" ;;
    esac
  fi
done <"$NORMALIZED"
sort -u "$EDGES" -o "$EDGES"; sort -u "$BROKEN" -o "$BROKEN"
sort -u "$ESCAPES" -o "$ESCAPES"; sort -u "$ANCHOR_UNVERIFIED" -o "$ANCHOR_UNVERIFIED"
sort -u "$NESTED_REFS" -o "$NESTED_REFS"
sort -u "$SYMLINK_REFS" -o "$SYMLINK_REFS"

EDGE_FACTS="$TMP/edge-facts"; awk -F'\t' '{print $1 "\t" $2 "\t" $3}' "$EDGES" >"$EDGE_FACTS"
emit_capped edge "$EDGE_FACTS" "$CAP"
emit_capped broken_reference "$BROKEN" "$CAP"
emit_capped escaping_reference "$ESCAPES" "$CAP"
emit_capped nested_root_reference "$NESTED_REFS" "$CAP"
emit_capped symlink_reference "$SYMLINK_REFS" "$CAP"
emit_capped anchor_unverified "$ANCHOR_UNVERIFIED" "$CAP"

# Breadth-first topology from the canonical root door. Edges to non-candidates remain visible facts
# but only normalized sources/targets participate in reachability.
REACHED="$TMP/reached"
if [ "$agents_state" = regular ]; then
  awk -F'\t' -v start=AGENTS.md '
    {adj[$2]=adj[$2] SUBSEP $3}
    END {
      head=1;tail=1;q[1]=start;seen[start]=1;depth[start]=0
      while(head<=tail) {
        cur=q[head++];n=split(adj[cur],a,SUBSEP)
        for(i=1;i<=n;i++) if(a[i]!="" && !seen[a[i]]) {
          seen[a[i]]=1;depth[a[i]]=depth[cur]+1;q[++tail]=a[i]
        }
      }
      for(p in seen) print p "\t" depth[p]
    }
  ' "$EDGES" | sort -u >"$REACHED"
else
  : >"$REACHED"
fi

REACH_FACTS="$TMP/reach-facts"; awk -F'\t' 'NF{print $1 "\t" $2}' "$REACHED" >"$REACH_FACTS"
emit_capped reachable "$REACH_FACTS" "$CAP"
max_depth="$(awk -F'\t' '$2+0>m{m=$2+0} END{print m+0}' "$REACHED")"
printf 'max_depth=%s\n' "$max_depth"

NO_INCOMING="$TMP/no-incoming"; UNREACHABLE="$TMP/unreachable"; DEAD_ENDS="$TMP/dead-ends"
: >"$NO_INCOMING"; : >"$UNREACHABLE"; : >"$DEAD_ENDS"
awk -F'\t' 'FILENAME==ARGV[1]{incoming[$3]=1;next} $2!="AGENTS.md" && !incoming[$2]{print $2}' "$EDGES" "$CANDIDATES" >"$NO_INCOMING"
awk -F'\t' 'FILENAME==ARGV[1]{reached[$1]=1;next} $2!="AGENTS.md" && !reached[$2]{print $2}' "$REACHED" "$CANDIDATES" >"$UNREACHABLE"
awk -F'\t' 'FILENAME==ARGV[1]{out[$2]=1;next} !($1 in out){print $1}' "$EDGES" "$REACHED" | sort -u >"$DEAD_ENDS"
emit_capped no_incoming_candidate "$NO_INCOMING" "$CAP"
emit_capped unreachable_candidate "$UNREACHABLE" "$CAP"
emit_capped dead_end "$DEAD_ENDS" "$CAP"
emit_capped dirty_candidate "$DIRTY" "$CAP"
