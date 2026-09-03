# `capture` — preserve one feedback observation

This procedure serves both explicit human capture and conservative agent-selected capture. Determine
the path from who owns the observation; never infer `origin` from its tone.

## Explicit human capture

Use only for `/agent-feedback capture <subject-type> <subject> [<message>]`.

1. Require one declared subject type (`skill`, `agent`, `harness`, `tool`, or `workflow`) and one
   lowercase-kebab subject. If either is missing or ambiguous, ask one concise question and do not
   call the provider. Unknown option-shaped input refuses.
2. Use `[<message>]`, or feedback prose elsewhere in that same human utterance when the positional
   message is omitted. If neither supplies a statement, ask one concise question and stop.
3. Preserve the human's statement as closely as the privacy pass allows. Produce a faithful summary
   of at most 240 UTF-8 bytes. Classify `friction`, `gap`, `win`, or `request`; generic praise and an
   incomplete suggestion are valid human submissions.
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

After real work, capture at most one highest-signal observation only when current context names one
reusable agent-facing subject and supports a concrete change or preservation case, incident,
consequence, response, and privacy-safe wording. Consuming-project defects, ordinary success, generic
praise, ratings, preferences, and speculative redesign skip silently. Never automatically capture
feedback about `agent-feedback` itself. Set `origin=agent`; all three detail fields are nonempty.
If no subject is defensible return `skipped=subject-ambiguous`; if the evidence bar fails return
`skipped=no-change-worthy-feedback`. Ask no follow-up on this path and invoke the provider at most once.

When inside a project, an optional project reference is
`local-sha256:<first-16-lowercase-hex>` of the physically resolved Git root; never store the path.
Provider failure is advisory to completed work: report its single diagnostic without reopening the
work or questioning the user.

Done when one requested or qualified observation was captured through one provider call, or the
documented ambiguity/skip outcome occurred without mutation.
