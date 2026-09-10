TYPE ST_SEQ_CONFIG :
STRUCT
    uiProcessID : UINT;
    udiSessionID : UDINT; // Nonzero boot epoch; stable until the FB is reinitialized.
    udiMaxFeedbackAgeMs : UDINT;
    udiTransitionTimeoutMs : UDINT;
    udiMaxCycleMs : UDINT;
END_STRUCT
END_TYPE
