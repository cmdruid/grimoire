#!/usr/bin/env bash
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
CUSTODY="$SKILL/scripts/source-custody.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-builder-custody.XXXXXX")"
T="$(CDPATH='' cd -P "$T" && pwd)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out" ERR="$T/err"; pass=0 fail=0 rc=0

ok(){ if "$@"; then pass=$((pass+1)); else echo "FAIL: $*" >&2; fail=$((fail+1)); fi; }
eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL: $1 expected=[$2] actual=[$3]" >&2; fail=$((fail+1)); fi; }
has(){ if grep -Fq -- "$2" "$1"; then pass=$((pass+1)); else echo "FAIL: missing [$2] in $1" >&2; fail=$((fail+1)); fi; }
run(){ local cwd="$1" source="$2"; rc=0; (cd "$cwd" && HOME="$T/home" GRIMOIRE_HOME="${3:-$T/manager}" "$CUSTODY" inspect "$source") >"$OUT" 2>"$ERR" || rc=$?; }
fact(){ sed -n "s/^$1=//p" "$OUT"; }

mkdir -p "$T/home" "$T/repo/skills/demo"
git -C "$T/repo" init -q
printf '%s\n' '---' 'name: demo' 'description: Test.' '---' '' '# Demo' >"$T/repo/skills/demo/SKILL.md"
printf '%s\n' '#!/usr/bin/env bash' 'echo demo' >"$T/repo/skills/demo/check.sh"
chmod 644 "$T/repo/skills/demo/check.sh"
git -C "$T/repo" add .
git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -qm init
head="$(git -C "$T/repo" rev-parse HEAD)"
before="$(git -C "$T/repo" status --short)"

run "$T/repo" demo
eq 'bare slug accepted' 0 "$rc"
has "$OUT" "physical-package-root=$T/repo/skills/demo"
has "$OUT" 'declared-name=demo'
has "$OUT" "git-root=$T/repo"
has "$OUT" "head=$head"
has "$OUT" 'tracked=yes'
has "$OUT" 'immutable=no'
has "$OUT" 'custodied=yes'
ok grep -Eq '^package-sha256=[0-9a-f]{64}$' "$OUT"
ok grep -Eq '^head=[0-9a-f]+$' "$OUT"
eq 'success emits the exact fact count' 9 "$(wc -l <"$OUT" | tr -d ' ')"
if grep -Eq '^(apply|action|reason)=' "$OUT"; then
  echo 'FAIL: success output contains a recommendation or diagnostic' >&2; fail=$((fail+1))
else
  pass=$((pass+1))
fi
digest="$(fact package-sha256)"
eq 'known frame digest' '66ab2cd1a05dfef8f3dfd3ec7433ef4d1d72f769ab8856fe6831d22d36a9fb06' "$digest"

for source in skills/demo skills/demo/SKILL.md "$T/repo/skills/demo"; do
  run "$T/repo" "$source"
  eq "source form $source accepted" 0 "$rc"
  eq "source form $source resolves physically" "$T/repo/skills/demo" "$(fact physical-package-root)"
  eq "source form $source keeps digest" "$digest" "$(fact package-sha256)"
done

run "$T/repo" missing
eq 'missing target refuses' 2 "$rc"
has "$ERR" 'reason=invalid-source'

mkdir -p "$T/repo/sub/demo"
printf '%s\n' '---' 'name: demo' 'description: Local collision.' '---' >"$T/repo/sub/demo/SKILL.md"
git -C "$T/repo" add sub/demo/SKILL.md
git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -qm collision
run "$T/repo/sub" demo
eq 'relative package and bare slug collision refuses' 2 "$rc"
has "$ERR" 'reason=ambiguous-source'

printf 'dirty\n' >>"$T/repo/skills/demo/check.sh"
run "$T/repo" demo; dirty="$(fact package-sha256)"
ok test "$dirty" != "$digest"
git -C "$T/repo" checkout -q -- skills/demo/check.sh

printf 'ignored.bin\n' >"$T/repo/skills/demo/.gitignore"
printf 'one\n' >"$T/repo/skills/demo/ignored.bin"
run "$T/repo" demo; ignored_one="$(fact package-sha256)"
printf 'two\n' >"$T/repo/skills/demo/ignored.bin"
run "$T/repo" demo; ignored_two="$(fact package-sha256)"
ok test "$ignored_one" != "$ignored_two"
rm "$T/repo/skills/demo/.gitignore" "$T/repo/skills/demo/ignored.bin"

run "$T/repo" demo; nonexec="$(fact package-sha256)"
chmod +x "$T/repo/skills/demo/check.sh"
run "$T/repo" demo; executable="$(fact package-sha256)"
ok test "$nonexec" != "$executable"
chmod 644 "$T/repo/skills/demo/check.sh"

ln -s first "$T/repo/skills/demo/link"
run "$T/repo" demo; link_one="$(fact package-sha256)"
rm "$T/repo/skills/demo/link"; ln -s second "$T/repo/skills/demo/link"
run "$T/repo" demo; link_two="$(fact package-sha256)"
ok test "$link_one" != "$link_two"
rm "$T/repo/skills/demo/link"

printf 'one\n' >"$T/repo/skills/demo/line
break"
run "$T/repo" demo; newline_one="$(fact package-sha256)"
printf 'two\n' >"$T/repo/skills/demo/line
break"
run "$T/repo" demo; newline_two="$(fact package-sha256)"
ok test "$newline_one" != "$newline_two"
rm "$T/repo/skills/demo/line
break"

