#!/usr/bin/env bash
# install.sh -- wire grimoire skills into an agent harness via symlinks.
#
# Usage:
#   ./install.sh <skill> [<skill>...]      install named skills
#   ./install.sh --pack <name>             install or reinstall a pack
#   ./install.sh --check --pack <name>     check an installed pack from its lock
#   ./install.sh --remove --pack <name>    remove an installed pack
#   ./install.sh --remove <skill>...       remove installed symlinks owned by this clone
#   ./install.sh --list                    show skills, packs, and install state
#   ./install.sh --target <dir> ...        override target dir (default: ~/.claude/skills)
#
# Packs follow docs/spec/pack-format.md (format 1). Both faced manifests beside
# SKILL.md and a faceless repository-root PACK.md are supported. Pack operations
# use the sidecar grimoire.lock and require python3 for lossless JSON updates.
set -euo pipefail

root="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
target="$HOME/.claude/skills"
mode="install"
names=()
pack_name=""
pack_manifest=""
pack_version=""
pack_description=""
pack_required_scalar=""
pack_optional_scalar=""
pack_required_words=""
pack_optional_words=""
pack_shape=""

frontmatter_key() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    index($0, k ":") == 1 {
      sub("^" k ":[[:space:]]*", "")
      if (substr($0, 1, 1) != "\"") sub(/[[:space:]]#.*$/, "")
      sub(/[[:space:]]+$/, "")
      print; exit
    }
  ' "$1"
}

unquote_scalar() {
  local value="$1"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
  esac
  printf '%s\n' "$value"
}

trim_token() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

resolve_pack() {
  local wanted="$1" manifest found=""
  for manifest in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$manifest" ] || continue
    if [ "$(frontmatter_key "$manifest" name)" = "$wanted" ]; then
      if [ -n "$found" ]; then
        echo "error: two PACK.md manifests declare name: $wanted" >&2
        return 2
      fi
      found="$manifest"
    fi
  done
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

append_manifest_members() {
  local scalar="$1" class="$2" token old_ifs="$IFS"
  IFS=','
  read -r -a tokens <<< "$scalar"
  IFS="$old_ifs"
  for token in "${tokens[@]}"; do
    token="$(trim_token "$token")"
    [ -n "$token" ] || {
      echo "error: $pack_manifest has an empty $class member" >&2
      return 1
    }
    printf '%s' "$token" | grep -Eq '^[a-z0-9-]+$' || {
      echo "error: invalid pack member name: $token" >&2
      return 1
    }
    case " $pack_required_words $pack_optional_words " in
      *" $token "*)
        echo "error: duplicate pack member: $token" >&2
        return 1 ;;
    esac
    if [ "$class" = "required" ]; then
      pack_required_words="${pack_required_words}${pack_required_words:+ }$token"
    else
      pack_optional_words="${pack_optional_words}${pack_optional_words:+ }$token"
    fi
  done
}

