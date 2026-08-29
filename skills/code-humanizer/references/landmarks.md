# Landmarks

A landmark is a visual handle a human uses to scan a file: purpose at the top,
section banners, grouping, and a docstring on an entry they will land on. It
is not a narration of the next line, and it is not a second specification.

## What to add

**File or module purpose.** One short block at the top, in the language's
usual form (`//!`, `"""`, `/** */`, a leading `#` comment). Say what this
file is for and when a reader should open it. Do not restate the package
layout.

**Section banners.** In a long file, mark distinct phases (parse, validate,
write). Match the file's existing comment style. One line, maybe two. A
banner that merely repeats the next function's name is noise.

**Grouping.** Blank lines between related statement clusters. Do not restyle
the file to a different formatter; if the project has a formatter, leave
token-level style to it and only add grouping the formatter preserves.

**Docstrings.** On exported or public functions, types, and methods a new
reader will jump to. Cover purpose, non-obvious arguments, and failure modes.
Skip trivial getters, test helpers, and functions whose signature is the
whole story.

**Why, not what.** A comment earns its place when it records a constraint,
trade-off, or invariant the code cannot say. `// retry because the API is
eventually consistent` is a landmark. `// increment i` is not.

## Language form

Follow the file in front of you. If it already has a docstring style, use
that style. If it has none, use the language's common convention — do not
invent a house style.

Do not wrap every block in ASCII art. A short `// ---- parse ----` or a
language doc-comment is enough.

## Mark vs write-time

`mark` may add only the items above. It may not rename identifiers, extract
helpers, split files, or change control flow.

Write-time (the standard in `SKILL.md`) also chooses names a human can scan,
keeps functions to one screen, and keeps one job per file — cheap while the
code is still being written.

## Anti-patterns

- Restating the next line in English.
- File-level essays that duplicate a map.
- Commenting out old code "for context".
- Banner noise in a 30-line file that is already one thought.
- Changing quotes, import order, or wrapping to match taste.
- Adding types, unwraps, or control-flow "clarity" as if they were landmarks.
