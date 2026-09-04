# Transport

Primary sources (syntax verified against these pages):

- IAP TCP forwarding overview: https://docs.cloud.google.com/iap/docs/tcp-forwarding-overview
- Use IAP for TCP forwarding: https://docs.cloud.google.com/iap/docs/using-tcp-forwarding
- `gcloud compute start-iap-tunnel`: https://docs.cloud.google.com/sdk/gcloud/reference/compute/start-iap-tunnel
- Connect to Linux VMs through IAP: https://docs.cloud.google.com/compute/docs/connect/ssh-using-iap
- `gcloud compute ssh`: https://docs.cloud.google.com/sdk/gcloud/reference/compute/ssh
- OS Login 2FA: https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin
- SSH credential practices: https://docs.cloud.google.com/compute/docs/connect/ssh-best-practices/credentials

## Chosen composition

`gcloud compute ssh --dry-run --tunnel-through-iap` is the documented public generator for the
equivalent OpenSSH command (`--dry-run`: print the ssh/scp command instead of executing it). The
IAP OpenSSH recipe uses `gcloud compute start-iap-tunnel %h %p --listen-on-stdin` as
`ProxyCommand`.

`open` takes that argv (parsed with `shlex`, never `eval`), replaces argv0 with `ssh`, strips a
forced TTY, and adds:

- `ControlMaster=yes`, `ControlPath=<session>/control.sock`, `ControlPersist=<seconds>`
- `ServerAliveInterval=30`, `ServerAliveCountMax=3`, `ExitOnForwardFailure=yes`
- `-f -N` so the master authenticates and backgrounds

Later `run` / `copy-*` use native `ssh` / `scp` with the same `ControlPath` and
`ControlMaster=no`. They do not call `gcloud compute ssh` or `gcloud compute scp`, which would
open a second independently authenticated SSH connection.

A unique mode-`0700` directory from `mktemp -d` holds the socket and non-secret state. The handle
is that absolute directory. The helper does not edit `~/.ssh/config`.

IAP wraps the SSH stream in HTTPS and does not require a public IP. OS Login 2FA is a separate
keyboard-interactive challenge at SSH authentication, after IAP has already authorized the
tunnel.

## Multiplexing hypothesis

OS Login 2FA authenticates **new SSH connections**. OpenSSH multiplexing reuses an already
authenticated connection, so additional channels normally do not re-prompt. That is a
**hypothesis**, not a promise. Fixture tests prove the helper issues one master authentication
and reuses it. Only the explicitly approved live smoke test in `references/live-smoke.md` can
prove the same on a given OS Login 2FA setup. Until that test has passed for the target, say
"the helper is designed for one MFA event per session" — never "MFA is bypassed or disabled".

## Fallback

If the live environment re-prompts on every multiplexed channel, or `ControlMaster` cannot be
established, do not disable OS Login 2FA and do not open public SSH. Fall back to **one**
persistent interactive SSH shell on the same IAP path (`gcloud compute ssh --tunnel-through-iap`
with a live TTY), optionally with remote `tmux` so work survives a drop. `tmux` is not a
prerequisite and does not replace authentication. Document the limitation and expect one MFA
event per new SSH connection.

`--tmux` on `open` creates a detached remote `tmux` session named `gcloud-operator` when `tmux`
exists on the guest; if it is missing, the helper continues.

## What this is not

- Not `gcloud compute ssh --troubleshoot` (see `references/failures.md`).
- Not a local listening port unless a future fallback uses `start-iap-tunnel --local-host-port`.
  The default path is `--listen-on-stdin` inside `ProxyCommand`, so there is no standing local
  bind.
- Not a copy of the user's `gcloud` configuration or `google_compute_engine` key into the
  session directory.
