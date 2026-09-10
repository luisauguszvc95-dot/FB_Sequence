TYPE ST_SEQ_CONTROL_RESULT :
STRUCT
    xValid : BOOL;
    udiSessionID : UDINT;
    udiAuthorityID : UDINT;
    uiProcessID : UINT;
    udiBatchID : UDINT;
    udiIntentID : UDINT; // Must echo the current Control IF request exactly.
    udiAgeMs : UDINT; // Receiver age of this result publication.
    xAccepted : BOOL;
    xRejected : BOOL;
    uiReasonID : UINT;
    xDone : BOOL; // Requested lifecycle action finished; not just accepted.
    xReleased : BOOL; // No resources remain owned by this process/session/batch.
    xResourceGranted : BOOL;
    udiResourceToken : UDINT;
END_STRUCT
END_TYPE
