#!/usr/bin/env python3
"""Build a deterministic, source-only offline bench ZIP with file hashes.

No Service source is copied. No .project/native compilation or release approval
is implied. Run verify_offline.py first; package generation is not validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def selected_files(root):
    paths = [root / "README.md", root / "docs/BANCADA_OFFLINE.md"]
    for directory in ("src", "tools", "tests", "integration/service_v02"):
        paths.extend(path for path in (root / directory).rglob("*")
                     if path.is_file() and path.suffix in (".st", ".py", ".json", ".md")
                     and "__pycache__" not in path.parts)
    return sorted(set(paths), key=lambda path: path.relative_to(root).as_posix())


def build(destination, root=ROOT):
    content = {path.relative_to(root).as_posix(): path.read_bytes() for path in selected_files(root)}
    manifest = {"schema": "sequence-bench-bundle/1", "content": "SOURCE_ONLY",
                "native_validation": "PENDING", "service_sources": "EXTERNAL_PINNED_DEPENDENCY",
                "files": {path: hashlib.sha256(data).hexdigest() for path, data in content.items()}}
    content["BUNDLE_MANIFEST.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    content["BUNDLE_README.txt"] = (
        "Sequence offline bench source package. Python 3.10+; no external packages.\n"
        "From this folder: python tools/verify_offline.py\n"
        "Run files/SQLite: python integration/service_v02/bench_transport.py demo --output build/demo\n"
        "Read docs/BANCADA_OFFLINE.md before the future native simulation.\n"
        "Native ST, PLC capture/export and target timing remain pending.\n"
        "Service source is separate; consult integration/service_v02/service_dependency.json.\n"
        "Historical manuals/PDFs linked in README are available in the repository, not in this source package.\n"
    ).encode()
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path, data in sorted(content.items()):
            info = zipfile.ZipInfo("FB_Sequence/" + path, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(destination.suffix + ".sha256").write_text(
        f"{digest}  {destination.name}\n", encoding="ascii")
    return {"path": str(destination), "sha256": digest, "files": len(content),
            "content": "SOURCE_ONLY", "native_validation": "PENDING"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/FB_Sequence_offline_bench.zip")
    args = parser.parse_args()
    print(json.dumps(build(args.output), indent=2))


if __name__ == "__main__":
    main()
