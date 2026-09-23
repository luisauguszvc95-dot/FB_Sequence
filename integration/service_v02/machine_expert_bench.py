"""Capture and return a persisted sink receipt in an already running SIMULATION.

Compatible syntax: IronPython 2.7 / Python 3. Pattern follows the existing
FB_Service historian helpers. This module never logs in, starts/stops tasks,
changes simulation mode, forces values, or writes source/audit/transport ACKs.
All native API behavior remains to be validated in Machine Expert 2.6.
"""
from __future__ import print_function

import hashlib
import json
import math
import os
import re
import tempfile

PREFIX = "PRG_SEQ_ServiceBench."
MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
MAX_BYTES = 256 * 1024
READBACK_ATTEMPTS = 20
READBACK_DELAY_MS = 100


def _pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("Duplicate JSON field: " + key)
        result[key] = value
    return result


def _invalid_constant(value):
    raise ValueError("Invalid JSON number: " + value)


def _load(path):
    with open(path, "rb") as source:
        raw = source.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("File exceeds 256 KiB")
    return json.loads(raw.decode("utf-8"), object_pairs_hook=_pairs,
                      parse_constant=_invalid_constant)


def _canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def _layout():
    monitoring = _load(os.path.join(MODULE_DIR, "monitoring_layout.json"))
    service = _load(os.path.join(MODULE_DIR, "service_event.schema.json"))
    if monitoring["schema"] != "sequence-bench-monitoring/1":
        raise ValueError("Unsupported monitoring layout")
    types = dict(service["types"])
    types["ST_SEQ_EVENT"] = {"fields": monitoring["source_event_fields"]}
    types["ST_SEQ_SVC_ENVELOPE"] = {"fields": {
        "udiMappingRevision": "UDINT", "xProjectionLossless": "BOOL",
        "stSourceEvent": "ST_SEQ_EVENT", "stServiceEvent": "ST_SVC_EventInput"}}
    return types, monitoring["enum_values"]


def _scalar(value, kind, enums):
    token = str(value).strip()
    if kind == "BOOL":
        if token.upper() in ("TRUE", "BOOL#TRUE"):
            return True
        if token.upper() in ("FALSE", "BOOL#FALSE"):
            return False
        raise ValueError("Invalid BOOL monitoring value: " + token)
    if kind in enums:
        member = token.rsplit(".", 1)[-1]
        if member in enums[kind] and ("." not in token or token.rsplit(".", 1)[0] == kind):
            return enums[kind][member]
        number = _scalar(token, "UINT", {})
        if number not in enums[kind].values():
            raise ValueError("Unknown enum monitoring value: " + token)
        return number
    token = token.upper().replace("_", "")
    if kind in ("REAL", "LREAL"):
        if token.startswith(kind + "#"):
            token = token[len(kind) + 1:]
        if not re.match(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:E[+-]?\d+)?$", token):
            raise ValueError("Invalid real monitoring value: " + token)
        number = float(token)
        if math.isnan(number) or math.isinf(number):
            raise ValueError("Nonfinite monitoring value")
        return number
    if kind not in ("UINT", "UDINT", "DWORD", "DINT"):
        raise ValueError("Unsupported monitoring type: " + kind)
    if token.startswith(kind + "#"):
        token = token[len(kind) + 1:]
    parts = token.split("#")
    if len(parts) == 1:
        if not re.match(r"^-?\d+$", token):
            raise ValueError("Invalid integer monitoring value: " + token)
        number = int(token, 10)
    elif len(parts) == 2 and parts[0] in ("2", "8", "16"):
        base = int(parts[0])
        allowed = "0123456789ABCDEF"[:base]
        if not parts[1] or any(char not in allowed for char in parts[1]):
            raise ValueError("Invalid IEC monitoring literal: " + token)
        number = int(parts[1], base)
    else:
        raise ValueError("Invalid monitoring literal: " + token)
    bits = 16 if kind == "UINT" else 32
    lower, upper = (-(2 ** 31), 2 ** 31) if kind == "DINT" else (0, 2 ** bits)
    if not lower <= number < upper:
        raise ValueError("Monitoring value outside " + kind)
    return number


def _read_struct(application, expression, kind, types, enums):
    spec = types.get(kind, {})
    if "fields" in spec:
        return dict((name, _read_struct(application, expression + "." + name,
                                       field_type, types, enums))
                    for name, field_type in sorted(spec["fields"].items()))
    return _scalar(application.read_value(expression), kind, enums)


def _require_target(application, device):
    if not application.is_logged_in:
        raise ValueError("An already connected simulation is required; no login performed")
    if not device.device.get_simulation_mode():
        raise ValueError("Only SIMULATION mode is accepted")
    if str(application.application_state).lower().split(".")[-1] != "run":
        raise ValueError("Simulation must already be in RUN; no state change performed")
    if list(application.get_forced_expressions()) or list(application.get_prepared_expressions()):
        raise ValueError("Forced or prepared values exist; no operation performed")
    for name in ("xEnableBench", "xPublicationAllowed", "xCaptureReady"):
        if not _scalar(application.read_value(PREFIX + name), "BOOL", {}):
            raise ValueError("Bench is not eligible: " + name)


