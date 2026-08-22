# Kind: founding

## Discriminator

A file is **founding-shaped** iff it has `founding` in `tags:`
**and** its structural H2 set is exactly the six map strings
below, each appearing once. This file owns the H2 strings; if
they drift, this file wins. A duplicate mapped H2 or an extra
unmapped H2 fails the shape — that file is not this kind.

Map H2s (exact strings, once each):

- Problem & users
- Scope & non-goals
- Architecture (components, boundaries, interfaces)
- Rejected alternatives and why
- Working conventions & layout
- Declared verification command (intended, not proven)

**Parser** (one grammar; `review` / `refine` share it):

1. **Front-matter.** If the file begins with a line `---`, YAML
   through the next line that is only `---`. `tags:` is a YAML
   sequence; `founding` is present iff that sequence contains
   the string `founding`.
2. **Structural H2.** A line matching `^##[ \t]+\S` that is
   **not** inside a fenced code block (`` ``` `` or `~~~`). A
   `##` line inside a fence is body content, not a heading.
3. **Body span** of an H2 = bytes after that heading line until
   the next structural H2 or EOF.
4. **Permitted chrome** (discarded, not leftover): the
   front-matter, one ATX H1 (`^#[ \t]+`), and blank lines
   around those.
5. **Leftover H2** = a structural H2 whose exact string is not
   in the map. **Authored leftover** = any non-whitespace byte
   outside permitted chrome and outside a mapped body (pre-map
   prose, trailing prose). Either leftover class is a soundness
   finding and refuses a later materialize of the repo.

**Gap vs settled** (mapped bodies only). Strip whole lines
matching `^Settled: [0-9]{4}-[0-9]{2}-[0-9]{2}\.$` and remaining
whitespace. Remainder empty → **gap**. Any remaining byte →
**settled**. Who/when-only is a gap. No italic / `TBD` / `<>`
special cases.

## Soundness axes

The six map H2s + leftover/gap. Shared floor in
`verbs/review.md` applies inside mapped bodies. Do not promote
`status`. A leftover H2 or authored leftover is a finding. A
gap is a finding. Do not add an H2 that is not in the map.

## Groundedness extras

Against the inlined map and live behavior — not a library
design doc. Ground-check + re-read still run. Do not promote
`status`.

## Refine legal locations

Location is a **mapped H2** string; no new H2. Fill the named
mapped section. A coverage gap is "fill the mapped section". A
new concern that needs a seventh H2 is **park** (or
restore-the-shape), not an extra heading. Do not strip
`founding`.
