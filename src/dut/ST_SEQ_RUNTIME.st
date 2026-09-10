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
END_STRUCT
END_TYPE
