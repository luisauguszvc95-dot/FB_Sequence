FUNCTION_BLOCK FB_SEQ_ToServiceAdapter
VAR_INPUT
    stCfg : ST_SEQ_SVC_CONFIG;
    xEventAvailable : BOOL;
    stEvent : ST_SEQ_EVENT;
    stReceipt : ST_SEQ_SVC_RECEIPT;
END_VAR
VAR_OUTPUT
    xEnvelopeValid : BOOL;
    stEnvelope : ST_SEQ_SVC_ENVELOPE;
    xConfigValid : BOOL;
    xSourceValid : BOOL;
    xPendingConflict : BOOL;
    xReceiptRejected : BOOL;
    xAck : BOOL;
    udiEventAckSessionID : UDINT;
    udiEventAckID : UDINT;
END_VAR
VAR
    stLatched : ST_SEQ_SVC_ENVELOPE;
    stEmpty : ST_SEQ_SVC_ENVELOPE;
    xPending : BOOL;
    xAckIssued : BOOL;
    xReceiptArmed : BOOL;
    xSameEvent : BOOL;
    xConfigMatches : BOOL;
    xReceiptMatches : BOOL;
    eDomain : E_SVC_Domain;
    eKind : E_SVC_EventKind;
    udiLatchedProducerID : UDINT;
END_VAR

// Pure software bridge. No Control/Sequence commands, output I/O or transport.
xEnvelopeValid := FALSE;
stEnvelope := stEmpty;
xAck := FALSE;
udiEventAckSessionID := UDINT#0;
udiEventAckID := UDINT#0;
xPendingConflict := FALSE;
xReceiptRejected := FALSE;

