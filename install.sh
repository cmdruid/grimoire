#!/usr/bin/env bash
# install.sh -- wire grimoire skills into an agent harness via symlinks.
#
# Usage:
#   ./install.sh <skill> [<skill>...]      install named skills
#   ./install.sh --pack <name>             install a pack (its PACK.md manifest, spec format 1)
#   ./install.sh --remove <skill>...       remove installed symlinks (only ones owned by this clone)
#   ./install.sh --list                    show skills, packs, and install state
#   ./install.sh --target <dir> ...        override target dir (default: ~/.claude/skills)
#
# Packs follow docs/spec/pack-format.md (format 1): a pack is a skill dir with a
# PACK.md (the face is an implicit member; optional members are default-installed).
# A pack install is transactional -- preflight the whole member set, link, then
# record the install in the sidecar lock `grimoire.lock` beside the target dir
# (e.g. target ~/.agents/skills -> lock ~/.agents/grimoire.lock, the global scope).
# Symlinks only: the clone stays canonical, edits here are live immediately.
# Codex (and other dir-scanning harnesses): point the harness at <clone>/skills
# directly (e.g. ln -s <clone>/skills ~/.agents/skills) -- no per-skill wiring.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
target="$HOME/.claude/skills"
mode="install"
names=()
pack_name=""
pack_manifest=""
pack_optional=""
pack_version=""

# frontmatter_key <file> <key> -- first frontmatter value for key (never reads the body)
frontmatter_key() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    index($0, k ":") == 1 { sub("^" k ":[[:space:]]*", ""); print; exit }
  ' "$1"
}

# resolve_pack <name> -- echo the PACK.md whose name: matches; fail when none does
resolve_pack() {
  for m in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$m" ] || continue
    if [ "$(frontmatter_key "$m" name)" = "$1" ]; then echo "$m"; return 0; fi
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pack)
      [ $# -ge 2 ] || { echo "error: --pack needs a name" >&2; exit 2; }
      pack_name="$2"
      shift ;;
    --remove) mode="remove" ;;
    --list)   mode="list" ;;
    --target)
      [ $# -ge 2 ] || { echo "error: --target needs a directory" >&2; exit 2; }
      target="$2"; shift ;;
    -h|--help) sed -n 's/^# \{0,1\}//p;18q' "$0"; exit 0 ;;
    -*) echo "error: unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *) names+=("$1") ;;
  esac
  shift
done

