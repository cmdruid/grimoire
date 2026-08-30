---
doctype: specs
status: published
schema: architect/spec@1
tags: [code-humanizer, skill-design]
---

# Code-humanizer write-time quality and visual scanability — Spec

## Problem

`code-humanizer` automatically applies whenever an agent writes or edits source, so agents are
correctly treating it as part of ordinary code authoring. Its current write-time standard, however,
defines success mostly through presentation: file-purpose comments, section landmarks, docstrings,
short functions, and one job per file. Those proxies can make code look considered without requiring
the behavior, local fit, error handling, or verification that lets a maintainer safely own it.

That automatic trigger also treats all source-shaped work alike. Durable application code, a release
script, a disposable spike, and infrastructure-as-code all load the same additional contract even
though the latter categories do not justify its cost by default. File extensions cannot express the
distinction: a Python file may be a maintained service module or a one-off repository utility.

The standard also applies to every source file touched in the session. A small fix in a large legacy
file can therefore imply a file-wide cleanup, even though the skill separately forbids a second tree
sweep. Blanket rules such as a purpose comment on every file and a one-screen limit on every function
can add noise or force arbitrary structure when the surrounding project has a clearer idiom.

Visual formatting is only partly covered. The package mentions blank-line grouping and defers
token-level style to a formatter, but it does not require consistent indentation, define formatter
authority, route explicit formatting requests, or address languages where indentation changes
program meaning. An agent can satisfy the current contract while leaving code visually ragged or,
worse, manually reindent indentation-sensitive code as though the change were cosmetic.

## Goal

Keep `code-humanizer` as an automatically applied writing overlay for durable application, service,
library, and maintained test source, but define humanized code as code a maintainer can safely
understand, change, and verify. Changed code must preserve the coding task's correctness and
constraints, fit the host project, remain simple and cohesive, and be visually scannable through
deliberate naming, control-flow shape, formatting, indentation, grouping, and useful landmarks.

Preserve `mark`, `map`, and `walk` as distinct modes. Expand `mark` only enough to own explicit
formatting and indentation requests while retaining its approval stop and semantics-preserving
boundary. Explicit invocation remains available for supported scripts, disposable code, and other
automatically excluded non-infrastructure inputs. Infrastructure-related code remains outside the
skill even under explicit invocation. Do not turn the package into a general review, debugging,
audit, or repository-wide refactoring workflow.

## Approach

Evolve the implicit write-time standard and the existing `mark` verb in place. Keep the name,
map record contract, scope helper, and navigation verbs. Narrow automatic invocation through a
role-and-lifecycle gate, while explicit invocation continues to reach every existing mode. Reframe
the public identity from "source a human can scan" to "durable source fit for human ownership" and
make scanability one part of a quality hierarchy rather than the definition of quality itself.

The hierarchy is:

1. Preserve the requested behavior and the task's correctness, security, performance, compatibility,
   and public-contract constraints.
2. Follow repository instructions, formatter configuration, established architecture, and nearby
   idioms.
3. Prefer the simplest cohesive implementation: explicit invariants and error paths, restrained
   abstraction, and no unnecessary public surface.
4. Make that implementation visually scannable with names, indentation, grouping, line breaks,
   landmarks, and comments for hidden constraints.
5. Run the host's applicable formatting and verification before handoff; scanability alone is never
   evidence that the coding task is complete.

Two alternatives are rejected:

- Making the skill explicit-only would restore a narrow readability utility but would lose the
  desired influence on agent-written code at creation time.
- Expanding it into a general code-quality reviewer would duplicate host checks and specialized
  workflows while creating a catchall routing surface. The skill instead supplies a write-time
  quality floor and leaves diagnosis, review, and broad remediation outside its boundary.

Universal indentation widths, line lengths, brace styles, or formatter choices are also rejected.
The host project owns those decisions; the skill makes agents discover and honor them.

A path or extension allowlist is rejected as the routing mechanism. Repository layout varies, and
the same language commonly serves application, test, operations, infrastructure, and disposable
roles. The agent instead classifies the work from the requested outcome, file role, surrounding
project context, and intended lifetime.

## Mechanism

### Routing and identity

Use two routing gates.

The frontmatter description is the primary gate. Automatic routing fires while creating or editing
durable application, service, library, or maintained test source. It does not auto-apply to
repository automation, release, maintenance, or operational scripts; spikes, scratch files,
prototypes, and other throwaway code; fixtures and snapshots; or generated and vendored code. These
exclusions prevent likely misrouting and belong in the description even though the detailed
procedure stays in the body.

Infrastructure-related code is a hard scope boundary, not merely an automatic-routing exclusion.
Infrastructure-as-code, deployment manifests, and CI, build, or infrastructure configuration do not
activate the skill implicitly and are refused when explicitly invoked. Their native project tools,
formatters, and conventions remain authoritative.

