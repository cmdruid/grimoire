# `anchor` — point the project front door at the records layer

Add one optional, project-owned discovery section to the repository-root `AGENTS.md`. This verb is
the only Journal operation that installs a front-door pointer. It advertises no skill route or
command roster and never runs from setup, repair, migration, search, closure, or curation.

1. Resolve `<root>` as the exact Git top level that owns `.records/`. For standalone custody, run
   `git status --porcelain=v1 -- AGENTS.md` from `<root>` before preview; any output stops with
   `reason=commit-custody-required detail=AGENTS.md` so the anchor cannot commit pre-existing
   front-door work. Inside an announced configuration sweep, proceed only when `AGENTS.md` is
   already an approved destination and return the complete resulting diff to that sweep's custody.
   Then run
   `scripts/records-anchor.sh preview --root <root>`. The helper requires an attached branch, no
   active Journal setup, an initialized ledger, the exact executable adjacent provider, a current
   managed `.records/README.md` block, and a safe `AGENTS.md` target. It doesn't initialize or repair
   the layer.
2. Show the complete preview, including the exact proposed `## Project records` section, and obtain
   explicit confirmation. A literal `.records/README.md` mention is already satisfied and needs no
   write. A conflicting canonical heading, unsafe path, or stale layer refuses.
3. After confirmation, run `scripts/records-anchor.sh apply --root <root> --confirmed`. Apply repeats
   the complete preflight and refuses a concurrent project edit. A missing `AGENTS.md` is created;
   otherwise the section is appended without changing existing bytes. No ownership markers are
   installed, and the resulting prose belongs to the project.
4. If the helper reports `wrote=AGENTS.md`, resolve commit custody using Journal's shared branch
   rules, then run `scripts/scoped-commit.sh <root> "Add records layer pointer" AGENTS.md`. Never
   stage another path. Inside an announced configuration sweep, return `AGENTS.md` to that sweep's
   custody instead of making a nested commit. A no-op makes no commit.

## Done when

The fixed records guide was already mentioned, or the exact approved marker-free section was added
to a safe repository-root `AGENTS.md`; existing project prose survived byte-for-byte, the layer was
not changed, and standalone custody produced one commit containing only `AGENTS.md`.