if [ "$mode" = "list" ]; then
  echo "skills ($root/skills), target: $target"
  for sk in "$root"/skills/*/; do
    name="$(basename "$sk")"
    state="-"
    [ -L "$target/$name" ] && state="installed -> $(readlink "$target/$name")"
    printf '  %-14s %s\n' "$name" "$state"
  done
  echo "packs (PACK.md manifests):"
  for m in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$m" ] || continue
    printf '  %-14s v%-8s %s\n' "$(frontmatter_key "$m" name)" \
      "$(frontmatter_key "$m" version)" "$(frontmatter_key "$m" required)"
  done
  exit 0
fi

# ---- pack resolution (spec format 1): face implicit, optional default-installed ----
if [ -n "$pack_name" ]; then
  pack_manifest="$(resolve_pack "$pack_name")" \
    || { echo "error: no PACK.md declares name: $pack_name (try --list)" >&2; exit 2; }
  fmt="$(frontmatter_key "$pack_manifest" format)"
  [ -z "$fmt" ] || [ "$fmt" = "1" ] \
    || { echo "error: pack $pack_name declares format: $fmt -- this tool implements format 1" >&2; exit 2; }
  pack_version="$(frontmatter_key "$pack_manifest" version)"
  pack_required="$(frontmatter_key "$pack_manifest" required | tr ',' ' ')"
  pack_optional="$(frontmatter_key "$pack_manifest" optional | tr ',' ' ')"
  [ -n "$pack_required" ] || { echo "error: $pack_manifest has no required: line" >&2; exit 2; }
  pack_dir="$(dirname "$pack_manifest")"
  if [ -f "$pack_dir/SKILL.md" ]; then
    face="$(frontmatter_key "$pack_dir/SKILL.md" name)"
    [ -n "$face" ] || face="$(basename "$pack_dir")"
    [ "$face" = "$pack_name" ] \
      || { echo "error: face name $face != pack name: $pack_name (spec: they MUST match)" >&2; exit 2; }
    names+=("$face")
  fi
  for s in $pack_required $pack_optional; do names+=("$s"); done
fi

[ ${#names[@]} -gt 0 ] || { echo "error: no skills named (try --list)" >&2; exit 2; }

# member_hash <skill-dir> -- the ecosystem skill-folder hash (spec Appendix A):
# regular files only, .git/node_modules pruned, sorted relative paths, sha256 over
# path-bytes + file-bytes per pair, no delimiters.
member_hash() {
  (
    CDPATH='' cd "$1" || exit 1
    find . \( -name .git -o -name node_modules \) -prune -o -type f -print \
      | sed 's|^\./||' | LC_ALL=C sort \
      | while IFS= read -r f; do printf '%s' "$f"; cat "./$f"; done \
      | if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi \
      | awk '{print "sha256:" $1}'
  )
}

# write_lock -- record the installed pack in the sidecar grimoire.lock (spec §3).
# python3 merges into an existing lock (preserving other packs and unknown keys);
# without python3 a fresh lock is written when none exists, else the stale lock is
# surfaced as a fact and left untouched.
write_lock() {
  lock_dir="$(CDPATH='' cd "$(dirname "$target")" && pwd)"
  lock_file="$lock_dir/grimoire.lock"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ref="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)"
  members_json=""
  for name in "${names[@]}"; do
    opt=false
    case " $pack_optional " in *" $name "*) opt=true ;; esac
    h="$(member_hash "$root/skills/$name")"
    members_json="${members_json}${members_json:+,}
      \"$name\": { \"hash\": \"$h\", \"optional\": $opt }"
  done
  entry_json="{
    \"version\": \"$pack_version\",
    \"source\": \"$root\",
    \"ref\": \"$ref\",
    \"installedAt\": \"$ts\",
    \"members\": {$members_json
    }
  }"
  if command -v python3 >/dev/null 2>&1; then
    LOCK_FILE="$lock_file" PACK_NAME="$pack_name" ENTRY_JSON="$entry_json" python3 - <<'PY'
import json, os, sys
path, pack = os.environ["LOCK_FILE"], os.environ["PACK_NAME"]
entry = json.loads(os.environ["ENTRY_JSON"])
lock = {"version": 1, "packs": {}}
if os.path.exists(path):
    try:
        with open(path) as f:
            lock = json.load(f)
    except ValueError:
        print(f"lock-unparseable {path} -- left untouched (spec: read-only)", file=sys.stderr)
        sys.exit(0)
    if lock.get("version", 1) > 1:
        print(f"lock-version {lock.get('version')} > 1 -- left untouched (spec: read-only)", file=sys.stderr)
        sys.exit(0)
lock.setdefault("packs", {})[pack] = entry
with open(path, "w") as f:
    json.dump(lock, f, indent=2)
    f.write("\n")
print(f"locked    {pack}@{entry['version']} -> {path}")
PY
  elif [ ! -e "$lock_file" ]; then
    printf '{\n  "version": 1,\n  "packs": {\n    "%s": %s\n  }\n}\n' \
      "$pack_name" "$entry_json" > "$lock_file"
    echo "locked    $pack_name@$pack_version -> $lock_file"
  else
    echo "lock-unmerged: $lock_file exists and python3 is unavailable -- lock not updated" >&2
  fi
}

# ---- transactional pack install (spec §5: preflight, link, then commit the lock) ----
# Preflight the whole member set: every member present on disk, no destination
# collision (an existing symlink to the same source is no collision). Any failure
# aborts with the fact before a single link is made; a mid-flight link error rolls
# back what this run created. Bare single-skill install (below) is untouched.
if [ "$mode" = "install" ] && [ -n "$pack_name" ]; then
  fail=0
  for name in "${names[@]}"; do
    src="$root/skills/$name"
    link="$target/$name"
    if [ ! -f "$src/SKILL.md" ]; then
      echo "preflight: missing-member $name (no skills/$name/SKILL.md)" >&2; fail=1
    fi
    if [ -L "$link" ]; then
      # Physical-path compare: a link that resolves to the same source through an
      # intermediate symlink chain is the same install, not a collision (the same
      # rule skills-lint.sh's wiring check applies).
      want="$(cd -P "$src" 2>/dev/null && pwd)"
      got="$(cd -P "$link" 2>/dev/null && pwd || true)"
      if [ -z "$got" ] || [ "$got" != "$want" ]; then
        echo "preflight: collision $name ($link -> $(readlink "$link"))" >&2; fail=1
      fi
    elif [ -e "$link" ]; then
      echo "preflight: collision $name ($link exists and is not a symlink)" >&2; fail=1
    fi
  done
  if [ "$fail" != 0 ]; then
    echo "abort: pack $pack_name preflight failed -- no partial install" >&2
    exit 1
  fi
  mkdir -p "$target"
  created=()
  for name in "${names[@]}"; do
    src="$root/skills/$name"
    link="$target/$name"
    if [ -L "$link" ]; then echo "ok       $name (already installed)"; continue; fi
    if ln -s "$src" "$link" 2>/dev/null; then
      created+=("$link")
      echo "installed $name -> $link"
    else
      echo "error: link failed for $name -- rolling back this run's links" >&2
      if [ ${#created[@]} -gt 0 ]; then
        for c in "${created[@]}"; do rm -f "$c"; done
      fi
      exit 1
    fi
  done
  write_lock
  echo "pack $pack_name: ${#names[@]} members installed or already present"
  exit 0
fi

mkdir -p "$target"
for name in "${names[@]}"; do
  src="$root/skills/$name"
  link="$target/$name"
  if [ "$mode" = "remove" ]; then
    if [ -L "$link" ]; then
      case "$(readlink "$link")" in
        "$root"/*) rm "$link"; echo "removed  $name" ;;
        *) echo "skip     $name: $link points outside this clone" ;;
      esac
    else
      echo "skip     $name: no symlink at $link"
    fi
    continue
  fi
  [ -f "$src/SKILL.md" ] || { echo "error: no skill at skills/$name" >&2; exit 2; }
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$src" ]; then echo "ok       $name (already installed)"; continue; fi
    echo "skip     $name: $link already points at $(readlink "$link") -- remove it first" >&2
    continue
  elif [ -e "$link" ]; then
    echo "skip     $name: $link exists and is not a symlink -- move it aside first" >&2
    continue
  fi
  ln -s "$src" "$link"
  echo "installed $name -> $link"
done
