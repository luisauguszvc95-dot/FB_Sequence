// OFFLINE MULTISCAN TEST POU: import with production types/FBs and ControlMock.
// Assign ONLY to a simulator/test task with no physical I/O. Every call is 10 ms
// of simulated time. Fresh non-retained instances run 28 checks in 28 calls.
// Inspect xDone, uiChecks, uiFailures, uiFirstFailureStep. Expected: TRUE,28,0,65535.
// Reinitialize the application to rerun; changing uiStep alone is insufficient.
// These are executable IDE test scenarios; their presence is not a test-run claim.
PROGRAM PRG_SEQ_IntegrationTests
VAR
    fbSeq : FB_Sequence;
    fbMock : FB_SEQ_ControlMock;
    stConfig : ST_SEQ_CONFIG;
    stRecipe : ST_SEQ_RECIPE;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stResultToSeq : ST_SEQ_CONTROL_RESULT;
    stRuntimeToSeq : ST_SEQ_CONTROL_RUNTIME;
    xMockEnable : BOOL;
    xAllowRequests : BOOL;
    xAllowExecution : BOOL;
    xAllowPublication : BOOL;
    xQualified : BOOL;
    xStepComplete : BOOL;
    xFinishActions : BOOL;
    udiAuthorityID : UDINT;
    xCorruptResultID : BOOL;
    xCorruptRuntimeID : BOOL;
    xPass : BOOL;
    uiStep : UINT;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailureStep : UINT := UINT#65535;
    xDone : BOOL;
END_VAR

IF xDone THEN RETURN; END_IF;

// Default stimuli are inert; permission changes remain in effect across scans.
stCommand.xValid := FALSE;
xQualified := FALSE;
xStepComplete := FALSE;
xFinishActions := FALSE;
xCorruptResultID := FALSE;
xCorruptRuntimeID := FALSE;

CASE uiStep OF
0: // Neither mock enable nor a Control grant exists.
    stConfig.uiProcessID := 1;
    stConfig.udiSessionID := 1001;
    stConfig.udiMaxFeedbackAgeMs := 100;
    stConfig.udiTransitionTimeoutMs := 1000;
    stConfig.udiMaxCycleMs := 100;
    stRecipe.udiRecipeID := 10;
    stRecipe.udiRevision := 1;
    stRecipe.uiStepCount := 1;
    stRecipe.astSteps[1].uiStepID := 100;
    stRecipe.astSteps[1].uiPhaseID := 1;
    stRecipe.astSteps[1].uiProfileID := 1;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitQualified;
    stRecipe.astSteps[1].udiQualifiedMs := 30;
    stRecipe.astSteps[1].udiTimeoutMs := 2000;
    stCommand.udiSessionID := stConfig.udiSessionID;
    stCommand.uiProcessID := stConfig.uiProcessID;
    stCommand.uiSourceID := 1;
    stCommand.udiRecipeID := stRecipe.udiRecipeID;
    stCommand.udiRecipeRevision := stRecipe.udiRevision;
    stCommand.udiRequestID := 1;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.xValid := TRUE;
1: // Permission bits alone cannot manufacture a nonzero Control authority.
    xMockEnable := TRUE;
    xAllowRequests := TRUE;
    xAllowExecution := TRUE;
    xAllowPublication := TRUE;
2: // A new request ID is required after the denied request.
    udiAuthorityID := 1;
    stCommand.udiRequestID := 2;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.xValid := TRUE;
3:
    stCommand.udiRequestID := 3;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.udiBatchID := 1;
    stCommand.xValid := TRUE;
4: // Acquire has completed in Control, but an unrelated ACK cannot advance.
    xCorruptResultID := TRUE;
5: // The original matching Acquire result is now admitted.
    ;
6: // A matching accepted result plus unrelated runtime is still insufficient.
    xQualified := TRUE;
    xStepComplete := TRUE;
    xCorruptRuntimeID := TRUE;
7: // First qualified observation establishes the interval boundary.
    xQualified := TRUE;
8: // An unqualified interval must not accrue qualified time.
    xQualified := FALSE;
9, 10, 11, 12:
    xQualified := TRUE;
13: // Control accepted Complete, but has not finished the physical closure.
    ;
14:
    xFinishActions := TRUE;
15: // Release is a separate transaction after closure Done.
    ;
16:
    stCommand.udiRequestID := 4;
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
17:
    stCommand.udiRequestID := 5;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.udiBatchID := 2;
    stCommand.xValid := TRUE;
18:
    ;
19: // Revoke requests and execution during the second batch.
    xAllowRequests := FALSE;
    xAllowExecution := FALSE;
20: // Restoring both permissions cannot resume the faulted batch.
    xAllowRequests := TRUE;
    xAllowExecution := TRUE;
21: // Publication permission controls every public Service envelope.
    xAllowPublication := FALSE;
22: // Requests remain permitted for closure while execution is denied.
    xAllowPublication := TRUE;
    xAllowExecution := FALSE;
23: // New Control epoch must not silently erase existing ownership.
    udiAuthorityID := 2;
24:
    xFinishActions := TRUE;
25:
    ;
26: // Reset requires the confirmed Abort then Release, not just a new grant.
    stCommand.udiRequestID := 6;
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
27: // Request permission does not imply permission to start execution.
    stCommand.udiRequestID := 7;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.udiBatchID := 3;
    stCommand.xValid := TRUE;
END_CASE;