def _open(online_api):
    application, device = None, None
    try:
        if online_api is None:
            raise ValueError("Machine Expert scripting API is unavailable; no simulation operation performed")
        application = online_api.create_online_application()
        if not application.is_logged_in:
            raise ValueError("Simulation is not connected; no login performed")
        device = application.get_online_device()
        _require_target(application, device)
        return application, device
    except Exception:
        _dispose(application, device)
        raise


def _dispose(application, device):
    try:
        if device is not None:
            device.Dispose()
    finally:
        if application is not None:
            application.Dispose()


def _snapshot(application, device):
    types, enums = _layout()
    snapshots = []
    for unused in range(2):
        _require_target(application, device)
        snapshot = {"schema": "sequence-service-bench-capture/1", "origin": "SIMULATOR_CAPTURE",
                    "envelope": _read_struct(application, PREFIX + "stCaptureEnvelope",
                                             "ST_SEQ_SVC_ENVELOPE", types, enums),
                    "ingress": _read_struct(application, PREFIX + "stCaptureIngress",
                                            "ST_SVC_EventReceipt", types, enums)}
        _require_target(application, device)
        snapshots.append(snapshot)
    if _canonical(snapshots[0]) != _canonical(snapshots[1]):
        raise ValueError("Capture changed during read; no file/receipt published")
    _identity(snapshots[0])
    return snapshots[0]


def _identity(capture):
    if set(capture) != set(("schema", "origin", "envelope", "ingress")):
        raise ValueError("Invalid capture fields")
    if capture["schema"] != "sequence-service-bench-capture/1" or capture["origin"] != "SIMULATOR_CAPTURE":
        raise ValueError("Receipt return requires a SIMULATOR_CAPTURE")
    envelope, ingress = capture["envelope"], capture["ingress"]
    event = envelope["stSourceEvent"]
    if (event["uiContractMajor"], event["uiContractMinor"]) != (0, 2):
        raise ValueError("Requires Sequence source schema 0.2")
    if ingress["xValid"] is not True or envelope["xProjectionLossless"] is not False:
        raise ValueError("Capture has no eligible Service insertion")
    identities = (("uiMachineID", "uiMachineID"), ("uiProducerSourceID", "uiSourceID"),
                  ("uiProcessID", "uiProcessID"), ("udiSessionID", "udiSourceEpoch"),
                  ("udiEventID", "udiSourceSeq"))
    result = []
    for source, destination in identities:
        if event[source] <= 0 or event[source] != ingress[destination]:
            raise ValueError("Source and Service identities differ")
        result.append(event[source])
    result.extend((envelope["udiMappingRevision"], ingress["udiBootID"], ingress["udiRecordID"]))
    if any(value <= 0 for value in result):
        raise ValueError("Capture identity must be positive")
    return tuple(result)


def capture(online_api, output_dir):
    """Read-only full capture; no source ACK, SQLite access, login or mode change."""
    application, device = _open(online_api)
    try:
        payload = _snapshot(application, device)
    finally:
        _dispose(application, device)
    identity = _identity(payload)
    directory = os.path.abspath(output_dir)
    if not os.path.isdir(directory):
        os.makedirs(directory)
    filename = "sequence_m{0}_p{1}_proc{2}_s{3}_e{4}_map{5}_b{6}_r{7}.json".format(*identity)
    destination = os.path.join(directory, filename)
    if os.path.exists(destination):
        if _canonical(_load(destination)) != _canonical(payload):
            raise ValueError("Existing capture has different full content")
    else:
        descriptor, temporary = tempfile.mkstemp(prefix=".sequence-capture-", suffix=".tmp", dir=directory)
        try:
            with os.fdopen(descriptor, "wb") as target:
                target.write(_canonical(payload) + b"\n")
                target.flush()
                os.fsync(target.fileno())
            try:
                if os.name == "nt":
                    # Windows rename fails if destination exists. IronPython 2.7
                    # need not provide os.link. Both paths publish only complete files.
                    os.rename(temporary, destination)
                else:
                    os.link(temporary, destination)
            except Exception:
                if not os.path.exists(destination) or _canonical(_load(destination)) != _canonical(payload):
                    raise
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print("CAPTURE_SAVED: " + destination)
    return destination


