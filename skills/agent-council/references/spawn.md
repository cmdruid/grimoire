# Spawn — the harness edge

Re-read each binary's `--help` once per session. Flags drift; this file
is intent plus a last-known surface, not a pin.

The orchestrator writes a prompt file in scratch and captures **stdout**
into `round1/<seat>.md` or `review/<seat>.md`. Codex `-o` is the parent
CLI writing the final message — same idea. Seats do not write scratch.

cwd for every seat is the **target workdir** (the directory target, or
the file’s parent; a `SKILL.md` file retargets to its parent). No model
pin unless the user named one for this convene. Read-only: prefer an
allow-list of read tools; otherwise disallow write/edit tools. If a CLI
would hang on a permission prompt, pass its non-interactive approve
flag **after** write tools are already gone.

| Seat | Letter | Binary | Intent |
|---|---|---|---|
| Claude | `c` | `claude` | `claude -p --bare` with write tools disallowed. If the process does not start in the target, `--add-dir <target>`. Allow `Read,Glob,Grep` (or the current equivalents). |
| Grok | `g` | `grok` | `grok -p --cwd <target> --prompt-file <scratch-prompt>`. Disallow write/edit tools (`--disallowed-tools` / `--tools` allow-list — re-read help). `--always-approve` only after writes are gone. |
| Codex | `x` | `codex` | `codex exec --sandbox read-only -c approval_policy="never" -C <target> -o <ballot-or-review-file>` with the prompt as the argument or on stdin. |

Do not retry an identical failed dispatch. Do not substitute a
same-family subagent. The orchestrator's own context is not a seat.
