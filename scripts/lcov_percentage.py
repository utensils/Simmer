#!/usr/bin/env python3
"""Compute line coverage percentage for a specific file from an LCOV report."""

from __future__ import annotations

import sys
from pathlib import Path


def coverage_for_file(lcov_path: Path, target: str) -> float:
    normalized_target = str(Path(target))
    covered = 0
    total = 0
    current_file: str | None = None

    with lcov_path.open() as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                current_file = Path(line[3:]).as_posix()
            elif line.startswith("DA:") and current_file is not None:
                if not current_file.endswith(normalized_target):
                    continue
                _, hits = line[3:].split(",", 1)
                total += 1
                if int(hits) > 0:
                    covered += 1

    if total == 0:
        return 100.0
    return (covered / total) * 100.0


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: scripts/lcov_percentage.py <coverage.lcov> <relative/path.swift>", file=sys.stderr)
        return 1

    lcov_path = Path(sys.argv[1])
    target = sys.argv[2]
    percentage = coverage_for_file(lcov_path, target)
    print(f"{percentage:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
