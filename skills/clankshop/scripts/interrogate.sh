#!/bin/sh
# interrogate.sh <root> -- project facts for the setup interview (mechanics section 8):
# gate-command candidates from package manifests, trunk name, remote + issue-system
# presence, .gitmodules inventory, doc landmarks. Facts only, one key=value per line;
# every decision stays in the verb interview.
set -eu
ROOT=${1:-.}
ROOT=$(CDPATH='' cd "$ROOT" && pwd)
cd "$ROOT"

# --- git shape: trunk, remotes, issue system ---
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git_repo=1"
  echo "head_branch=$(git symbolic-ref --short -q HEAD || true)"
  trunk=""
  t=$(git symbolic-ref --short -q refs/remotes/origin/HEAD || true)
  [ -n "$t" ] && trunk=${t#origin/}
  if [ -z "$trunk" ]; then
    for c in main master trunk; do
      if git show-ref --verify -q "refs/heads/$c"; then trunk=$c; break; fi
    done
  fi
  echo "trunk=$trunk"
  echo "remotes=$(git remote | paste -sd, -)"
  origin_url=$(git remote get-url origin 2>/dev/null || true)
  case "$origin_url" in
    *github.com*)    echo "issue_system=github" ;;
    *gitlab*)        echo "issue_system=gitlab" ;;
    *bitbucket*)     echo "issue_system=bitbucket" ;;
    "")              echo "issue_system=none" ;;
    *)               echo "issue_system=unknown-remote" ;;
  esac
else
  echo "git_repo=0"
  echo "head_branch="
  echo "trunk="
  echo "remotes="
  echo "issue_system=none"
fi

# --- submodule inventory (.gitmodules is the declared list; gitlink truth is check facts) ---
if [ -f .gitmodules ]; then
  subs=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk '{print $2}' | paste -sd, -)
  echo "submodules=$subs"
  echo "submodule_count=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk 'END{print NR}')"
else
  echo "submodules="
  echo "submodule_count=0"
fi

# --- gate-command candidates from package manifests ---
manifests=""
gates=""
add_gate() { gates="${gates:+$gates,}$1"; }

if [ -f package.json ]; then
  manifests="package.json"
  runner="npm run"
  test_cmd="npm test"
  if [ -f pnpm-lock.yaml ]; then runner="pnpm run"; test_cmd="pnpm test"; fi
  if [ -f yarn.lock ]; then runner="yarn"; test_cmd="yarn test"; fi
  if [ -f bun.lockb ] || [ -f bun.lock ]; then runner="bun run"; test_cmd="bun test"; fi
  # Script names inside the "scripts" object only -- a dependency named "test" is not a gate.
  scripts=$(awk '
    /"scripts"[[:space:]]*:[[:space:]]*{/ { ins = 1; next }
    ins && /}/ { ins = 0 }
    ins && match($0, /"[A-Za-z0-9:_-]+"[[:space:]]*:/) {
      s = substr($0, RSTART + 1); sub(/".*$/, "", s); print s
    }
  ' package.json)
  for s in test lint typecheck check build; do
    if printf '%s\n' "$scripts" | grep -qx "$s"; then
      if [ "$s" = test ]; then add_gate "$test_cmd"; else add_gate "$runner $s"; fi
    fi
  done
fi
if [ -f Makefile ]; then
  manifests="${manifests:+$manifests,}Makefile"
  for t in test lint check build; do
    if grep -Eq "^$t:" Makefile; then add_gate "make $t"; fi
  done
fi
if [ -f Cargo.toml ]; then
  manifests="${manifests:+$manifests,}Cargo.toml"
  add_gate "cargo test"
fi
if [ -f go.mod ]; then
  manifests="${manifests:+$manifests,}go.mod"
  add_gate "go test ./..."
fi
if [ -f pyproject.toml ]; then
  manifests="${manifests:+$manifests,}pyproject.toml"
  if grep -q pytest pyproject.toml; then add_gate "pytest"; fi
fi
echo "manifests=$manifests"
echo "gate_candidates=$gates"

# --- doc landmarks (existing entry points and stores the interview builds around) ---
landmarks=""
for f in README.md AGENTS.md CLAUDE.md CONTRIBUTING.md GLOSSARY.md \
         docs .handbook .records .agents .github; do
  [ -e "$f" ] && landmarks="${landmarks:+$landmarks,}$f"
done
echo "landmarks=$landmarks"
