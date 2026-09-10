FUNCTION_BLOCK FB_SEQ_CommandGate
VAR_INPUT
    stRequest : ST_SEQ_COMMAND_REQUEST;
    udiSessionID : UDINT;
    uiProcessID : UINT;
END_VAR
VAR_OUTPUT
    xNew : BOOL;
    eReason : E_SEQ_REASON;
    udiLastRequestID : UDINT;
END_VAR
VAR
    xSeen : BOOL;
    udiSeenSession : UDINT;
    udiSeenRequest : UDINT;
END_VAR

// One serialized Service dispatcher per instance. Identity is immutable once sent.
// Repeated IDs never execute again. Clearing xValid does not reset the high-water mark.
xNew := FALSE;
eReason := E_SEQ_REASON.None;
IF stRequest.xValid THEN
    IF NOT xSeen OR (stRequest.udiSessionID <> udiSeenSession)
       OR (stRequest.udiRequestID <> udiSeenRequest) THEN
        xSeen := TRUE;
        udiSeenSession := stRequest.udiSessionID;
        udiSeenRequest := stRequest.udiRequestID;
        xNew := TRUE;
        IF (udiSessionID = 0) OR (stRequest.udiSessionID <> udiSessionID) THEN
            eReason := E_SEQ_REASON.SessionMismatch;
        ELSIF (stRequest.udiRequestID = 0)
           OR (stRequest.udiRequestID <= udiLastRequestID) THEN
            eReason := E_SEQ_REASON.InvalidRequest;
        ELSE
            // Consume the ID even when the semantic request will be rejected.
            udiLastRequestID := stRequest.udiRequestID;
            IF stRequest.uiProcessID <> uiProcessID THEN
                eReason := E_SEQ_REASON.WrongProcess;
            END_IF;
        END_IF;
    END_IF;
END_IF;
END_FUNCTION_BLOCK
