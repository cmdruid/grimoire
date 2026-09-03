#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CUSTODY="$SKILL/scripts/source-custody.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-custody.XXXXXX")"
trap 'rm -rf "$T"' EXIT
H="$T/home"; new_home "$H"

make_skill_repo(){
  local repo="$1" name="$2" sub="${3:-skill}"
  mkdir -p "$repo/$sub"; git -C "$repo" init -q
  printf '%s\n' '---' "name: $name" 'description: Test.' '---' '' '# Test' > "$repo/$sub/SKILL.md"
  git -C "$repo" add .; git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm init
  printf '%s/%s\n' "$repo" "$sub"
}

SRC="$(make_skill_repo "$T/source" demo)"
mkdir -p "$T/installed"; cp "$SRC/SKILL.md" "$T/installed/SKILL.md"
HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed" > "$T/absent"
has "$T/absent" 'source=absent'
has "$T/absent" 'apply=analysis-only'

HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$SRC" > "$T/eligible"
has "$T/eligible" 'matching-skill=yes'
has "$T/eligible" 'tracked=yes'
has "$T/eligible" 'immutable=no'
has "$T/eligible" 'apply=eligible'

HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$T/installed" > "$T/direct"
has "$T/direct" 'direct-installed=yes'
has "$T/direct" 'apply=analysis-only'

ln -s "$SRC" "$T/installed-link"
HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed-link" --source "$SRC" > "$T/target"
has "$T/target" 'direct-installed=no'
has "$T/target" 'apply=eligible'

U="$T/untracked"; mkdir "$U"; cp "$SRC/SKILL.md" "$U/SKILL.md"
HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$U" > "$T/untracked.out"
has "$T/untracked.out" 'tracked=no'
has "$T/untracked.out" 'reason=untracked-source'

WRONG="$(make_skill_repo "$T/wrong" other)"
HOME="$H" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$WRONG" > "$T/wrong.out"
has "$T/wrong.out" 'matching-skill=no'
has "$T/wrong.out" 'reason=skill-mismatch'

G="$T/grimoire"; IMM="$(make_skill_repo "$G/store/checkouts/source-key/snapshot-key" demo)"
HOME="$H" GRIMOIRE_HOME="$G" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$IMM" > "$T/immutable"
has "$T/immutable" 'immutable=yes'
has "$T/immutable" 'reason=immutable-yes'
ln -s "$IMM" "$T/immutable-link"
HOME="$H" GRIMOIRE_HOME="$G" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$T/immutable-link" > "$T/immutable-link.out"
has "$T/immutable-link.out" 'immutable=yes'

LOOK="$(make_skill_repo "$G/store/checkouts-copy/source-key/snapshot-key" demo)"
HOME="$H" GRIMOIRE_HOME="$G" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$LOOK" > "$T/lookalike"
has "$T/lookalike" 'immutable=no'
has "$T/lookalike" 'apply=eligible'

ABSENT="$T/absent-manager"
HOME="$H" GRIMOIRE_HOME="$ABSENT" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$SRC" > "$T/no-manager"
has "$T/no-manager" 'immutable=no'

BAD="$T/bad-manager"; mkdir "$BAD" "$T/bad-store-target"; ln -s "$T/bad-store-target" "$BAD/store"
HOME="$H" GRIMOIRE_HOME="$BAD" "$CUSTODY" inspect --skill demo --installed "$T/installed" --source "$SRC" > "$T/unknown"
has "$T/unknown" 'immutable=unknown'
has "$T/unknown" 'apply=analysis-only'
has "$T/unknown" 'reason=immutable-unknown'

finish source-custody-test