// One scan of request/feedback latency, with fresh snapshots on every mock call.
fbMock(xEnable := xMockEnable, stRequest := fbSeq.stControlRequest,
    stConfig := stConfig, xAllowRequests := xAllowRequests,
    xAllowExecution := xAllowExecution, xAllowPublication := xAllowPublication,
    xQualified := xQualified, xStepComplete := xStepComplete,
    xFaulted := FALSE, xRejectRequest := FALSE,
    xFinishActions := xFinishActions, udiAuthorityID := udiAuthorityID);
stResultToSeq := fbMock.stResult;
stRuntimeToSeq := fbMock.stRuntime;
IF xCorruptResultID THEN
    stResultToSeq.udiIntentID := stResultToSeq.udiIntentID + 100;
END_IF;
IF xCorruptRuntimeID THEN
    stRuntimeToSeq.udiIntentID := stRuntimeToSeq.udiIntentID + 100;
END_IF;
fbSeq(xEnable := TRUE, stConfig := stConfig, udiDeltaMs := 10,
    stCommand := stCommand, stRecipeCandidate := stRecipe,
    stAuthority := fbMock.stAuthority, stControlResult := stResultToSeq,
    stControlRuntime := stRuntimeToSeq,
    udiEventAckSessionID := 0, udiEventAckID := 0);

xPass := FALSE;
CASE uiStep OF
0, 1:
    xPass := NOT fbSeq.stControlRequest.xValid
        AND NOT fbSeq.stRuntime.xDataValid AND NOT fbSeq.stCommandResult.xValid
        AND NOT fbSeq.xEventAvailable AND (fbSeq.uiEventCount = 0)
        AND (fbSeq.stRuntime.udiSessionID = 0) AND (fbSeq.stEvent.udiEventID = 0);
2:
    xPass := fbSeq.stRuntime.xDataValid AND fbSeq.stRuntime.xRecipeLoaded
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted)
        AND (fbSeq.stCommandResult.udiRequestID = 2);
3:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Starting)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Acquire)
        AND fbSeq.stControlRequest.xValid;
4:
    xPass := fbMock.stResult.xDone AND fbMock.stRuntime.xResourceGranted
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Starting)
        AND (fbSeq.stRuntime.udiResourceToken = 0)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Acquire);
5:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Execute)
        AND (fbSeq.stRuntime.udiResourceToken = 1);
6:
    xPass := fbMock.stResult.xAccepted AND NOT fbMock.stResult.xDone
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 0);
7, 8, 9:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 0);
10:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 10);
11:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 20);
12:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Completing)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Complete)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 30)
        AND fbMock.stRuntime.xResourceGranted;
13:
    xPass := fbMock.stResult.xAccepted AND NOT fbMock.stResult.xDone
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Completing)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Complete)
        AND fbMock.stRuntime.xResourceGranted;
14:
    xPass := fbMock.stResult.xDone
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Completing)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release)
        AND fbMock.stRuntime.xResourceGranted;
15:
    xPass := fbMock.stResult.xReleased AND NOT fbMock.stRuntime.xResourceGranted
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Complete)
        AND (fbSeq.stRuntime.udiResourceToken = 0)
        AND NOT fbSeq.stControlRequest.xValid;
16:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stRuntime.udiBatchID = 0)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted);
17:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Starting)
        AND (fbSeq.stRuntime.udiBatchID = 2)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Acquire);
18:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Execute)
        AND fbMock.stRuntime.xResourceGranted;
19:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stRuntime.eReason = E_SEQ_REASON.AuthorityDenied)
        AND NOT fbSeq.stControlRequest.xValid AND NOT fbMock.stResult.xValid
        AND fbMock.stRuntime.xResourceGranted;
20:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND fbSeq.stControlRequest.xValid
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort)
        AND fbMock.stRuntime.xResourceGranted;
21:
    xPass := NOT fbSeq.stRuntime.xDataValid AND NOT fbSeq.stCommandResult.xValid
        AND (fbSeq.stRuntime.udiSessionID = 0) AND (fbSeq.stRuntime.udiBatchID = 0)
        AND (fbSeq.stCommandResult.udiRequestID = 0)
        AND NOT fbSeq.xEventAvailable AND (fbSeq.stEvent.udiEventID = 0)
        AND (fbSeq.uiEventCount = 0) AND (fbSeq.udiEventsDropped = 0)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort)
        AND fbMock.stRuntime.xResourceGranted;
22:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort)
        AND fbSeq.xEventAvailable AND fbMock.stRuntime.xResourceGranted;
23:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort)
        AND (fbSeq.stControlRequest.udiAuthorityID = 2)
        AND NOT fbMock.stResult.xValid AND fbMock.stRuntime.xResourceGranted;
24:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND fbMock.stResult.xDone AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release)
        AND fbMock.stRuntime.xResourceGranted;
25:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND fbMock.stResult.xReleased AND NOT fbMock.stRuntime.xResourceGranted
        AND NOT fbSeq.stControlRequest.xValid AND (fbSeq.stRuntime.udiResourceToken = 0);
26:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted)
        AND NOT fbMock.stRuntime.xResourceGranted;
27:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Rejected)
        AND (fbSeq.stCommandResult.eReason = E_SEQ_REASON.AuthorityDenied)
        AND NOT fbSeq.stControlRequest.xValid;
END_CASE;

uiChecks := uiChecks + 1;
IF NOT xPass THEN
    IF uiFailures = 0 THEN uiFirstFailureStep := uiStep; END_IF;
    uiFailures := uiFailures + 1;
END_IF;
IF uiStep = 27 THEN xDone := TRUE;
ELSE uiStep := uiStep + 1; END_IF;
END_PROGRAM
