"""Check exact pinned Service DUTs without vendoring or modifying them."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii")
                        + b"\0" + data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("service_root", type=Path,
                        help="Unmodified checkout/export of the pinned FB_Service")
    args = parser.parse_args()
    pin = json.loads(Path(__file__).with_name("service_dependency.json").read_text())
    failures = []
    for relative, expected in pin["files"].items():
        path = args.service_root / relative
        if not path.is_file():
            failures.append(f"MISSING: {relative}")
        elif git_blob_sha(path.read_bytes()) != expected:
            failures.append(f"MISMATCH: {relative}")
    for failure in failures:
        print(failure)
    if failures:
        print("Do not activate the mapper: dependency differs from the pinned bytes.")
        return 1
    print(f"PASS: {len(pin['files'])} canonical Service DUTs match {pin['commit']}.")
    print("This is dependency identity verification, not ST compilation or integration.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
