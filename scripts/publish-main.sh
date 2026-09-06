#!/usr/bin/env bash
# Publish an allowlisted product snapshot onto `main` from a source ref (default: `dev`).
# Uses git plumbing only: it never checks out `main` in the caller's worktree.
#
# Workshop paths stay on `dev`. `main` is a sequence of production trees, not a merge of `dev`.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/publish-main.sh [--source REF] [--message TEXT]

Write a new `main` commit whose tree is the allowlisted product paths from REF.
The caller's worktree is not switched. Run this from `dev`.
EOF
  exit 2
}

SOURCE=dev
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      [[ $# -ge 2 ]] || usage
      SOURCE=$2
      shift 2
      ;;
    --message)
      [[ $# -ge 2 ]] || usage
      MESSAGE=$2
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

DEST=main
ALLOWLIST=(
  crates
  Cargo.toml
  Cargo.lock
  README.md
  LICENSE
)

write_main_gitignore() {
  cat >"$1" <<'EOF'
TODO.md
/target
/repos/
.DS_Store
.agents/
.records/
.trackers/
.streams/
.spaces/
.workstreams/
AGENTS.md
DEVELOPMENT.md
grimoire.toml
grimoire.lock
EOF
}

if [[ "$(git branch --show-current)" == "$DEST" ]]; then
  echo "publish-main: refuse to run with '$DEST' checked out; switch to $SOURCE and retry." >&2
  exit 1
fi

source_commit=$(git rev-parse --verify "${SOURCE}^{commit}")
short=$(git rev-parse --short "$source_commit")

missing=0
for path in "${ALLOWLIST[@]}"; do
  if ! git cat-file -e "${source_commit}:${path}" 2>/dev/null; then
    echo "publish-main: '${path}' is not in ${SOURCE} (${short})." >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

index=$(mktemp)
tree_work=$(mktemp -d)
trap 'rm -f "$index"; rm -rf "$tree_work"' EXIT
export GIT_INDEX_FILE=$index
export GIT_WORK_TREE=$tree_work

git read-tree --empty
git restore --source="$source_commit" --staged --worktree -- "${ALLOWLIST[@]}"

write_main_gitignore "${tree_work}/.gitignore"
git add -- .gitignore

tree=$(git write-tree)
unset GIT_INDEX_FILE GIT_WORK_TREE

dest_exists=0
if git show-ref --verify --quiet "refs/heads/${DEST}"; then
  dest_exists=1
fi

if [[ -z "$MESSAGE" ]]; then
  if [[ "$dest_exists" -eq 1 ]]; then
    MESSAGE="Publish product snapshot from ${SOURCE} (${short})"
  else
    MESSAGE="Establish production snapshot from ${SOURCE} (${short})"
  fi
fi

if [[ "$dest_exists" -eq 1 ]]; then
  if [[ "$(git rev-parse "${DEST}^{tree}")" == "$tree" ]]; then
    echo "publish-main: ${DEST} already has this tree; nothing to publish."
    exit 0
  fi
  commit=$(git commit-tree "$tree" -p "$DEST" -m "$MESSAGE")
else
  commit=$(git commit-tree "$tree" -m "$MESSAGE")
fi
git update-ref "refs/heads/${DEST}" "$commit"

echo "publish-main: ${DEST} -> $(git rev-parse --short "$commit")  tree $(git rev-parse --short "$tree")"
echo "publish-main: source ${SOURCE} ${short}"
git ls-tree --name-only "$DEST"
