#!/usr/bin/env python3
"""File-only Sequence envelope transport. No PLC, network or ACK writer.

Python 3.10+, standard library. The input identifies synthetic data explicitly.
Only a successful SQLite transaction can produce a sink receipt file. The
separate PLC receipt gate remains the authority for source ACK eligibility.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile

from envelope_store import EnvelopeStore, EnvelopeConflict, MAX_BYTES, validate

CAPTURE_SCHEMA = "sequence-service-bench-capture/1"
RECEIPT_SCHEMA = "sequence-service-bench-receipt/1"
FOLDER = Path(__file__).resolve().parent


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def _pairs(items):
    result = {}
    for name, value in items:
        if name in result:
            raise ValueError(f"duplicate JSON field: {name}")
        result[name] = value
    return result


def _constant(value):
    raise ValueError(f"non-finite JSON number: {value}")


def read_json(path):
    with Path(path).open("rb") as source:
        raw = source.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("file exceeds 256 KiB")
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                          parse_constant=_constant)
    except (UnicodeError, RecursionError) as error:
        raise ValueError("invalid or deeply nested UTF-8 JSON") from error


def validate_capture(capture):
    if type(capture) is not dict or set(capture) != {"schema", "origin", "envelope", "ingress"}:
        raise ValueError("expected complete bench capture object")
    if capture["schema"] != CAPTURE_SCHEMA:
        raise ValueError("unsupported capture schema")
    if capture["origin"] not in ("SYNTHETIC_OFFLINE", "SIMULATOR_CAPTURE"):
        raise ValueError("only explicitly identified offline captures are supported")
    validate(capture["envelope"], capture["ingress"])
    if (capture["origin"] == "SYNTHETIC_OFFLINE"
            and capture["envelope"]["stSourceEvent"]["xSyntheticTime"] is not True):
        raise ValueError("synthetic capture must retain synthetic source time")
    return capture


def capture_hash(capture):
    return hashlib.sha256(canonical(capture)).hexdigest()


def expected_sink(capture):
    event, ingress = capture["envelope"]["stSourceEvent"], capture["ingress"]
    return {"stSourceReceipt": {
        "xValid": True, "xFullEnvelopeOwned": True,
        "udiMappingRevision": capture["envelope"]["udiMappingRevision"],
        **{name: event[name] for name in ("uiMachineID", "uiProducerSourceID", "uiProcessID",
                                        "udiSessionID", "udiEventID")}},
        "udiServiceBootID": ingress["udiBootID"],
        "udiServiceRecordID": ingress["udiRecordID"]}


def receipt_document(capture, sink):
    return {"schema": RECEIPT_SCHEMA, "origin": capture["origin"],
            "capture_sha256": capture_hash(capture), "status": "COMMITTED",
            "sink_receipt": sink, "source_ack": "NOT_WRITTEN",
            "audit_ack": "NOT_WRITTEN", "transport_ack": "NOT_WRITTEN"}


def verify_receipt(capture, receipt):
    validate_capture(capture)
    # Canonical comparison distinguishes true from 1, and rejects extra fields.
    if canonical(receipt) != canonical(receipt_document(capture, expected_sink(capture))):
        raise ValueError("receipt does not match the exact capture, source and Service binding")
    return True


def atomic_json(path, value, no_clobber=False):
    """Publish a complete file only; fsync content before atomic same-dir rename."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        if no_clobber:
            try:
                # Atomic publication without overwriting a competing receipt.
                # Local NTFS/POSIX hard links are supported; unsupported filesystems
                # fail explicitly after COMMIT, and replay can recover elsewhere.
                os.link(temporary, path)
            except FileExistsError:
                if canonical(read_json(path)) != canonical(value):
                    raise ValueError("receipt path is already owned by another capture")
        else:
            os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _distinct_paths(*paths):
    paths = [Path(path) for path in paths]
    for index, first in enumerate(paths):
        for second in paths[index + 1:]:
            if first.resolve() == second.resolve() or (
                    first.exists() and second.exists() and first.samefile(second)):
                raise ValueError("capture, database and receipt must be distinct files")


def persist_file(capture_path, database_path, receipt_path):
    _distinct_paths(capture_path, database_path, receipt_path)
    if str(database_path) == ":memory:" or str(database_path).startswith("file:"):
        raise ValueError("file transport requires a persistent filesystem SQLite database")
    capture = validate_capture(read_json(capture_path))
    expected = receipt_document(capture, expected_sink(capture))
    # Never replace a receipt for another capture, including content changed under
    # the same source IDs. Every file consumer still must verify capture_sha256.
    receipt_path = Path(receipt_path)
    if receipt_path.exists():
        verify_receipt(capture, read_json(receipt_path))
    database_path = Path(database_path)
    database_path.parent.mkdir(parents=True, exist_ok=True)
    store = EnvelopeStore(database_path)
    try:
        sink = store.persist(capture["envelope"], capture["ingress"])
    finally:
        store.close()
    document = receipt_document(capture, sink)
    if canonical(document) != canonical(expected):
        raise ValueError("sink returned an unexpected binding")
    atomic_json(receipt_path, document, no_clobber=True)
    return document


