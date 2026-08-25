# `query` (alias `list` / `search` / `find`) — look up a host procedure

Look up what is already on disk under `$FLOW_GLOB`
(`<agent-workspace>/*/flows/*.md`). Read-only. Do not mint or mkdir. This
file runs **only** after dispatch chose `query`
(including the `list` / `search` / `find` aliases). `/shopbook query`
with no topic is list.

## Query walk

1. Resolve project root (conversation → cwd → ask). Resolve
   `<agent-workspace>` from the door (else `.spaces`).
2. Run `search` if there is a query, including a single kebab-case stem;
   else `list` (`/shopbook query`
   with no topic is list). Invoke this skill's `scripts/flows-index.sh`
   `list|search --root --workspace [--query]`.
3. Decision:
   - `matches=0` → **not found**; stop. Do not invent a procedure. Do
     not fall through to `create`. Do not name another skill. Do not
     mkdir any flow directory.
   - `matches=1` → that path.
   - `matches>1` → print stem / title / use-when for each; **ask**;
     never pick silently.
4. The **calling** agent reads that file **in full** and follows it. Do
   not substitute a summary.

## Done when

- One match: read the file in full and followed it.
- Several matches: printed candidates and asked; did not pick silently.
- Zero matches / missing workspace: said **not found**; did not mint or
  mkdir; did not call `scripts/flows-create.sh`.
