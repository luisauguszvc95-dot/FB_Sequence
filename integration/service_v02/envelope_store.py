"""Offline DEMO sink for a complete Sequence envelope and Service insertion receipt.

No PLC/network client. Returns a sink receipt only after SQLite COMMIT. The
canonical ST source supplies the complete event field inventory and enum values.
This separate sidecar path is not the Service 160-word wire image.
"""
from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 256 * 1024
SERVICE_TYPES = json.loads(Path(__file__).with_name("service_event.schema.json")
                          .read_text(encoding="utf-8"))["types"]


class EnvelopeConflict(ValueError):
    """A previously stored identity has different content or Service binding."""


def _code(path):
    return re.sub(r"//[^\n]*|\(\*.*?\*\)", "", path.read_text(encoding="utf-8"), flags=re.S)


def _integer(value, bits, name, *, nonzero=False):
    if type(value) is not int or not int(nonzero) <= value < 2 ** bits:
        raise ValueError(f"invalid {name}")


def _canonical(value):
    result = json.dumps(value, sort_keys=True, separators=(",", ":"),
                        ensure_ascii=False, allow_nan=False)
    if len(result.encode()) > MAX_BYTES:
        raise ValueError("envelope exceeds 256 KiB")
    return result


def _service_shape(value, kind):
    if kind in SERVICE_TYPES:
        spec = SERVICE_TYPES[kind]
        if "values" in spec:
            if type(value) is not int or value not in spec["values"]:
                raise ValueError(f"invalid {kind}")
        else:
            if type(value) is not dict or set(value) != set(spec["fields"]):
                raise ValueError(f"incomplete {kind}")
            for name, field_type in spec["fields"].items():
                _service_shape(value[name], field_type)
    elif kind == "BOOL":
        if type(value) is not bool:
            raise ValueError("invalid BOOL")
    elif kind in ("UINT", "UDINT", "DWORD"):
        _integer(value, 16 if kind == "UINT" else 32, kind)
    elif kind == "DINT":
        if type(value) is not int or not -(2**31) <= value < 2**31:
            raise ValueError("invalid DINT")
    elif kind in ("REAL", "LREAL"):
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError(f"invalid {kind}")
    else:
        raise ValueError(f"unsupported field type {kind}")


def validate(envelope, ingress):
    """Reject incomplete source data; do not invent missing fields or provenance."""
    if type(envelope) is not dict or type(ingress) is not dict:
        raise ValueError("expected envelope and ingress objects")
    if set(envelope) != {"udiMappingRevision", "xProjectionLossless", "stSourceEvent", "stServiceEvent"}:
        raise ValueError("incomplete ST_SEQ_SVC_ENVELOPE")
    _service_shape(ingress, "ST_SVC_EventReceipt")
    _service_shape(envelope.get("stServiceEvent"), "ST_SVC_EventInput")
    source = envelope.get("stSourceEvent")
    if type(source) is not dict:
        raise ValueError("missing complete source event")
    fields = dict(re.findall(r"\b(\w+)\s*:\s*(\w+)\s*;",
                             _code(ROOT / "src/dut/ST_SEQ_EVENT.st")))
    if set(source) != set(fields):
        raise ValueError("source fields differ from canonical ST_SEQ_EVENT")
    for name, kind in fields.items():
        value = source[name]
        if kind == "BOOL":
            if type(value) is not bool:
                raise ValueError(f"invalid {name}")
        elif kind in ("UINT", "UDINT"):
            _integer(value, 16 if kind == "UINT" else 32, name)
        elif kind.startswith("E_SEQ_"):
            allowed = {int(v) for v in re.findall(r"\b\w+\s*:=\s*(\d+)",
                                                  _code(ROOT / f"src/dut/{kind}.st"))}
            if type(value) is not int or value not in allowed:
                raise ValueError(f"invalid {name}")
        else:
            raise ValueError(f"unsupported canonical type {kind}")
    if (source["uiContractMajor"], source["uiContractMinor"]) != (0, 2):
        raise ValueError("requires Sequence schema 0.2")
    _integer(envelope.get("udiMappingRevision"), 32, "mapping", nonzero=True)
    if envelope.get("xProjectionLossless") is not False:
        raise ValueError("generic projection must declare information loss")
    if ingress.get("xValid") is not True:
        raise ValueError("no successful Service insertion receipt")
    mapping = {"uiMachineID": "uiMachineID", "uiSourceID": "uiProducerSourceID",
               "uiProcessID": "uiProcessID", "udiSourceEpoch": "udiSessionID",
               "udiSourceSeq": "udiEventID"}
    for target, origin in mapping.items():
        _integer(source[origin], 16 if origin.startswith("ui") else 32, origin,
                 nonzero=True)
        _integer(ingress.get(target), 16 if target.startswith("ui") else 32,
                 target, nonzero=True)
        if ingress[target] != source[origin]:
            raise ValueError(f"mismatched ingress {target}")
    for name in ("udiBootID", "udiRecordID"):
        _integer(ingress.get(name), 32, name, nonzero=True)
    projection = envelope.get("stServiceEvent")
    if type(projection) is not dict or projection.get("xValid") is not True:
        raise ValueError("missing eligible Service projection")
    header, context = projection.get("stHeader", {}), projection.get("stContext", {})
    if header.get("xValid") is not True:
        raise ValueError("invalid projection header")
    for field in ("uiSourceID", "udiSourceEpoch", "udiSourceSeq"):
        if type(header.get(field)) is not int or header[field] != ingress[field]:
            raise ValueError(f"mismatched projection {field}")
    if context.get("uiProcessID") != source["uiProcessID"]:
        raise ValueError("mismatched projection process")
    if (header["uiSchemaMajor"], header["uiSchemaMinor"]) != (2, 0):
        raise ValueError("requires Service schema 2.0")
    if (header["eQuality"] not in (2, 3) or header["eProducerKind"] != 6
        or header["udiProducerID"] == 0 or projection["eDomain"] == 0
        or projection["eKind"] == 0 or source["eKind"] == 0):
        raise ValueError("ineligible Sequence projection")
    if (not source["xOccurrenceTimeValid"] or not projection["stTime"]["xValid"]
        or projection["stTime"]["udiTickMs"] != source["udiOccurrenceTickMs"]
        or header["udiTickMs"] != source["udiOccurrenceTickMs"]):
        raise ValueError("source occurrence time is unavailable or inconsistent")
    for field in ("udiBatchID", "udiRecipeID", "udiRecipeRevision", "uiStepID"):
        if context[field] != source[field]:
            raise ValueError(f"mismatched projection context {field}")
    for target, origin in {"uiEventCode": "eKind", "uiReasonID": "eReason",
                           "udiCorrelationID": "udiRequestID", "dwOldState": "eStateBefore",
                           "dwNewState": "eState", "diOldValue": "uiStepIDBefore",
                           "diNewValue": "uiStepID"}.items():
        if projection[target] != source[origin]:
            raise ValueError(f"mismatched projection {target}")
    _canonical(envelope)


