# Failures

Start with non-mutating process, socket, account, IAM, VM, and IAP checks. Do not recommend
`gcloud compute ssh --troubleshoot` as the first recovery action.

| Symptom | `class=` | What to do |
|---|---|---|
| `Operation not permitted` / not writable `~/.config/gcloud` | `sandbox_denied` | Escalate `scripts/gcloud-session.sh`. Do not copy the credential store. |
| `invalid_grant` / reauthentication required / no active account | `auth_expired` | Human reauthenticates `gcloud`; then `doctor` again. |
| `PERMISSION_DENIED` / IAM 403 on describe or IAP | `iam_missing` | Stop. The caller grants roles; this helper does not. Need the inspection and IAP/OS Login roles below. |
| 2FA reject / keyboard-interactive denied | `oslogin_2fa` | Wrong method or stale code. Choose `security-code` or `authenticator` explicitly; request a **fresh** code. Do not retry a code the server already accepted. |
| IAP tunnel / `start-iap-tunnel` 403 | `iap_failure` | Confirm IAP IAM and that the VM has no requirement for a public SSH path. Keep IAP-only. |
| `Permission denied (publickey)` / sshd refused | `guest_ssh` | OS Login profile, guest sshd, or key publication. Still do not open TCP 22. |
| `Address already in use` | `port_occupied` | The default `ProxyCommand` path should not bind a local port. If a fallback bind collides, close the stale session or pick another port. Never kill unrelated listeners. |
| Control socket present, `ssh -O check` fails | `stale_socket` | `close` that handle; `open` a new session with a fresh code. |
| Socket gone or master died mid-command | `master_dead` | `close`, then `open` again. Optional remote `tmux` protects in-guest work, not the tunnel. |
| MFA menu never appeared before timeout | prompt expiry | Request a fresh code; `open` immediately after it arrives. |
| Connection dropped after the code was sent, before success or a clear reject | ambiguous auth | Treat as unknown. Request a **fresh** code. Do not reuse the previous one. |
| Live account / project / zone / VM / OS Login user ≠ recorded identity | `identity_mismatch` | Refuse the handle. Open a new session for the intended target. |
| Remote command non-zero, `ssh -O check` still succeeds | `remote_command_failed` | The transport is healthy. Fix the command; do not reopen MFA. |
| Copy destination already exists | (refuse) | Pass `--overwrite` only when the caller authorized that exact overwrite. |
| `close` interrupted | — | Re-run `close -- HANDLE`. Idempotent: missing handle prints `closed=already`. Foreign or broad paths (the host temporary directory, `$HOME`, repo root) are refused. |

## Least-privilege IAM for this helper

`doctor` / `open` need these **inspection** permissions even when IAP SSH itself would
succeed. Project Owner hides gaps; grant them explicitly:

- `compute.instances.get`
- `compute.instances.list`
- `compute.projects.get` (project metadata, including effective OS Login)

Plus, for the IAP/OS Login path itself:

- `iap.tunnelInstances.accessViaIAP` (`roles/iap.tunnelResourceAccessor`)
- `roles/compute.osLogin` or `roles/compute.osAdminLogin` if sudo is required
- `iam.serviceAccounts.actAs` only if the VM has an attached service account

Do not grant extra roles as a connectivity workaround.

## `gcloud compute ssh --troubleshoot`

Not read-only. Official SSH troubleshooting documents that the tool can require
`networkmanagement.connectivitytests.create` / `delete` / `get`, and in observed sessions it
enabled the Network Management API and created a connectivity-test resource.

Default: refused. If the surrounding task authorizes those exact mutations:

1. Inventory enabled services and existing connectivity tests.
2. Preview: may enable `networkmanagement.googleapis.com`; may create connectivity tests; does
   **not** authorize firewall, external-IP, metadata, or IAM changes.
3. Run `gcloud-session.sh troubleshoot --authorize-mutations ...`.
4. Delete only the tests this run created. Do not disable APIs automatically.

## Classification order

Sandbox denial is not "unauthenticated". Expired user auth is not "missing IAM". Missing IAM is
not "IAP is broken". OS Login 2FA failure is not "guest sshd is down". A failed remote command
on a live master is not a transport failure.
