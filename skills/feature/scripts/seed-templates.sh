#!/usr/bin/env bash
# seed-templates.sh <root>
#
# Deploy feature's bundled planning templates as a project-OVERRIDABLE seed at
# <root>/.agents/feature/templates/ (Layer 3, "templates-as-seed" -- model doc
# docs/design/2026-07-18-skill-self-init-model.md §5.2/B3). The skill's bundled
# templates/ stay the baked defaults; the deployed seed is the project's
# override layer, which design/plan prefer when present.
#
# Create-if-absent: a project's edited override is NEVER clobbered, so re-running
# only backfills templates the project hasn't taken over. Idempotent.
#
# DOCTRINE: a mutating mechanical helper (sibling of backlog's scaffold-records.sh)
# -- it only ever CREATES seed files from the bundled defaults; it never rewrites
# an existing one. A deployable-assets home does NOT make feature a steward
# (roadmap "The model"): it just ships customizable files. Prints created=/exists=
# facts; the verb keeps the judgment.
set -euo pipefail

root="${1:?usage: seed-templates.sh <root>}"
[ -d "$root" ] || { echo "FAIL: root $root is not a directory" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../templates"
[ -d "$src" ] || { echo "FAIL: bundled templates dir $src missing" >&2; exit 2; }
dst="$root/.agents/feature/templates"
mkdir -p "$dst"

created=0 existed=0
copy() {  # copy <dst-relpath> ; body (for generated files) on stdin, or omit for a bundled copy
  local base="$1"
  if [ -e "$dst/$base" ]; then echo "exists=$base"; existed=$((existed + 1)); return 1; fi
  return 0
}

for f in "$src"/*.md; do
  base="$(basename "$f")"
  if copy "$base"; then cp "$f" "$dst/$base"; echo "created=$base"; created=$((created + 1)); fi
done

# A README the project reads to understand the override contract (create-if-absent).
if copy "README.md"; then
  cat > "$dst/README.md" <<'EOF'
# .agents/feature/templates/ — deployable planning-template seed

`/feature`'s planning-artifact shapes (`plan-design.md`, `plan-implementation.md`,
`roadmap.md`, `adr.md`), deployed here as a **project-overridable seed**. Edit any
file to tailor a template to this project; `/feature design` / `/feature plan`
**prefer a template found here** and fall back to the skill's bundled default when
this seed lacks it. Re-running the seeder only backfills missing files — it never
overwrites an edit you made here.
EOF
  echo "created=README.md"; created=$((created + 1))
fi

echo "seed=$dst created=$created existed=$existed"