The body carries a short applicability backstop for false-positive loads: classify by the code's
role and intended lifecycle, never by extension alone. A maintained service entry point remains
application source even if it lives under `bin/`; a Python release helper remains a script even
though it shares an extension with the service. When the role is ambiguous, skip the implicit
write-time standard and continue the coding task normally.

Explicit invocation bypasses the automatic exclusions only for supported non-infrastructure code.
A user may invoke `/code-humanizer`, `mark`, `map`, or `walk`, or explicitly ask to humanize,
comment, document, format, indent, or navigate a supported script or disposable program. Continue
routing bare invocation, "humanize," comments, and docstrings to `mark`; route "format this," "fix
the indentation," and equivalent visual-source requests there as well. An explicit invocation on
infrastructure-related code reports that the target is outside the skill's scope and makes no edit.

The implemented frontmatter should carry the equivalent of this self-contained trigger, shortened
only when routing probes show no loss of discrimination:

```yaml
description: "Use while writing or editing durable application, service, library, shipped CLI, or maintained test source so it remains fit for human ownership; and for explicit requests to humanize, format, indent, mark, map, or walk supported non-infrastructure code. Do not auto-apply to repository automation or operational scripts, spikes, scratch or throwaway code, fixtures or snapshots, or generated or vendored code. Infrastructure-as-code, deployment manifests, and CI/build infrastructure are out of scope even when explicitly invoked."
```

Use _agent-written code_ when describing the primary concern. Do not use _generated code_ as a loose
synonym: vendored files and machine-generated artifacts are not ordinary edit targets. When such an
artifact is in scope, change its generator or template when available; otherwise edit the artifact
only when the user explicitly asks and the project permits it.

Update the package tagline in `SKILL.md`, `README.md`, and `PACK.md` to the same human-ownership
identity. The inventory text should remain short and preserve the three explicit verbs.

### Write-time quality standard

Apply the standard to code the session introduces or materially reshapes, plus formatting needed to
make that changed code fit its immediate context, and only after the automatic applicability gate
passes or the user explicitly invokes the skill. Merely touching a legacy file does not authorize
adding headers, docstrings, banners, helpers, or formatting elsewhere in the file. Continue to
forbid a second sweep of the tree and unrelated cleanup.

Replace metric-like shape rules with decisions:

- A function is small enough when its responsibility and control flow are understandable together;
  there is no screen or line-count limit.
- A file is cohesive when its contents change for the same reason; there is no one-job slogan that
  forces premature splitting.
- Extract a helper or split a new file only when the coding task already authorizes creating that
  structure and the result clarifies a real responsibility. Do not refactor existing code solely to
  satisfy this standard.
- Prefer direct code over speculative layers, generic helpers with one caller, or clever compression.
- Make invariants, failure behavior, resource ownership, and edge cases explicit in code or types
  where possible. Use comments when the constraint or trade-off cannot be expressed clearly there.
- Add file-purpose comments and public docstrings only when they help a reader navigate or understand
  a non-obvious contract. Self-explanatory files, signatures, getters, tests, and conventional entry
  points do not need ceremonial prose.

The standard is subordinate to the authorized coding task. It must not broaden the requested change,
change a public API for aesthetics, weaken performance or security properties, or conceal an
unresolved correctness problem behind comments. Skipping this skill's automatic mode does not waive
the host project's ordinary formatting, testing, or code-quality requirements; it avoids only the
additional humanizer contract.

### Formatting and indentation

Formatting is a normal part of both write-time humanization and an explicitly approved `mark` pass.
Use this precedence:

1. The repository's documented formatting command and checked-in configuration.
2. An established language formatter already used by the project.
3. The conventions visible in the surrounding file when no formatter is available.

Run the applicable formatter on the narrowest supported touched scope and inspect the resulting
diff. A project-prescribed formatter may make its normal canonical token changes. Do not install a
formatter, add or alter formatter configuration, or silently run a repository-wide reformat. If the
only available command has broad effects, follow an explicit host instruction to run it; otherwise
preserve local style and report that no narrow formatter was available.

When formatting manually, preserve the local tabs-versus-spaces choice, indentation depth,
continuation alignment, brace placement, and wrapping convention. Use indentation to expose nesting,
blank lines to group one thought, and line breaks to reveal control flow or data structure. Do not
compress several decisions into a dense one-liner merely to reduce vertical space, and do not expand
idiomatic compact code mechanically.

Indentation is syntax in some languages. In an indentation-sensitive language, `mark` may apply a
trusted formatter to parseable code or adjust continuation whitespace that cannot change block
nesting. It must not guess at ambiguous nesting or make a manual indentation change that can alter
control flow; that is a behavioral repair outside `mark` and requires an implementation request.

### Explicit `mark` behavior

Broaden `mark` from landmarks-only to visual, semantics-preserving source presentation: approved
landmarks, grouping, formatting, and safe indentation. Its intent summary must state which files need
landmarks, formatter application, or manual whitespace adjustment and must still wait for a short
go-ahead.

