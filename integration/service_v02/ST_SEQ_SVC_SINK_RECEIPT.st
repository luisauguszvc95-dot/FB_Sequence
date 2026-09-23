TYPE ST_SEQ_SVC_SINK_RECEIPT :
STRUCT
    // Trusted sink owns the complete envelope AND binds it to this Service record.
    stSourceReceipt : ST_SEQ_SVC_RECEIPT;
    udiServiceBootID : UDINT;
    udiServiceRecordID : UDINT;
END_STRUCT
END_TYPE
