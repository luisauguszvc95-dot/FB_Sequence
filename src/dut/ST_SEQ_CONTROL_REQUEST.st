TYPE ST_SEQ_CONTROL_REQUEST :
STRUCT
    xValid : BOOL;
    udiSessionID : UDINT;
    udiAuthorityID : UDINT;
    uiProcessID : UINT;
    udiBatchID : UDINT;
    udiIntentID : UDINT; // Changes when action/step changes; retained until superseded.
    eAction : E_SEQ_ACTION;
    uiStepID : UINT;
    uiPhaseID : UINT;
    uiProfileID : UINT;
    udiResourceToken : UDINT;
    rParameter1 : REAL;
    rParameter2 : REAL;
END_STRUCT
END_TYPE
