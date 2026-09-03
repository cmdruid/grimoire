# `capture` — preserve one change-worthy observation

This procedure also handles bare `/skill-feedback` and `/skill-feedback <skill>`.

1. Resolve the target from the explicit skill argument, otherwise from the most recently completed
   named skill in the current custodial context. Never infer it from a generic tool call. If there is
   no defensible target, return `skipped=skill-ambiguous` without asking a question. An explicit
   `capture skill-feedback` is legal; an automatic post-use route must not target this skill itself.
2. Apply all five checks before storing anything:
   - **Change:** the observation would plausibly change the target skill or preserve behavior a
     future revision might remove.
   - **Incident:** identify what concretely happened in this invocation.
   - **Consequence:** identify the failure, ambiguity, workaround, excess work, avoided error, or
     useful protection.
   - **Response:** name a plausible instruction, mechanism, trigger, test, or boundary to change or
     preserve.
   - **Privacy:** remove project/person names, absolute paths, proprietary identifiers, secrets, raw
     prompts, environment values, and unnecessary source excerpts.
3. If the change test fails or any other required part would need guessing, return
   `skipped=no-change-worthy-feedback`. Generic praise, ratings, preferences without an incident,
   speculative redesign, and consuming-project defects do not qualify. If several unrelated items
   qualify, choose the highest-signal one; one invocation records at most one coherent observation.
4. Structure a one-sentence summary (at most 240 UTF-8 bytes), nonempty incident, consequence, and
   suggestion (each at most 2,000 UTF-8 bytes), and classify `friction`, `gap`, `win`, or `new-skill`.
   For a win, the suggestion states exactly what should be preserved. Do not pass the caller's raw
   observation through unchanged.
5. Resolve the installed target package when safely available and run package-local
   `scripts/skill-content-ref.py <skill-directory>`. Use its `content-sha256:` result; otherwise use
   `unknown`. Record the used command or verb as the invocation, or `unknown` only when context
   supplies none.
6. When inside a project, physically resolve its Git top level and compute
   `local-sha256:<first-16-lowercase-hex>` over that absolute path. Pass no project reference outside
   a project. Never store the path itself.
7. Invoke package-local `scripts/feedback.sh capture` exactly once with the structured fields and
   optional project reference. Return only its `captured=<id>` and `count=1` lines. Provider failure
   is advisory to the completed skill outcome: report its single diagnostic without reopening the
   completed work or questioning the user.

Done when one qualified observation was captured through one provider call, or one documented
`skipped=` reason was returned without mutation or follow-up.
