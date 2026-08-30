# Landmarks and source presentation

A landmark is a visual handle a human uses to scan a file: purpose when it is
not obvious, section banners around real phases, grouping, and a useful
docstring on an entry they will land on. It is not a narration of the next line
or a second specification. Formatting and indentation expose the same structure
without adding prose.

## What to add

**File or module purpose.** When the role is not already clear, use one short
block at the top in the language's usual form (`//!`, `"""`, `/** */`, a
leading `#` comment). Say what the file is for and when a reader should open it.
Skip self-explanatory conventional entry points and do not restate the package
layout.

**Section banners.** In a long file, mark distinct phases (parse, validate,
write). Match the file's existing comment style. One line, maybe two. A
banner that merely repeats the next function's name is noise.

**Grouping.** Blank lines between related statement clusters. Do not restyle
the file to a different formatter; if the project has a formatter, leave
token-level style to it and only add grouping the formatter preserves.

**Docstrings.** Add one to an exported or public function, type, or method when
a new reader needs its non-obvious contract, arguments, invariants, ownership,
or failure modes. Skip trivial getters, test helpers, and APIs whose name and
signature tell the whole story.

**Why, not what.** A comment earns its place when it records a constraint,
trade-off, or invariant the code cannot say. `// retry because the API is
eventually consistent` is a landmark. `// increment i` is not.

## Formatting and indentation

Use this precedence:

1. Repository command and checked-in configuration.
2. An established language formatter already used by the project.
3. The conventions visible in the surrounding file.

Use the narrowest supported touched scope and inspect the formatter diff. A
project formatter may make its normal canonical token changes. Do not install a
formatter, change its configuration, or silently format the whole repository.
When only a broad formatter command exists, use it only when host instructions
require it; otherwise preserve local style and report the limitation.

For manual work, preserve tabs versus spaces, indentation depth, continuation
alignment, braces, and wrapping. Indentation should reveal nesting; blank lines
should group one thought; line breaks should expose control flow or structured
data. Preserve idiomatic compact expressions when they remain easy to follow.

**Indentation-sensitive languages.** Apply a trusted formatter only to
parseable code. Without one, adjust only continuation whitespace that cannot
change block nesting. Ambiguous nesting is not a presentation decision: stop and
report that it needs behavioral repair.

## Language form

Follow the file in front of you. If it already has a docstring style, use
that style. If it has none, use the language's common convention — do not
invent a house style.

Do not wrap every block in ASCII art. A short `// ---- parse ----` or a
language doc-comment is enough.

## Mark vs write-time

`mark` may change presentation, not meaning: comments, docstrings, blank lines,
semantics-neutral whitespace, and canonical output from the project's formatter.
It may not change identifiers, APIs, behavior, control flow, abstractions,
dependencies, or file boundaries.

Write-time follows the full quality hierarchy in `SKILL.md`: correctness and
project fit constrain design and scanability. It may choose names or structure
only within the underlying coding task's authorized change.

## Anti-patterns

- Restating the next line in English.
- File-level essays that duplicate a map.
- Commenting out old code "for context".
- Banner noise in a 30-line file that is already one thought.
- Ceremonial comments or docstrings on obvious files, APIs, getters, or tests.
- Readability theater: arbitrary helper extraction, file splitting, or vertical
  expansion that makes code look structured without clarifying responsibility.
- Changing quotes, import order, indentation, or wrapping to match personal
  taste rather than the project formatter or surrounding convention.
- Adding types, unwraps, or control-flow "clarity" as if they were presentation.
