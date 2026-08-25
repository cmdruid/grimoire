#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/../.." && pwd)"
ENGINE="$SKILL/scripts/trackers.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
W=.spaces
RUN=(/bin/bash "$ENGINE" --root "$ROOT" --workspace "$W")
pass=0 fail=0

ok() { if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else echo "FAIL: $*" >&2; fail=$((fail+1)); fi; }
no() { if "$@" >/dev/null 2>&1; then echo "FAIL accepted: $*" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }
has() { if grep -qF -- "$2" "$1"; then pass=$((pass+1)); else echo "FAIL missing '$2' in $1" >&2; fail=$((fail+1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail+1)); fi; }

# Starts red until the staged engine exists.
ok "${RUN[@]}" setup --list
ok "${RUN[@]}" setup --apply tasks issues
T="$ROOT/$W/backlog/trackers/tasks.tsv"
C="$ROOT/$W/backlog/hooks/debrief.md"
has "$T" $'id\tstatus\tcreated\tcompleted\ttext\tlink'
has "$C" '## tasks'

out="$("${RUN[@]}" add --tracker tasks --text 'ship alpha')"
has <(printf '%s\n' "$out") 'id=tasks-1'
"${RUN[@]}" add --tracker tasks --text 'ship beta' --link docs/beta.md >/dev/null
"${RUN[@]}" complete tasks-1 >/dev/null
"${RUN[@]}" update tasks-2 --text 'ship beta safely' >/dev/null
has "$T" $'tasks-1\tdone\t'
has "$T" 'ship beta safely'

"${RUN[@]}" drop tasks-2 >/dev/null
"${RUN[@]}" add --tracker tasks --text 'ship gamma' >/dev/null
has "$T" 'tasks-3'
sed -i.bak '/^# highwater=/d' "$T" && rm "$T.bak"
"${RUN[@]}" add --tracker tasks --text 'ship delta' >/dev/null
has "$T" '# highwater=4'

"${RUN[@]}" add --tracker issues --text 'broken link' --link docs/shared.md >/dev/null
"${RUN[@]}" complete --link docs/shared.md >/dev/null
has "$ROOT/$W/backlog/trackers/issues.tsv" $'issues-1\tdone\t'

out="$("${RUN[@]}" list)"
has <(printf '%s\n' "$out") $'stem=issues\topen=0\tmodule=true'
out="$("${RUN[@]}" compile)"
has <(printf '%s\n' "$out") 'stem=issues'
has <(printf '%s\n' "$out") 'stem=tasks'

sum_t="$(shasum "$T" | awk '{print $1}')"
"${RUN[@]}" setup --apply tasks >/dev/null
eq "incumbent tracker preserved" "$sum_t" "$(shasum "$T" | awk '{print $1}')"

# Component-local repair in both directions.
rm "$C"
"${RUN[@]}" setup --apply tasks >/dev/null
has "$C" '## tasks'
rm "$T"
sum_c="$(shasum "$C" | awk '{print $1}')"
"${RUN[@]}" setup --apply tasks >/dev/null
eq "module preserved" "$sum_c" "$(shasum "$C" | awk '{print $1}')"
has "$T" '# highwater=0'

# An injected stop after the first component is repaired on rerun.
rm "$T"; rm "$C"
no env BACKLOG_TEST_FAIL_AFTER_FIRST_COMPONENT=1 "${RUN[@]}" setup --apply tasks
[ -f "$T" ] && [ ! -f "$C" ] && pass=$((pass+1)) || fail=$((fail+1))
ok "${RUN[@]}" setup --apply tasks
has "$C" '## tasks'

ok "${RUN[@]}" tracker-add custom
has "$C" '## custom'
no "${RUN[@]}" tracker-add custom
no "${RUN[@]}" tracker-add ../escape
no "${RUN[@]}" tracker-add Upper
no "${RUN[@]}" add --tracker custom --text $'bad\ttext'
no "${RUN[@]}" add --tracker custom --text good --link ../escape

"${RUN[@]}" add --tracker custom --text one >/dev/null
"${RUN[@]}" add --tracker custom --text two >/dev/null
no "${RUN[@]}" reorder --tracker custom --ids custom-1
ok "${RUN[@]}" reorder --tracker custom --ids custom-2,custom-1
no "${RUN[@]}" tracker-remove custom
"${RUN[@]}" complete custom-1 >/dev/null
"${RUN[@]}" complete custom-2 >/dev/null
ok "${RUN[@]}" tracker-remove custom

# Module-first removal leaves a legal tracker-only state after interruption.
ok "${RUN[@]}" tracker-add removable
no env BACKLOG_TEST_FAIL_AFTER_MODULE_REMOVE=1 "${RUN[@]}" tracker-remove removable
[ -f "$ROOT/$W/backlog/trackers/removable.tsv" ] && pass=$((pass+1)) || fail=$((fail+1))
ok "${RUN[@]}" tracker-remove removable

# Missing cookbook compiles to zero blocks; orphan module refuses compile.
mv "$C" "$C.saved"
eq "absent cookbook is empty" "" "$("${RUN[@]}" compile)"
mv "$C.saved" "$C"
printf '\n## orphan\nroute it\n' >> "$C"
no "${RUN[@]}" compile
sed -i.bak '/^## orphan/,$d' "$C" && rm "$C.bak"
printf '\n## tasks\nduplicate\n' >> "$C"
no "${RUN[@]}" compile

# Migration import allocates above highwater, preserves row facts, and receipts
# the source so replay is a zero-change operation.
ROWS="$ROOT/import.tsv"
printf '%s\n' $'open\t2026-01-01\t\tlegacy open\tdocs/open.md' \
  $'done\t2026-01-02\t2026-02-03\tlegacy done\tdocs/done.md' > "$ROWS"
out="$("${RUN[@]}" migrate-import --tracker tasks --source trackers/2026-01-01-old.md --rows "$ROWS")"
has <(printf '%s\n' "$out") 'changes=2'
has "$T" '# migrated=trackers/2026-01-01-old.md'
has "$T" $'tasks-1\topen\t2026-01-01\t\tlegacy open\tdocs/open.md'
has "$T" $'tasks-2\tdone\t2026-01-02\t2026-02-03\tlegacy done\tdocs/done.md'
sum_t="$(shasum "$T" | awk '{print $1}')"
out="$("${RUN[@]}" migrate-import --tracker tasks --source trackers/2026-01-01-old.md --rows "$ROWS")"
has <(printf '%s\n' "$out") 'changes=0'
eq "migration replay preserves tracker bytes" "$sum_t" "$(shasum "$T" | awk '{print $1}')"
printf '%s\n' $'open\tbad-date\t\tbad\t' > "$ROWS"
no "${RUN[@]}" migrate-import --tracker tasks --source trackers/bad.md --rows "$ROWS"

# Unsafe parents refuse without following the link.
SAFE="$(mktemp -d)"
ln -s "$SAFE" "$ROOT/link"
no /bin/bash "$ENGINE" --root "$ROOT" --workspace link tracker-add leak
eq "symlink escape stayed empty" "0" "$(find "$SAFE" -mindepth 1 | wc -l | tr -d ' ')"
no /bin/bash "$ENGINE" --root "$ROOT" --workspace ../escape setup --list

echo "trackers-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
