TYPE ST_SEQ_CONTROL_AUTHORITY :
STRUCT
    xValid : BOOL;
    udiSessionID : UDINT;
    uiProcessID : UINT;
    udiAuthorityID : UDINT; // Control-issued nonzero grant generation; never reused in session.
    udiAgeMs : UDINT; // Receiver age, based on new Control publications.
    xAllowRequests : BOOL;
    xAllowExecution : BOOL;
    xAllowPublication : BOOL;
END_STRUCT
END_TYPE