After approval, `mark` may change comments, docstrings, blank lines, and semantics-neutral whitespace,
plus canonical output from the project's formatter. It may not change identifiers, APIs, behavior,
control flow, abstractions, dependencies, or file boundaries. If formatting exposes a parse error,
ambiguous indentation, or a change that cannot be shown semantics-preserving, stop and report it
instead of repairing it under `mark`.

`map` and `walk` remain unchanged and read-only by default.

### Completion and package surface

The write-time standard does not replace the underlying task's completion criteria. Before handoff,
format the touched source using the rule above and run the host's applicable tests, diagnostics, or
other required verification. Formatting and verification already completed for the underlying task
satisfy this requirement; do not repeat them solely because the humanizer loaded. Report unavailable
checks and failures honestly. Humanizer completion means the authorized changed code follows the
quality hierarchy, its formatting was handled or accounted for, and no unrelated source was swept.

Revise these package surfaces:

- `skills/code-humanizer/SKILL.md`: identity, routing, write-time hierarchy, scope, and completion.
- `skills/code-humanizer/references/landmarks.md`: conditional landmarks, formatting and indentation
  rules, and readability-theater anti-patterns. Keep the current filename to avoid an unhelpful
  resource rename.
- `skills/code-humanizer/verbs/mark.md`: approved formatting scope, formatter behavior, indentation
  safety, and the existing stop.
- `skills/code-humanizer/scripts/tests/skill-doc-test.sh`: contract assertions for the new invariants
  and removal of assertions that preserve rejected proxies.
- `README.md` and `PACK.md`: concise inventory wording only.

No change is expected in `map.md`, `walk.md`, `scope.sh`, map schemas, typed edges, or project
templates. If implementation reveals that `scope.sh` omits a source type needed by a concrete
acceptance case, treat that as a separate evidenced correction rather than widening the lister
speculatively.

## Verification

Run the package tests and the library gate:

```text
skills/code-humanizer/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh .
git diff --check
```

Any new contract assertion must be red-proved against a deliberately broken temporary copy before
the live package is accepted. Static phrase checks establish only that the contract is present; they
do not establish agent behavior.

Test routing separately from behavior. Follow the library's routing-probe acceptance method in
`skills/skill-builder/docs/BOUNDARY-AUDIT.md`: provide only the available skill descriptions and each
prompt below to a fresh evaluation context when available, record the selected skill or absence, and
treat every unexpected selection or omission as a failure. A same-session trace that already loaded
`code-humanizer` is not routing evidence.

After routing passes, exercise the loaded skill's behavior in an isolated fixture or same-session
trace:

| Case | Required behavior |
|---|---|
| New Python application module under a source directory, with an existing formatter | Automatically applies, follows nearby architecture, runs the configured formatter on the touched scope, and verifies behavior; comments are not treated as completion. |
| Shipped single-file CLI or application entry point | Automatically applies even when its executable form resembles a script. |
| Maintained test source | Automatically applies without adding ceremonial comments to trivial test helpers. |
| Python release helper under a scripts directory | Does not auto-apply; explicit invocation may apply because the target is supported non-infrastructure code. |
| Disposable spike or scratch program | Does not auto-apply and does not add durable documentation or structure for its own sake. |
| Ordinary Terraform, deployment-manifest, or CI/build infrastructure work | Does not select the skill automatically. |
| Explicit `/code-humanizer` invocation on infrastructure | Loads the skill only to report that the target is outside scope; it does not list or edit files. |
| Ambiguous migration helper under a tools directory | Defaults to skipping the implicit standard rather than delaying the task with classification work. |
| Explicit `mark RELEASE_SCRIPT` | Applies despite the automatic script exclusion and retains the preview and approval stop. |
| One-line fix in a large legacy file | Formats the changed region as the project permits without adding file-wide banners, docstrings, helpers, or unrelated whitespace churn. |
| Explicit "format and indent this file" | Dispatches to `mark`, previews the intended formatting work, waits for approval, and makes no behavioral change. |
| Parseable indentation-sensitive source | Uses the project's trusted formatter or changes only continuation whitespace; block nesting remains unchanged. |
| Ambiguous indentation-sensitive source | Stops `mark` and reports that the request requires a behavioral repair instead of guessing the intended nesting. |
| Trivial exported API | Does not add a docstring that merely repeats the name or signature. |
| Idiomatic compact expression | Preserves it when the control flow remains apparent; no mechanical expansion to meet a length proxy. |
| Vendored or machine-generated artifact | Leaves the artifact alone and points to the generator unless direct editing was explicitly requested and permitted. |
| `map` or `walk` invocation | Retains the existing conversational, read-only behavior and record rules. |

Acceptance requires all package tests and the library lint gate to pass, no target-unrelated diff,
no excluded case that triggers the implicit standard, no explicit invocation blocked by an automatic
exclusion for supported non-infrastructure code, no ordinary infrastructure prompt that selects the
skill, every explicit infrastructure invocation refusing before file listing or editing, and no
behavioral case that treats visual polish as a substitute for correct, locally appropriate, verified
code.
