# `capture` — preserve one feedback observation

This procedure serves both explicit human capture and conservative agent-selected capture. Determine
the path from who owns the observation; never infer `origin` from its tone.

## Explicit human capture

Use only for `/agent-feedback capture <subject-type> <subject> [<message>]`.

1. Require one declared subject type (`skill`, `agent`, `harness`, `tool`, or reusable `workflow`)
   and one subject. Normalize an unambiguous subject to lowercase kebab of at most 120 UTF-8 bytes;
   never guess among targets. If either is missing or ambiguous, ask one concise question and do not
   call the provider. Unknown option-shaped input refuses.
2. Use `[<message>]`, or feedback prose elsewhere in that same human utterance when the positional
   message is omitted. If neither supplies a statement, ask one concise question and stop.
3. Preserve the human's statement nearly verbatim except necessary privacy redaction and whitespace
   normalization. Produce a faithful summary of at most 240 UTF-8 bytes. Classify `friction`, `gap`,
   `win`, or `request`; generic praise, an incomplete suggestion, and a `win` with no suggestion are
   valid human submissions.
4. Fill incident, consequence, and suggestion only where the human's words or current context support
   them; each may be empty. Do not invent detail. If safe redaction would destroy the meaning, ask for
   a safe restatement instead of storing one you invented.
5. Apply the privacy pass: remove secrets, raw prompts, environment values, absolute project paths,
   proprietary identifiers, person/project names, and unnecessary excerpts. Set `redacted=yes` if
   anything changed, otherwise `redacted=no`.
6. Set `origin=human` and `invocation=/agent-feedback capture`. Resolve `subject_ref` only for a
   skill, using package-local `scripts/skill-content-ref.py` when a safely available installed skill
   directory is unambiguous; otherwise use `unknown`.
7. Invoke package-local `scripts/feedback.sh capture` exactly once with every required flag and an
   optional privacy-safe project reference. Return only `captured=<id>`, `count=1`, and
   `redacted=yes|no`; never echo stored content.

## Agent-selected capture

After real work, capture at most one coherent highest-signal observation only when all five checks
pass:

1. **Reuse ownership:** the remedy belongs to a reusable skill, agent, harness, tool, or workflow,
   not the consuming product or one repository's local process.
2. **Change-worthiness:** the observation could change the subject or preserve valuable behavior.
3. **Incident and consequence:** current context establishes what happened and why it mattered.
4. **Response:** current context supports a change, test, boundary, or preservation instruction.
5. **Privacy:** every stored field satisfies the privacy pass above.

Consuming-project defects, local-process feedback, ordinary success, generic praise, ratings,
preferences, and speculative redesign skip silently. Never automatically capture feedback about
`agent-feedback` itself. Set `origin=agent`; incident, consequence, and suggestion are all nonempty,
and a preservation `win` names what must remain intact. If no single subject is defensible return
`skipped=subject-ambiguous`; if any other quality check fails return
`skipped=no-change-worthy-feedback`. Ask no follow-up on this path, call the provider at most once,
and therefore add at most one row.

For a qualifying case, classify the subject type and one of the four kinds, write a concise summary
and coherent privacy-safe statement, retain the actual command/verb/interaction as `invocation` (or
`unknown` only when none is available), fill the three supported detail fields, and set `redacted`
from whether the privacy pass changed the statement. Resolve a skill content reference only as
described below. Invoke the same exact provider `capture` grammar used by the human path with
`origin=agent`; do not ask the provider to infer or repair any field.

When inside a project, an optional project reference is
`local-sha256:<first-16-lowercase-hex>` of the physically resolved Git root; never store the path.
`subject_ref` is `unknown` unless current context supplies a privacy-safe reference of at most 512
bytes. References may be repository-relative identities or non-local URLs, but never contain a
parent traversal segment or use a POSIX-absolute, Windows-drive, UNC/backslash-rooted, tilde-rooted,
or local `file:` URI form. Only a skill subject may use the package content identity helper, and a
repository commit never substitutes for subject identity. Provider failure is
advisory to completed work: report its single diagnostic without reopening the work or questioning
the user.

Done when one requested or qualified observation was captured through one provider call, or the
documented ambiguity/skip outcome occurred without mutation.
