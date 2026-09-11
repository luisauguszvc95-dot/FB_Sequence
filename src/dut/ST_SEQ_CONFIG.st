TYPE ST_SEQ_CONFIG :
STRUCT
    uiProcessID : UINT;
    udiSessionID : UDINT; // Nonzero boot epoch; stable until the FB is reinitialized.
    udiMaxFeedbackAgeMs : UDINT;
    udiTransitionTimeoutMs : UDINT;
    udiMaxCycleMs : UDINT;
    uiMachineID : UINT; // Audit identity; zero keeps execution possible but trace not ready.
    uiProducerSourceID : UINT; // Stable producer slot, NOT command origin/operator identity.
END_STRUCT
END_TYPE
