"""Mock API tests only: no native IDE, PLC connection or hardware execution."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch

FOLDER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(FOLDER))
import bench_transport as bench
import machine_expert_bench as native


class Device:
    def __init__(self):
        self.device = self
        self.simulation = True
        self.disposed = False

    def get_simulation_mode(self):
        return self.simulation

    def Dispose(self):
        self.disposed = True


class Application:
    def __init__(self):
        capture = bench.read_json(FOLDER / "examples/synthetic_capture.json")
        self.capture = deepcopy(capture)
        self.capture["origin"] = "SIMULATOR_CAPTURE"
        self.device = Device()
        self.is_logged_in = True
        self.application_state = "run"
        self.disposed = False
        self.forced = []
        self.prepared = {}
        self.writes = []
        self.values = {}
        self.fail_body = False
        self.fail_final = False
        self.corrupt_body = False
        self.foreign_on_prepare = False
        self.change_read = False
        self.authority_reads = 0
        self.never_arm = False
        self.on_delay = None
        self.delays = 0
        self.rebuild_values()

    def rebuild_values(self):
        def flatten(prefix, value):
            if isinstance(value, dict):
                for field, child in value.items():
                    flatten(prefix + "." + field, child)
            else:
                self.values[prefix] = "TRUE" if value is True else "FALSE" if value is False else str(value)
        flatten(native.PREFIX + "stCaptureEnvelope", self.capture["envelope"])
        flatten(native.PREFIX + "stCaptureIngress", self.capture["ingress"])
        for name in ("xEnableBench", "xPublicationAllowed", "xCaptureReady"):
            self.values[native.PREFIX + name] = "TRUE"
        self.values[native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"] = "FALSE"
        self.values[native.PREFIX + "fbReceiptGate.xReadyForReceipt"] = "FALSE"

    def read_value(self, expression):
        if expression.endswith("stSourceEvent.udiAuthorityID"):
            self.authority_reads += 1
            if self.change_read and self.authority_reads == 2:
                return "UDINT#99"
        return self.values[expression]

    def get_online_device(self):
        return self.device

    def get_forced_expressions(self):
        return self.forced

    def get_prepared_expressions(self):
        return list(self.prepared)

    def get_prepared_value(self, expression):
        return self.prepared.get(expression)

    def set_prepared_value(self, expression, value):
        if value is None:
            self.prepared.pop(expression, None)
        else:
            self.prepared[expression] = value
            if self.foreign_on_prepare:
                self.prepared["OTHER.value"] = "UDINT#9"

    def write_prepared_values(self):
        owned = dict(self.prepared)
        self.writes.append(owned)
        for index, (name, value) in enumerate(owned.items()):
            if not name.startswith(native.PREFIX + "stSinkReturned."):
                raise AssertionError("unrelated value would be written")
            self.values[name] = value
            if self.fail_body and len(self.writes) == 2 and index == 1:
                raise IOError("injected partial body write")
        if self.corrupt_body and len(self.writes) == 2:
            self.values[native.PREFIX + "stSinkReturned.udiServiceRecordID"] = "UDINT#999"
        if self.fail_final and len(self.writes) == 3:
            raise IOError("injected failure after final write reached simulation")

    def delay(self, milliseconds):
        self.delays += 1
        if not self.never_arm and native._scalar(self.values[
                native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"], "BOOL", {}) is False:
            self.values[native.PREFIX + "fbReceiptGate.xReadyForReceipt"] = "TRUE"
        if self.on_delay:
            self.on_delay(self)

    def Dispose(self):
        self.disposed = True


class Online:
    def __init__(self, app):
        self.app = app

    def create_online_application(self):
        return self.app


class MachineExpertHelperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = Application()
        self.online = Online(self.app)

    def captured_and_persisted(self):
        self.capture_path = native.capture(self.online, str(self.root / "captures"))
        self.receipt_path = self.root / "receipt.json"
        bench.persist_file(self.capture_path, self.root / "events.sqlite3", self.receipt_path)
        return self.capture_path, str(self.receipt_path)

    def test_full_capture_sqlite_return_path_uses_only_sink_receipt_input(self):
        capture_path, receipt_path = self.captured_and_persisted()
        payload = bench.read_json(capture_path)
        self.assertEqual(payload["origin"], "SIMULATOR_CAPTURE")
        self.assertEqual(payload["envelope"], self.app.capture["envelope"])
        result = native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(result["status"], "SUBMITTED")
        self.assertEqual(len(self.app.writes), 3)
        valid = native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"
        self.assertEqual(self.app.writes[0], {valid: "BOOL#FALSE"})
        self.assertEqual(self.app.writes[-1], {valid: "BOOL#TRUE"})
        self.assertNotIn(valid, self.app.writes[1])
        self.assertFalse(self.app.prepared)
        self.assertTrue(self.app.device.disposed and self.app.disposed)
        self.assertGreaterEqual(self.app.delays, 2)

    def test_capture_never_writes_and_repeat_keeps_exact_file(self):
        path = native.capture(self.online, str(self.root))
        original = Path(path).read_bytes()
        self.assertEqual(native.capture(self.online, str(self.root)), path)
        self.assertEqual(Path(path).read_bytes(), original)
        self.assertFalse(self.app.writes)

    def test_capture_publication_failure_leaves_no_partial_final_and_can_retry(self):
        with patch.object(native.os, "fsync", side_effect=OSError("injected disk failure")):
            with self.assertRaises(OSError):
                native.capture(self.online, str(self.root))
        self.assertFalse(list(self.root.glob("*.json")))
        self.assertFalse(list(self.root.glob("*.tmp")))
        path = native.capture(self.online, str(self.root))
        self.assertEqual(bench.read_json(path)["origin"], "SIMULATOR_CAPTURE")

    def test_simulation_run_login_forced_and_prepared_guards(self):
        for case in ("simulation", "run", "login", "forced", "prepared", "permission", "capture"):
            app = Application()
            if case == "simulation": app.device.simulation = False
            if case == "run": app.application_state = "stop"
            if case == "login": app.is_logged_in = False
            if case == "forced": app.forced = ["OTHER"]
            if case == "prepared": app.prepared = {"OTHER": "1"}
            if case == "permission": app.values[native.PREFIX + "xPublicationAllowed"] = "FALSE"
            if case == "capture": app.values[native.PREFIX + "xCaptureReady"] = "FALSE"
            with self.subTest(case=case), self.assertRaises(ValueError):
                native.capture(Online(app), str(self.root / case))
            self.assertFalse(app.writes)
            self.assertTrue(app.disposed)

    def test_missing_api_fails_explicitly(self):
        with self.assertRaisesRegex(ValueError, "API is unavailable"):
            native.capture(None, str(self.root))

    def test_head_content_changes_during_capture_no_file_published(self):
        self.app.change_read = True
        with self.assertRaisesRegex(ValueError, "changed during"):
            native.capture(self.online, str(self.root))
        self.assertFalse(list(self.root.glob("*.json")))
        self.assertTrue(self.app.disposed)

    def test_unknown_monitoring_literal_fails_closed(self):
        self.app.values[native.PREFIX + "stCaptureEnvelope.stSourceEvent.udiEventID"] = "???"
        with self.assertRaises(ValueError):
            native.capture(self.online, str(self.root))
        self.assertFalse(list(self.root.glob("*.json")))

    def test_parser_supports_iec_enum_and_float_and_rejects_ambiguity(self):
        _, enums = native._layout()
        self.assertEqual(native._scalar("UINT#16#FF", "UINT", enums), 255)
        self.assertEqual(native._scalar("UDINT#4_294_967_295", "UDINT", enums), 4294967295)
        self.assertEqual(native._scalar("DINT#-2", "DINT", enums), -2)
        self.assertEqual(native._scalar("E_SEQ_EVENT_KIND.CommandResult", "E_SEQ_EVENT_KIND", enums), 3)
        self.assertEqual(native._scalar("LREAL#1.25E-2", "LREAL", enums), 0.0125)
        for value, kind in (("BOOL#1", "BOOL"), ("UINT#65536", "UINT"),
                            ("LREAL#NaN", "LREAL"), ("LREAL#1e999", "LREAL"),
                            ("CommandResult (3)", "E_SEQ_EVENT_KIND"), ("DWORD#16#GG", "DWORD")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                native._scalar(value, kind, enums)

    def test_existing_capture_with_modified_data_is_not_overwritten(self):
        path = native.capture(self.online, str(self.root))
        original = Path(path).read_bytes()
        self.app.values[native.PREFIX + "stCaptureEnvelope.stSourceEvent.udiAuthorityID"] = "18"
        with self.assertRaisesRegex(ValueError, "different full content"):
            native.capture(self.online, str(self.root))
        self.assertEqual(Path(path).read_bytes(), original)

    def test_mismatched_or_synthetic_receipt_never_prepares_writes(self):
        capture_path, receipt_path = self.captured_and_persisted()
        receipt = bench.read_json(receipt_path)
        receipt["sink_receipt"]["udiServiceRecordID"] += 1
        bench.atomic_json(receipt_path, receipt)
        with self.assertRaisesRegex(ValueError, "does not match"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertFalse(self.app.writes)
        with self.assertRaisesRegex(ValueError, "SIMULATOR_CAPTURE"):
            native._receipt_values(bench.read_json(FOLDER / "examples/synthetic_capture.json"), receipt)

    def test_current_payload_changed_since_persistence_never_writes(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.values[native.PREFIX + "stCaptureEnvelope.stSourceEvent.udiAuthorityID"] = "18"
        with self.assertRaisesRegex(ValueError, "differs from"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertFalse(self.app.writes)

    def test_raw_low_must_be_observed_by_gate_before_body_or_valid(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.never_arm = True
        with self.assertRaisesRegex(ValueError, "raw-low"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(len(self.app.writes), 1)
        self.assertEqual(self.app.delays, native.READBACK_ATTEMPTS)

    def test_partial_body_failure_leaves_invalid_receipt_and_cleans_preparations(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.fail_body = True
        with self.assertRaises(IOError):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(self.app.values[native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"], "BOOL#FALSE")
        self.assertEqual(len(self.app.writes), 2)
        self.assertFalse(self.app.prepared)

    def test_corrupt_body_readback_never_publishes_valid(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.corrupt_body = True
        with self.assertRaisesRegex(ValueError, "read-back"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(len(self.app.writes), 2)
        self.assertEqual(self.app.values[native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"], "BOOL#FALSE")

    def test_permission_revoked_during_readback_never_publishes_valid(self):
        capture_path, receipt_path = self.captured_and_persisted()
        def revoke(app):
            if app.delays == 2:
                app.values[native.PREFIX + "xPublicationAllowed"] = "FALSE"
        self.app.on_delay = revoke
        with self.assertRaisesRegex(ValueError, "not eligible"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(len(self.app.writes), 2)

    def test_foreign_preparation_is_not_written_or_removed(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.foreign_on_prepare = True
        with self.assertRaisesRegex(ValueError, "Prepared expressions changed"):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertFalse(self.app.writes)
        self.assertEqual(self.app.prepared, {"OTHER.value": "UDINT#9"})

    def test_exception_after_final_delivery_is_not_reported_as_success(self):
        capture_path, receipt_path = self.captured_and_persisted()
        self.app.fail_final = True
        with self.assertRaises(IOError):
            native.apply_receipt(self.online, capture_path, receipt_path, self.app)
        self.assertEqual(len(self.app.writes), 3)
        self.assertEqual(self.app.values[native.PREFIX + "stSinkReturned.stSourceReceipt.xValid"], "BOOL#TRUE")
        self.assertFalse(self.app.prepared)

    def test_monitoring_metadata_matches_canonical_source_and_service_enum_values(self):
        layout = bench.read_json(FOLDER / "monitoring_layout.json")
        root = FOLDER.parents[1]
        text = re.sub(r"//[^\n]*", "", (root / "src/dut/ST_SEQ_EVENT.st").read_text())
        self.assertEqual(layout["source_event_fields"], dict(re.findall(r"\b(\w+)\s*:\s*(\w+)\s*;", text)))
        service = bench.read_json(FOLDER / "service_event.schema.json")
        for name, enum in layout["enum_values"].items():
            if name.startswith("E_SEQ_"):
                data = (root / "src/dut" / (name + ".st")).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), layout["enum_source_sha256"][name])
                self.assertEqual(enum, {k: int(v) for k, v in re.findall(r"\b(\w+)\s*:=\s*(\d+)", data.decode())})
            else:
                self.assertEqual(set(enum.values()), set(service["types"][name]["values"]))


if __name__ == "__main__":
    unittest.main()
