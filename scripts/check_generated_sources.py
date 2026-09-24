#!/usr/bin/env python3
"""Check that Dart part files needed by builds are committed and present."""

from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
PART = re.compile(r"^\s*part\s+['\"]([^'\"]+\.(?:g|freezed)\.dart)['\"]\s*;", re.M)


def main() -> int:
    tracked = set(
        subprocess.check_output(["git", "ls-files", "--cached", "--", "lib"], cwd=ROOT)
        .decode()
        .splitlines()
    )
    missing = []
    checked = 0
    for source in (ROOT / "lib").rglob("*.dart"):
        for part in PART.findall(source.read_text(encoding="utf-8")):
            target = source.parent / part
            relative = target.relative_to(ROOT).as_posix()
            checked += 1
            if not target.is_file() or relative not in tracked:
                missing.append(relative)

    for path in missing:
        print(f"Missing or untracked generated source: {path}", file=sys.stderr)
    if missing:
        return 1
    print(f"Verified {checked} checked-in generated Dart part files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
