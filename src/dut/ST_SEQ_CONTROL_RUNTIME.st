TYPE ST_SEQ_CONTROL_RUNTIME :
STRUCT
    xValid : BOOL;
    udiSessionID : UDINT;
    udiAuthorityID : UDINT;
    uiProcessID : UINT;
    udiBatchID : UDINT;
    udiIntentID : UDINT;
    udiAgeMs : UDINT; // Receiver computes age since coherent observation, never publisher age.
    xReady : BOOL;
    xFaulted : BOOL;
    xQualified : BOOL;
    xStepComplete : BOOL;
    xResourceGranted : BOOL;
    udiResourceToken : UDINT;
    uiReasonID : UINT;
    // Read-only process projection of Control runtime; NOT a second equipment runtime.
END_STRUCT
END_TYPE
