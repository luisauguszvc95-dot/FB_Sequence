PROGRAM PRG_SEQ_ReceiptGateTests
VAR
    xDone : BOOL;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailure : UINT;
    fbGate : FB_SEQ_ServiceReceiptGate;
    stEnvelope : ST_SEQ_SVC_ENVELOPE;
    stIngress : ST_SVC_EventReceipt;
    stSink : ST_SEQ_SVC_SINK_RECEIPT;
    xAvailable : BOOL;
END_VAR
// Isolated software test. Native result remains pending.
IF NOT xDone THEN
    xAvailable := TRUE;
    stEnvelope.udiMappingRevision := UDINT#1;
    stEnvelope.stSourceEvent.uiContractMajor := UINT#0;
    stEnvelope.stSourceEvent.uiContractMinor := UINT#2;
    stEnvelope.stSourceEvent.uiMachineID := UINT#1;
    stEnvelope.stSourceEvent.uiProducerSourceID := UINT#301;
    stEnvelope.stSourceEvent.uiProcessID := UINT#7;
    stEnvelope.stSourceEvent.udiSessionID := UDINT#1001;
    stEnvelope.stSourceEvent.udiEventID := UDINT#42;
    stEnvelope.stServiceEvent.xValid := TRUE;
    stEnvelope.stServiceEvent.stHeader.xValid := TRUE;
    stEnvelope.stServiceEvent.stHeader.uiSourceID := UINT#301;
    stEnvelope.stServiceEvent.stHeader.udiSourceEpoch := UDINT#1001;
    stEnvelope.stServiceEvent.stHeader.udiSourceSeq := UDINT#42;
    stEnvelope.stServiceEvent.stContext.uiProcessID := UINT#7;
    stIngress.xValid := TRUE;
    stIngress.uiMachineID := UINT#1;
    stIngress.uiSourceID := UINT#301;
    stIngress.uiProcessID := UINT#7;
    stIngress.udiSourceEpoch := UDINT#1001;
    stIngress.udiSourceSeq := UDINT#42;
    stIngress.udiBootID := UDINT#2002;
    stIngress.udiRecordID := UDINT#65;
    stSink.stSourceReceipt.xValid := TRUE;
    stSink.stSourceReceipt.xFullEnvelopeOwned := TRUE;
    stSink.stSourceReceipt.udiMappingRevision := UDINT#1;
    stSink.stSourceReceipt.uiMachineID := UINT#1;
    stSink.stSourceReceipt.uiProducerSourceID := UINT#301;
    stSink.stSourceReceipt.uiProcessID := UINT#7;
    stSink.stSourceReceipt.udiSessionID := UDINT#1001;
    stSink.stSourceReceipt.udiEventID := UDINT#42;
    stSink.udiServiceBootID := UDINT#2002;
    stSink.udiServiceRecordID := UDINT#65;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Preheld raw receipt rejected
    uiChecks := uiChecks + UINT#1;
    IF NOT (fbGate.xRejected AND NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    stSink.stSourceReceipt.xValid := FALSE;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Raw low arms this eligible binding
    uiChecks := uiChecks + UINT#1;
    IF NOT (NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    stSink.stSourceReceipt.xValid := TRUE;
    stSink.udiServiceRecordID := UDINT#64;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Wrong Service record rejected
    uiChecks := uiChecks + UINT#1;
    IF NOT (fbGate.xRejected AND NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    stSink.udiServiceRecordID := UDINT#65;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Wrong receipt consumed arming; another low required
    uiChecks := uiChecks + UINT#1;
    IF NOT (NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    stSink.stSourceReceipt.xValid := FALSE;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    stSink.stSourceReceipt.xValid := TRUE;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Exact full ownership after low
    uiChecks := uiChecks + UINT#1;
    IF NOT (fbGate.stReceipt.xValid AND (fbGate.stReceipt.udiEventID = UDINT#42)) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    xAvailable := FALSE;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Withdrawal masks receipt
    uiChecks := uiChecks + UINT#1;
    IF NOT (NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    xAvailable := TRUE;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // First regrant scan is low to rearm mapper
    uiChecks := uiChecks + UINT#1;
    IF NOT (NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // Next scan retries previously owned binding
    uiChecks := uiChecks + UINT#1;
    IF NOT (fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    stEnvelope.stSourceEvent.udiEventID := UDINT#43;
    stEnvelope.stServiceEvent.stHeader.udiSourceSeq := UDINT#43;
    stIngress.udiSourceSeq := UDINT#43;
    stIngress.udiRecordID := UDINT#66;
    fbGate(xEnable := TRUE, xEnvelopeValid := xAvailable, stEnvelope := stEnvelope, stIngress := stIngress, stSink := stSink);
    // New head cannot inherit old ownership
    uiChecks := uiChecks + UINT#1;
    IF NOT (NOT fbGate.stReceipt.xValid) THEN
        uiFailures := uiFailures + UINT#1;
        IF uiFirstFailure = UINT#0 THEN uiFirstFailure := uiChecks; END_IF;
    END_IF;
    xDone := TRUE;
END_IF;
END_PROGRAM

