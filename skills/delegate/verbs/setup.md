# `setup [<root>]` — create the optional byproducts policy point

1. Resolve `<root>` from the argument, else the current repository root. It must exist; canonicalize
   it. Delegate uses only the fixed `.spaces/delegate/hooks/` namespace.
2. Run package-local `scripts/delegate-setup.sh <root>` standalone, or add `--write-only` inside an
   announced configuration sweep. It resolves the package skeleton at `templates/hooks/byproducts.md`, which must be an existing regular
   file whose exact size is zero; otherwise refuse before writing.
3. Preflight and then recheck immediately before each creation the chain
   `<root>/.spaces/delegate/hooks/`. A present component must be a real directory, never a
   symlink. Refuse symlinks, files, and incompatible entries without following them.
4. Destination `byproducts.md`:
   - absent → copy the skeleton's exact empty bytes;
   - existing regular file, empty or non-empty → preserve it byte-for-byte as incumbent;
   - symlink, directory, or other entry → refuse.
5. The deployer handles commit custody. When standalone and the file was created, it commits exactly
   `.spaces/delegate/hooks/byproducts.md`. A rerun or incumbent makes no commit. Never write a
   front-door block or another owner's namespace. Inside an announced configuration sweep, remain
   write-only and return the created path to the caller for its one aggregate commit.

Done when the absent destination was created as an exact zero-byte file with the correct commit
custody, or the incumbent was preserved with no write and no commit.
