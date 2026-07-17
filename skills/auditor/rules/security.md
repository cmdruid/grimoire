# Security -- audit rule
> Are the trust boundaries held and secrets kept out of every observable sink?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `SEC`.

## Why it matters

Even applications with a narrow attack surface have at least one trust boundary:
a secret (API key, token, credential) enters the process from the environment or a
config file and must travel only to the one authenticated endpoint it authorizes,
never to a log line, a screenshot artifact, a committed file, or any other
observable sink. A second common boundary is a tool-dispatch or plugin layer that
executes external code: if that layer is not constrained to a declared surface, it
becomes an arbitrary execution path.

The scope of this dimension scales with the application's threat model. A server
handling financial data has a broad threat model; a desktop utility calling a
cloud API has a narrow one. In either case, the key invariants are:

1. Secrets are read from the environment in exactly one place, stored in a
   non-inspectable field, and consumed only at the authorized sink.
2. Tool-dispatch / plugin / eval surfaces are constrained to a declared interface;
   no escape to arbitrary shell execution or unrestricted file I/O.
3. No secret reaches any observability sink: the log stream, debug output, or
   diagnostic artifacts.

**Boundary with OBS:** OBS owns the *structure* of what is logged (are stray print
calls present, is structured logging used correctly). SEC owns whether a *secret
value* reaches any of those sinks. A finding about logging format lands in OBS;
a finding about a credential in a log line lands in SEC.

## Scoring anchors (1-5)

- 5 -- Secrets are read from the environment in exactly one place, stored in a
  non-inspectable field (not `<language: debug-printable>`), sent only to the
  authorized sink, and never passed to any log macro or artifact path. The secret
  source (e.g., `.env`) is gitignored and no key-like literal appears in committed
  code. The tool-dispatch boundary is enforced: the declared interface is the sole
  dispatch point and no escape hatch (arbitrary shell exec, unrestricted file
  write, etc.) exists.
- 4 -- One minor deviation: e.g., the secret-carrying type derives a debug
  representation but no call site actually prints it. No secret literal committed.
- 3 -- The secret is never logged but the type carrying it is debug-printable and
  passed near a log call at least once. Or: one config path is missing validation
  and would fall through to an error message containing the secret on a
  misconfiguration. Tool boundary holds.
- 2 -- The secret value (not just its presence) appears in at least one log or
  print call in a non-test code path. Or: the tool-dispatch surface has an
  unconstrained code path that can reach outside the declared boundary.
- 1 -- The secret is hardcoded as a literal, or committed in a config file, or
  logged on every use. The tool-dispatch surface has no meaningful boundary.

## Decision logic

1. Run the secret-exposure greps (see Anti-patterns).
2. Inspect the secret-carrying type: is the field private? Does the type derive
   a debug/inspect representation? Is the field ever formatted or passed to a log
   macro? Confirm the secret travels only to the authorized sink.
3. Check that the secret source (e.g., `.env`) is gitignored and that no key-like
   literal (long alphanumeric string) appears in committed source files other than
   placeholder examples.
4. Inspect the tool-dispatch / plugin layer: enumerate the declared interface.
   Confirm none provide arbitrary shell execution, unrestricted file I/O, or
   network calls outside the declared surface.
5. Check diagnostic artifact paths (e.g., captured run artifacts, state dumps): scan
   output format for any field that serializes the secret or the model configuration.
6. Score against the anchors; use the lower anchor when two fit.
7. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: find environment-variable reads in source -- triage each for whether the value is logged.>
<language: find secret/key/token field names passed to logging macros.>
<language: find the secret-carrying field -- confirm it is never formatted into a log.>
<language: find hardcoded key-like string literals (20+ chars, alphanumeric/dash/underscore).>
<language: check whether the secret source file is tracked by version control.>
<language: find tool-dispatch / plugin execution entry points -- confirm they are declared, not open-ended.>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Presence check on the secret env var.** A check for whether the variable is
  set (e.g., `.is_ok()` or `is_defined`) discards the value; this is correct and
  is not a finding. The log line that follows it logs the outcome, not the secret.
- **The secret field is a string type.** The primitive string type does not expose
  the value in a debug representation by default in most languages; what matters is
  whether the *containing type* derives a debug representation AND is passed to a
  log macro. Check both conditions before filing.
- **Placeholder example file in the repo.** An example config file containing only
  a blank placeholder (e.g., `API_KEY=`) is the canonical pattern for onboarding.
  A committed example with a placeholder is correct; a committed config with a real
  key is a finding.
- **Test-only env vars.** Environment variables that load test fixtures or
  scripted models do not carry secret values. Not a SEC finding.
- **Pre-initialization print calls.** Print calls that run before any secret is
  read (e.g., usage-error messages printed at startup before config is loaded)
  carry no secret material. Not a finding.

## How to quantify

<language: count environment-variable reads (manual triage required for each);
confirm zero key-like literals in committed source;
count declared tool/plugin interface entries (the declared surface).
Report as: `env reads: N (triage); long literals: L; tool declarations: T`.
SEC findings are binary -- either the boundary holds or it does not. A single
confirmed secret-exposure is a P0 finding regardless of score.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