class EnvelopeStore:
    def __init__(self, path):
        self.connection = sqlite3.connect(path, isolation_level=None)
        self.connection.execute("PRAGMA synchronous=FULL")
        self.connection.execute("""CREATE TABLE IF NOT EXISTS sequence_envelopes (
            source_key TEXT PRIMARY KEY,
            service_key TEXT UNIQUE NOT NULL,
            envelope_json TEXT NOT NULL,
            ingress_json TEXT NOT NULL
        )""")

    def persist(self, envelope, ingress):
        envelope, ingress = deepcopy(envelope), deepcopy(ingress)
        validate(envelope, ingress)
        event = envelope["stSourceEvent"]
        source_key = _canonical([event[k] for k in (
            "uiMachineID", "uiProducerSourceID", "uiProcessID", "udiSessionID", "udiEventID")])
        service_key = _canonical([ingress[k] for k in ("uiMachineID", "udiBootID", "udiRecordID")])
        encoded, encoded_ingress = _canonical(envelope), _canonical(ingress)
        con = self.connection
        con.execute("BEGIN IMMEDIATE")
        try:
            old = con.execute("SELECT service_key,envelope_json,ingress_json FROM sequence_envelopes WHERE source_key=?",
                              (source_key,)).fetchone()
            if old is not None:
                if old != (service_key, encoded, encoded_ingress):
                    raise EnvelopeConflict("source identity already stored with different full content or binding")
            else:
                con.execute("INSERT INTO sequence_envelopes VALUES (?,?,?,?)",
                            (source_key, service_key, encoded, encoded_ingress))
            con.execute("COMMIT")
        except BaseException:
            if con.in_transaction:
                con.execute("ROLLBACK")
            raise
        # Construct only after COMMIT (also for an exact duplicate).
        return {"stSourceReceipt": {
            "xValid": True, "xFullEnvelopeOwned": True,
            "udiMappingRevision": envelope["udiMappingRevision"],
            **{k: event[k] for k in ("uiMachineID", "uiProducerSourceID",
                                    "uiProcessID", "udiSessionID", "udiEventID")}},
            "udiServiceBootID": ingress["udiBootID"],
            "udiServiceRecordID": ingress["udiRecordID"]}

    def close(self):
        self.connection.close()
