---
name: gcloud-operator
description: "Use when an agent must run gcloud, SSH, or SCP against Google Cloud; when a private Compute Engine VM is reachable only through Identity-Aware Proxy; when OS Login 2FA prompts for a security code (g.co/sc) or Google Authenticator; when a repository sandbox blocks writes to ~/.config/gcloud; or when control-plane work needs service-account impersonation. Keywords: gcloud, IAP, OS Login, 2FA, MFA, start-iap-tunnel, compute ssh, compute scp, ~/.config/gcloud."
---

# gcloud-operator — IAP/OS Login sessions for Google Cloud

Operate GCP from an agent session without weakening IAP-only SSH, OS Login 2FA, IAM, or
the caller's mutation approvals. Session creation does **not** authorize a resource mutation.

Disposition: **scratch-only**. Ephemeral `mktemp` session directories; no durable project home.

## Choose a path

| Situation | Path |
|---|---|
| Cached `gcloud` already authenticated; control-plane read or an already-authorized mutation | Ordinary `gcloud` with `--project` / `--zone` (escalate the helper if the sandbox blocks `~/.config/gcloud`) |
| Several SSH commands or file transfers to a private VM | Persistent IAP/SSH session below |
| Bounded control-plane call that must run as a service account | `gcloud --impersonate-service-account`; never SSH |
| OS Login 2FA will prompt | Stop, collect a **fresh** code, then `open` |
| Unattended guest deploy / no human for 2FA | Stop; that needs a deployment architecture, not this helper |

## Helper

Resolve `scripts/gcloud-session.sh` from this skill's own base directory. It is the one
stable entrypoint (prefix-matching approval can permit the whole capability).

```
gcloud-session.sh doctor --project PROJECT --zone ZONE --vm VM
gcloud-session.sh open   --project PROJECT --zone ZONE --vm VM
                         --mfa-method security-code|authenticator
                         [--mfa-code-file PATH] [--control-persist SECONDS] [--tmux]
gcloud-session.sh run        -- HANDLE [--] COMMAND [ARG...]
gcloud-session.sh copy-to    -- HANDLE LOCAL_PATH REMOTE_PATH [--overwrite]
gcloud-session.sh copy-from  -- HANDLE REMOTE_PATH LOCAL_PATH [--overwrite]
gcloud-session.sh status     -- HANDLE
gcloud-session.sh close      -- HANDLE
gcloud-session.sh troubleshoot --project PROJECT --zone ZONE --vm VM --authorize-mutations
```

`--mfa-method` is required and **never inferred from digit count**. `security-code` is
https://g.co/sc. `authenticator` is a Google Authenticator one-time password.

## Operator session

1. Run `doctor`. It is read-only. Confirm the printed VM identity, project, zone, account,
   `planned_network_path=iap-tcp`, and `transport=unverified`. Effective `oslogin` /
   `oslogin_2fa` must be true (instance metadata overrides project). If
   `class=sandbox_denied`, escalate this helper; **do not copy**
   `~/.config/gcloud` or credentials into the repo, the host temporary directory, or the session directory.
2. If a master already exists for this handle (`status` `alive=true` and identity matches), do not
   ask for another code.
3. Ask the human to choose `security-code` or `authenticator` and to give a **fresh** code. Write
   the code to a regular, non-symlink file owned by the current user, mode `0600` (no group or
   other access), that is not in the repo. Prefer a non-echoing secret-input channel when the
   harness has one. An ordinary PTY write is not secret; never claim it is.
4. Run `open` immediately with `--mfa-code-file`. Do not wait across a user turn with a live
   prompt. `open` accepts the file, then unlinks it on every path — including preflight and
   dry-run failures. It reports `mfa_completed=true` only after matching the requested method
   and submitting the code to an OS Login verification prompt. It reports `transport=verified`
   only after the master is alive. Never repeat the code in a reply, log, state file, or error.
5. `run` / `copy-to` / `copy-from` reuse the master. This does not authorize guest mutations; the
   surrounding task or runbook must authorize the exact command.
6. `close` the handle when done. It is idempotent and removes only that session's processes and
   paths.

Default `ControlPersist` is 12 minutes (60–3600 allowed). `status` prints `expires_at`.

## Examples

Read-only inspection (no MFA yet):

```
gcloud-session.sh doctor --project PROJECT --zone ZONE --vm VM
```

One session, several guest commands, then a round-trip file (after a fresh MFA code):

```
gcloud-session.sh open --project PROJECT --zone ZONE --vm VM \
  --mfa-method security-code --mfa-code-file /path/to/code
# handle=/tmp/gcloud-operator-sess.xxxxxx
gcloud-session.sh run -- HANDLE -- uname -a
gcloud-session.sh run -- HANDLE -- systemctl is-active ssh
gcloud-session.sh copy-to -- HANDLE ./notes.txt /tmp/notes.txt
gcloud-session.sh copy-from -- HANDLE /tmp/notes.txt ./notes.from-vm.txt
gcloud-session.sh close -- HANDLE
```

Transport mechanics, multiplexing hypothesis, and the interactive-shell fallback:
`references/transport.md`. Failure catalog: `references/failures.md`. Threat model:
`references/threat-model.md`. Live proof (explicit approval only): `references/live-smoke.md`.

## Safety

- Require explicit `PROJECT`, `ZONE`, and `VM` on every new session. No glob or ambiguous name.
- Keep IAP-only SSH intact. Never create an external IP or a public TCP 22 rule as a workaround.
- `doctor`, `open`, `status`, and ordinary recovery do not enable APIs, create diagnostic
  resources, alter metadata, change IAM, or mutate firewalls.
- Prohibit `gcloud compute ssh --troubleshoot` by default. If the caller authorizes that exact
  command, `troubleshoot --authorize-mutations` previews possible mutations (Network Management
  API enablement; connectivity-test resources), inventories prior state, and prints cleanup.
- Do not persist Google credentials, SSH private keys, tokens, or MFA values in the session
  directory.
- `copy-*` refuses to overwrite an existing destination unless `--overwrite`.
- Cleanup never targets unresolved variables, globs, home directories, repository roots, or
  the host temporary directory as a whole.

## Service accounts

Impersonation is an optional **control-plane** mode (`doctor --impersonate-service-account`).
It uses the caller's identity for short-lived credentials so audit logs keep the original
principal. Never create or recommend persistent service-account keys when impersonation or
workload identity is available. Never use a service account to bypass OS Login 2FA for
interactive production administration. Do not grant impersonation or IAM roles automatically.

## Edges

Scratch-only operator: ephemeral session dirs, no typed artifact, no registration.

<!-- edges:gcloud-operator -->
- produces: — (ephemeral IAP/SSH session state, consumed inline, not a typed artifact)
- handoff: — (none; the caller continues the surrounding task)
- consumes: — (none; reads caller-supplied project/zone/vm, not a typed artifact)
<!-- /edges:gcloud-operator -->

## Done when

`doctor` printed the exact target; one MFA event opened the session if required; subsequent
commands and transfers reused that handle; `close` removed the socket and tunnel; no helper
step weakened IAP, OS Login 2FA, IAM, or the caller's mutation approvals.
