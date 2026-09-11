TYPE ST_SEQ_SVC_ENVELOPE :
STRUCT
    udiMappingRevision : UDINT;
    xProjectionLossless : BOOL;
    // Authoritative, immutable source event. Never discard this sidecar.
    stSourceEvent : ST_SEQ_EVENT;
    // Searchable generic projection; intentionally not a full audit copy.
    stServiceEvent : ST_SVC_EventInput;
END_STRUCT
END_TYPE
