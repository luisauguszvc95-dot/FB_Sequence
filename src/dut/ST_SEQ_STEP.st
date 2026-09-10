TYPE ST_SEQ_STEP :
STRUCT
    uiStepID : UINT;
    uiPhaseID : UINT;
    uiProfileID : UINT; // Interpreted by the machine-specific Control IF adapter.
    eKind : E_SEQ_STEP_KIND;
    udiQualifiedMs : UDINT;
    udiTimeoutMs : UDINT; // Active step time; excludes Held, includes unqualified Running.
    rParameter1 : REAL; // Generic DEMO parameters; meaning belongs to the profile.
    rParameter2 : REAL;
END_STRUCT
END_TYPE
