# Observability -- audit rule
> Is logging structured, routed, and free of stray output?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `OBS`.

## Why it matters

Most projects establish one or more sanctioned observability channels (a structured
logging framework, a diagnostics overlay, a metrics sink). Stray `<language: print
statements>` bypass all sanctioned channels: they are invisible to log filters,
unstructured, impossible to route or redact, and likely to leak developer-facing
internals to end-users in a production build. They are also the first place a
secret value would appear if a debug-print were left in.

Where a tool-dispatch or agent layer is involved, log calls that record tool events
must carry structured fields so that a future log filter can silence or capture
those events independently.

**Boundary with SEC:** OBS owns whether logging is *structured and routed*. SEC
owns whether a *secret value* appears in a log line. A print call with no sensitive
content is an OBS finding; the same line printing a credential is a SEC finding.
File in SEC and note the OBS violation; don't double-count.

**Boundary with dev-tool code paths:** print calls and stderr writes in
command-line tool paths (e.g., a dump/inspect mode that runs instead of the
application's normal mode) are acceptable because those paths are terminal-mode
tools, not the hot path. Triage each hit before filing.

## Scoring anchors (1-5)

- 5 -- All runtime diagnostic output goes through the sanctioned logging framework.
  No `<language: stray print/write calls>` in production code paths (main loop,
  content loaders, agent/dispatch layer). Any diagnostic overlay or snapshot
  resource is wired through the structured channel, not ad-hoc strings. Agent or
  tool-dispatch events carry structured fields.
- 4 -- One or two stderr/print calls exist in early-startup error paths (before
  the logging framework initializes) with a clear justification comment. All
  in-application and content-loader paths use the sanctioned channel.
- 3 -- Several print calls in content loaders or application code that should
  use the structured channel instead. Structured logging is mixed (some events
  use the framework, some fall back to print). Diagnostic overlay works but some
  fields are formatted ad-hoc outside the sanctioned resource.
- 2 -- Print calls scattered across content loaders and application systems. No
  distinction between structured diagnostic output and unstructured debug prints.
  Debug-print calls present in non-test code.
- 1 -- Print calls are the primary output channel. The logging framework is wired
  but not actually used for runtime events. No structured event logging. Debug
  prints in hot-path code.

## Decision logic

1. Run the stray-output grep (see Anti-patterns). Collect every hit.
2. For each hit, classify the call site:
   - Inside a test-only block -> **acceptable, skip**.
   - In a CLI-mode path that runs instead of the application window (e.g., a
     `--dump` or `--tool` branch) -> **acceptable; note as intentional CLI output**.
   - In a content loader (e.g., a definition file loader, a config reader) ->
     **finding candidate**: these should use the structured logger to stay routed.
   - In any application system (functions registered in the main loop) -> **finding**.
3. Triage debug-print hits separately: temporary debug aids should never appear in
   committed non-test code.
4. Check tool/agent logging: does the dispatch layer use structured logging with
   field syntax (`log!(field=value, "message")`) or bare string interpolation?
5. Score against the anchors; use the lower anchor when two fit.
6. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: find all stray print/write/debug-print calls in source -- every hit needs manual triage.>
<language: count stray output calls (denominator for scoring).>
<language: find content-loader paths that use stray prints instead of the structured logger -- highest-priority findings.>
<language: check tool/agent logging for structured field syntax vs bare string interpolation.>
<language: find debug-print calls in non-test code -- the most urgent catch.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Print calls in CLI-mode branches.** A `--render`, `--dump`, or `--tool` branch
  that prints to stdout/stderr before or instead of launching the application is
  intentional terminal-mode output; the logging framework may not even be
  initialized at that point.
- **Inspector / tool output paths.** A tool path that writes its result to stdout
  (e.g., the path to a generated file) is the tool's intended output channel; it
  is not an application-loop log.
- **Print calls in test-only blocks.** Test output is acceptable; it does not
  affect the end-user or the log stream.
- **Content loaders using print calls -- these are NOT false positives.** These are
  the primary OBS finding candidates: the message content may be correct (errors
  surfaced, defaults applied) but the channel bypasses the structured logger. Triage
  each: the fix is to route through the logging framework, not to remove the message.

## How to quantify

<language: count stray output calls (all source); count the subset in content-loader
paths (highest-priority candidates); count structured-logger calls (positive signal --
are the macros being used at all?). Report as:
`stray output: N total (M in content-loader paths); structured-log calls: T`.
A rising stray-output count is an early signal that new code is not following the
logging convention.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
