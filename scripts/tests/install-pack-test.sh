#!/usr/bin/env bash
set -euo pipefail

repo="$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-pack-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_faceless_lock() {
  python3 - "$1" <<'PY'
import json, sys

with open(sys.argv[1]) as handle:
    lock = json.load(handle)
entry = lock["packs"]["clankshop"]
assert entry["version"] == "3.1.0", entry
assert entry["manifest"]["name"] == "clankshop", entry
assert entry["manifest"]["required"] == "journal", entry
assert "clankshop" not in entry["skills"], entry
assert entry["skills"]["journal"]["required"] is True, entry
PY
}

target="$tmp/project/skills"
lock="$tmp/project/grimoire.lock"

"$repo/install.sh" --target "$target" --pack clankshop
[ -L "$target/journal" ] || fail "required member was not installed"
[ -L "$target/workspace" ] || fail "workspace member was not installed"
[ ! -e "$target/clankshop" ] && [ ! -L "$target/clankshop" ] \
  || fail "faceless pack installed an implicit face"
assert_faceless_lock "$lock"

list_out="$tmp/list.out"
"$repo/install.sh" --target "$target" --list >"$list_out"
grep -Eq '^  clankshop[[:space:]]+v3\.1\.0' "$list_out" \
  || fail "list did not render the root faceless pack"

"$repo/install.sh" --target "$target" --check --pack clankshop

mv "$target/journal" "$tmp/journal.link"
if "$repo/install.sh" --target "$target" --check --pack clankshop >"$tmp/check.out" 2>&1; then
  fail "check accepted a missing required member"
fi
grep -q 'required-member-missing journal' "$tmp/check.out" \
  || fail "check did not report the missing required member"
mv "$tmp/journal.link" "$target/journal"

# Reinstall is the upgrade path from the old faced shape: the stale face entry
# and link are removed as members no longer declared by the new release.
ln -s "$repo/skills/clankshop" "$target/clankshop"
python3 - "$lock" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as handle:
    lock = json.load(handle)
lock["packs"]["clankshop"]["skills"]["clankshop"] = {
    "hash": "sha256:retired-face",
    "required": True,
}
with open(path, "w") as handle:
    json.dump(lock, handle, indent=2)
    handle.write("\n")
PY
"$repo/install.sh" --target "$target" --pack clankshop
[ ! -e "$target/clankshop" ] && [ ! -L "$target/clankshop" ] \
  || fail "reinstall retained the retired face"
assert_faceless_lock "$lock"

# A faceless check must use the cached manifest, not the source tree.
cp "$lock" "$tmp/lock.with-manifest"
python3 - "$lock" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as handle:
    lock = json.load(handle)
del lock["packs"]["clankshop"]["manifest"]
with open(path, "w") as handle:
    json.dump(lock, handle)
    handle.write("\n")
PY
if "$repo/install.sh" --target "$target" --check --pack clankshop >"$tmp/cache.out" 2>&1; then
  fail "check accepted a faceless lock with no cached manifest"
fi
grep -q 'cached-manifest-missing' "$tmp/cache.out" \
  || fail "check did not use the cached faceless manifest"
mv "$tmp/lock.with-manifest" "$lock"

"$repo/install.sh" --target "$target" --remove --pack clankshop
[ ! -e "$target/journal" ] || fail "remove left the required member installed"
python3 - "$lock" <<'PY'
import json, sys

with open(sys.argv[1]) as handle:
    lock = json.load(handle)
assert "clankshop" not in lock.get("packs", {}), lock
PY

before_unknown="$tmp/before-unknown"
cp "$lock" "$before_unknown"
if "$repo/install.sh" --target "$target" --pack grimoire >"$tmp/unknown.out" 2>&1; then
  fail "reserved pack name grimoire unexpectedly resolved"
fi
cmp -s "$before_unknown" "$lock" || fail "unknown pack changed the lock"

for bad in unparseable newer; do
  bad_root="$tmp/$bad"
  bad_target="$bad_root/skills"
  bad_lock="$bad_root/grimoire.lock"
  mkdir -p "$bad_root"
  case "$bad" in
    unparseable) printf '%s\n' 'not json' >"$bad_lock" ;;
    newer) printf '%s\n' '{"version": 2, "packs": {}}' >"$bad_lock" ;;
  esac
  cp "$bad_lock" "$bad_root/before.lock"
  if "$repo/install.sh" --target "$bad_target" --pack clankshop >"$bad_root/out" 2>&1; then
    fail "$bad lock unexpectedly allowed install"
  fi
  cmp -s "$bad_root/before.lock" "$bad_lock" || fail "$bad lock changed"
  [ ! -e "$bad_target/journal" ] || fail "$bad lock failure left member links"
done

unwritable_root="$tmp/unwritable"
mkdir -p "$unwritable_root/skills"
printf '%s\n' '{"version": 1, "packs": {}}' >"$unwritable_root/grimoire.lock"
cp "$unwritable_root/grimoire.lock" "$tmp/unwritable.before"
chmod 500 "$unwritable_root"
if "$repo/install.sh" --target "$unwritable_root/skills" --pack clankshop \
    >"$tmp/unwritable.out" 2>&1; then
  chmod 700 "$unwritable_root"
  fail "unwritable lock path unexpectedly allowed install"
fi
chmod 700 "$unwritable_root"
grep -q 'lock commit failed' "$tmp/unwritable.out" \
  || fail "unwritable fixture did not reach the lock commit"
cmp -s "$tmp/unwritable.before" "$unwritable_root/grimoire.lock" \
  || fail "unwritable lock changed"
[ ! -e "$unwritable_root/skills/journal" ] \
  || fail "lock write failure left member links"

forbidden_hits() {
  local face_path="skills/clan""kshop"
  local invocation="/clan""kshop[[:space:]]+(setup|migrate|check)"
  local stamp="Seeded from clan""kshop"
  local loader="doctrine/scripts/context""\.sh[[:space:]]+(design|build|test|review)"
  rg -n -e "$face_path" -e "$invocation" -e "$stamp" -e "$loader" "$@"
}

live=(
  "$repo/AGENTS.md"
  "$repo/README.md"
  "$repo/install.sh"
  "$repo/PACK.md"
  "$repo/docs/spec"
  "$repo/skills"
  "$repo/crates"
)
if hits="$(forbidden_hits "${live[@]}" 2>/dev/null)"; then
  printf '%s\n' "$hits" >&2
  fail "retired face/composition references remain in live surfaces"
fi

# Red-proof the absence population without mutating the live tree.
mkdir -p "$tmp/red-proof"
printf '%s\n' "skills/clan""kshop" >"$tmp/red-proof/forbidden.md"
forbidden_hits "$tmp/red-proof" >/dev/null 2>&1 \
  || fail "absence gate did not detect a planted retired face path"

echo "install-pack-test: ok"
