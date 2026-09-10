// OFFLINE TEST DOUBLE ONLY. No I/O, equipment logic or safety function.
// Call before FB_Sequence in the same cyclic task: requests take one scan to echo.
FUNCTION_BLOCK FB_SEQ_ControlMock
VAR_INPUT
    xEnable : BOOL := FALSE;
    stRequest : ST_SEQ_CONTROL_REQUEST;
    stConfig : ST_SEQ_CONFIG;
    xAllowRequests : BOOL := FALSE;
    xAllowExecution : BOOL := FALSE;
    xAllowPublication : BOOL := FALSE;
    xQualified : BOOL := FALSE;
    xStepComplete : BOOL := FALSE;
    xFaulted : BOOL := FALSE;
    xRejectRequest : BOOL := FALSE;
    xFinishActions : BOOL := FALSE;
    udiAuthorityID : UDINT := 0;
END_VAR
VAR_OUTPUT
    stAuthority : ST_SEQ_CONTROL_AUTHORITY;
    stResult : ST_SEQ_CONTROL_RESULT;
    stRuntime : ST_SEQ_CONTROL_RUNTIME;
END_VAR
VAR
    stEmptyAuthority : ST_SEQ_CONTROL_AUTHORITY;
    stEmptyResult : ST_SEQ_CONTROL_RESULT;
    stEmptyRuntime : ST_SEQ_CONTROL_RUNTIME;
    xGrantValid : BOOL;
    xRequestMatches : BOOL;
    xOwnerMatches : BOOL;
    xOwned : BOOL;
    xClosureDone : BOOL;
    udiOwnerSession : UDINT;
    uiOwnerProcess : UINT;
    udiOwnerBatch : UDINT;
    udiToken : UDINT;
END_VAR

// Permission loss, disable and authority epoch changes NEVER release ownership.
// Reinitialize this non-retained test instance to reset the entire mock.
stAuthority := stEmptyAuthority;
stResult := stEmptyResult;
stRuntime := stEmptyRuntime;
xGrantValid := xEnable AND (stConfig.udiSessionID > 0)
    AND (stConfig.uiProcessID > 0) AND (udiAuthorityID > 0);
IF xGrantValid THEN
    stAuthority.xValid := TRUE;
    stAuthority.udiSessionID := stConfig.udiSessionID;
    stAuthority.uiProcessID := stConfig.uiProcessID;
    stAuthority.udiAuthorityID := udiAuthorityID;
    stAuthority.udiAgeMs := 0; // Freshly republished on every invocation.
    stAuthority.xAllowRequests := xAllowRequests;
    stAuthority.xAllowExecution := xAllowExecution;
    stAuthority.xAllowPublication := xAllowPublication;

    stRuntime.xValid := TRUE;
    stRuntime.udiSessionID := stConfig.udiSessionID;
    stRuntime.uiProcessID := stConfig.uiProcessID;
    stRuntime.udiAuthorityID := udiAuthorityID;
    stRuntime.udiAgeMs := 0;
    stRuntime.xReady := NOT xFaulted;
    stRuntime.xFaulted := xFaulted;
    stRuntime.udiBatchID := udiOwnerBatch;
END_IF;

xRequestMatches := xGrantValid AND xAllowRequests AND stRequest.xValid
    AND (stRequest.udiSessionID = stConfig.udiSessionID)
    AND (stRequest.uiProcessID = stConfig.uiProcessID)
    AND (stRequest.udiAuthorityID = udiAuthorityID)
    AND (stRequest.udiBatchID > 0) AND (stRequest.udiIntentID > 0);
xOwnerMatches := (stRequest.udiSessionID = udiOwnerSession)
    AND (stRequest.uiProcessID = uiOwnerProcess)
    AND (stRequest.udiBatchID = udiOwnerBatch);

IF xRequestMatches THEN
    stResult.xValid := TRUE;
    stResult.udiSessionID := stRequest.udiSessionID;
    stResult.uiProcessID := stRequest.uiProcessID;
    stResult.udiAuthorityID := stRequest.udiAuthorityID;
    stResult.udiBatchID := stRequest.udiBatchID;
    stResult.udiIntentID := stRequest.udiIntentID;
    stResult.udiAgeMs := 0;
    stRuntime.udiBatchID := stRequest.udiBatchID;
    stRuntime.udiIntentID := stRequest.udiIntentID;
    // Explicit positive handling below; unsupported requests are rejected.
    IF NOT xRejectRequest THEN
        CASE stRequest.eAction OF
        E_SEQ_ACTION.Acquire:
            IF xAllowExecution AND NOT xFaulted AND ((NOT xOwned) OR xOwnerMatches) THEN
                IF NOT xOwned THEN
                    xOwned := TRUE;
                    udiOwnerSession := stRequest.udiSessionID;
                    uiOwnerProcess := stRequest.uiProcessID;
                    udiOwnerBatch := stRequest.udiBatchID;
                    udiToken := 1;
                    xClosureDone := FALSE;
                END_IF;
                stResult.xAccepted := TRUE;
                stResult.xDone := TRUE;
            END_IF;
        E_SEQ_ACTION.Execute:
            IF xAllowExecution AND NOT xFaulted AND xOwned AND xOwnerMatches
               AND (stRequest.udiResourceToken = udiToken) THEN
                stResult.xAccepted := TRUE;
                stRuntime.xQualified := xQualified;
                stRuntime.xStepComplete := xStepComplete;
                // Acceptance never implies step completion or a lifecycle Done.
                xClosureDone := FALSE;
            END_IF;
        E_SEQ_ACTION.Hold:
            IF xOwned AND xOwnerMatches AND (stRequest.udiResourceToken = udiToken) THEN
                stResult.xAccepted := TRUE;
                stResult.xDone := xFinishActions;
                xClosureDone := FALSE; // A confirmed hold is not batch closure.
            END_IF;
        E_SEQ_ACTION.Complete, E_SEQ_ACTION.Stop, E_SEQ_ACTION.Abort:
            IF (NOT xOwned) OR xOwnerMatches THEN
                // Token zero may occur if an Acquire ACK was lost before abort.
                // Session/process/batch still identify the owned transaction.
                stResult.xAccepted := TRUE;
                stResult.xDone := xFinishActions;
                IF xFinishActions THEN
                    xClosureDone := TRUE;
                    udiOwnerSession := stRequest.udiSessionID;
                    uiOwnerProcess := stRequest.uiProcessID;
                    udiOwnerBatch := stRequest.udiBatchID;
                END_IF;
            END_IF;
        E_SEQ_ACTION.Release:
            IF xOwnerMatches AND xClosureDone THEN
                stResult.xAccepted := TRUE;
                stResult.xDone := TRUE;
                xOwned := FALSE;
                udiToken := 0;
                // Preserve closed identity for idempotent repeated Release.
                stResult.xReleased := TRUE;
            END_IF;
        END_CASE;
    END_IF;
    stResult.xRejected := NOT stResult.xAccepted;
    IF stResult.xRejected THEN stResult.uiReasonID := 1; END_IF;
    stResult.xResourceGranted := xOwned;
    stResult.udiResourceToken := udiToken;
END_IF;

IF xGrantValid THEN
    stRuntime.xResourceGranted := xOwned;
    stRuntime.udiResourceToken := udiToken;
END_IF;
END_FUNCTION_BLOCK
