"""File/SQLite failure tests. These tests do not execute PLC Structured Text."""
from copy import deepcopy
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
import threading
import unittest
from unittest.mock import patch

FOLDER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(FOLDER))
import bench_transport as bench
from envelope_store import EnvelopeConflict, EnvelopeStore


class FileTransportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.capture = bench.read_json(FOLDER / "examples/synthetic_capture.json")
        self.input = self.root / "capture.json"
        self.database = self.root / "events.sqlite3"
        self.receipt = self.root / "receipt.json"
        bench.atomic_json(self.input, self.capture)

    def persist(self):
        return bench.persist_file(self.input, self.database, self.receipt)

    def test_cli_process_roundtrip_and_replay(self):
        command = [sys.executable, str(FOLDER / "bench_transport.py"), "persist",
                   "--capture", str(self.input), "--database", str(self.database),
                   "--receipt", str(self.receipt)]
        for _ in range(2):
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["source_ack"], "NOT_WRITTEN")
        report = bench.inspect_database(self.database)
        self.assertEqual(report["record_count"], 1)
        self.assertEqual(report["records"][0]["envelope"], self.capture["envelope"])
        self.assertTrue(bench.verify_receipt(self.capture, bench.read_json(self.receipt)))

    def test_two_concurrent_collectors_remain_idempotent(self):
        command = [sys.executable, str(FOLDER / "bench_transport.py"), "persist",
                   "--capture", str(self.input), "--database", str(self.database),
                   "--receipt", str(self.receipt)]
        processes = [subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      text=True) for _ in range(2)]
        for process in processes:
            _, stderr = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 1)

    def test_ambiguous_duplicate_json_fields_fail_before_database(self):
        self.input.write_text('{"schema":"one","schema":"two"}', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            self.persist()
        self.assertFalse(self.database.exists())
        self.assertFalse(self.receipt.exists())

    def test_nonfinite_numbers_are_never_accepted(self):
        for value in ("NaN", "Infinity", "-Infinity"):
            self.input.write_text('{"value":' + value + '}', encoding="utf-8")
            with self.assertRaises(ValueError):
                self.persist()
        self.assertFalse(self.receipt.exists())

    def test_oversized_input_fails_before_parsing(self):
        self.input.write_bytes(b" " * (bench.MAX_BYTES + 1))
        with self.assertRaisesRegex(ValueError, "256 KiB"):
            self.persist()
        self.assertFalse(self.database.exists())

    def test_truncated_or_non_utf8_capture_never_produces_receipt(self):
        for data in (b'{"schema":', b'\xff\xff'):
            self.input.write_bytes(data)
            with self.assertRaises(ValueError):
                self.persist()
        self.assertFalse(self.receipt.exists())

    def test_exact_schema_and_explicit_synthetic_provenance_required(self):
        for change in ({"origin": "LIVE_PLC"}, {"schema": "unknown"}, {"extra": 1}):
            bad = deepcopy(self.capture); bad.update(change)
            bench.atomic_json(self.input, bad)
            with self.assertRaises(ValueError):
                self.persist()
        bad = deepcopy(self.capture)
        bad["envelope"]["stSourceEvent"]["xSyntheticTime"] = False
        bad["envelope"]["stServiceEvent"]["stHeader"]["eQuality"] = 3
        with self.assertRaisesRegex(ValueError, "synthetic capture"):
            bench.validate_capture(bad)

    def test_memory_database_is_rejected_by_file_workflow(self):
        for path in (":memory:", "file:database?mode=memory"):
            with self.assertRaisesRegex(ValueError, "persistent filesystem"):
                bench.persist_file(self.input, path, self.receipt)
        self.assertFalse(self.receipt.exists())

    def test_path_collisions_preserve_input(self):
        original = self.input.read_bytes()
        for database, receipt in ((self.input, self.receipt), (self.database, self.input),
                                  (self.database, self.database)):
            with self.assertRaisesRegex(ValueError, "distinct"):
                bench.persist_file(self.input, database, receipt)
        self.assertEqual(self.input.read_bytes(), original)

    def test_hardlink_collision_is_rejected(self):
        try:
            os.link(self.input, self.receipt)
        except OSError:
            self.skipTest("filesystem does not allow hard links")
        with self.assertRaisesRegex(ValueError, "distinct"):
            self.persist()

    def test_receipt_failure_after_commit_can_be_recovered_by_replay(self):
        with patch.object(bench.os, "link", side_effect=OSError("injected receipt failure")):
            with self.assertRaises(OSError):
                self.persist()
        self.assertFalse(self.receipt.exists())
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 1)
        self.assertFalse(list(self.root.glob("*.tmp")))
        self.persist()
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 1)
        self.assertTrue(bench.verify_receipt(self.capture, bench.read_json(self.receipt)))

    def test_concurrent_different_captures_cannot_overwrite_one_receipt(self):
        changed = deepcopy(self.capture)
        changed["envelope"]["stSourceEvent"]["udiEventID"] += 1
        changed["envelope"]["stServiceEvent"]["stHeader"]["udiSourceSeq"] += 1
        changed["ingress"]["udiSourceSeq"] += 1
        changed["ingress"]["udiRecordID"] += 1
        second = self.root / "second.json"
        bench.atomic_json(second, changed)
        barrier = threading.Barrier(2)
        original = bench.atomic_json

        def publish(*args, **kwargs):
            barrier.wait(timeout=10)
            return original(*args, **kwargs)

        with patch.object(bench, "atomic_json", side_effect=publish), ThreadPoolExecutor(2) as pool:
            futures = [pool.submit(bench.persist_file, path, self.database, self.receipt)
                       for path in (self.input, second)]
            results, failures = [], []
            for future in futures:
                try:
                    results.append(future.result(timeout=15))
                except ValueError as error:
                    failures.append(error)
        self.assertEqual(len(results), 1)
        self.assertEqual(len(failures), 1)
        self.assertEqual(bench.read_json(self.receipt), results[0])
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 2)

    def test_oversized_float_integer_is_rejected_with_value_error(self):
        self.capture["envelope"]["stServiceEvent"]["lrValue"] = 10 ** 400
        with self.assertRaises(ValueError):
            bench.validate_capture(self.capture)

    def test_database_commit_failure_cannot_publish_receipt(self):
        store = EnvelopeStore(self.database)
        store.connection.set_authorizer(lambda action, arg1, *_:
            sqlite3.SQLITE_DENY if action == sqlite3.SQLITE_TRANSACTION and arg1 == "COMMIT"
            else sqlite3.SQLITE_OK)
        with patch.object(bench, "EnvelopeStore", return_value=store):
            with self.assertRaises(sqlite3.Error):
                self.persist()
        self.assertFalse(self.receipt.exists())
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 0)

    def test_database_lock_returns_failure_and_no_receipt(self):
        store = EnvelopeStore(self.database)
        store.connection.execute("BEGIN IMMEDIATE")
        other = EnvelopeStore(self.database)
        other.connection.execute("PRAGMA busy_timeout=1")
        try:
            with patch.object(bench, "EnvelopeStore", return_value=other):
                with self.assertRaises(sqlite3.OperationalError):
                    self.persist()
        finally:
            store.connection.execute("ROLLBACK"); store.close()
        self.assertFalse(self.receipt.exists())

    def test_invalid_existing_database_is_closed_and_no_receipt_published(self):
        self.database.write_bytes(b"not a sqlite database")
        with self.assertRaises(sqlite3.DatabaseError):
            self.persist()
        self.assertFalse(self.receipt.exists())
        self.database.unlink()  # A leaked SQLite handle would fail on Windows.

    def test_existing_receipt_for_other_capture_is_not_overwritten(self):
        self.persist()
        original = self.receipt.read_bytes()
        bad = deepcopy(self.capture)
        bad["envelope"]["stSourceEvent"]["udiAuthorityID"] += 1
        bench.atomic_json(self.input, bad)
        with self.assertRaises(ValueError):
            self.persist()
        self.assertEqual(self.receipt.read_bytes(), original)
        with self.assertRaises(ValueError):
            bench.verify_receipt(bad, bench.read_json(self.receipt))

    def test_service_record_reuse_for_other_event_fails_without_receipt(self):
        self.persist()
        bad = deepcopy(self.capture)
        bad["envelope"]["stSourceEvent"]["udiEventID"] += 1
        bad["envelope"]["stServiceEvent"]["stHeader"]["udiSourceSeq"] += 1
        bad["ingress"]["udiSourceSeq"] += 1
        bench.atomic_json(self.input, bad)
        receipt = self.root / "new_receipt.json"
        with self.assertRaises(sqlite3.IntegrityError):
            bench.persist_file(self.input, self.database, receipt)
        self.assertFalse(receipt.exists())
        self.assertEqual(bench.inspect_database(self.database)["record_count"], 1)

    def test_every_receipt_identity_and_mapping_is_checked(self):
        receipt = self.persist()
        for field in receipt["sink_receipt"]["stSourceReceipt"]:
            bad = deepcopy(receipt)
            old = bad["sink_receipt"]["stSourceReceipt"][field]
            bad["sink_receipt"]["stSourceReceipt"][field] = False if type(old) is bool else old + 1
            with self.subTest(field=field), self.assertRaises(ValueError):
                bench.verify_receipt(self.capture, bad)
        for field in ("udiServiceBootID", "udiServiceRecordID"):
            bad = deepcopy(receipt); bad["sink_receipt"][field] += 1
            with self.subTest(field=field), self.assertRaises(ValueError):
                bench.verify_receipt(self.capture, bad)

    def test_numeric_one_cannot_impersonate_valid_boolean(self):
        receipt = self.persist()
        receipt["sink_receipt"]["stSourceReceipt"]["xValid"] = 1
        with self.assertRaises(ValueError):
            bench.verify_receipt(self.capture, receipt)

    def test_invented_actor_utc_and_external_context_are_rejected(self):
        fields = [("eActorKind",), ("udiActorID",), ("lrValue",),
                  ("stTime", "udiUtcSeconds"), ("stTime", "uiClockSourceID"),
                  ("stTime", "eQuality"), ("stContext", "udiWorkOrderID"),
                  ("stHeader", "eQuality"), ("uiObjectID",), ("eDomain",), ("eKind",)]
        for fields_path in fields:
            bad = deepcopy(self.capture)
            current = bad["envelope"]["stServiceEvent"]
            for field in fields_path[:-1]:
                current = current[field]
            current[fields_path[-1]] += 1
            with self.subTest(field=fields_path), self.assertRaises(ValueError):
                bench.validate_capture(bad)

    def test_inspection_does_not_create_a_missing_database(self):
        with self.assertRaises(sqlite3.OperationalError):
            bench.inspect_database(self.database)
        self.assertFalse(self.database.exists())

    def test_inspection_detects_payload_key_tampering(self):
        self.persist()
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute("UPDATE sequence_envelopes SET source_key='[1,301,7,1001,99]'")
        with self.assertRaisesRegex(ValueError, "stored keys"):
            bench.inspect_database(self.database)

    def test_demo_runs_and_does_not_overwrite_previous_artifacts(self):
        output = self.root / "demo"
        report = bench.demo(output)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["check_count"], 14)
        self.assertEqual(report["native_st_execution"], "NOT_EXECUTED")
        with self.assertRaises(ValueError):
            bench.demo(output)

    def test_st_composition_has_one_writer_and_never_fabricates_ownership(self):
        code = (FOLDER / "PRG_SEQ_ServiceBench.st").read_text()
        calls = ["fbControlMock(", "fbSequence(", "fbMapper(", "fbService(", "fbReceiptGate("]
        offsets = []
        for call in calls:
            self.assertEqual(code.count(call), 1)
            offsets.append(code.index(call))
        self.assertEqual(offsets, sorted(offsets))
        self.assertNotRegex(code, r"stSinkReturned\.[\w.]+\s*:=|%[IQ]|GVL_")
        self.assertIn("stReceipt := fbReceiptGate.stReceipt", code)
        self.assertIn("IF xPublicationAllowed AND fbMapper.xAck THEN", code)
        self.assertIn("stAuditAck := stAuditAck", code)
        self.assertIn("stServiceCfg.stOEEPolicy.xEnabled := FALSE", code)


if __name__ == "__main__":
    unittest.main()
