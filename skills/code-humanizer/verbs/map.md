# `/code-humanizer map` — a navigation snapshot

Tell a lost reader where to start and which files to read, in order. The map
is a snapshot of a moving tree: pointers, a revision stamp, not pasted
source. It lives in the conversation unless the human asks to save it.

## Procedure

1. **Resolve `<root>`** — `git rev-parse --show-toplevel`. Non-git → ask.
2. **List the files.** Run `scripts/scope.sh <root> [--path <rel>]` from this
   skill's own `scripts/`. Same scope rules as `mark` (named path, else the
   current git change, cap 20, whole-repo only when said explicitly). If the
   span is larger than the cap, map the selected slice and say what was
   omitted; do not pretend the map covers the rest.
3. **Read enough to name roles.** For each selected file, one job in a
   phrase. Find the entry point a newcomer should open first — a `main`, a
   public API, a router, a crate root — not "the first file alphabetically."
4. **Write the map in conversation**, in this shape:

   ```markdown
   # Map — <scope>
   Built against: <git rev-parse --short HEAD> (<dirty|clean>)
   Verify before trusting: paths move; re-run map if the tree has shifted.

   Start here: `<path>` — <why>

   Then, in order:
   1. `<path>` — <role>
   2. `<path>` — <role>

   Skip unless you need: `<path>` — <why>
   ```

   Pointers only. Do not paste function bodies. Do not pose as a README or
   as the source of truth.
5. **Save only if asked.** Persistence is in SKILL.md *Record contract*.
   Author the conversational map as the body, mint
   `.records/records.sh new maps
   --schema code-humanizer/map@1 --title "<scope>" --tag code-humanizer --tag map`
   when that tool is executable; otherwise file-mode the same four-key
   shape at `.records/maps/YYYY-MM-DD-<slug>.md` (`status: published`
   — the snapshot is the account of this run). Put `built-against: <sha>` in
   the body, not as a reserved front-matter key. Create `maps/` on first
   write. Do not commit unless this invocation is standalone *and* the human
   asked to save; then one pathspec-scoped commit of the new record only.

## Done when

The map names a start, a reading order, and a revision stamp; it stayed in
conversation unless a save was asked; a saved file matches the in-package
record contract; omitted files (if any) were named.
