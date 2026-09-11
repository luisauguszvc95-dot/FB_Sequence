// OFFLINE ONLY. Execute once in an isolated integration test application.
// This harness exercises the actual ST adapter, not a Python model.
// Expected after native execution: xDone=TRUE, uiChecks=23, uiFailures=0.
// That result is a TARGET EXPECTATION, not a result observed by repository CI.
PROGRAM PRG_SEQ_ServiceAdapterTests
VAR
    fbAdapter : FB_SEQ_ToServiceAdapter;
    fbDefault : FB_SEQ_ToServiceAdapter;
    stCfg : ST_SEQ_SVC_CONFIG;
    stEvent : ST_SEQ_EVENT;
    stReceipt : ST_SEQ_SVC_RECEIPT;
    stNoReceipt : ST_SEQ_SVC_RECEIPT;
    axChecks : ARRAY[1..23] OF BOOL;
    xDone : BOOL;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailure : UINT;
    i : INT;
END_VAR

IF NOT xDone THEN
    // A fresh instance with all inputs omitted remains disabled/invalid.
    fbDefault();
    axChecks[1] := NOT fbDefault.xAck AND NOT fbDefault.xEnvelopeValid
        AND NOT fbDefault.xConfigValid;

    stCfg.xEnable := TRUE;
    stCfg.uiServiceContractMajor := UINT#2;
    stCfg.uiServiceContractMinor := UINT#0;
    stCfg.udiMappingRevision := UDINT#1;
    stCfg.uiExpectedMachineID := UINT#11;
    stCfg.uiExpectedProducerSourceID := UINT#21;
    stCfg.uiExpectedProcessID := UINT#31;
    stCfg.udiProducerID := UDINT#301;
    stEvent.uiContractMajor := UINT#0;
    stEvent.uiContractMinor := UINT#2;
    stEvent.uiMachineID := UINT#11;
    stEvent.uiProducerSourceID := UINT#21;
    stEvent.uiProcessID := UINT#31;
    stEvent.udiSessionID := UDINT#41;
    stEvent.udiEventID := UDINT#51;
    stEvent.uiSourceID := UINT#99;
    stEvent.udiAuthorityID := UDINT#101;
    stEvent.udiOccurrenceTickMs := UDINT#4321;
    stEvent.xOccurrenceTimeValid := TRUE;
    stEvent.eKind := E_SEQ_EVENT_KIND.StateChanged;
    stReceipt.xValid := TRUE;
    stReceipt.xFullEnvelopeOwned := TRUE;
    stReceipt.udiMappingRevision := UDINT#1;
    stReceipt.uiMachineID := UINT#11;
    stReceipt.uiProducerSourceID := UINT#21;
    stReceipt.uiProcessID := UINT#31;
    stReceipt.udiSessionID := UDINT#41;
    stReceipt.udiEventID := UDINT#51;

    // Preheld exact receipt cannot release a newly latched head.
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[2] := fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck
        AND fbAdapter.xReceiptRejected;
    axChecks[3] := NOT fbAdapter.stEnvelope.xProjectionLossless
        AND (fbAdapter.stEnvelope.stSourceEvent.udiAuthorityID = UDINT#101)
        AND (fbAdapter.stEnvelope.stServiceEvent.stHeader.uiSourceID = UINT#21)
        AND (fbAdapter.stEnvelope.stSourceEvent.uiSourceID = UINT#99)
        AND (fbAdapter.stEnvelope.stServiceEvent.stTime.udiUtcSeconds = UDINT#0)
        AND (fbAdapter.stEnvelope.stServiceEvent.stTime.udiTickMs = UDINT#4321);

    // Explicit low arms only the current head.
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[4] := fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;
    stReceipt.uiMachineID := UINT#12;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[5] := NOT fbAdapter.xAck AND fbAdapter.xReceiptRejected;
    stReceipt.uiMachineID := UINT#11;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[6] := NOT fbAdapter.xAck; // fixing a held receipt needs a new low

    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[7] := fbAdapter.xAck
        AND (fbAdapter.udiEventAckSessionID = UDINT#41)
        AND (fbAdapter.udiEventAckID = UDINT#51);
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[8] := fbAdapter.xAck AND NOT fbAdapter.xEnvelopeValid
        AND (fbAdapter.udiEventAckID = UDINT#51);

    // Simulate an ACK missed because publication was revoked before consumption.
    fbAdapter(stCfg := stCfg, xEventAvailable := FALSE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[21] := NOT fbAdapter.xAck;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[22] := fbAdapter.xAck
        AND (fbAdapter.udiEventAckID = UDINT#51);

    // New head needs its own receipt cycle, even if an exact receipt is preheld.
    stEvent.udiEventID := UDINT#52;
    stReceipt.udiEventID := UDINT#52;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[9] := fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    fbAdapter(stCfg := stCfg, xEventAvailable := FALSE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[10] := NOT fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck
        AND (fbAdapter.stEnvelope.stSourceEvent.udiEventID = UDINT#0);
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[11] := fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;

    // No full-envelope ownership => no ACK even with exact identity.
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    stReceipt.xFullEnvelopeOwned := FALSE;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[12] := NOT fbAdapter.xAck AND fbAdapter.xReceiptRejected;
    stReceipt.xFullEnvelopeOwned := TRUE;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);

    // Disable also invalidates previously armed receipt.
    stCfg.xEnable := FALSE;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[13] := NOT fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;
    stCfg.xEnable := TRUE;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[14] := NOT fbAdapter.xAck;

    // A new unowned head cannot overwrite the retained event 52.
    stEvent.udiEventID := UDINT#53;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[15] := fbAdapter.xPendingConflict
        AND NOT fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;
    stEvent.udiEventID := UDINT#52;
    stEvent.udiAuthorityID := UDINT#999; // same-key source mutation ignored
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[16] := fbAdapter.xEnvelopeValid
        AND (fbAdapter.stEnvelope.stSourceEvent.udiAuthorityID = UDINT#101);

    stCfg.udiMappingRevision := UDINT#2;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[17] := fbAdapter.xPendingConflict AND NOT fbAdapter.xAck;
    stCfg.udiMappingRevision := UDINT#1;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stReceipt);
    axChecks[18] := fbAdapter.xAck
        AND (fbAdapter.udiEventAckID = UDINT#52);

    // Unsupported target version and unconfigured source identity fail closed.
    stCfg.uiServiceContractMajor := UINT#3;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[19] := NOT fbAdapter.xConfigValid
        AND NOT fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;
    stCfg.uiServiceContractMajor := UINT#2;
    stEvent.uiProducerSourceID := UINT#0;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[20] := NOT fbAdapter.xSourceValid
        AND NOT fbAdapter.xEnvelopeValid AND NOT fbAdapter.xAck;

    stEvent.uiProducerSourceID := UINT#21;
    stEvent.udiEventID := UDINT#53;
    stEvent.xOccurrenceTimeValid := FALSE;
    fbAdapter(stCfg := stCfg, xEventAvailable := TRUE,
        stEvent := stEvent, stReceipt := stNoReceipt);
    axChecks[23] := fbAdapter.xEnvelopeValid
        AND NOT fbAdapter.stEnvelope.stServiceEvent.xValid
        AND NOT fbAdapter.stEnvelope.stSourceEvent.xOccurrenceTimeValid
        AND NOT fbAdapter.xAck;

    FOR i := 1 TO 23 DO
        uiChecks := uiChecks + UINT#1;
        IF NOT axChecks[i] THEN
            uiFailures := uiFailures + UINT#1;
            IF uiFirstFailure = UINT#0 THEN
                uiFirstFailure := INT_TO_UINT(i);
            END_IF;
        END_IF;
    END_FOR;
    xDone := TRUE;
END_IF;
END_PROGRAM
