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
    uiSourceID : UINT;
    eCommand : E_SEQ_CMD;
    eCommandResult : E_SEQ_RESULT;
    eReason : E_SEQ_REASON;
    // Service adds transport/ingestion timestamp; no fabricated wall-clock time.
END_STRUCT
END_TYPE
