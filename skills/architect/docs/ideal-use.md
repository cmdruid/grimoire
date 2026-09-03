# Ideal use — a worked arc through the spine

A *"how to use me"* example, read on demand. Both branches below are legitimate. The feature arc
ends at the accepted specification; saved drafts and spike records are supporting artifacts, not
feature handoffs.

## The feature: JSON output for `report`

`brainstorm "let users get report output as JSON"` harvests the conversation and reads the current
command. It proposes a `--json` flag and a separate subcommand, recommending the flag because it
reuses the existing parse and report model. The user gets a useful synthesis in conversation.

### Branch A: conversation was enough

The user decides not to keep working on the idea. Architect stops. No draft, spec record, or other
artifact was created. Duration, importance, and unresolved questions do not change that outcome.

### Branch B: save, resume, and promote

The user says `brainstorm save report-json`. Architect writes one current synthesis to
`.agents/skilldata/architect/drafts/report-json.md`. A later agent resumes that explicit path,
updates the same file, and may run a confirmed bounded spike only if cheap investigation cannot
settle a material feasibility question. Completed spike evidence is linked from the draft.

`spec <draft>` carries settled decisions and relied-on spike citations into a new `architect/spec@1`
record. It does not copy transient experiment code or raw working notes. After the dated spec exists,
Architect marks the draft `Disposition: promoted` and links the spec. It grills remaining gaps,
self-reviews, and asks the human to read the result. The spec remains `status: draft` until the
caller's accepted review publishes it.

The accepted spec is Architect's sole feature baton. Implementation sequencing is a different job.

## Genesis (a different arc)

The feature-spec arc above still ends at the accepted spec. Genesis is a different arc: `new` mints
a founding-shaped working file, `grill` / `spec` fill its six map sections in place, and `deploy`
materializes a git repository. Do not run this arc on a feature spec or workspace draft.
