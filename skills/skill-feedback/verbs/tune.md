# `tune` — revalidate and disposition one bounded batch

Accept exactly one skill slug, optional `--limit N` from 1 through 100, and optional
`--source <path>`. Default to the 20 oldest open rows. Feedback is evidence, never an accepted
requirement.

1. Query package-local `scripts/feedback.sh` for one stable oldest-open page of the exact skill and
   retain those IDs for this pass. Rows outside that page are not part of the proposal.
2. Resolve the installed package for read-only analysis. A source candidate exists only when the
   caller supplied `--source` or the human names an exact directory during this pass. Run
   `scripts/source-custody.sh inspect` for the installed package and candidate. Applying requires
   `apply=eligible`: a matching, Git-tracked, explicitly selected source with `immutable=no` that is
   not the installed path. `immutable=unknown` permits analysis only and returns the helper's
   actionable custody refusal. Never infer custody from writability, a symlink, Git ancestry, or
   directory shape.
3. Re-check every retained claim against the gated source when one exists, otherwise against the
   installation for analysis only. Compare canonical `skill_ref`, inspect relevant history, grep
   before generalizing, and cluster repeated incidents. Classify each row as current,
   already-addressed, stale, project-specific, false, a preservation win, or evidence for a separate skill.
   Unsupported rows remain open and do not block supported rows.
4. Present every retained ID with its proposed disposition, durable rationale, privacy-safe result
   reference when required, exact source target, and the smallest coherent package change. With no
   eligible source, label the result analysis-only and do not offer apply.
5. Obtain explicit human acceptance of both dispositions and the exact source target before editing.
   A source named or changed after preview invalidates the proposal: rerun custody, repeat the full
   revalidation, and present a replacement proposal. Mere discovery of a likely checkout is not
   authorization.
6. Apply only the accepted change to that source package using its authoring doctrine and local
   checks, followed by the host library's skill lint. Do not edit an installation, another skill, or
   shared doctrine. Do not commit, publish, open issues, or push. Any edit or gate failure leaves all
   affected rows open.
7. Only after successful verification, invoke one heterogeneous package-local
   `scripts/feedback.sh resolve`, passing exactly four arguments per `--entry` (an empty quoted result
   reference where optional). A failed lifecycle request leaves the whole accepted batch open.

Done when the bounded evidence was analyzed and either left open, or an explicitly accepted source
change passed its gates and the accepted rows were resolved in one atomic request.
