#!/usr/bin/env python3
"""Compute grimoire/skill-content@1 for one safely traversable skill directory."""

from __future__ import annotations

import hashlib
import os
import stat
import sys
from pathlib import Path

PREFIX = b"grimoire/skill-content@1\0"
IGNORED = {
    b".git", b".hg", b".svn", b".grimoire", b"node_modules", b"target",
    b".cache", b".tmp", b".worktrees", b".workstreams", b"build", b"dist",
    b"vendor", b"fixtures",
}


class Unavailable(Exception):
    pass


def field(value: bytes) -> bytes:
    return len(value).to_bytes(8, "big", signed=False) + value


def raw_name(name: str) -> bytes:
    return os.fsencode(name)


def collect(root: Path, current: Path, prefix: bytes, depth: int = 0) -> list[tuple[bytes, bytes, bytes, bytes]]:
    if depth > 32:
        raise Unavailable("depth-limit")
    records: list[tuple[bytes, bytes, bytes, bytes]] = []
    try:
        entries = list(os.scandir(current))
    except OSError as exc:
        raise Unavailable("unreadable-directory") from exc
    entries.sort(key=lambda entry: raw_name(entry.name))
    for entry in entries:
        name = raw_name(entry.name)
        relative = name if not prefix else prefix + b"/" + name
        try:
            info = entry.stat(follow_symlinks=False)
        except OSError as exc:
            raise Unavailable("unstable-entry") from exc
        if stat.S_ISLNK(info.st_mode):
            try:
                target = os.readlink(entry.path)
            except OSError as exc:
                raise Unavailable("unreadable-symlink") from exc
            records.append((b"L", relative, b"120000", os.fsencode(target)))
        elif stat.S_ISDIR(info.st_mode):
            if name in IGNORED:
                continue
            records.extend(collect(root, Path(entry.path), relative, depth + 1))
        elif stat.S_ISREG(info.st_mode):
            try:
                with open(entry.path, "rb") as handle:
                    payload = handle.read()
            except OSError as exc:
                raise Unavailable("unreadable-file") from exc
            mode = b"100755" if info.st_mode & 0o111 else b"100644"
            records.append((b"F", relative, mode, payload))
        else:
            raise Unavailable("unsupported-entry")
    return records


def main() -> int:
    if len(sys.argv) != 2:
        print("reason=usage", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    try:
        if path.is_symlink() or not path.is_dir():
            raise Unavailable("invalid-skill-directory")
        root = Path(os.path.realpath(path))
        if not (root / "SKILL.md").is_file() or (root / "SKILL.md").is_symlink():
            raise Unavailable("missing-skill-manifest")
        records = collect(root, root, b"")
        if len(records) > 100_000:
            raise Unavailable("entry-limit")
        records.sort(key=lambda record: record[1])
        digest = hashlib.sha256()
        digest.update(PREFIX)
        for kind, relative, mode, payload in records:
            digest.update(kind)
            digest.update(field(relative))
            digest.update(field(mode))
            digest.update(field(payload))
        print(f"content-sha256:{digest.hexdigest()}")
        return 0
    except (OSError, Unavailable) as exc:
        detail = str(exc) or "unavailable"
        print(f"unknown reason={detail}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
