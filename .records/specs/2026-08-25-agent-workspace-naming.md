---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, naming]
---

# Agent workspace naming — Spec

## Problem

`workspace` is overloaded. In this repository it names the project-local, skill-owned
`<owner>/<kind>/...` tree and its read-only format guard, but it can also mean the repository,
a Cargo workspace, a VS Code workspace, a worktree, or an agent's general working directory.
The bare `/workspace` face therefore needs context before its purpose is legible, and neither
`workspace` nor the current default `.dev` immediately says that this is where skills keep their
project-scoped support files. `.dev` additionally leans toward local or ephemeral development
state, while this root contains durable, committed project sources of truth.

The actual grammar is owner-first, `<agent-workspace>/<skill>/<kind>/...`; there is no literal
shared `skills/` directory. Even with that structure, the root can feel like a dumping ground
because its six kinds are heterogeneous: doctrine, hooks, scripts, templates, trackers, and
flows. A new name may improve orientation, but it cannot substitute for the ownership rule and
closed kind set that keep the root bounded.

The proposed replacement, `<agent-artifacts>` with default `.artifacts`, removes that collision
but introduces a category problem. This library normally calls specs, plans, notes, reports, and
other work products artifacts; those live under `<agent-records>`, not in the renamed root. The
root in question instead holds source-of-truth project configuration and executable support:
doctrine, hooks, scripts, templates, trackers, and flows. Outside the library, `.artifacts` also
often suggests derived, disposable, or CI/build output, which is the wrong custody signal for
hand-maintained doctrine and templates.

The current root contract and `workspace` guard landed recently, so this is the least expensive
time to reconsider their names. The abstract root name, default directory, and skill face are
three separate decisions: the first and third can remain `workspace` while the default changes.

## Goal

Keep `<agent-workspace>` and the `workspace` skill while replacing the `.dev` default with a short,
durable-sounding path that reflects the owner-first layout and remains distinct from typed work
products in `<agent-records>`. The change is a hard cut: no compatibility or migration behavior.

## Approach

Recommended direction: keep the front-door key `<agent-workspace>` and the `workspace` skill, and
change the default from `.dev` to `.spaces`.

```text
.records/   typed work products
.spaces/    skill-owned project support
```

The plural has useful structural meaning: the workspace root is a collection of skill-owned
spaces, one `<skill>/` namespace each, and every space is divided into the closed kind set. The
path stays compact at depth (`.spaces/auditor/doctrine/...`), carries no build-output implication,
and avoids `.dev`'s local/ephemeral connotation. Although `.spaces` does not independently say
“agent,” neither does `.records`; the front-door names `agent-workspace:` and `agent-records:`
supply ownership while the defaults remain terse.

In explanatory prose, call the root the **agent workspace** and define `.spaces` once as its
default. “Agent support workspace” is useful when introducing its purpose, but need not become a
third formal term.

Alternatives rejected at brainstorm weight:

- **Keep `.dev`.** Shortest and already implemented, but retains the ambiguity that prompted this
  design and suggests disposable local-development state.
- **Use `.agent-workspace`.** Maximally explicit in an unexplained tree, but unnecessarily long in
  the deeply nested paths this root intentionally carries.
- **Rename the concept to `workbench` or `support`.** Both are plausible, but neither improves the
  six-kind fit enough to justify replacing the accepted `workspace` vocabulary and skill face.

`agent-config`, `agent-state`, and `agent-tooling` are not stronger candidates: config excludes
tracker state and executables; state excludes static doctrine and templates; tooling understates
project-owned policy and living data. `agent-home` risks collision with the user's or harness's
global home, while `agent-resources` is at least as generic as workspace.

Historical completed specs should remain unchanged: they record the vocabulary and decisions in
force when their work shipped. Only live doctrine, current package surfaces, tests, and current
forward-looking docs should move.

## Mechanism

The front-door key, symbolic token, skill name, owner-first grammar, and closed kinds remain
unchanged. Only the undeclared default changes:

```text
<agent-workspace> = first line-start `agent-workspace:` in AGENTS.md, then CLAUDE.md;
                    else `.spaces`
```

The change reaches every default literal, resolver, fixture, lint invariant, README/PACK surface,
and consuming project that currently relies on an undeclared `.dev`. The live census spans roughly
sixty non-historical files across at least thirteen skills. Historical completed specs remain
unchanged.

This is an alpha hard cut with no migration mechanism:

- Readers with no declaration resolve `.spaces` directly.
- Readers do not probe for, adopt, warn about, or move an existing `.dev` tree.
- `agent-workspace:` continues accepting any valid repo-relative path. An explicitly declared
  `.dev` therefore remains an ordinary override, not a legacy alias.
- The library does not mutate consuming projects' directories.

## Verification

A repo-wide live-literal census must show no `.dev` fallback outside historical records and the
explicit-override proof. Run all affected skill harnesses and the skill-builder lint suite. Fixtures
must cover fresh `.spaces`, arbitrary declared values (including explicit `.dev`), all six owned
kinds, and coincident workspace/records roots. No fixture should implement legacy adoption.

## Open questions

None.
