---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Control-flow complexity review and audit — Spec

This specification adds one coordinated capability to two independent skill packages. Inspector
uses complexity only within its existing document-refinement and completed-implementation review
boundaries. Auditor adds a portable scored dimension for repository-wide control-flow complexity.
Neither skill calls the other, reads the other's doctrine, or shares runtime configuration.

This specification extends the current Inspector contract in
`.records/specs/2026-08-27-inspector-revise-and-refine.md` and Auditor's rubric contract in
`skills/auditor/BOOTSTRAP.md`. It does not supersede either artifact.

## Problem

Inspector and Auditor both notice some symptoms of complex code, but neither owns cyclomatic
complexity as explicit evidence.

Inspector refinement can remove duplicated or speculative mechanisms from a spec or plan, yet it
does not explicitly look for designs that multiply later control-flow paths through modes, flags,
fallbacks, compatibility branches, or interacting states. Inspector's implementation kind reviews
correctness, cohesion, tests, and failure paths, but it does not ask whether a completed change
introduced avoidable branch growth or whether the new independent paths are meaningfully exercised.

Auditor's Readability rule measures function length, nesting, magic values, and signature burden.
Those are useful proxies for human legibility, but they do not measure the number of independent
paths through authored control flow. A short function can have many paths, while a long sequential
function can have few. Consequently the repository-wide audit cannot identify, calibrate, or trend
cyclomatic-complexity hotspots without conflating them with readability.

A naive addition would be worse than the gap. Regex branch counting is not a language parser;
different analyzers count boolean operators, exception handlers, and match arms differently; a
universal threshold turns a prompt into an unsupported verdict; and a metric applied to generated
code, lookup tables, or exhaustive dispatch can produce confident false positives. The capability
therefore needs an explicit population, analyzer identity, unavailable state, and judgment boundary.

## Goal

Add proportional control-flow complexity to the library at three depths:

1. `/inspector refine` qualitatively simplifies avoidable branch multiplication in specs and plans
   without pretending that a document has measurable cyclomatic complexity.
2. `/inspector review` of a completed implementation examines complexity introduced by the named
   change, using same-analyzer before/after facts when available and grounded qualitative evidence
   otherwise.
3. Auditor adds a thirteenth portable `Complexity` dimension that measures and inspects authored
   repository control flow in depth, calibrates its scoring to the host, and records reproducible
   facts without installing tooling during a pass.

Complexity numbers remain evidence. They never map directly to an Inspector verdict, an Auditor
finding, or Auditor's `--check` failure. Every finding still needs a specific consequence and a
concrete remedy after false-positive review.

## Approach

**Chosen: one concept, three depths, independent implementations.** Inspector keeps its narrow
artifact/change scope. Refinement reasons about design-induced branch multiplication; implementation
review checks the changed control flow. Auditor owns the repository-wide metric, calibrated scoring,
hotspot inspection, and trend evidence.

Cyclomatic complexity uses the analyzer's documented control-flow model. The canonical definition is
`M = E - N + 2P` over a control-flow graph; for a single structured function it is commonly
equivalent to one plus analyzer-defined decision increments. The package does not implement that
formula with textual matching. Numeric results are comparable only when analyzer, analyzer version,
configuration, population, and exclusions are the same.

**Rejected: extend `/inspector refine` to source code.** Refine is an explicit minimum-sufficiency
pass over specs and plans. Accepting implementation would cross its kind gate, turn Inspector into a
code-remediation tool, and weaken the existing rule that implementation review is verdict-only.

**Rejected: add an Inspector complexity-audit verb.** A repository-wide quality pass already belongs
to Auditor. A new Inspector mode would duplicate scope selection, doctrine, scoring, reporting, and
finding-drain behavior.

**Rejected: fold the full metric into Readability.** Readability asks whether a person can follow the
code; Complexity asks how many independent control-flow paths exist and what verification burden they
create. Combining them would hide the deeper analysis and make the score ambiguous. Their rule files
instead state a non-duplication seam.

