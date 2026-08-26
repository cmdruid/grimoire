# `setup [<root>]` — deploy active Contractor templates

Run package-local `scripts/contractor-setup.sh <root>` standalone, or add `--write-only` in an
announced configuration sweep. It preflights and immediately rechecks every write, then deploys
`plan.md` and `roadmap.md` absent-only beneath `<agent-workspace>/contractor/templates/`. Valid
incumbents win; recognized legacy copies refuse with `/contractor migrate <source-path>`.

Runbooks remain compiled and no generic runbook template is deployed. Schemas, record shells,
package-only assets, and sibling paths stay packaged or untouched. Standalone setup makes one
pathspec-scoped commit over exactly its reported writes; sweep mode is write-only and a no-op rerun
makes no commit.

Done when both templates are present and valid and commit custody matches the invocation mode.
