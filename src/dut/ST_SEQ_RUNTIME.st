TYPE ST_SEQ_RUNTIME :
STRUCT
    xDataValid : BOOL;
    uiContractMajor : UINT;
    uiContractMinor : UINT;
    uiProcessID : UINT;
    udiSessionID : UDINT;
    udiAuthorityID : UDINT;
    eState : E_SEQ_STATE;
    eReason : E_SEQ_REASON;
    xRecipeLoaded : BOOL;
    udiRecipeID : UDINT;
    udiRecipeRevision : UDINT;
    udiBatchID : UDINT;
    uiStepIndex : UINT;
    uiStepCount : UINT;
    uiStepID : UINT;
    uiPhaseID : UINT;
    udiStepElapsedMs : UDINT;
    udiQualifiedElapsedMs : UDINT;
    udiStateElapsedMs : UDINT;
    xWaitingOperator : BOOL;
    udiPromptID : UDINT;
    udiResourceToken : UDINT;
    udiLastControlIntentID : UDINT;
    uiControlReasonID : UINT;
    uiMachineID : UINT;
    uiProducerSourceID : UINT;
    uiProfileID : UINT;
    udiRevision : UDINT; // Monotonic publication generation; saturates, never silently wraps.
    udiTickMs : UDINT;
    xTimeValid : BOOL;
    xSyntheticTime : BOOL;
    xTraceReady : BOOL; // Provenance identity + non-synthetic valid time; NOT durable delivery.
    xTraceHistoryComplete : BOOL; // No locally known loss in this boot. Not end-to-end proof.
END_STRUCT
END_TYPE