load_manifest() {
  local fmt pack_dir face status
  set +e
  pack_manifest="$(resolve_pack "$pack_name")"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    [ "$status" -ne 1 ] || echo "error: no PACK.md declares name: $pack_name (try --list)" >&2
    return 2
  fi
  fmt="$(frontmatter_key "$pack_manifest" format)"
  [ -z "$fmt" ] || [ "$fmt" = "1" ] || {
    echo "error: pack $pack_name declares format: $fmt -- this tool implements format 1" >&2
    return 2
  }
  pack_version="$(frontmatter_key "$pack_manifest" version)"
  pack_description="$(unquote_scalar "$(frontmatter_key "$pack_manifest" description)")"
  pack_required_scalar="$(unquote_scalar "$(frontmatter_key "$pack_manifest" required)")"
  pack_optional_scalar="$(unquote_scalar "$(frontmatter_key "$pack_manifest" optional)")"
  if [ -z "$pack_version" ] || ! printf '%s' "$pack_version" \
      | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$'; then
      echo "error: pack $pack_name has an invalid version: $pack_version" >&2
      return 2
  fi
  [ -n "$pack_description" ] || {
    echo "error: $pack_manifest has no description" >&2
    return 2
  }
  [ -n "$pack_required_scalar" ] || {
    echo "error: $pack_manifest has no required: line" >&2
    return 2
  }

  pack_required_words=""
  pack_optional_words=""
  append_manifest_members "$pack_required_scalar" required || return 2
  [ -z "$pack_optional_scalar" ] \
    || append_manifest_members "$pack_optional_scalar" optional || return 2

  pack_dir="$(CDPATH='' cd "$(dirname "$pack_manifest")" && pwd)"
  if [ -f "$pack_dir/SKILL.md" ]; then
    pack_shape="faced"
    face="$(frontmatter_key "$pack_dir/SKILL.md" name)"
    [ -n "$face" ] || face="$(basename "$pack_dir")"
    [ "$face" = "$pack_name" ] || {
      echo "error: face name $face != pack name: $pack_name" >&2
      return 2
    }
    case " $pack_required_words $pack_optional_words " in
      *" $face "*)
        echo "error: faced pack $pack_name lists its implicit face" >&2
        return 2 ;;
    esac
  elif [ "$pack_dir" = "$root" ]; then
    pack_shape="faceless"
    case " $pack_required_words $pack_optional_words " in
      *" $pack_name "*)
        echo "error: faceless pack $pack_name lists a member with its own name" >&2
        return 2 ;;
    esac
  else
    echo "error: faceless PACK.md must be at the repository root: $pack_manifest" >&2
    return 2
  fi
}

