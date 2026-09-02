#!/usr/bin/env bash
# layer-status-test.sh — public-state classification without workspace state.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; STATUS="$SKILL/scripts/records-layer-status.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-layer-status.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

run_status() { "$STATUS" setup --root "$1" >"$OUT" 2>"$ERR"; }
fact_value() { sed -n "s/^$1=//p" "$OUT" | head -n 1; }
init_repo() {
  mkdir -p "$1"; git -C "$1" init -q
  git -C "$1" config user.name Fixture; git -C "$1" config user.email fixture@example.invalid
}
install_layer() {
  mkdir -p "$1/.records"
  cp "$SKILL/scripts/records.sh" "$1/.records/records.sh"; chmod 755 "$1/.records/records.sh"
  : >"$1/.records/history.tsv"
  cp "$SKILL/templates/records-readme-block.md" "$1/.records/README.md"
}

plain="$TMP/plain"; mkdir -p "$plain"; ln -s "$TMP/missing" "$plain/.spaces"
run_status "$plain"
expect_eq "unwitnessed root can initialize" uninitialized "$(fact_value recovery_state)"
expect_eq "workspace symlink is ignored" absent "$(fact_value layer_status)"

healthy="$TMP/healthy"; mkdir -p "$healthy"; install_layer "$healthy"
mkdir -p "$healthy/.spaces/journal"; printf 'old-looking\n' >"$healthy/.spaces/journal/setup.intent"
run_status "$healthy"
expect_eq "healthy ledger initializes layer" initialized "$(fact_value recovery_state)"
expect_eq "canonical provider is current" current "$(fact_value provider_status)"
expect_eq "managed block is current" current "$(fact_value readme_status)"

tracked="$TMP/tracked"; init_repo "$tracked"; mkdir -p "$tracked/.records"
: >"$tracked/.records/history.tsv"; git -C "$tracked" add .records/history.tsv
git -C "$tracked" commit -qm ledger; rm "$tracked/.records/history.tsv"
cp "$SKILL/templates/records-readme-block.md" "$tracked/.records/README.md"
run_status "$tracked"
expect_eq "HEAD ledger wins over README witness" git-restore "$(fact_value recovery_state)"

managed="$TMP/managed"; mkdir -p "$managed/.records"
sed 's/## Use the records tool/## Drifted records tool/' \
  "$SKILL/templates/records-readme-block.md" >"$managed/.records/README.md"
run_status "$managed"
expect_eq "drifted managed block witnesses loss" human-review "$(fact_value recovery_state)"

archived="$TMP/archived"; mkdir -p "$archived/.records/notes"
printf '%s\n' '---' 'doctype: notes' 'status: archived' 'schema: notepad/note@1' 'tags: []' \
  '---' '# Closed' >"$archived/.records/notes/2026-09-02-closed.md"
run_status "$archived"
expect_eq "archived record witnesses loss" human-review "$(fact_value recovery_state)"
expect_eq "archived witness fact" present "$(fact_value archived_witness)"

decoys="$TMP/decoys"; mkdir -p "$decoys/.records/notes"
printf '%s\n' '---' 'doctype: notes' 'status: published' '---' '# Body' 'status: archived' \
  >"$decoys/.records/notes/2026-09-02-body-only.md"
printf '%s\n' '---' 'doctype: notes' 'status: archived' '---' \
  >"$decoys/.records/notes/undated.md"
printf '%s\n' '---' 'status: archived' '---' \
  >"$decoys/.records/notes/2026-09-02-no-doctype.md"
printf '%s\n' '---' 'doctype: notes' 'status: archived' \
  >"$decoys/.records/notes/2026-09-02-unterminated.md"
ln -s "$archived/.records/notes/2026-09-02-closed.md" \
  "$decoys/.records/notes/2026-09-02-symlink.md"
run_status "$decoys"
expect_eq "decoys do not witness loss" absent "$(fact_value archived_witness)"
expect_eq "decoys permit initialization" uninitialized "$(fact_value recovery_state)"

malformed="$TMP/malformed"; mkdir -p "$malformed/.records"
printf '%s\n' '<!-- journal:records-tool BEGIN -->' >"$malformed/.records/README.md"
run_status "$malformed"
expect_eq "malformed marker is unsafe" unsafe "$(fact_value recovery_state)"

unsafe="$TMP/unsafe"; mkdir -p "$unsafe/target"; ln -s "$unsafe/target" "$unsafe/.records"
run_status "$unsafe"
expect_eq "symlinked records root is unsafe" unsafe "$(fact_value recovery_state)"

# Mutation proof: the fixture catches a helper that starts treating workspace residue as state.
mutant="$TMP/mutant-skill"; mkdir -p "$mutant/scripts" "$mutant/templates"
cp "$STATUS" "$mutant/scripts/records-layer-status.sh"
cp "$SKILL/scripts/records.sh" "$mutant/scripts/records.sh"
cp "$SKILL/scripts/records-readme-status.sh" "$mutant/scripts/records-readme-status.sh"
cp "$SKILL/templates/records-readme-block.md" "$mutant/templates/records-readme-block.md"
chmod 755 "$mutant/scripts/"*.sh
sed -i.bak '/root="$(CDPATH/a\
[ ! -e "$root/.spaces" ] || die workspace-state' "$mutant/scripts/records-layer-status.sh"
rm "$mutant/scripts/records-layer-status.sh.bak"
rc=0; "$mutant/scripts/records-layer-status.sh" setup --root "$healthy" >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -ne 0 ]; then pass=$((pass + 1)); else
  echo 'FAIL: workspace-dependency mutant survived' >&2; fail=$((fail + 1))
fi

report layer-status-test
