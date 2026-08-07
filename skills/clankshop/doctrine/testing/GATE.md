# GATE — what green means here

<!-- spine-doc v1
kind: testing
doctrine: clankshop
doctrine-version: 1
refs: .handbook/**
-->

The gate definition — the one command that must pass before any commit lands (INV-1), and what it
actually checks. This seed is a skeleton with command slots; the verification steward tends the
filled version as the project's gate evolves.

## The gate command

- **Full gate:** `<gate>` — the land-blocking check. Green means: `<what green covers — tests,
  lint, types, format, doc checks>`.
- **Cheap suite:** `<cheap-suite command, if one exists>` — the fast subset for mid-task feedback
  (a data/param retune still runs this; a visual check alone is structurally blind to pin-tests).
- **Scoped runs:** `<how to run one test file / one package>` — the inner-loop command.

## When which

| moment | run |
|---|---|
| mid-task, after each edit | the scoped run for what you touched |
| before each commit | the full gate (INV-1) |
| after a data/param retune | cheap suite + the visual/scenario check |
| before landing on `<trunk>` | the full gate, on the rebased result |

## Known costs

`<gate runtime, flaky suites, environment prerequisites — anything that makes an agent misjudge
a red run. Empty until the project earns entries.>`