def _receipt_values(capture_payload, receipt_payload):
    identity = _identity(capture_payload)
    event, ingress = capture_payload["envelope"]["stSourceEvent"], capture_payload["ingress"]
    source_receipt = {"xValid": True, "xFullEnvelopeOwned": True,
                      "udiMappingRevision": identity[5]}
    for name in ("uiMachineID", "uiProducerSourceID", "uiProcessID", "udiSessionID", "udiEventID"):
        source_receipt[name] = event[name]
    expected = {"schema": "sequence-service-bench-receipt/1", "origin": "SIMULATOR_CAPTURE",
                "capture_sha256": hashlib.sha256(_canonical(capture_payload)).hexdigest(),
                "status": "COMMITTED", "source_ack": "NOT_WRITTEN", "audit_ack": "NOT_WRITTEN",
                "transport_ack": "NOT_WRITTEN", "sink_receipt": {
                    "stSourceReceipt": source_receipt, "udiServiceBootID": ingress["udiBootID"],
                    "udiServiceRecordID": ingress["udiRecordID"]}}
    if _canonical(receipt_payload) != _canonical(expected):
        raise ValueError("Sink file does not match the exact captured envelope")
    values = []
    for name, value in sorted(source_receipt.items()):
        if name == "xValid":
            continue
        kind = "BOOL" if name.startswith("x") else "UDINT" if name.startswith("udi") else "UINT"
        values.append(("stSourceReceipt." + name, kind, value))
    values.extend((("udiServiceBootID", "UDINT", ingress["udiBootID"]),
                   ("udiServiceRecordID", "UDINT", ingress["udiRecordID"])))
    return values


def _literal(kind, value):
    if kind == "BOOL":
        return "BOOL#TRUE" if value else "BOOL#FALSE"
    return kind + "#" + str(value)


def _write(application, device, values):
    _require_target(application, device)
    owned = {}
    try:
        for field, kind, value in values:
            expression = PREFIX + "stSinkReturned." + field
            owned[expression] = (kind, value)
            application.set_prepared_value(expression, _literal(kind, value))
        # _require_target would reject our own prepared values, so inspect all
        # the other guards after confirming exactly our preparations are present.
        if set(application.get_prepared_expressions()) != set(owned):
            raise ValueError("Prepared expressions changed; no write performed")
        for expression, (kind, value) in owned.items():
            if _scalar(application.get_prepared_value(expression), kind, {}) != value:
                raise ValueError("Prepared receipt changed; no write performed")
        if (not application.is_logged_in or not device.device.get_simulation_mode()
                or str(application.application_state).lower().split(".")[-1] != "run"
                or list(application.get_forced_expressions())):
            raise ValueError("Simulation status changed before write")
        for name in ("xEnableBench", "xPublicationAllowed", "xCaptureReady"):
            if not _scalar(application.read_value(PREFIX + name), "BOOL", {}):
                raise ValueError("Publication became ineligible before write")
        application.write_prepared_values()
    finally:
        for expression, (kind, value) in owned.items():
            current = application.get_prepared_value(expression)
            if current is not None:
                try:
                    same = _scalar(current, kind, {}) == value
                except ValueError:
                    same = False
                if same:
                    application.set_prepared_value(expression, None)


def _wait_readback(application, device, values, system_api, require_armed=False):
    for unused in range(READBACK_ATTEMPTS):
        system_api.delay(READBACK_DELAY_MS)
        _require_target(application, device)
        matches = all(_scalar(application.read_value(PREFIX + "stSinkReturned." + field),
                              kind, {}) == value for field, kind, value in values)
        armed = not require_armed or _scalar(application.read_value(
            PREFIX + "fbReceiptGate.xReadyForReceipt"), "BOOL", {})
        if matches and armed:
            return
    raise ValueError("Receipt read-back/eligible raw-low not observed; final valid not published")


def apply_receipt(online_api, capture_path, receipt_path, system_api):
    """Return ONLY the existing sink receipt to the simulator's designated input.

    The SQLite CLI must run successfully first. The helper neither constructs
    ownership from RAM nor writes a Sequence/Audit/Adapter ACK. A failure at the
    final write may occur after delivery; inspect the simulation before retry.
    """
    if system_api is None or not callable(getattr(system_api, "delay", None)):
        raise ValueError("Machine Expert system.delay is required for observable read-back")
    capture_payload, receipt_payload = _load(capture_path), _load(receipt_path)
    values = _receipt_values(capture_payload, receipt_payload)
    application, device = _open(online_api)
    try:
        if _canonical(_snapshot(application, device)) != _canonical(capture_payload):
            raise ValueError("Current complete envelope differs from the persisted capture")
        low = [("stSourceReceipt.xValid", "BOOL", False)]
        _write(application, device, low)
        _wait_readback(application, device, low, system_api, require_armed=True)
        _write(application, device, values)
        _wait_readback(application, device, low + values, system_api, require_armed=True)
        if _canonical(_snapshot(application, device)) != _canonical(capture_payload):
            raise ValueError("Complete capture changed before publication; valid remains false")
        _write(application, device, [("stSourceReceipt.xValid", "BOOL", True)])
    finally:
        _dispose(application, device)
    print("SINK_RECEIPT_SUBMITTED; inspect mapper ACK and source queue in the simulation")
    return {"status": "SUBMITTED", "source_ack": "NOT_WRITTEN", "native_acceptance": "CHECK_WATCHES"}


if __name__ == "__main__":
    raise SystemExit("Import this helper inside Machine Expert Scripting Immediate; native API is not available here.")
