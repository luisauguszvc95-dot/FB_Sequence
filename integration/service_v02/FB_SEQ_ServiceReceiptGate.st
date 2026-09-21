FUNCTION_BLOCK FB_SEQ_ServiceReceiptGate
VAR_INPUT
    xEnable : BOOL;
    xEnvelopeValid : BOOL;
    stEnvelope : ST_SEQ_SVC_ENVELOPE;
    stIngress : ST_SVC_EventReceipt;
    stSink : ST_SEQ_SVC_SINK_RECEIPT;
END_VAR
VAR_OUTPUT
    stReceipt : ST_SEQ_SVC_RECEIPT;
    xEligible : BOOL;
    xRejected : BOOL;
END_VAR
VAR
    stEmpty : ST_SEQ_SVC_RECEIPT;
    stOwnedReceipt : ST_SEQ_SVC_RECEIPT;
    stBoundIngress : ST_SVC_EventReceipt;
    udiBoundMapping : UDINT;
    xBound : BOOL;
    xArmed : BOOL;
    xOwned : BOOL;
    xSame : BOOL;
    xMatches : BOOL;
    xWasEligible : BOOL;
    xResume : BOOL;
END_VAR

// Optional receipt join; never sends commands, writes GVLs or removes either queue.
stReceipt := stEmpty;
xRejected := FALSE;
xEligible := xEnable AND xEnvelopeValid
    AND stEnvelope.stServiceEvent.xValid
    AND stEnvelope.stServiceEvent.stHeader.xValid
    AND (stEnvelope.udiMappingRevision <> UDINT#0)
    AND (stEnvelope.stSourceEvent.uiContractMajor = UINT#0)
    AND (stEnvelope.stSourceEvent.uiContractMinor = UINT#2)
    AND (stEnvelope.stSourceEvent.uiMachineID <> UINT#0)
    AND (stEnvelope.stSourceEvent.uiProducerSourceID <> UINT#0)
    AND (stEnvelope.stSourceEvent.uiProcessID <> UINT#0)
    AND (stEnvelope.stSourceEvent.udiSessionID <> UDINT#0)
    AND (stEnvelope.stSourceEvent.udiEventID <> UDINT#0)
    AND stIngress.xValid
    AND (stIngress.udiBootID <> UDINT#0)
    AND (stIngress.udiRecordID <> UDINT#0)
    AND (stIngress.uiMachineID = stEnvelope.stSourceEvent.uiMachineID)
    AND (stIngress.uiSourceID = stEnvelope.stSourceEvent.uiProducerSourceID)
    AND (stIngress.uiProcessID = stEnvelope.stSourceEvent.uiProcessID)
    AND (stIngress.udiSourceEpoch = stEnvelope.stSourceEvent.udiSessionID)
    AND (stIngress.udiSourceSeq = stEnvelope.stSourceEvent.udiEventID)
    AND (stIngress.uiSourceID = stEnvelope.stServiceEvent.stHeader.uiSourceID)
    AND (stIngress.uiProcessID = stEnvelope.stServiceEvent.stContext.uiProcessID)
    AND (stIngress.udiSourceEpoch = stEnvelope.stServiceEvent.stHeader.udiSourceEpoch)
    AND (stIngress.udiSourceSeq = stEnvelope.stServiceEvent.stHeader.udiSourceSeq);
xResume := xEligible AND NOT xWasEligible;
xWasEligible := xEligible;

IF NOT xEligible THEN
    // A masked output is NOT a low edge at the raw sink receipt input.
    xArmed := FALSE;
ELSE
    xSame := xBound
        AND (udiBoundMapping = stEnvelope.udiMappingRevision)
        AND (stBoundIngress.uiMachineID = stIngress.uiMachineID)
        AND (stBoundIngress.uiSourceID = stIngress.uiSourceID)
        AND (stBoundIngress.uiProcessID = stIngress.uiProcessID)
        AND (stBoundIngress.udiSourceEpoch = stIngress.udiSourceEpoch)
        AND (stBoundIngress.udiSourceSeq = stIngress.udiSourceSeq)
        AND (stBoundIngress.udiBootID = stIngress.udiBootID)
        AND (stBoundIngress.udiRecordID = stIngress.udiRecordID);
    IF NOT xSame THEN
        stBoundIngress := stIngress;
        udiBoundMapping := stEnvelope.udiMappingRevision;
        xBound := TRUE;
        xArmed := FALSE;
        xOwned := FALSE;
    END_IF;

    IF xOwned THEN
        // One low scan after regrant rearms a mapper that missed our prior receipt.
        // Ownership remains retained; do not invent a new sink transaction.
        IF NOT xResume THEN
            stReceipt := stOwnedReceipt;
        END_IF;
    ELSIF NOT stSink.stSourceReceipt.xValid THEN
        xArmed := TRUE;
    ELSE
        xMatches := stSink.stSourceReceipt.xFullEnvelopeOwned
            AND (stSink.udiServiceBootID = stBoundIngress.udiBootID)
            AND (stSink.udiServiceRecordID = stBoundIngress.udiRecordID)
            AND (stSink.stSourceReceipt.udiMappingRevision = udiBoundMapping)
            AND (stSink.stSourceReceipt.uiMachineID = stBoundIngress.uiMachineID)
            AND (stSink.stSourceReceipt.uiProducerSourceID = stBoundIngress.uiSourceID)
            AND (stSink.stSourceReceipt.uiProcessID = stBoundIngress.uiProcessID)
            AND (stSink.stSourceReceipt.udiSessionID = stBoundIngress.udiSourceEpoch)
            AND (stSink.stSourceReceipt.udiEventID = stBoundIngress.udiSourceSeq);
        IF xArmed AND xMatches THEN
            stOwnedReceipt := stSink.stSourceReceipt;
            xOwned := TRUE;
            stReceipt := stOwnedReceipt;
        ELSE
            xRejected := TRUE;
        END_IF;
        xArmed := FALSE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK
