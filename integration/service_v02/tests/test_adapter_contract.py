"""Offline protocol-model + source guard tests; NOT native ST execution."""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
ADAPTER = ROOT / "integration/service_v02/FB_SEQ_ToServiceAdapter.st"
sys.path.insert(0, str(ROOT / "tools"))
import check_sources


class ReceiptModel:
    """Small oracle for intended receipt state transitions, separate from ST."""
    def __init__(self):
        self.pending = None
        self.mapping = None
        self.armed = False
        self.acked = False

    def scan(self, source, receipt=None, *, enabled=True, mapping=1):
        result = {"ack": False, "valid": False, "conflict": False,
                  "rejected": False, "envelope": None}
        if not enabled or source is None or not source.get("valid", True):
            self.armed = False
            return result
        same = self.pending is not None and self.pending["key"] == source["key"]
        if self.pending is None or (self.acked and not same):
            self.pending = deepcopy(source)
            self.mapping = mapping
            self.armed = False
            self.acked = False
            same = True
        if not same or self.mapping != mapping:
            result["conflict"] = True
            self.armed = False
        elif self.acked:
            result["ack"] = True
        elif not self.acked:
            result["valid"] = True
            result["envelope"] = deepcopy(self.pending)
            if receipt is None or not receipt.get("valid", True):
                self.armed = True
            else:
                exact = (receipt["key"] == self.pending["key"]
                         and receipt.get("full", False)
                         and receipt.get("mapping") == self.mapping)
                if self.armed and exact:
                    result["ack"] = True
                    self.acked = True
                else:
                    result["rejected"] = True
                self.armed = False
        return result


class AdapterProtocolTests(unittest.TestCase):
    def setUp(self):
        self.model = ReceiptModel()
        self.source = {"key": (11, 21, 31, 41, 51), "authority": 100,
                       "origin_tick": 4321, "command_source": 99}
        self.receipt = {"key": self.source["key"], "mapping": 1, "full": True}

    def test_exact_full_ownership_after_low_receipt(self):
        self.assertTrue(self.model.scan(self.source)["valid"])
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])

    def test_preheld_exact_receipt_must_first_go_low(self):
        self.assertFalse(self.model.scan(self.source, self.receipt)["ack"])
        self.assertFalse(self.model.scan(self.source, self.receipt)["ack"])
        self.model.scan(self.source)
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])

    def test_every_wrong_identity_component_blocks(self):
        for index in range(5):
            with self.subTest(index=index):
                m = ReceiptModel()
                m.scan(self.source)
                bad = deepcopy(self.receipt)
                key = list(bad["key"])
                key[index] += 1
                bad["key"] = tuple(key)
                self.assertFalse(m.scan(self.source, bad)["ack"])
                self.assertFalse(m.scan(self.source, self.receipt)["ack"])
                m.scan(self.source)
                self.assertTrue(m.scan(self.source, self.receipt)["ack"])

    def test_partial_projection_is_not_ownership(self):
        self.model.scan(self.source)
        receipt = dict(self.receipt, full=False)
        self.assertTrue(self.model.scan(self.source, receipt)["rejected"])

    def test_wrong_mapping_revision_is_not_ownership(self):
        self.model.scan(self.source)
        self.assertFalse(self.model.scan(self.source, dict(self.receipt, mapping=2))["ack"])

    def test_repeated_receipt_holds_only_the_same_owned_head_ack(self):
        self.model.scan(self.source)
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])
        self.model.scan(self.source)
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])
        new = dict(self.source, key=(11, 21, 31, 41, 52))
        self.assertFalse(self.model.scan(new, self.receipt)["ack"])

    def test_lost_ack_restores_after_publication_regrant_for_owned_head(self):
        self.model.scan(self.source)
        self.assertTrue(self.model.scan(self.source, self.receipt)["ack"])
        self.assertFalse(self.model.scan(None, self.receipt)["ack"])
        self.assertTrue(self.model.scan(self.source)["ack"])
        self.assertFalse(self.model.scan(self.source, enabled=False)["ack"])
        self.assertTrue(self.model.scan(self.source)["ack"])

    def test_publication_revocation_masks_payload_and_rearms(self):
        self.model.scan(self.source)
        result = self.model.scan(None, self.receipt)
        self.assertFalse(result["valid"])
        self.assertFalse(result["ack"])
        self.assertIsNone(result["envelope"])
        self.assertFalse(self.model.scan(self.source, self.receipt)["ack"])

    def test_disabled_adapter_masks_and_retains(self):
        self.model.scan(self.source)
        result = self.model.scan(self.source, self.receipt, enabled=False)
        self.assertFalse(result["valid"])
        self.assertFalse(result["ack"])
        self.assertEqual(self.model.pending, self.source)

    def test_unowned_source_head_change_blocks_not_overwrites(self):
        self.model.scan(self.source)
        new = dict(self.source, key=(11, 21, 31, 41, 52))
        self.assertTrue(self.model.scan(new)["conflict"])
        self.assertEqual(self.model.pending, self.source)

    def test_new_head_after_ack_needs_new_receipt_edge(self):
        self.model.scan(self.source)
        self.model.scan(self.source, self.receipt)
        new = dict(self.source, key=(11, 21, 31, 41, 52))
        receipt = dict(self.receipt, key=new["key"])
        result = self.model.scan(new, receipt)
        self.assertTrue(result["valid"])
        self.assertFalse(result["ack"])
        self.model.scan(new)
        self.assertTrue(self.model.scan(new, receipt)["ack"])

    def test_mapper_revision_change_cannot_reinterpret_pending(self):
        self.model.scan(self.source)
        result = self.model.scan(self.source, mapping=2)
        self.assertTrue(result["conflict"])
        self.assertFalse(result["valid"])
        self.assertEqual(self.model.mapping, 1)

    def test_full_payload_is_immutable_for_same_identity(self):
        first = self.model.scan(self.source)
        later = self.model.scan(dict(self.source, authority=999, origin_tick=9999))
        self.assertEqual(first["envelope"], later["envelope"])


