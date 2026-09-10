TYPE ST_SEQ_COMMAND_RESULT :
STRUCT
    xValid : BOOL;
    udiSessionID : UDINT;
    udiRequestID : UDINT;
    uiSourceID : UINT;
    uiProcessID : UINT;
    eCommand : E_SEQ_CMD;
    eResult : E_SEQ_RESULT; // Admission only: Accepted is NOT process completion.
    eReason : E_SEQ_REASON;
    eStateAfter : E_SEQ_STATE;
END_STRUCT
END_TYPE
