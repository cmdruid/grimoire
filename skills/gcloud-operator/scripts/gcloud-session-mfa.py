#!/usr/bin/env python3
"""Drive OS Login 2FA over a PTY. Never logs or reprints the code."""
from __future__ import print_function

import argparse
import os
import pty
import re
import select
import stat
import sys
import time

EXIT_OK = 0
EXIT_EXPIRED = 10
EXIT_WRONG_METHOD = 11
EXIT_AMBIGUOUS = 12
EXIT_CODEFILE = 13
EXIT_SSH = 14
EXIT_NO_MFA = 15

MFA_CODE_MAX_BYTES = 128

METHOD_MENU = re.compile(
    r"(?is)(select.*(authentication|second factor|verification|method)|please choose)"
)
# Recognized OS Login verification prompts only. Bare "password" is not one.
CODE_PROMPT = re.compile(
    r"(?i)("
    r"enter (the )?(verification )?code"
    r"|verification code"
    r"|security code"
    r"|enter (the )?one[- ]time (code|passcode)"
    r"|authenticator (code|otp|passcode)"
    r")"
)
SUCCESS = re.compile(
    r"(?i)(authenticated|now backgrounded|controlpersist|entering interactive session)"
)
FAIL = re.compile(
    r"(?i)(permission denied|failed to authenticate|invalid code|incorrect code|authentication failed)"
)
MENU_LINE = re.compile(r"(?m)^\s*(\d+)\s*[.)]\s*(.+)$")


def die(msg, rc):
    print("gcloud-session-mfa: " + msg, file=sys.stderr)
    return rc


def redact(buf, code):
    if code:
        buf = buf.replace(code, "[REDACTED]")
    buf = re.sub(r"ya29\.[A-Za-z0-9._\-]+", "ya29.[REDACTED]", buf)
    return buf


def resolve_menu_choice(blob, method):
    """Return ('wait', None), ('ok', numstr), or ('refuse', None)."""
    matches = MENU_LINE.findall(blob)
    if not matches:
        return ("wait", None)
    for num, label in matches:
        low = label.lower()
        if method == "security-code" and (
            "g.co/sc" in low or "security code" in low or "google security" in low
        ):
            return ("ok", num)
        if method == "authenticator" and (
            "authenticator" in low or "totp" in low
        ):
            return ("ok", num)
    if len(matches) >= 2 or METHOD_MENU.search(blob):
        return ("refuse", None)
    return ("wait", None)


def read_code(path):
    if not path:
        raise IOError("missing")
    try:
        st = os.lstat(path)
    except OSError:
        raise IOError("missing")
    if stat.S_ISLNK(st.st_mode):
        raise IOError("symlink")
    if not stat.S_ISREG(st.st_mode):
        raise IOError("not-regular")
    if st.st_uid != os.getuid():
        raise IOError("owner")
    if st.st_mode & 0o077:
        raise IOError("mode")
    if st.st_size < 1:
        raise IOError("empty")
    if st.st_size > MFA_CODE_MAX_BYTES:
        raise IOError("too-large")
    with open(path, "rb") as fh:
        data = fh.read()
    try:
        os.remove(path)
    except OSError:
        try:
            with open(path, "wb") as fh:
                fh.write(b"\0" * len(data))
            os.remove(path)
        except OSError:
            pass
    if data.count(b"\n") > 1:
        raise IOError("lines")
    line = data.decode("utf-8", "replace").splitlines()[0] if data else ""
    line = line.strip()
    if not line:
        raise IOError("empty")
    return line


def append_log(path, text, code):
    if not path:
        return
    try:
        with open(path, "a") as fh:
            fh.write(redact(text, code))
            if not text.endswith("\n"):
                fh.write("\n")
    except OSError:
        pass


