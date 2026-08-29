# `/code-humanizer walk` — a conversational tour

Sit with the reader on one path through the code. Teach the next thing they
need, then stop. Nothing is written unless they ask to save a map of what
they just walked.

## Procedure

1. **Resolve `<root>`** — `git rev-parse --show-toplevel`. Non-git → ask.
2. **Pick one path.** A named file or symbol wins. Otherwise run
   `scripts/scope.sh <root> [--path <rel>]` and choose the entry point among
   the selected files (same rule as `map`: `main`, public API, router, crate
   root). Do not tour every selected file in one turn.
3. **Walk in reading order**, short stops:

   - Where we are (`<path>`, the function or type).
   - What this step does, in one or two sentences.
   - Where control goes next, with a pointer.
   - What usually bites here, if the code or a nearby comment says so.

   Pointers over paste. Quote a few lines only when the landmark is the
   shape of the code itself (a match, a state machine) and a path would not
   show it.
4. **Pause.** After the first two or three stops, ask whether to continue,
   zoom in, or stop. Do not dump the rest of the file.
5. **No write by default.** If they ask to keep the tour, follow
   `verbs/map.md` step 5 using the path just walked as the map's scope. Do
   not mark source as a side effect of a walk.

## Done when

The tour started at an entry point, stayed on one path, paused before
becoming a novel, and wrote nothing unless a map save was asked.
