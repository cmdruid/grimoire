#!/usr/bin/env python3
"""PTY-aware SSH stand-in for MFA helper and wrapper tests. Never a real client."""
from __future__ import print_function

import os
import sys
import time


def write(msg):
    sys.stdout.write(msg)
    sys.stdout.flush()


def parse_ssh_argv(argv):
    ctl = ""
    master = ""
    action = ""
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "-o" and i + 1 < len(argv):
            val = argv[i + 1]
            if val.startswith("ControlPath="):
                ctl = val.split("=", 1)[1]
            elif val.startswith("ControlMaster="):
                master = val.split("=", 1)[1]
            i += 2
            continue
        if a.startswith("-o") and "=" in a[2:]:
            val = a[2:]
            if val.startswith("ControlPath="):
                ctl = val.split("=", 1)[1]
            elif val.startswith("ControlMaster="):
                master = val.split("=", 1)[1]
            i += 1
            continue
        if a == "-S" and i + 1 < len(argv):
            ctl = argv[i + 1]
            i += 2
            continue
        if a == "-O" and i + 1 < len(argv):
            action = argv[i + 1]
            i += 2
            continue
        if a in ("-f", "-N", "-t", "-T", "-n", "-q"):
            i += 1
            continue
        if a == "-i":
            i += 2
            continue
        if a == "--":
            i += 1
            break
        if a.startswith("-"):
            i += 1
            continue
        break
    return ctl, master, action


def write_master(ctl):
    if not ctl:
        return
    d = os.path.dirname(ctl)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with open(ctl, "w") as fh:
        fh.write("master\n")


def capture_write(text):
    path = os.environ.get("MFA_CAPTURE")
    if not path:
        return
    with open(path, "a") as fh:
        fh.write(text)


def run_challenge(ctl):
    mode = os.environ.get("FAKE_MFA_MODE", "ok")
    if mode == "expire":
        time.sleep(float(os.environ.get("FAKE_MFA_SLEEP", "3")))
        sys.exit(1)
    if mode == "no-mfa":
        write_master(ctl)
        sys.exit(0)
    if mode == "password":
        write("Password:\n")
        got = sys.stdin.readline()
        capture_write("password_len=%d\n" % len(got.strip()))
        sys.exit(1)
    if mode == "unknown-menu":
        write("Please select an authentication method:\n")
        write("  1. SMS text message\n")
        write("  2. Hardware security key\n")
        choice = sys.stdin.readline()
        capture_write("choice=%s" % choice)
        sys.exit(1)
    if mode == "reordered":
        write("Please select an authentication method:\n")
        write("  1. Google Authenticator\n")
        write("  2. Security code from https://g.co/sc\n")
    else:
        write("Please select an authentication method:\n")
        write("  1. Security code from https://g.co/sc\n")
        write("  2. Google Authenticator\n")
    choice = sys.stdin.readline()
    if not choice:
        sys.exit(1)
    capture_write("choice=%s" % choice)
    if mode == "wrong-method":
        write("Failed to authenticate with Google 2FA\n")
        sys.exit(1)
    write("Enter code:\n")
    code = sys.stdin.readline()
    if not code:
        sys.exit(1)
    capture_write("code_len=%d\n" % len(code.strip()))
    if mode == "ambiguous":
        sys.exit(255)
    if mode == "reject-code":
        write("Permission denied (keyboard-interactive)\n")
        sys.exit(1)
    expect_choice = os.environ.get("MFA_EXPECT_CHOICE")
    if expect_choice and choice.strip() != expect_choice:
        write("Failed to authenticate with Google 2FA\n")
        sys.exit(1)
    expect_code = os.environ.get("MFA_EXPECT_CODE")
    if expect_code and code.strip() != expect_code:
        write("Permission denied (keyboard-interactive)\n")
        sys.exit(1)
    write_master(ctl)
    write("Authenticated to host.\n")
    sys.exit(0)


def main():
    argv = sys.argv[1:]
    ctl, master, action = parse_ssh_argv(argv)
    if not ctl:
        ctl = os.environ.get("FAKE_CONTROL_PATH", "")
    if action == "check":
        if ctl and os.path.exists(ctl):
            with open(ctl) as fh:
                if "master" in fh.read():
                    sys.exit(0)
        sys.exit(255)
    if action == "exit":
        if ctl and os.path.exists(ctl):
            os.remove(ctl)
        sys.exit(0)
    run_challenge(ctl)


if __name__ == "__main__":
    main()