class AdapterSourceTests(unittest.TestCase):
    def test_st_delimiters(self):
        for path in ADAPTER.parent.rglob("*.st"):
            findings = []
            source = check_sources.parse_source(path, findings)
            check_sources.check_delimiters(source, findings)
            self.assertEqual(findings, [], path.name)

    def test_boundaries_and_exact_identity_guards(self):
        text = check_sources.mask_noncode(ADAPTER.read_text())
        self.assertNotRegex(text, r"%[IQ]|GVL_|FB_Service\s*\(")
        self.assertIn("stLatched.stSourceEvent := stEvent;", text)
        self.assertIn("stLatched.xProjectionLossless := FALSE;", text)
        self.assertIn("IF xReceiptArmed AND xReceiptMatches THEN", text)
        for name in ("uiMachineID", "uiProducerSourceID", "uiProcessID",
                     "udiSessionID", "udiEventID"):
            self.assertIn(f"stReceipt.{name} = stLatched.stSourceEvent.{name}", text)
        self.assertIn("stReceipt.xFullEnvelopeOwned", text)
        self.assertIn("stReceipt.udiMappingRevision = stLatched.udiMappingRevision", text)

    def test_event_enum_coverage_and_no_fabricated_utc_actor(self):
        text = check_sources.mask_noncode(ADAPTER.read_text())
        enum = (ROOT / "src/dut/E_SEQ_EVENT_KIND.st").read_text()
        members = re.findall(r"\b(\w+)\s*:=\s*\d+", enum)
        for member in members:
            self.assertIn(f"E_SEQ_EVENT_KIND.{member}", text)
        self.assertNotRegex(text, r"udiUtcSeconds\s*:=|uiUtcMilliseconds\s*:=")
        self.assertIn("eActorKind := E_SVC_ActorKind.UNKNOWN;", text)
        self.assertIn("stHeader.uiSourceID := stEvent.uiProducerSourceID;", text)
        self.assertNotIn("stHeader.uiSourceID := stEvent.uiSourceID;", text)
        self.assertIn("stServiceEvent.xValid := stEvent.xOccurrenceTimeValid;", text)


if __name__ == "__main__":
    unittest.main()
