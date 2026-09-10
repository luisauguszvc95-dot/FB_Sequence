TYPE ST_SEQ_COMMAND_REQUEST :
STRUCT
    xValid : BOOL; // Level held until the matching terminal command result is observed.
    udiSessionID : UDINT;
    udiRequestID : UDINT; // Single Service dispatcher: strictly increasing, no wrap in session.
    uiSourceID : UINT; // Audit identity; authorization is performed by Service.
    uiProcessID : UINT;
    eCommand : E_SEQ_CMD;
    udiBatchID : UDINT;
    udiRecipeID : UDINT;
    udiRecipeRevision : UDINT;
    uiStepID : UINT;
    udiPromptID : UDINT;
END_STRUCT
END_TYPE
