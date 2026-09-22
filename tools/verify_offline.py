#!/usr/bin/env python3
"""One reproducible local gate for Sequence source checks and bench software."""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/offline")
    parser.add_argument("--service", type=Path, help="optional local checkout for pinned DUT validation")
    args = parser.parse_args(argv)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / "verification.json"
    report = {"schema": "sequence-offline-verification/1", "status": "RUNNING",
              "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "python": platform.python_version(), "platform": platform.platform(),
              "native_st_compilation": "NOT_EXECUTED", "native_st_execution": "NOT_EXECUTED",
              "plc_capture_receipt_helper": "PREPARED_NOT_NATIVE_EXECUTED", "checks": [], "tests": 0}
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    commands = [
        ("static_core_and_native_fixtures", ["tools/check_sources.py", "--source-dir", "src", "--source-dir", "tests"]),
        ("checker_tests", ["-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"]),
        ("integration_file_sqlite_tests", ["-m", "unittest", "discover", "-s", "integration/service_v02/tests", "-v"]),
    ]
    if args.service:
        commands.append(("pinned_service_duts", ["integration/service_v02/verify_service_dependency.py", str(args.service.resolve())]))
    try:
        with tempfile.TemporaryDirectory(prefix="sequence-demo-", dir=output) as temporary:
            commands.append(("file_demo", ["integration/service_v02/bench_transport.py", "demo", "--output", str(Path(temporary) / "demo")]))
            for name, command in commands:
                result = subprocess.run([sys.executable, *command], cwd=ROOT,
                                        capture_output=True, text=True, encoding="utf-8", timeout=120,
                                        env=dict(os.environ, PYTHONIOENCODING="utf-8"))
                log = result.stdout + result.stderr
                (output / f"{name}.log").write_text(log, encoding="utf-8")
                entry = {"name": name, "command": ["python", *command], "returncode": result.returncode}
                count = re.search(r"Ran (\d+) tests?", log)
                if "unittest" in command:
                    if not count or int(count[1]) == 0:
                        raise ValueError(f"{name}: no tests executed")
                    entry["tests"] = int(count[1]); report["tests"] += int(count[1])
                report["checks"].append(entry)
                if result.returncode:
                    raise ValueError(f"{name} failed; inspect {output / (name + '.log')}")
                print(f"PASS {name}" + (f" ({entry['tests']} tests)" if "tests" in entry else ""))
            report["file_demo"] = json.loads((Path(temporary) / "demo/report.json").read_text(encoding="utf-8"))
        report["source_sha256"] = {}
        for directory in ("src", "tools", "tests", "integration/service_v02"):
            for path in sorted((ROOT / directory).rglob("*")):
                if path.is_file() and path.suffix in (".st", ".py", ".json") and "__pycache__" not in path.parts:
                    report["source_sha256"][path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        report["status"] = "PASS_OFFLINE"
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        report["status"] = "FAILED"; report["error"] = str(error)
        print(str(error), file=sys.stderr)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{report['status']}: {report_path}; native ST remains pending")
    return 0 if report["status"] == "PASS_OFFLINE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
