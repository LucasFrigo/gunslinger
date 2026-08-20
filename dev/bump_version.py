#!/usr/bin/env python3
"""Bump VERSION and project.godot application/config/version.

Usage:
  python dev/bump_version.py patch|minor|major

Keeps a prerelease suffix (e.g. -alpha) unless --drop-prerelease is passed.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
PROJECT_FILE = ROOT / "project.godot"
VERSION_RE = re.compile(r'^config/version="([^"]*)"', re.MULTILINE)


def parse_version(raw: str) -> tuple[int, int, int, str]:
    raw = raw.strip()
    if not raw:
        raise ValueError("VERSION is empty")
    core, sep, pre = raw.partition("-")
    parts = core.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError("VERSION must be SemVer MAJOR.MINOR.PATCH[-prerelease], got %r" % raw)
    suffix = ("-" + pre) if sep else ""
    return int(parts[0]), int(parts[1]), int(parts[2]), suffix


def bump(major: int, minor: int, patch: int, kind: str) -> tuple[int, int, int]:
    if kind == "major":
        return major + 1, 0, 0
    if kind == "minor":
        return major, minor + 1, 0
    if kind == "patch":
        return major, minor, patch + 1
    raise ValueError("unknown bump kind %r" % kind)


def write_version(new: str) -> None:
    VERSION_FILE.write_text(new + "\n", encoding="utf-8")
    project = PROJECT_FILE.read_text(encoding="utf-8")
    if not VERSION_RE.search(project):
        raise ValueError("project.godot is missing application/config/version")
    PROJECT_FILE.write_text(
        VERSION_RE.sub('config/version="%s"' % new, project, count=1),
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("patch", "minor", "major"))
    parser.add_argument(
        "--drop-prerelease",
        action="store_true",
        help="Strip -alpha (or other) suffix after bumping.",
    )
    args = parser.parse_args()

    major, minor, patch, suffix = parse_version(VERSION_FILE.read_text(encoding="utf-8"))
    major, minor, patch = bump(major, minor, patch, args.kind)
    if args.drop_prerelease:
        suffix = ""
    new = "%d.%d.%d%s" % (major, minor, patch, suffix)
    write_version(new)
    print(new)
    return 0


if __name__ == "__main__":
    sys.exit(main())
