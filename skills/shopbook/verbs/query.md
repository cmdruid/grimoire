# `query` (alias `list` / `search` / `find`) — look up a host procedure

Look up what is already on disk under `$DST`. Read-only. Do not mint. Do
not mkdir `$DST`. This file runs **only** after dispatch chose `query`
(including the `list` / `search` / `find` aliases). `/shopbook query`
with no topic is list.

## Query walk

1. Resolve project root (conversation → cwd → ask). Resolve
   `<agent-workspace>` from the door (else `.dev`).
2. If the remaining argument is a single kebab-case stem, test `$DST/<stem>.md`.
   Present → that path; go to step 5. Absent → do not mkdir `$DST`
   (a miss leaves `$DST` absent); do not call `flows-create.sh`;
   continue to step 3 and search that token. Do not invent a
   procedure. Do not fall through to `create`. Do not name another
   skill.
3. Run `search` if there is a query, including a kebab-case stem whose
   `$DST/<stem>.md` was absent in step 2; else `list` (`/shopbook query`
   with no topic is list). Invoke this skill's `scripts/flows-index.sh`
   `list|search --root --workspace [--query]`.
4. Decision:
   - `matches=0` → **not found**; stop. Do not invent a procedure. Do
     not fall through to `create`. Do not name another skill. Do not
     mkdir `$DST`.
   - `matches=1` → that path.
   - `matches>1` → print stem / title / use-when for each; **ask**;
     never pick silently.
5. The **calling** agent reads that file **in full** and follows it. Do
   not substitute a summary.

## Done when

- One match: read the file in full and followed it.
- Several matches: printed candidates and asked; did not pick silently.
- Zero matches / missing `$DST`: said **not found**; did not mint; did
  not mkdir `$DST`; did not call `scripts/flows-create.sh`.