def main(argv):
    p = argparse.ArgumentParser(prog="gcloud-session-mfa")
    p.add_argument("--method", required=True, choices=["security-code", "authenticator"])
    p.add_argument("--code-file", required=True)
    p.add_argument("--timeout", type=int, default=90)
    p.add_argument("--log", default="")
    p.add_argument("ssh", nargs=argparse.REMAINDER)
    args = p.parse_args(argv)
    ssh = args.ssh
    if ssh and ssh[0] == "--":
        ssh = ssh[1:]
    if not ssh:
        return die("missing ssh argv after --", EXIT_SSH)

    try:
        code = read_code(args.code_file)
    except IOError as exc:
        why = str(exc)
        if why == "empty":
            return die("mfa code file empty; request a fresh code", EXIT_CODEFILE)
        if why == "too-large":
            return die("mfa code file too large", EXIT_CODEFILE)
        if why == "symlink":
            return die("mfa code file must be a regular file, not a symlink", EXIT_CODEFILE)
        if why == "mode":
            return die("mfa code file must have no group or other access", EXIT_CODEFILE)
        if why == "owner":
            return die("mfa code file must be owned by the current user", EXIT_CODEFILE)
        if why == "lines":
            return die("mfa code file must contain exactly one line", EXIT_CODEFILE)
        return die("mfa code file missing", EXIT_CODEFILE)

    sent_code = False
    sent_method = False
    saw_menu = False
    deadline = time.time() + args.timeout
    buf = ""
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(ssh[0], ssh)
        os._exit(127)

    rc = EXIT_AMBIGUOUS
    try:
        while time.time() < deadline:
            ready, _, _ = select.select([fd], [], [], 0.5)
            chunk = ""
            if ready:
                try:
                    chunk = os.read(fd, 4096).decode("utf-8", "replace")
                except OSError:
                    break
                if chunk == "":
                    wpid, status = os.waitpid(pid, 0)
                    child_ok = os.WIFEXITED(status) and os.WEXITSTATUS(status) == 0
                    if sent_method and sent_code and child_ok:
                        rc = EXIT_OK
                    elif sent_method and sent_code:
                        rc = EXIT_AMBIGUOUS
                    elif child_ok:
                        rc = EXIT_NO_MFA
                        print(
                            "gcloud-session-mfa: SSH succeeded without an observed OS Login 2FA challenge",
                            file=sys.stderr,
                        )
                    else:
                        rc = EXIT_SSH
                    pid = None
                    break
                buf += chunk
                append_log(args.log, chunk, code)
            if not sent_method:
                state, choice = resolve_menu_choice(buf, args.method)
                if state == "refuse":
                    rc = EXIT_WRONG_METHOD
                    append_log(args.log, "unknown-or-unmatched-mfa-menu\n", code)
                    print(
                        "gcloud-session-mfa: unknown or unmatched MFA menu; refusing to guess",
                        file=sys.stderr,
                    )
                    break
                if state == "ok":
                    saw_menu = True
                    os.write(fd, (choice + "\n").encode("utf-8"))
                    sent_method = True
                    append_log(args.log, "sent-method-choice=%s\n" % choice, code)
            if sent_method and not sent_code and CODE_PROMPT.search(buf):
                os.write(fd, (code + "\n").encode("utf-8"))
                sent_code = True
                append_log(args.log, "sent-code=yes\n", code)
            if FAIL.search(buf):
                rc = EXIT_WRONG_METHOD if sent_code or sent_method else EXIT_SSH
                break
            if sent_method and sent_code and SUCCESS.search(buf):
                rc = EXIT_OK
                try:
                    os.waitpid(pid, 0)
                except OSError:
                    pass
                pid = None
                break
            wpid, status = os.waitpid(pid, os.WNOHANG)
            if wpid != 0:
                child_ok = os.WIFEXITED(status) and os.WEXITSTATUS(status) == 0
                if sent_method and sent_code and child_ok:
                    rc = EXIT_OK
                elif sent_method and sent_code:
                    rc = EXIT_AMBIGUOUS
                elif child_ok:
                    rc = EXIT_NO_MFA
                    print(
                        "gcloud-session-mfa: SSH succeeded without an observed OS Login 2FA challenge",
                        file=sys.stderr,
                    )
                else:
                    rc = EXIT_SSH
                pid = None
                break
        else:
            if sent_code:
                rc = EXIT_AMBIGUOUS
            elif not sent_method:
                rc = EXIT_EXPIRED
            else:
                rc = EXIT_EXPIRED
    finally:
        code = ""
        if pid:
            try:
                os.kill(pid, 15)
                os.waitpid(pid, 0)
            except OSError:
                pass
        try:
            os.close(fd)
        except OSError:
            pass
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