xConfigValid :=
    (stCfg.uiServiceContractMajor = UINT#2)
    AND (stCfg.uiServiceContractMinor = UINT#0)
    AND (stCfg.udiMappingRevision <> UDINT#0)
    AND (stCfg.uiExpectedMachineID <> UINT#0)
    AND (stCfg.uiExpectedProducerSourceID <> UINT#0)
    AND (stCfg.uiExpectedProcessID <> UINT#0)
    AND (stCfg.udiProducerID <> UDINT#0);

xSourceValid := xEventAvailable
    AND (stEvent.uiContractMajor = UINT#0)
    AND (stEvent.uiContractMinor = UINT#2)
    AND (stEvent.uiMachineID = stCfg.uiExpectedMachineID)
    AND (stEvent.uiProducerSourceID = stCfg.uiExpectedProducerSourceID)
    AND (stEvent.uiProcessID = stCfg.uiExpectedProcessID)
    AND (stEvent.udiSessionID <> UDINT#0)
    AND (stEvent.udiEventID <> UDINT#0);

eDomain := E_SVC_Domain.UNDEFINED;
eKind := E_SVC_EventKind.UNDEFINED;
CASE stEvent.eKind OF
    E_SEQ_EVENT_KIND.StateChanged:
        eDomain := E_SVC_Domain.PROCESS;
        eKind := E_SVC_EventKind.STATE_TRANSITION;
    E_SEQ_EVENT_KIND.StepChanged:
        eDomain := E_SVC_Domain.PROCESS;
        eKind := E_SVC_EventKind.CONTEXT_CHANGE;
    E_SEQ_EVENT_KIND.CommandResult:
        eDomain := E_SVC_Domain.PROCESS;
        eKind := E_SVC_EventKind.INTEGRATION;
    E_SEQ_EVENT_KIND.RecipeLoaded:
        eDomain := E_SVC_Domain.RECIPE;
        eKind := E_SVC_EventKind.CONTEXT_CHANGE;
    E_SEQ_EVENT_KIND.BatchStarted, E_SEQ_EVENT_KIND.BatchFinished:
        eDomain := E_SVC_Domain.BATCH;
        eKind := E_SVC_EventKind.BATCH_TRANSITION;
    E_SEQ_EVENT_KIND.StepStarted, E_SEQ_EVENT_KIND.StepFinished,
    E_SEQ_EVENT_KIND.PromptIssued, E_SEQ_EVENT_KIND.FaultRaised,
    E_SEQ_EVENT_KIND.FaultCleared:
        eDomain := E_SVC_Domain.PROCESS;
        eKind := E_SVC_EventKind.STATE_TRANSITION;
    E_SEQ_EVENT_KIND.PromptConfirmed, E_SEQ_EVENT_KIND.ResourceAcquired,
    E_SEQ_EVENT_KIND.ResourceReleased:
        eDomain := E_SVC_Domain.PROCESS;
        eKind := E_SVC_EventKind.INTEGRATION;
    E_SEQ_EVENT_KIND.RecipeRejected:
        eDomain := E_SVC_Domain.RECIPE;
        eKind := E_SVC_EventKind.INTEGRATION;
END_CASE;
xSourceValid := xSourceValid
    AND (eDomain <> E_SVC_Domain.UNDEFINED)
    AND (eKind <> E_SVC_EventKind.UNDEFINED);

xSameEvent := xPending
    AND (stLatched.stSourceEvent.uiMachineID = stEvent.uiMachineID)
    AND (stLatched.stSourceEvent.uiProducerSourceID = stEvent.uiProducerSourceID)
    AND (stLatched.stSourceEvent.uiProcessID = stEvent.uiProcessID)
    AND (stLatched.stSourceEvent.udiSessionID = stEvent.udiSessionID)
    AND (stLatched.stSourceEvent.udiEventID = stEvent.udiEventID);

IF NOT stCfg.xEnable OR NOT xConfigValid OR NOT xSourceValid THEN
    // Permission withdrawal suppresses output and ACK; retain pending privately.
    xReceiptArmed := FALSE;
ELSE
    IF (NOT xPending) OR (xAckIssued AND NOT xSameEvent) THEN
        stLatched := stEmpty;
        stLatched.udiMappingRevision := stCfg.udiMappingRevision;
        stLatched.xProjectionLossless := FALSE;
        stLatched.stSourceEvent := stEvent;
        // Unknown origin time keeps the full sidecar but blocks this projection.
        // Otherwise Service could replace it with ingestion time on collection.
        stLatched.stServiceEvent.xValid := stEvent.xOccurrenceTimeValid;
        stLatched.stServiceEvent.stHeader.xValid := stEvent.xOccurrenceTimeValid;
        stLatched.stServiceEvent.stHeader.uiSchemaMajor := stCfg.uiServiceContractMajor;
        stLatched.stServiceEvent.stHeader.uiSchemaMinor := stCfg.uiServiceContractMinor;
        stLatched.stServiceEvent.stHeader.uiSourceID := stEvent.uiProducerSourceID;
        stLatched.stServiceEvent.stHeader.eProducerKind := E_SVC_ActorKind.SEQUENCE_SOURCE;
        stLatched.stServiceEvent.stHeader.udiProducerID := stCfg.udiProducerID;
        stLatched.stServiceEvent.stHeader.udiSourceEpoch := stEvent.udiSessionID;
        stLatched.stServiceEvent.stHeader.udiSourceSeq := stEvent.udiEventID;
        stLatched.stServiceEvent.stHeader.udiTickMs := stEvent.udiOccurrenceTickMs;
        stLatched.stServiceEvent.stHeader.eQuality := E_SVC_DataQuality.GOOD;
        IF stEvent.xSyntheticTime OR NOT stEvent.xOccurrenceTimeValid THEN
            stLatched.stServiceEvent.stHeader.eQuality := E_SVC_DataQuality.UNCERTAIN;
        END_IF;
        // Valid here means the origin supplied its monotonic time, NOT valid UTC.
        stLatched.stServiceEvent.stTime.xValid := stEvent.xOccurrenceTimeValid;
        stLatched.stServiceEvent.stTime.udiTickMs := stEvent.udiOccurrenceTickMs;
        stLatched.stServiceEvent.stTime.eQuality := E_SVC_TimeQuality.UNSYNCHRONIZED;
        // UTC, clock source and authenticated actor remain zero/unknown.
        stLatched.stServiceEvent.stContext.udiBatchID := stEvent.udiBatchID;
        stLatched.stServiceEvent.stContext.udiRecipeID := stEvent.udiRecipeID;
        stLatched.stServiceEvent.stContext.udiRecipeRevision := stEvent.udiRecipeRevision;
        stLatched.stServiceEvent.stContext.uiProcessID := stEvent.uiProcessID;
        stLatched.stServiceEvent.stContext.uiStepID := stEvent.uiStepID;
        stLatched.stServiceEvent.eDomain := eDomain;
        stLatched.stServiceEvent.eKind := eKind;
        stLatched.stServiceEvent.uiObjectID := stEvent.uiProcessID;
        stLatched.stServiceEvent.uiEventCode := TO_UINT(stEvent.eKind);
        stLatched.stServiceEvent.uiReasonID := TO_UINT(stEvent.eReason);
        stLatched.stServiceEvent.eActorKind := E_SVC_ActorKind.UNKNOWN;
        stLatched.stServiceEvent.udiCorrelationID := stEvent.udiRequestID;
        stLatched.stServiceEvent.dwOldState := TO_DWORD(stEvent.eStateBefore);
        stLatched.stServiceEvent.dwNewState := TO_DWORD(stEvent.eState);
        stLatched.stServiceEvent.diOldValue := UINT_TO_DINT(stEvent.uiStepIDBefore);
        stLatched.stServiceEvent.diNewValue := UINT_TO_DINT(stEvent.uiStepID);
        udiLatchedProducerID := stCfg.udiProducerID;
        xPending := TRUE;
        xAckIssued := FALSE;
        xReceiptArmed := FALSE;
        xSameEvent := TRUE;
    END_IF;

    xConfigMatches :=
        (stLatched.udiMappingRevision = stCfg.udiMappingRevision)
        AND (stLatched.stServiceEvent.stHeader.uiSchemaMajor = stCfg.uiServiceContractMajor)
        AND (stLatched.stServiceEvent.stHeader.uiSchemaMinor = stCfg.uiServiceContractMinor)
        AND (udiLatchedProducerID = stCfg.udiProducerID);
    xPendingConflict := NOT xSameEvent OR NOT xConfigMatches;

    IF xPendingConflict THEN
        // Never overwrite an unowned event with another source head/config.
        xReceiptArmed := FALSE;
    ELSIF xAckIssued THEN
        // Hold/retry the exact already-owned head until the source advances.
        // This survives an ACK missed at a task/publication boundary.
        xAck := TRUE;
        udiEventAckSessionID := stLatched.stSourceEvent.udiSessionID;
        udiEventAckID := stLatched.stSourceEvent.udiEventID;
    ELSIF NOT xAckIssued THEN
        stEnvelope := stLatched;
        xEnvelopeValid := TRUE;
        IF NOT stReceipt.xValid THEN
            xReceiptArmed := TRUE;
        ELSE
            xReceiptMatches := stReceipt.xFullEnvelopeOwned
                AND (stReceipt.udiMappingRevision = stLatched.udiMappingRevision)
                AND (stReceipt.uiMachineID = stLatched.stSourceEvent.uiMachineID)
                AND (stReceipt.uiProducerSourceID = stLatched.stSourceEvent.uiProducerSourceID)
                AND (stReceipt.uiProcessID = stLatched.stSourceEvent.uiProcessID)
                AND (stReceipt.udiSessionID = stLatched.stSourceEvent.udiSessionID)
                AND (stReceipt.udiEventID = stLatched.stSourceEvent.udiEventID);
            IF xReceiptArmed AND xReceiptMatches THEN
                xAck := TRUE;
                udiEventAckSessionID := stLatched.stSourceEvent.udiSessionID;
                udiEventAckID := stLatched.stSourceEvent.udiEventID;
                xAckIssued := TRUE;
            ELSE
                xReceiptRejected := TRUE;
            END_IF;
            xReceiptArmed := FALSE;
        END_IF;
    END_IF;
END_IF;
END_FUNCTION_BLOCK