**Rejected: compute cyclomatic complexity with portable regexes.** Text searches may surface branch
candidates for qualitative inspection, but they cannot emit a cyclomatic-complexity number. An
analyzer must parse the language. If no suitable project-pinned analyzer is available, the metric is
explicitly unavailable.

**Rejected: require or install an analyzer.** A portable skill cannot assume one tool or mutate the
host toolchain during review or audit. Fresh Auditor setup records the selected existing analyzer or
the unavailable state; later passes consume that decision. Inspector uses only a tool already named
by project instructions or its effective implementation doctrine.

**Rejected: ship a universal numeric failure threshold.** Analyzer semantics and project shapes
vary. Fresh setup may offer provisional bands for calibration, but only the host rubric can adopt a
threshold. Crossing it selects a hotspot for inspection; it does not by itself create a finding.

## Mechanism

### Shared fact and judgment contract

A numeric complexity claim is supported only when it names:

- analyzer and analyzer version;
- analyzed population, including target path or changed functions;
- exclusions, at least generated/vendor code and any host-specific exclusions;
- the function or method identity and source location;
- the reported value; and
- for a delta, the before and after endpoints measured with identical analyzer configuration.

The population is authored executable control flow. Comments, documentation examples, generated or
vendored code, data tables, and declarative configuration are excluded by default. A host may add
language-specific exclusions. Test code remains in the population only when the host deliberately
audits test maintainability; otherwise it is reported separately or excluded.

Every analyzer adapter normalizes one authored function per UTF-8 TSV row:

```text
<score><TAB><repo-relative-path><TAB><line><TAB><symbol>
```

`score` is an integer greater than or equal to one; `repo-relative-path` is a nonempty normalized
path inside the attributed population; `line` is a positive integer; `symbol` is nonempty. Fields
may not contain tabs or newlines. Duplicate `(path, line, symbol)` identities and malformed rows
refuse numeric aggregation. The adapter enumerates the declared source-file population before
analysis and reports analyzed, skipped, and parse-error file counts; if it cannot prove which files
were analyzed, coverage is partial.

Analyzer status has three values:

- `available` — the configured command succeeded, identified its version, covered the complete
  declared file population, and reported no skipped or parse-error files; a complete population
  containing zero authored functions is still available;
- `partial` — a trustworthy versioned run occurred but skipped, failed to parse, or could not prove
  coverage of part of the declared population, whether or not it produced function rows; and
- `unavailable` — no project-pinned analyzer is configured or no trustworthy versioned execution
  can run against the requested population.

Unavailable is a fact, not a quality failure. Partial aggregates may identify candidates, but are
labeled partial and cannot support threshold counts or cross-pass comparisons. In either state, the
reviewer or auditor continues qualitatively, states the limitation and omitted paths when known,
and never substitutes a regex-derived number.

Neither the raw value nor a threshold crossing is a finding. Judgment must inspect the actual branch
structure, determine whether the complexity is inherent or avoidable, examine verification of the
material paths, refute the applicable false positives, and satisfy the owning skill's normal
materiality or finding-entry contract.

Cyclomatic complexity is not treated as a test-count requirement. A value of `N` does not imply
exactly `N` unit tests. Tests may cover several basis paths, and path combinations can exceed the
metric. The supported claim is narrower: higher independent-path count increases the verification
surface, so material branches and interactions need evidence appropriate to their risk.

### Inspector refinement: qualitative design simplicity

`/inspector refine` remains restricted to specs and plans and never runs a code analyzer. Extend its
supported-simplification pass to look for design mechanisms that multiply implementation paths:

- multiple flags or modes whose combinations create a state cross-product;
- fallback chains or retry branches with no distinct required outcome;
- compatibility paths not required by an accepted constraint;
- repeated conditional requirements that can be expressed by one invariant;
- parallel mechanisms selected by substrate rather than user-visible behavior; and
- exception branches whose ownership or verification cannot be stated independently.

A supported proposal removes, consolidates, or replaces such a mechanism only when the existing
refinement preservation contract still holds. Legitimately distinct modes, safety responses,
failure boundaries, and accepted compatibility requirements remain. If branch necessity is
ambiguous, refine asks one focused question and stops under its existing rules.

The refinement report uses plain design language such as “four interacting modes create behavior
combinations the goal does not require.” It must not label a document with a cyclomatic-complexity
score, estimate a future score, or claim a numeric reduction. Proposal, confirmation, apply,
status-custody, and mandatory full-review behavior remain unchanged.

### Inspector implementation review: change-scoped regression check

Extend `skills/inspector/kinds/implementation.md` with:

- a soundness axis requiring changed control flow to be proportionate to the required behavior and
  free of avoidable branch multiplication; and
- a groundedness extra requiring inspection of changed authored functions for complexity growth and
  verification of their material paths.

When project instructions or the effective Inspector implementation doctrine name an existing
complexity analyzer, run it over the resolved before and after endpoints of the named diff, range,
worktree, or commit. Use identical analyzer version, configuration, population, and exclusions.
Report changed-function deltas and newly introduced hotspots; do not compare results produced by
different analyzers or versions.

Numeric deltas require both endpoint trees to be materializable read-only from the named target.
Use analyzer input or temporary snapshots; never apply the diff, switch the checkout, or amend the
reviewed target. A newly added function has before value `--`; a deleted function has after value
`--`. If either endpoint cannot be constructed, mark delta analysis unavailable with reason
`endpoint-unavailable` and perform the qualitative changed-control-flow review instead.

No new front-door variable, shared configuration file, analyzer registry, or dependency on Auditor
is introduced. Inspector does not discover an analyzer by scanning package managers and never
installs one. When no analyzer is named or execution is unavailable, inspect the changed control
flow qualitatively and include the limitation as a confidence note when it matters.

The ordinary implementation materiality gate determines the outcome. A rise such as `9 -> 16` is a
review prompt, not a verdict. A reportable finding must identify the avoidable decisions or coupled
states, explain the correctness/verification/maintainability consequence, and propose a remedy such
as separating policy from dispatch, extracting an independently testable decision, replacing flags
with a state model, or adding missing path evidence. Generated code, exhaustive enum dispatch,
table-driven logic, parsers/state machines, and intentionally sequential test scaffolds are explicit
false-positive checks.

Implementation review remains conversation-only and verdict-only. It never enters `revise` or
`refine`, edits code, publishes, or writes status.

### Auditor Complexity dimension

Add `skills/auditor/rules/complexity.md` as the thirteenth portable dimension:

```text
Complexity | CPLX | Is authored control-flow complexity proportionate, isolated, and adequately tested?
```

The file follows Auditor's uniform rule shape and is complete on its own. Its decision logic:

1. Resolve the audited target and the rule's configured analyzer recipe and exclusions.
2. Run the configured analyzer when available; record identity, version, status, population, and
   exclusions before interpreting results.
3. Inspect the highest-complexity authored functions in the target, every function above the host's
   calibrated hotspot threshold when one exists, and any hotspot in a Deep blast-radius target.
4. Identify the decisions responsible for each candidate and decide whether they are inherent,
   table/exhaustive structure, or avoidable policy/state coupling.
5. Trace material branches and interactions to test evidence without equating score to test count.
6. Apply the rule's false-positive list, score against host-calibrated anchors, and file only
   consequential, actionable findings.

Its scoring anchors remain qualitative until setup calibrates them. Score 5 requires reproducible
analyzer facts or specific `file:line` evidence across the target plus refutation of hotspots; 4 is
limited low-risk deviation; 3 is at least one material localized hotspot; 2 is multiple or
high-blast-radius avoidable hotspots with weak path evidence; 1 is pervasive unbounded control-flow
complexity. Analyzer unavailability lowers confidence but does not mechanically select a score.