run "$T/repo" demo; no_admin="$(fact package-sha256)"
mkdir -p "$T/repo/skills/demo/.git"
printf 'volatile one\n' >"$T/repo/skills/demo/.git/state"
run "$T/repo" demo; admin_one="$(fact package-sha256)"
printf 'volatile two\n' >"$T/repo/skills/demo/.git/state"
run "$T/repo" demo; admin_two="$(fact package-sha256)"
eq 'Git administrative bytes excluded' "$no_admin" "$admin_one"
eq 'Git administrative changes excluded' "$admin_one" "$admin_two"
rm -rf "$T/repo/skills/demo/.git"

mkdir -p "$T/untracked/demo"
cp "$T/repo/skills/demo/SKILL.md" "$T/untracked/demo/SKILL.md"
chmod -R u+w "$T/untracked"
run "$T/repo" "$T/untracked/demo"
eq 'untracked source is facts, not helper failure' 0 "$rc"
has "$OUT" 'tracked=no'
has "$OUT" 'custodied=no'

mkdir -p "$T/repo/skills/bad-name"
printf '%s\n' '---' 'name: Bad Name' 'description: Test.' '---' >"$T/repo/skills/bad-name/SKILL.md"
git -C "$T/repo" add skills/bad-name/SKILL.md
git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -qm bad-name
run "$T/repo" bad-name
has "$OUT" 'name-matches-directory=no'
has "$OUT" 'custodied=no'

mkdir -p "$T/no-git/demo"
cp "$T/repo/skills/demo/SKILL.md" "$T/no-git/demo/SKILL.md"
run "$T/repo" "$T/no-git/demo"
has "$OUT" 'git-root=absent'
has "$OUT" 'head=absent'
has "$OUT" 'custodied=no'

mkdir -p "$T/unborn/demo"
git -C "$T/unborn" init -q
cp "$T/repo/skills/demo/SKILL.md" "$T/unborn/demo/SKILL.md"
git -C "$T/unborn" add demo/SKILL.md
run "$T/repo" "$T/unborn/demo"
has "$OUT" 'tracked=yes'
has "$OUT" 'head=absent'
has "$OUT" 'custodied=no'

mkdir -p "$T/symlink-manifest/demo"
ln -s "$T/repo/skills/demo/SKILL.md" "$T/symlink-manifest/demo/SKILL.md"
run "$T/repo" "$T/symlink-manifest/demo"
eq 'symlinked manifest refuses' 2 "$rc"
has "$ERR" 'reason=invalid-manifest'

mkdir -p "$T/repo/skills/wrong"
printf '%s\n' '---' 'name: other' 'description: Test.' '---' >"$T/repo/skills/wrong/SKILL.md"
git -C "$T/repo" add skills/wrong/SKILL.md
git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -qm wrong
run "$T/repo" wrong
has "$OUT" 'declared-name=other'
has "$OUT" 'name-matches-directory=no'
has "$OUT" 'custodied=no'

LOOK="$T/manager/store/checkouts-copy/key/snapshot"
mkdir -p "$LOOK/skills/demo"
cp "$T/repo/skills/demo/SKILL.md" "$LOOK/skills/demo/SKILL.md"
git -C "$LOOK" init -q
git -C "$LOOK" add .
git -C "$LOOK" -c user.name=test -c user.email=test@example.invalid commit -qm init
run "$T/repo" "$LOOK/skills/demo" "$T/manager"
has "$OUT" 'immutable=no'
has "$OUT" 'custodied=yes'

mkdir -p "$T/unsafe-manager" "$T/store-target"
ln -s "$T/store-target" "$T/unsafe-manager/store"
run "$T/repo" "$T/repo/skills/demo" "$T/unsafe-manager"
has "$OUT" 'immutable=unknown'
has "$OUT" 'custodied=no'

mkdir -p "$T/manager/store/checkouts/key/snapshot/skills/demo"
cp "$T/repo/skills/demo/SKILL.md" "$T/manager/store/checkouts/key/snapshot/skills/demo/SKILL.md"
git -C "$T/manager/store/checkouts/key/snapshot" init -q
git -C "$T/manager/store/checkouts/key/snapshot" add .
git -C "$T/manager/store/checkouts/key/snapshot" -c user.name=test -c user.email=test@example.invalid commit -qm init
run "$T/repo" "$T/manager/store/checkouts/key/snapshot/skills/demo" "$T/manager"
has "$OUT" 'immutable=yes'
has "$OUT" 'custodied=no'

ln -s "$T/untracked/demo" "$T/untracked-link"
run "$T/repo" "$T/untracked-link"
has "$OUT" 'physical-package-root='
has "$OUT" 'tracked=no'
has "$OUT" 'custodied=no'

chmod -R a-w "$T/repo/skills/demo"
run "$T/repo" demo
has "$OUT" 'custodied=yes'
chmod -R u+w "$T/repo/skills/demo"

mkfifo "$T/repo/skills/demo/pipe"
run "$T/repo" demo
eq 'unsupported entry refuses' 2 "$rc"
has "$ERR" 'reason=unsupported-entry'
rm "$T/repo/skills/demo/pipe"

eq 'helper leaves repository state unchanged except fixture changes' "$before" "$(git -C "$T/repo" status --short | grep -v '^?? skills/wrong/' || true)"

printf 'source-custody-test: pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
