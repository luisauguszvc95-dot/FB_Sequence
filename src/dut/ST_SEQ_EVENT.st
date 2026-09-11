TYPE ST_SEQ_EVENT :
STRUCT
    udiEventID : UDINT;
    udiSessionID : UDINT;
    udiAuthorityID : UDINT;
    uiProcessID : UINT;
    udiBatchID : UDINT;
    udiRecipeID : UDINT;
    udiRecipeRevision : UDINT;
    eKind : E_SEQ_EVENT_KIND;
    eState : E_SEQ_STATE;
    uiStepID : UINT;
    udiRequestID : UDINT;
    udiCommandSessionID : UDINT;
    uiSourceID : UINT; // Command route/origin; not producer identity or authenticated actor.
    eCommand : E_SEQ_CMD;
    eCommandResult : E_SEQ_RESULT;
    eReason : E_SEQ_REASON;
    // Immutable source provenance, schema 0.2. No UTC or authenticated actor fabricated.
    uiContractMajor : UINT;
    uiContractMinor : UINT;
    uiMachineID : UINT;
    uiProducerSourceID : UINT; // Event producer, distinct from uiSourceID (command source).
    udiOccurrenceTickMs : UDINT;
    xOccurrenceTimeValid : BOOL;
    xSyntheticTime : BOOL;
    eStateBefore : E_SEQ_STATE;
    uiStepIDBefore : UINT;
    udiBatchIDBefore : UDINT;
    udiRecipeIDBefore : UDINT;
    udiRecipeRevisionBefore : UDINT;
    uiPhaseID : UINT;
    uiProfileID : UINT;
    udiIntentID : UDINT;
    udiPromptID : UDINT;
    udiResourceTokenBefore : UDINT;
    udiResourceToken : UDINT;
    udiStepElapsedMs : UDINT;
    udiQualifiedElapsedMs : UDINT;
    udiRequestedRecipeID : UDINT;
    udiRequestedRecipeRevision : UDINT;
    udiRequestedBatchID : UDINT;
    uiRequestedStepID : UINT;
    udiRequestedPromptID : UDINT;
END_STRUCT
END_TYPE