The bundled false-positive section includes generated/vendor code, exhaustive match/dispatch over a
closed set, named lookup tables, parser and state-machine code whose states are inherent and explicit,
framework-generated branches, and intentionally sequential tests. An exception is justified only
after reading it; category resemblance alone is not a waiver.

State the scoring seam in both adjacent rules:

- `CPLX` owns independent-path count, avoidable decision multiplication, hotspot isolation, and the
  resulting verification burden.
- `READ` owns legibility, length, nesting, naming, signatures, and mental backtracking.
- one defect receives one primary finding/dimension; the audit may cite adjacent evidence without
  filing or scoring the same defect twice.

### Auditor analyzer and metrics contract

Fresh `/auditor setup` adds analyzer selection to the decision walk after language selection:

1. Prefer a complexity analyzer already pinned in the project's normal toolchain.
2. Record its stable invocation, version command, source population, and exclusions in the deployed
   Complexity rule's `How to quantify` section and in `metrics.sh`.
3. If none is available, record `status: unavailable`; do not install a package or invent a number.

`metrics.sh` remains a stable, project-owned read-only entrypoint and stores no history. Relax the
Auditor-specific “dependency-free” sentence only enough to permit commands already pinned by the
host toolchain. The script itself must use shell plus declared project tools, perform no network or
installation, and preserve the existing behavior of other metrics.

The `metrics.sh` stub in `BOOTSTRAP.md` owns two distinct units:

1. a project-filled adapter that invokes the selected analyzer, enumerates its declared file
   population, and emits the normalized TSV rows and coverage counters above; and
2. a generic validation and aggregation body, delimited by stable
   `# complexity-summary begin` / `# complexity-summary end` comments, that setup copies verbatim.

The generic body rejects malformed or duplicate rows, orders candidates by score descending then
path bytewise, line numerically, and symbol bytewise, and computes the facts below. Package tests
execute this shipped body against fake adapter output; they do not reimplement its arithmetic in a
test-only function. Analyzer-specific parsing remains in the project-filled adapter.

Its Complexity output is a compact fact set containing analyzer, version, status, population,
exclusions, expected/analyzed/skipped/parse-error file counts, authored-function count, maximum,
upper-percentile value when the analyzer supplies at least ten authored functions, count above the
host-calibrated hotspot threshold when one exists, and the ten highest-scoring functions with
locations. The upper-percentile fact is nearest-rank p90 over the attributed function population;
for fewer than ten functions it is `--`. For `partial`, both p90 and threshold count are `--`. Do
not synthesize a threshold count when no calibrated threshold exists. The pass report quotes these
facts; report history remains the trend store.

An available complete population with zero authored functions reports authored-function count `0`,
maximum and p90 as `--`, an empty hotspot list, and threshold count `0` when a calibrated threshold
exists (`--` when none exists).

Complexity is not added to `metrics.sh --check` by default. A host may deliberately promote a
specific complexity invariant into its own gate, but the portable rubric provides no failure
threshold.

Fresh Auditor setup deploys and indexes all thirteen portable dimensions. Existing deployed rubrics
remain host-owned incumbents: ordinary audit, `metrics`, and `check` never add the new rule or edit
`GUIDE.md`/`metrics.sh`. An explicit setup rerun may seed the absent bundled rule under Auditor's
namespace, but setup is not complete until the decision walk either calibrates and indexes it with
the owner's approval or explicitly reports that the incumbent rubric has left it inactive. No
incumbent file is silently refreshed, and no audit scores an unindexed rule merely because the file
exists.

### Package independence and live surfaces

Inspector and Auditor keep their current typed edges and output custody. Inspector does not consume
Auditor doctrine or reports; Auditor does not consume Inspector verdicts. No pack seam, project hook,
front-door variable, shared analyzer file, or cross-skill call is added.

Update only live catalog or package prose whose numeric dimension count or advertised behavior would
otherwise become false. Historical specifications, plans, and reports remain historical evidence and
are not rewritten.

## Verification

### Inspector

- Refinement fixtures surface removable flag/mode cross-products, redundant fallback branches, and
  substrate-shaped alternatives while preserving required safety and failure branches.
- Refinement never runs an analyzer, emits a numeric complexity claim, accepts implementation, or
  changes its proposal/confirmation/status/re-review machine.
- Implementation fixtures cover a same-analyzer regression, a high-but-justified exhaustive
  dispatch, a numeric hotspot with no consequential defect, analyzer unavailability, and avoidable
  branching with missing path evidence.
- A raw score or threshold crossing cannot select a verdict; the fixture requires the complete
  materiality chain for a finding.
- The reviewed implementation target remains unmodified, and review exposes no
  revise/refine/remediation transition.

### Auditor

- The bundled Complexity rule contains the complete uniform shape, `CPLX` ownership seam, scoring
  anchors, ordered decision logic, analyzer-unavailable behavior, and false-positive refutations.
- Readability names the reciprocal seam, and a fixture rejects duplicate findings for one defect.
- BOOTSTRAP and its GUIDE skeleton enumerate thirteen portable dimensions and index Complexity.
- Fresh setup deploys thirteen rules; rerun and customized incumbents remain byte-identical except
  for changes explicitly authorized during the interactive decision walk.
- Metrics fixtures prove available and unavailable analyzer states, identity/version reporting,
  the partial state, malformed/duplicate-row refusal, exclusions, stable population attribution,
  deterministic ranked hotspots, and no default `--check` failure. They execute the generic summary
  body shipped in the BOOTSTRAP stub.
- A deployed twelve-rule rubric fixture proves both explicit outcomes after setup seeds the absent
  Complexity leaf: adoption edits and indexes the calibrated rule only after the owner's decision,
  while inactive disposition preserves `GUIDE.md` and `metrics.sh`, reports the inactive leaf, and
  leaves ordinary audit passes unable to score it.
- A mutation that replaces analyzer output with regex branch counts must fail.
- A mutation that turns the calibrated hotspot threshold into an automatic finding or gate must
  fail.

### Whole feature

- Red-prove every new check by planting one defect, requiring the assertion to fail, restoring the
  fixture, and confirming byte identity.
- Run `skills/inspector/scripts/tests/run.sh`, `skills/auditor/scripts/tests/run.sh`, and
  `skills/skill-builder/scripts/skills-lint.sh`.
- Run Architect's ground check over this specification, then re-read the complete changed routers,
  verbs, kind/rule doctrine, setup paths, tests, and live catalog surfaces.
- Grep confirms neither package names or reads the other inside its leaf implementation.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| C1 | Add Inspector's qualitative design-simplicity and change-scoped implementation complexity judgments | Inspector refine + implementation fixtures and red-proofs | `skills/inspector/{verbs/refine.md,kinds/implementation.md,scripts/tests/refine-test.sh,scripts/tests/implementation-test.sh}` |
| C2 | Add Auditor's portable Complexity rule, normalized analyzer/summary contract, Readability seam, fresh and brownfield setup behavior, and all affected tests | full Auditor harness with available/partial/unavailable, setup-adoption, inactive-leaf, and red-proof fixtures; library lint | `skills/auditor/{SKILL.md,BOOTSTRAP.md,verbs/setup.md,rules/complexity.md,rules/readability.md,scripts/auditor-seed.sh,scripts/tests/complexity-test.sh,scripts/tests/setup-test.sh,scripts/tests/run.sh}` |

C1 and C2 are independent. One landing may contain both after their package-local tests pass.

## Out of scope

- Code remediation or code refinement by Inspector.
- A new Inspector audit verb or a shared Inspector/Auditor runtime.
- Cognitive-complexity, NPath, Halstead, maintainability-index, coverage, or churn-weight formulas;
  they may be considered later but are not aliases for this metric.
- Automatic analyzer installation, network access, a universal threshold, or cross-analyzer trend
  comparison.
- A standing complexity database or CSV; audit reports remain the trend history.
- Retrofitting historical specs, plans, reports, or already deployed host rubrics without explicit
  owner calibration.
