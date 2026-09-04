#!/usr/bin/env bash
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
CUSTODY="$SKILL/scripts/source-custody.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-builder-custody.XXXXXX")"
T="$(CDPATH='' cd -P "$T" && pwd)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out" ERR="$T/err"; pass=0 fail=0 rc=0

eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL: $1 expected=[$2] actual=[$3]" >&2; fail=$((fail+1)); fi; }
has(){ if grep -Fq -- "$2" "$1"; then pass=$((pass+1)); else echo "FAIL: missing [$2] in $1" >&2; fail=$((fail+1)); fi; }
run(){ local cwd="$1" source="$2"; rc=0; (cd "$cwd" && HOME="$T/home" GRIMOIRE_HOME="${3:-$T/manager}" "$CUSTODY" inspect "$source") >"$OUT" 2>"$ERR" || rc=$?; }
fact(){ sed -n "s/^$1=//p" "$OUT"; }

mkdir -p "$T/home" "$T/repo/skills/demo"
git -C "$T/repo" init -q
printf '%s\n' '---' 'name: demo' 'description: Test.' '---' '# Demo' >"$T/repo/skills/demo/SKILL.md"
git -C "$T/repo" add .
git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -qm init
before="$(git -C "$T/repo" status --short)"

run "$T/repo" demo
eq 'bare slug accepted' 0 "$rc"
has "$OUT" "physical-package-root=$T/repo/skills/demo"
has "$OUT" 'declared-name=demo'
has "$OUT" "git-root=$T/repo"
has "$OUT" 'tracked=yes'
has "$OUT" 'immutable=no'
has "$OUT" 'custodied=yes'
eq 'success emits concise facts' 7 "$(wc -l <"$OUT" | tr -d ' ')"

for source in skills/demo skills/demo/SKILL.md "$T/repo/skills/demo"; do
  run "$T/repo" "$source"
  eq "source form $source accepted" 0 "$rc"
  eq "source form $source resolves physically" "$T/repo/skills/demo" "$(fact physical-package-root)"
done

run "$T/repo" missing
eq 'missing target refuses' 2 "$rc"
has "$ERR" 'reason=invalid-source'

mkdir -p "$T/repo/sub/demo"
printf '%s\n' '---' 'name: demo' 'description: Collision.' '---' >"$T/repo/sub/demo/SKILL.md"
run "$T/repo/sub" demo
eq 'relative package and bare slug collision refuses' 2 "$rc"
has "$ERR" 'reason=ambiguous-source'
rm -rf "$T/repo/sub"

mkdir -p "$T/untracked/demo"
cp "$T/repo/skills/demo/SKILL.md" "$T/untracked/demo/SKILL.md"
run "$T/repo" "$T/untracked/demo"
has "$OUT" 'tracked=no'
has "$OUT" 'custodied=no'

mkdir -p "$T/repo/skills/wrong"
printf '%s\n' '---' 'name: other' 'description: Test.' '---' >"$T/repo/skills/wrong/SKILL.md"
git -C "$T/repo" add skills/wrong/SKILL.md
run "$T/repo" wrong
has "$OUT" 'name-matches-directory=no'
has "$OUT" 'custodied=no'

mkdir -p "$T/no-git/demo"
cp "$T/repo/skills/demo/SKILL.md" "$T/no-git/demo/SKILL.md"
run "$T/repo" "$T/no-git/demo"
has "$OUT" 'git-root=absent'
has "$OUT" 'custodied=no'

mkdir -p "$T/symlink-manifest/demo"
ln -s "$T/repo/skills/demo/SKILL.md" "$T/symlink-manifest/demo/SKILL.md"
run "$T/repo" "$T/symlink-manifest/demo"
eq 'symlinked manifest refuses' 2 "$rc"
has "$ERR" 'reason=invalid-manifest'

LOOK="$T/manager/store/checkouts/key/snapshot/skills/demo"
mkdir -p "$LOOK"
cp "$T/repo/skills/demo/SKILL.md" "$LOOK/SKILL.md"
git -C "$T/manager/store/checkouts/key/snapshot" init -q
git -C "$T/manager/store/checkouts/key/snapshot" add .
run "$T/repo" "$LOOK" "$T/manager"
has "$OUT" 'immutable=yes'
has "$OUT" 'custodied=no'

eq 'helper leaves repository state unchanged' "$before" "$(git -C "$T/repo" status --short | grep -v '^A  skills/wrong/SKILL.md' || true)"

printf 'source-custody-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
