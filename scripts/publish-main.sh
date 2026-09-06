#!/usr/bin/env bash
# Publish an allowlisted product snapshot onto `main` from a source ref (default: `dev`).
# Uses git plumbing only: it never checks out `main` in the caller's worktree.
#
# Include list: scripts/main.allowlist
# Published .gitignore: scripts/main.gitignore
# Both are read from the source commit, not the working tree.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/publish-main.sh [--source REF] [--message TEXT]

Write a new `main` commit whose tree is the paths listed in
scripts/main.allowlist on REF. The caller's worktree is not switched.
Run this from `dev`.
EOF
  exit 2
}

SOURCE=dev
MESSAGE=""
ALLOWLIST_PATH=scripts/main.allowlist
GITIGNORE_PATH=scripts/main.gitignore

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

if [[ "$(git branch --show-current)" == "$DEST" ]]; then
  echo "publish-main: refuse to run with '$DEST' checked out; switch to $SOURCE and retry." >&2
  exit 1
fi

source_commit=$(git rev-parse --verify "${SOURCE}^{commit}")
short=$(git rev-parse --short "$source_commit")

for spec in "$ALLOWLIST_PATH" "$GITIGNORE_PATH"; do
  if ! git cat-file -e "${source_commit}:${spec}" 2>/dev/null; then
    echo "publish-main: '${spec}' is not in ${SOURCE} (${short})." >&2
    exit 1
  fi
done

ALLOWLIST=()
allowlist_tmp=$(mktemp)
gitignore_tmp=$(mktemp)
index=$(mktemp)
tree_work=$(mktemp -d)
trap 'rm -f "$allowlist_tmp" "$gitignore_tmp" "$index"; rm -rf "$tree_work"' EXIT

git show "${source_commit}:${ALLOWLIST_PATH}" >"$allowlist_tmp"
git show "${source_commit}:${GITIGNORE_PATH}" >"$gitignore_tmp"

while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  case "$line" in
    ''|\#*) continue ;;
  esac
  ALLOWLIST+=("$line")
done <"$allowlist_tmp"

if [[ ${#ALLOWLIST[@]} -eq 0 ]]; then
  echo "publish-main: '${ALLOWLIST_PATH}' in ${SOURCE} (${short}) lists no paths." >&2
  exit 1
fi

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

export GIT_INDEX_FILE=$index
export GIT_WORK_TREE=$tree_work

git read-tree --empty
git restore --source="$source_commit" --staged --worktree -- "${ALLOWLIST[@]}"

cp "$gitignore_tmp" "${tree_work}/.gitignore"
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
