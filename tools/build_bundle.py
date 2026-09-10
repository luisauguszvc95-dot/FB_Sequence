#!/usr/bin/env python3
"""Validate and assemble review/import artifacts; no compiler is invoked."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from check_sources import check_repository, write_inventory


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-dir", action="append", help="repeatable; default: src")
    args = parser.parse_args()
    result = check_repository(args.root, tuple(args.source_dir or ["src"]))
    if not result.ok:
        for finding in result.findings:
            print(finding.display(result.root), file=sys.stderr)
        print("Build stopped: fix static source findings first.", file=sys.stderr)
        return 1

    output = result.root / "build"
    output.mkdir(parents=True, exist_ok=True)
    paths = [source.path.relative_to(result.root).as_posix() for source in result.import_order]
    (output / "import_order.txt").write_text("\n".join(paths) + "\n", encoding="utf-8")
    chunks = ["// FB_Sequence review bundle. Generated; edit individual src files.\n"
              "// Import as individual TYPE/GVL/POU objects in the target IDE.\n"
              "// This is not a compiled program, PLCopen XML or a native project.\n"]
    for index, source in enumerate(result.import_order, 1):
        path = source.path.relative_to(result.root).as_posix()
        chunks.append(f"\n// --- {index:03d}: {path} ---\n{source.original.rstrip()}\n")
    (output / "all_sources.st").write_text("\n".join(chunks), encoding="utf-8")
    write_inventory(result, result.root / "docs" / "INVENTORY.md")
    print(f"Generated {len(paths)} ordered objects: build/all_sources.st, build/import_order.txt, docs/INVENTORY.md")
    print("Static checks passed; ST compilation and runtime validation remain pending.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