def inspect_database(path):
    # mode=ro must not silently create a missing database, nor change journal mode.
    uri = Path(path).resolve().as_uri() + "?mode=ro"
    with closing(sqlite3.connect(uri, uri=True)) as connection, connection:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise ValueError(f"SQLite integrity check failed: {integrity}")
        rows = connection.execute(
            "SELECT source_key,service_key,envelope_json,ingress_json "
            "FROM sequence_envelopes ORDER BY source_key").fetchall()
    records = []
    for source_key, service_key, envelope_json, ingress_json in rows:
        envelope, ingress = json.loads(envelope_json), json.loads(ingress_json)
        validate(envelope, ingress)
        event = envelope["stSourceEvent"]
        expected_source = [event[k] for k in ("uiMachineID", "uiProducerSourceID",
                                             "uiProcessID", "udiSessionID", "udiEventID")]
        expected_service = [ingress[k] for k in ("uiMachineID", "udiBootID", "udiRecordID")]
        if json.loads(source_key) != expected_source or json.loads(service_key) != expected_service:
            raise ValueError("stored keys differ from the complete payload")
        records.append({"source_key": expected_source, "service_key": expected_service,
                        "envelope": envelope, "ingress": ingress})
    return {"status": "PASS", "integrity": integrity, "record_count": len(records), "records": records}


def demo(output):
    output = Path(output)
    if output.exists() and any(output.iterdir()):
        raise ValueError("demo output must be a new or empty directory")
    output.mkdir(parents=True, exist_ok=True)
    capture = validate_capture(read_json(FOLDER / "examples/synthetic_capture.json"))
    capture_path, database_path = output / "capture.json", output / "envelopes.sqlite3"
    receipt_path = output / "receipt.json"
    atomic_json(capture_path, capture)
    checks = []

    def check(name, condition):
        if not condition:
            raise AssertionError(name)
        checks.append(name)

    check("no_receipt_before_persistence", not receipt_path.exists())
    receipt = persist_file(capture_path, database_path, receipt_path)
    check("receipt_correlates_exact_capture", verify_receipt(capture, read_json(receipt_path)))
    saved = inspect_database(database_path)
    check("full_envelope_roundtrip_from_other_connection",
          saved["records"][0]["envelope"] == capture["envelope"])
    check("service_binding_roundtrip", saved["records"][0]["ingress"] == capture["ingress"])
    replay = persist_file(capture_path, database_path, receipt_path)
    check("replay_returns_identical_receipt", replay == receipt)
    check("replay_does_not_duplicate", inspect_database(database_path)["record_count"] == 1)
    event = saved["records"][0]["envelope"]["stSourceEvent"]
    check("admission_remains_accepted", event["eCommandResult"] == 1)
    check("command_origin_differs_from_event_producer", event["uiSourceID"] == 99
          and event["uiProducerSourceID"] == 301)
    check("authority_is_preserved", event["udiAuthorityID"] == 17)
    check("no_source_audit_or_transport_ack_written", all(receipt[k] == "NOT_WRITTEN"
          for k in ("source_ack", "audit_ack", "transport_ack")))

    wrong = deepcopy(receipt)
    wrong["sink_receipt"]["udiServiceRecordID"] += 1
    try:
        verify_receipt(capture, wrong)
    except ValueError:
        checks.append("wrong_service_record_rejected")
    else:
        raise AssertionError("wrong service receipt accepted")
    changed = deepcopy(capture)
    changed["envelope"]["stSourceEvent"]["udiAuthorityID"] += 1
    atomic_json(output / "conflicting_capture.json", changed)
    try:
        persist_file(output / "conflicting_capture.json", database_path, output / "conflict_receipt.json")
    except EnvelopeConflict:
        checks.append("same_identity_changed_payload_rejected")
    else:
        raise AssertionError("changed payload overwrote source history")
    check("conflict_does_not_publish_receipt", not (output / "conflict_receipt.json").exists())
    check("original_data_survives_conflict", inspect_database(database_path)["records"][0]["envelope"]
          == capture["envelope"])
    report = {"schema": "sequence-service-bench-report/1", "status": "PASS",
              "checks": checks, "check_count": len(checks), "source": "SYNTHETIC_OFFLINE",
              "transport": "REAL_LOCAL_FILES", "persistence": "REAL_SQLITE_COMMIT_AND_REOPEN",
              "native_st_execution": "NOT_EXECUTED", "plc_connection": "NOT_ATTEMPTED",
              "native_capture_receipt_helper": "PREPARED_NOT_NATIVE_EXECUTED",
              "source_ack": "NOT_WRITTEN", "audit_ack": "NOT_WRITTEN",
              "transport_ack": "NOT_WRITTEN"}
    atomic_json(output / "report.json", report)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("demo", help="run a synthetic demonstration with real files and SQLite")
    run.add_argument("--output", required=True, type=Path)
    persist = commands.add_parser("persist", help="store a complete capture; publish a sink receipt after COMMIT")
    persist.add_argument("--capture", required=True, type=Path)
    persist.add_argument("--database", required=True)
    persist.add_argument("--receipt", required=True, type=Path)
    inspect = commands.add_parser("inspect", help="read and validate the database without modification")
    inspect.add_argument("--database", required=True, type=Path)
    verify = commands.add_parser("verify-receipt", help="check file binding; this never writes a source ACK")
    verify.add_argument("--capture", required=True, type=Path)
    verify.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "demo":
            result = demo(args.output)
        elif args.command == "persist":
            result = persist_file(args.capture, args.database, args.receipt)
        elif args.command == "inspect":
            result = inspect_database(args.database)
        else:
            verify_receipt(read_json(args.capture), read_json(args.receipt))
            result = {"status": "MATCH", "proof": "FILE_BINDING_ONLY", "source_ack": "NOT_WRITTEN"}
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    except (ValueError, OSError, sqlite3.Error, AssertionError) as error:
        print(json.dumps({"status": "FAILED", "error": str(error),
                          "new_receipt": "NOT_CONFIRMED", "source_ack": "NOT_WRITTEN"}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
