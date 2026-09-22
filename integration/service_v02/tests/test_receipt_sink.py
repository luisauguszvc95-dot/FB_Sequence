"""Real SQLite tests and a protocol oracle; native ST execution is a separate gate."""
from copy import deepcopy
from contextlib import closing
import json
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
import unittest

FOLDER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(FOLDER))
from envelope_store import EnvelopeStore, EnvelopeConflict, SERVICE_TYPES, ROOT


def sample():
    def default(kind):
        if kind in SERVICE_TYPES:
            spec = SERVICE_TYPES[kind]
            if "fields" in spec:
                return {k: default(v) for k, v in spec["fields"].items()}
            return spec["values"][0]
        return False if kind == "BOOL" else 0
    text = re.sub(r"//[^\n]*", "", (ROOT / "src/dut/ST_SEQ_EVENT.st").read_text())
    fields = dict(re.findall(r"\b(\w+)\s*:\s*(\w+)\s*;", text))
    event = {k: False if t == "BOOL" else 0 for k, t in fields.items()}
    event.update(uiContractMajor=0, uiContractMinor=2, uiMachineID=1,
                 uiProducerSourceID=301, uiProcessID=7, udiSessionID=1001,
                 udiEventID=42, eKind=3, eCommandResult=1, uiSourceID=99,
                 udiCommandSessionID=123, udiRequestID=456,
                 udiAuthorityID=17, udiBatchID=100, udiBatchIDBefore=99,
                 xOccurrenceTimeValid=True, udiOccurrenceTickMs=2468)
    projection = default("ST_SVC_EventInput")
    projection["xValid"] = True
    projection["stHeader"].update(xValid=True, uiSchemaMajor=2, uiSchemaMinor=0,
                                  uiSourceID=301, udiSourceEpoch=1001, udiSourceSeq=42,
                                  eProducerKind=6, udiProducerID=301, eQuality=3,
                                  udiTickMs=2468)
    projection["stContext"].update(uiProcessID=7, udiBatchID=100)
    projection["stTime"].update(xValid=True, udiTickMs=2468)
    projection.update(eDomain=4, eKind=12, uiObjectID=7, uiEventCode=3,
                      udiCorrelationID=456)
    envelope = {"udiMappingRevision": 1, "xProjectionLossless": False,
                "stSourceEvent": event, "stServiceEvent": projection}
    ingress = dict(xValid=True, uiMachineID=1, uiSourceID=301, uiProcessID=7,
                   udiSourceEpoch=1001, udiSourceSeq=42, udiBootID=2002, udiRecordID=12)
    return envelope, ingress


def receipt_key(sink):
    s = sink["stSourceReceipt"]
    return tuple(s[k] for k in ("uiMachineID", "uiProducerSourceID", "uiProcessID",
                                "udiSessionID", "udiEventID", "udiMappingRevision")) + (
        sink["udiServiceBootID"], sink["udiServiceRecordID"])


class GateModel:
    def __init__(self):
        self.binding = None
        self.armed = False
        self.owned = False
        self.was_eligible = False

    def scan(self, binding, sink=None, *, eligible=True):
        resume = eligible and not self.was_eligible
        self.was_eligible = eligible
        if not eligible:
            self.armed = False
            return False
        if binding != self.binding:
            self.binding, self.armed, self.owned = binding, False, False
        if self.owned:
            return not resume
        if sink is None or not sink["stSourceReceipt"]["xValid"]:
            self.armed = True
            return False
        self.owned = (self.armed and sink["stSourceReceipt"]["xFullEnvelopeOwned"]
                      and receipt_key(sink) == self.binding)
        self.armed = False
        return self.owned


class EnvelopeStoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "sidecar.sqlite3"
        self.store = EnvelopeStore(self.path)
        self.env, self.ingress = sample()

    def tearDown(self):
        self.store.close(); self.tmp.cleanup()

    def test_receipt_after_real_commit_preserves_every_source_field(self):
        receipt = self.store.persist(self.env, self.ingress)
        with closing(sqlite3.connect(self.path)) as other, other:
            saved = json.loads(other.execute("SELECT envelope_json FROM sequence_envelopes").fetchone()[0])
        self.assertEqual(saved, self.env)
        self.assertEqual(saved["stSourceEvent"]["eCommandResult"], 1)
        self.assertEqual(saved["stSourceEvent"]["uiSourceID"], 99)
        self.assertEqual(receipt["stSourceReceipt"]["uiProducerSourceID"], 301)
        self.assertTrue(receipt["stSourceReceipt"]["xFullEnvelopeOwned"])

    def test_exact_duplicate_is_idempotent_after_reopen(self):
        first = self.store.persist(self.env, self.ingress)
        self.store.close(); self.store = EnvelopeStore(self.path)
        self.assertEqual(self.store.persist(self.env, self.ingress), first)
        self.assertEqual(self.store.connection.execute("SELECT COUNT(*) FROM sequence_envelopes").fetchone()[0], 1)

    def test_missing_each_source_field_rejects_before_any_receipt(self):
        for field in self.env["stSourceEvent"]:
            with self.subTest(field=field):
                bad = deepcopy(self.env); del bad["stSourceEvent"][field]
                with self.assertRaises(ValueError): self.store.persist(bad, self.ingress)

    def test_missing_projection_field_is_not_a_full_envelope(self):
        del self.env["stServiceEvent"]["uiReasonID"]
        with self.assertRaises(ValueError): self.store.persist(self.env, self.ingress)

    def test_malformed_or_relabelled_projection_never_gets_full_receipt(self):
        for field in ("uiEventCode", "uiReasonID", "udiCorrelationID", "dwNewState"):
            with self.subTest(field=field):
                bad = deepcopy(self.env); bad["stServiceEvent"][field] += 1
                with self.assertRaises(ValueError): self.store.persist(bad, self.ingress)
        bad = deepcopy(self.env); bad["stSourceEvent"]["xOccurrenceTimeValid"] = False
        with self.assertRaises(ValueError): self.store.persist(bad, self.ingress)

    def test_every_mismatched_source_receipt_component_is_rejected(self):
        for field in ("uiMachineID", "uiSourceID", "uiProcessID", "udiSourceEpoch", "udiSourceSeq"):
            with self.subTest(field=field):
                bad = dict(self.ingress); bad[field] += 1
                with self.assertRaises(ValueError): self.store.persist(self.env, bad)

    def test_projection_only_or_invalid_ingress_is_not_full_ownership(self):
        with self.assertRaises(ValueError): self.store.persist(self.env["stServiceEvent"], self.ingress)
        with self.assertRaises(ValueError): self.store.persist(self.env, dict(self.ingress, xValid=False))

    def test_reused_identity_with_changed_reason_or_mapping_cannot_overwrite(self):
        self.store.persist(self.env, self.ingress)
        for field in ("udiAuthorityID", "udiBatchIDBefore", "eCommandResult"):
            bad = deepcopy(self.env); bad["stSourceEvent"][field] += 1
            with self.assertRaises(EnvelopeConflict): self.store.persist(bad, self.ingress)
        with self.assertRaises(EnvelopeConflict):
            self.store.persist(dict(self.env, udiMappingRevision=2), self.ingress)

    def test_different_boot_binding_requires_reconciliation(self):
        self.store.persist(self.env, self.ingress)
        with self.assertRaises(EnvelopeConflict):
            self.store.persist(self.env, dict(self.ingress, udiBootID=2003))

    def test_insert_failure_never_returns_a_receipt(self):
        self.store.connection.execute("CREATE TRIGGER reject_insert BEFORE INSERT ON sequence_envelopes BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        with self.assertRaises(sqlite3.DatabaseError): self.store.persist(self.env, self.ingress)
        self.assertFalse(self.store.connection.in_transaction)
        self.assertEqual(self.store.connection.execute("SELECT COUNT(*) FROM sequence_envelopes").fetchone()[0], 0)

    def test_commit_failure_rolls_back_and_produces_no_receipt(self):
        self.store.connection.set_authorizer(lambda action, arg1, *_:
            sqlite3.SQLITE_DENY if action == sqlite3.SQLITE_TRANSACTION and arg1 == "COMMIT" else sqlite3.SQLITE_OK)
        with self.assertRaises(sqlite3.DatabaseError): self.store.persist(self.env, self.ingress)
        # Python 3.10 does not support disabling this callback with None.
        # Keep the denied-COMMIT injection and explicitly restore allow-all.
        self.store.connection.set_authorizer(lambda *_: sqlite3.SQLITE_OK)
        self.assertEqual(self.store.connection.execute("SELECT COUNT(*) FROM sequence_envelopes").fetchone()[0], 0)


class ReceiptGateTests(unittest.TestCase):
    def setUp(self):
        env, ingress = sample()
        store = EnvelopeStore(":memory:")
        self.sink = store.persist(env, ingress); store.close()
        self.key = receipt_key(self.sink)
        self.gate = GateModel()

    def test_preheld_receipt_needs_raw_low_after_ingress_is_eligible(self):
        self.assertFalse(self.gate.scan(self.key, self.sink, eligible=False))
        self.assertFalse(self.gate.scan(self.key, self.sink))
        self.gate.scan(self.key)
        self.assertTrue(self.gate.scan(self.key, self.sink))

    def test_each_source_mapping_and_service_identity_must_match(self):
        for index in range(8):
            gate = GateModel(); key = list(self.key); key[index] += 1
            gate.scan(tuple(key))
            self.assertFalse(gate.scan(tuple(key), self.sink))

    def test_new_head_cannot_reuse_owned_receipt(self):
        self.gate.scan(self.key); self.assertTrue(self.gate.scan(self.key, self.sink))
        key = list(self.key); key[4] += 1
        self.assertFalse(self.gate.scan(tuple(key), self.sink))

    def test_revocation_disarms_unowned_but_keeps_owned_exact_binding(self):
        self.gate.scan(self.key)
        self.gate.scan(self.key, eligible=False)
        self.assertFalse(self.gate.scan(self.key, self.sink))
        self.gate.scan(self.key); self.gate.scan(self.key, self.sink)
        self.assertFalse(self.gate.scan(self.key, eligible=False))
        self.assertFalse(self.gate.scan(self.key))
        self.assertTrue(self.gate.scan(self.key))

    def test_owned_receipt_rearms_mapper_after_revocation_before_source_ack(self):
        from test_adapter_contract import ReceiptModel
        mapper = ReceiptModel()
        source = {"key": self.key[:5]}
        mapper.scan(source)
        self.gate.scan(self.key)
        self.assertTrue(self.gate.scan(self.key, self.sink))
        # Publication withdrawn before the mapper consumed the gate's output.
        mapper.scan(None)
        self.gate.scan(self.key, eligible=False)
        self.assertFalse(self.gate.scan(self.key, self.sink))
        self.assertFalse(mapper.scan(source)["ack"])
        self.assertTrue(self.gate.scan(self.key, self.sink))
        self.assertTrue(mapper.scan(source, {"key": self.key[:5], "mapping": 1, "full": True})["ack"])

    def test_partial_ownership_never_opens_gate(self):
        self.gate.scan(self.key)
        self.sink["stSourceReceipt"]["xFullEnvelopeOwned"] = False
        self.assertFalse(self.gate.scan(self.key, self.sink))

    def test_st_guards_include_raw_edge_and_all_receipt_components(self):
        code = (FOLDER / "FB_SEQ_ServiceReceiptGate.st").read_text()
        self.assertIn("ELSIF NOT stSink.stSourceReceipt.xValid THEN", code)
        self.assertIn("IF xArmed AND xMatches THEN", code)
        self.assertNotRegex(code, r"%[IQ]|GVL_|E_SEQ_RESULT\.")
        for name in ("uiMachineID", "uiProducerSourceID", "uiProcessID", "udiSessionID", "udiEventID", "udiMappingRevision"):
            self.assertIn(f"stSink.stSourceReceipt.{name} =", code)
        self.assertIn("stSink.udiServiceBootID =", code)
        self.assertIn("stSink.udiServiceRecordID =", code)


if __name__ == "__main__":
    unittest.main()