lock_path() {
  case "$target" in
    "$HOME"/.claude/*|"$HOME"/.agents/*|"$HOME"/.codex/*|"$HOME"/.cursor/*)
      printf '%s/.agents/grimoire.lock\n' "$HOME" ;;
    *)
      parent="$(CDPATH='' cd "$(dirname "$target")" && pwd)"
      case "$(basename "$parent")" in
        .agents|.claude|.codex|.cursor) project_root="$(dirname "$parent")" ;;
        *)                              project_root="$parent" ;;
      esac
      printf '%s/grimoire.lock\n' "$project_root" ;;
  esac
}

need_python() {
  command -v python3 >/dev/null 2>&1 || {
    echo "error: pack operations require python3 to update grimoire.lock safely" >&2
    return 1
  }
}

validate_lock() {
  python3 - "$1" <<'PY'
import json, os, sys

path = sys.argv[1]
if not os.path.exists(path):
    raise SystemExit(0)
try:
    with open(path) as handle:
        lock = json.load(handle)
except (OSError, ValueError) as error:
    print(f"lock-unparseable {path}: {error} -- left untouched", file=sys.stderr)
    raise SystemExit(1)
if lock.get("version", 1) > 1:
    print(f"lock-version {lock.get('version')} > 1 -- left untouched", file=sys.stderr)
    raise SystemExit(1)
if not isinstance(lock.get("packs", {}), dict):
    print(f"lock-unparseable {path}: packs is not an object -- left untouched", file=sys.stderr)
    raise SystemExit(1)
PY
}

lock_state() {
  python3 - "$1" "$2" <<'PY'
import json, os, sys

path, pack = sys.argv[1:]
if not os.path.exists(path):
    print("ABSENT")
    raise SystemExit(0)
with open(path) as handle:
    lock = json.load(handle)
entry = lock.get("packs", {}).get(pack)
if entry is None:
    print("ABSENT")
    raise SystemExit(0)
print("PRESENT")
print("MANIFEST" if isinstance(entry.get("manifest"), dict) else "NO_MANIFEST")
for name, member in sorted(entry.get("skills", {}).items()):
    required = "true" if member.get("required", False) else "false"
    print(f"MEMBER\t{name}\t{required}\t{member.get('hash', '')}")
PY
}

member_hash() {
  (
    CDPATH='' cd "$1" || exit 1
    find . \( -name .git -o -name node_modules \) -prune -o -type f -print \
      | sed 's|^\./||' | LC_ALL=C sort \
      | while IFS= read -r file; do printf '%s' "$file"; cat "./$file"; done \
      | if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi \
      | awk '{print "sha256:" $1}'
  )
}

write_lock() {
  local lock_file="$1" skills_lines="" name required hash ref timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ref="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)"
  for name in "${names[@]}"; do
    required=true
    case " $pack_optional_words " in *" $name "*) required=false ;; esac
    hash="$(member_hash "$root/skills/$name")"
    skills_lines="${skills_lines}${skills_lines:+
}$name	$hash	$required"
  done
  LOCK_FILE="$lock_file" PACK_NAME="$pack_name" PACK_VERSION="$pack_version" \
    PACK_DESCRIPTION="$pack_description" PACK_REQUIRED="$pack_required_scalar" \
    PACK_OPTIONAL="$pack_optional_scalar" PACK_SHAPE="$pack_shape" PACK_SOURCE="$root" \
    PACK_REF="$ref" PACK_TIMESTAMP="$timestamp" PACK_SKILLS="$skills_lines" \
    python3 - <<'PY'
import json, os, tempfile

path = os.environ["LOCK_FILE"]
pack = os.environ["PACK_NAME"]
lock = {"version": 1, "packs": {}}
if os.path.exists(path):
    with open(path) as handle:
        lock = json.load(handle)
if lock.get("version", 1) > 1:
    raise RuntimeError(f"lock-version {lock.get('version')} > 1 -- left untouched")

skills = {}
for line in os.environ.get("PACK_SKILLS", "").splitlines():
    name, digest, required = line.split("\t")
    skills[name] = {"hash": digest, "required": required == "true"}

entry = {
    "version": os.environ["PACK_VERSION"],
    "source": os.environ["PACK_SOURCE"],
    "installedAt": os.environ["PACK_TIMESTAMP"],
    "skills": skills,
}
if os.environ.get("PACK_REF"):
    entry["ref"] = os.environ["PACK_REF"]
if os.environ["PACK_SHAPE"] == "faceless":
    entry["manifest"] = {
        "name": pack,
        "version": os.environ["PACK_VERSION"],
        "description": os.environ["PACK_DESCRIPTION"],
        "required": os.environ["PACK_REQUIRED"],
        "optional": os.environ["PACK_OPTIONAL"],
    }
lock.setdefault("packs", {})[pack] = entry

directory = os.path.dirname(path)
os.makedirs(directory, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix=".grimoire.lock.", dir=directory)
try:
    with os.fdopen(fd, "w") as handle:
        json.dump(lock, handle, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
except BaseException:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
print(f"locked    {pack}@{entry['version']} -> {path}")
PY
}

drop_lock_entry() {
  local lock_file="$1"
  LOCK_FILE="$lock_file" PACK_NAME="$pack_name" python3 - <<'PY'
import json, os, tempfile

path, pack = os.environ["LOCK_FILE"], os.environ["PACK_NAME"]
with open(path) as handle:
    lock = json.load(handle)
lock.get("packs", {}).pop(pack, None)
directory = os.path.dirname(path)
fd, temporary = tempfile.mkstemp(prefix=".grimoire.lock.", dir=directory)
try:
    with os.fdopen(fd, "w") as handle:
        json.dump(lock, handle, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
except BaseException:
    try:
        os.unlink(temporary)
    except OSError:
        pass
    raise
PY
}

member_referenced_elsewhere() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys

path, removed_pack, member = sys.argv[1:]
with open(path) as handle:
    lock = json.load(handle)
for name, entry in lock.get("packs", {}).items():
    if name != removed_pack and member in entry.get("skills", {}):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

remove_owned_link() {
  local name="$1" link destination
  link="$target/$name"
  if [ -L "$link" ]; then
    destination="$(readlink "$link")"
    case "$destination" in
      "$root"/*) rm "$link"; echo "removed  $name" ;;
      *) echo "skip     $name: $link points outside this clone" ;;
    esac
  elif [ -e "$link" ]; then
    echo "skip     $name: $link is not an owned symlink"
  else
    echo "skip     $name: no symlink at $link"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pack)
      [ $# -ge 2 ] || { echo "error: --pack needs a name" >&2; exit 2; }
      pack_name="$2"; shift ;;
    --check) mode="check" ;;
    --remove) mode="remove" ;;
    --list) mode="list" ;;
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
  for skill_dir in "$root"/skills/*/; do
    name="$(basename "$skill_dir")"
    state="-"
    [ -L "$target/$name" ] && state="installed -> $(readlink "$target/$name")"
    printf '  %-14s %s\n' "$name" "$state"
  done
  echo "packs (PACK.md manifests):"
  for manifest in "$root/PACK.md" "$root"/skills/*/PACK.md; do
    [ -f "$manifest" ] || continue
    printf '  %-14s v%-8s %s\n' "$(frontmatter_key "$manifest" name)" \
      "$(frontmatter_key "$manifest" version)" "$(frontmatter_key "$manifest" required)"
  done
  exit 0
fi

if [ -n "$pack_name" ] && [ ${#names[@]} -gt 0 ]; then
  echo "error: pack and individual skill operands cannot be mixed" >&2
  exit 2
fi

if [ "$mode" = "check" ] && [ -z "$pack_name" ]; then
  echo "error: --check requires --pack <name>" >&2
  exit 2
fi

if [ -n "$pack_name" ]; then
  need_python || exit 1
  lock_file="$(lock_path)"

  if [ "$mode" = "install" ]; then
    load_manifest || exit $?
    validate_lock "$lock_file" || exit 1
    old_state="$(lock_state "$lock_file" "$pack_name")"
    existing=false
    [ "$(printf '%s\n' "$old_state" | head -n 1)" = "PRESENT" ] && existing=true

    names=()
    if [ "$pack_shape" = "faced" ]; then names+=("$pack_name"); fi
    for name in $pack_required_words; do names+=("$name"); done
    for name in $pack_optional_words; do
      if [ "$existing" = false ] || printf '%s\n' "$old_state" \
          | awk -F '\t' -v wanted="$name" \
              '$1 == "MEMBER" && $2 == wanted { found = 1 } END { exit !found }'; then
        names+=("$name")
      fi
    done

    fail=0
    for name in "${names[@]}"; do
      src="$root/skills/$name"
      link="$target/$name"
      if [ ! -f "$src/SKILL.md" ]; then
        echo "preflight: missing-member $name (no skills/$name/SKILL.md)" >&2
        fail=1
      fi
      if [ -L "$link" ]; then
        want="$(CDPATH='' cd -P "$src" 2>/dev/null && pwd || true)"
        got="$(CDPATH='' cd -P "$link" 2>/dev/null && pwd || true)"
        if [ -z "$want" ] || [ -z "$got" ] || [ "$got" != "$want" ]; then
          echo "preflight: collision $name ($link -> $(readlink "$link"))" >&2
          fail=1
        fi
      elif [ -e "$link" ]; then
        echo "preflight: collision $name ($link exists and is not a symlink)" >&2
        fail=1
      fi
    done
    [ "$fail" = 0 ] || {
      echo "abort: pack $pack_name preflight failed -- no partial install" >&2
      exit 1
    }

    mkdir -p "$target"
    created=()
    for name in "${names[@]}"; do
      src="$root/skills/$name"
      link="$target/$name"
      if [ -L "$link" ]; then
        echo "ok       $name (already installed)"
      elif ln -s "$src" "$link" 2>/dev/null; then
        created+=("$link")
        echo "installed $name -> $link"
      else
        echo "error: link failed for $name -- rolling back this run's links" >&2
        for created_link in "${created[@]}"; do rm -f "$created_link"; done
        exit 1
      fi
    done
    if ! write_lock "$lock_file"; then
      echo "error: lock commit failed -- rolling back this run's links" >&2
      for created_link in "${created[@]}"; do rm -f "$created_link"; done
      exit 1
    fi

    while IFS=$'\t' read -r kind old_name _; do
      [ "$kind" = "MEMBER" ] || continue
      current=false
      for name in "${names[@]}"; do [ "$name" = "$old_name" ] && current=true; done
      if [ "$current" = false ] \
          && ! member_referenced_elsewhere "$lock_file" "$pack_name" "$old_name"; then
        remove_owned_link "$old_name"
      fi
    done <<< "$old_state"
    echo "pack $pack_name: ${#names[@]} members installed or already present"
    exit 0
  fi

  validate_lock "$lock_file" || exit 1
  state="$(lock_state "$lock_file" "$pack_name")"
  if [ "$(printf '%s\n' "$state" | head -n 1)" != "PRESENT" ]; then
    echo "error: pack $pack_name is not installed in $lock_file" >&2
    exit 2
  fi

  if [ "$mode" = "check" ]; then
    broken=0
    has_manifest=false
    has_face_member=false
    while IFS=$'\t' read -r kind name required locked_hash; do
      case "$kind" in
        MANIFEST) has_manifest=true ;;
        MEMBER)
          [ "$name" = "$pack_name" ] && has_face_member=true
          link="$target/$name"
          if [ ! -e "$link" ]; then
            if [ "$required" = "true" ]; then
              echo "required-member-missing $name"
              broken=1
            else
              echo "optional-member-absent $name (fine)"
            fi
          else
            current_hash="$(member_hash "$link")"
            if [ "$current_hash" = "$locked_hash" ]; then
              echo "ok       $name"
            else
              echo "member-moved $name locked=$locked_hash current=$current_hash"
            fi
          fi ;;
      esac
    done <<< "$state"
    if [ "$has_manifest" = false ] && [ "$has_face_member" = false ]; then
      echo "cached-manifest-missing $pack_name"
      broken=1
    elif [ "$has_manifest" = false ] && [ ! -f "$target/$pack_name/PACK.md" ]; then
      echo "installed-manifest-missing $pack_name"
      broken=1
    fi
    [ "$broken" = 0 ] || exit 1
    echo "pack $pack_name: check complete"
    exit 0
  fi

  if [ "$mode" = "remove" ]; then
    while IFS=$'\t' read -r kind name _; do
      [ "$kind" = "MEMBER" ] || continue
      if member_referenced_elsewhere "$lock_file" "$pack_name" "$name"; then
        echo "retained $name (referenced by another pack)"
      else
        remove_owned_link "$name"
      fi
    done <<< "$state"
    drop_lock_entry "$lock_file"
    echo "pack $pack_name: removed"
    exit 0
  fi
fi

[ "$mode" != "check" ] || exit 2
[ ${#names[@]} -gt 0 ] || { echo "error: no skills named (try --list)" >&2; exit 2; }

mkdir -p "$target"
for name in "${names[@]}"; do
  src="$root/skills/$name"
  link="$target/$name"
  if [ "$mode" = "remove" ]; then
    remove_owned_link "$name"
    continue
  fi
  [ -f "$src/SKILL.md" ] || { echo "error: no skill at skills/$name" >&2; exit 2; }
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$src" ]; then
      echo "ok       $name (already installed)"
      continue
    fi
    echo "skip     $name: $link already points at $(readlink "$link") -- remove it first" >&2
    continue
  elif [ -e "$link" ]; then
    echo "skip     $name: $link exists and is not a symlink -- move it aside first" >&2
    continue
  fi
  ln -s "$src" "$link"
  echo "installed $name -> $link"
done
