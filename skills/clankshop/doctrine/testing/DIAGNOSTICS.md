# DIAGNOSTICS — the debugging playbook

<!-- spine-doc v1
kind: testing
doctrine: clankshop
doctrine-version: 1
refs: .handbook/**
-->

Symptom → first moves: the project's playbook for diagnosing a failure, consulted by whoever runs
the diagnostic procedure (the bug lane's walk). This seed carries the universal discipline
headings; per-symptom chapters accrue as the project earns them — an investigation that surfaced
a missing chapter is exactly the signal that adds one.

## The discipline (universal)

1. **Reproduce** — no diagnosis before a reproduction; record the exact command/seed/steps. A
   flaky reproduction is itself a finding (note the rate).
2. **Trace** — read the actual error in full, then follow the data flow backward from the failure
   to its origin. Check `GOTCHAS.md` with what you learn.
3. **Hypothesize** — one testable hypothesis at a time; state what observation would falsify it.
4. **Verify** — the smallest possible probe that confirms or kills the hypothesis. Three failed
   minimal fixes → suspect the architecture, not the line.
5. **Fix** — the root cause, never the symptom; human-confirm before the fix lands.

## Symptom chapters

Each chapter: `## <symptom class>` — first moves, the observability tools to reach for, the known
dead ends. Seeded empty:

`<e.g. "test passes locally, fails in CI" · "build breaks after dependency bump" · "flaky
end-to-end suite" — filled per project as investigations accumulate.>`

## Harness and tooling

`<the project's debugging tools: how to get verbose logs, the E2E/integration harness, visual
fast-paths, profilers. Empty until filled.>`
