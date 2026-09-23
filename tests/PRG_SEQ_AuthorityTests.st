// OFFLINE CORRELATION REGRESSION, 8 scans. Expected TRUE,8,0,65535 for
// xDone,uiChecks,uiFailures,uiFirstFailureStep. Requires target IDE execution.
// A Release result from authority 1 cannot combine with runtime from authority 2.
PROGRAM PRG_SEQ_AuthorityTests
VAR
    fbSeq : FB_Sequence;
    fbMock : FB_SEQ_ControlMock;
    stConfig : ST_SEQ_CONFIG;
    stRecipe : ST_SEQ_RECIPE;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stAuthorityToSeq : ST_SEQ_CONTROL_AUTHORITY;
    stRuntimeToSeq : ST_SEQ_CONTROL_RUNTIME;
    udiAuthorityID : UDINT := 1;
    udiReleaseIntentBefore : UDINT;
    xAllowExecution : BOOL := TRUE;
    xFinishActions : BOOL;
    xPass : BOOL;
    uiStep : UINT;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailureStep : UINT := UINT#65535;
    xDone : BOOL;
END_VAR

IF xDone THEN RETURN; END_IF;
stCommand.xValid := FALSE;
xFinishActions := FALSE;
CASE uiStep OF
0:
    stConfig.uiProcessID := 1;
    stConfig.udiSessionID := 6001;
    stConfig.udiMaxFeedbackAgeMs := 100;
    stConfig.udiTransitionTimeoutMs := 1000;
    stConfig.udiMaxCycleMs := 100;
    stRecipe.udiRecipeID := 10;
    stRecipe.udiRevision := 1;
    stRecipe.uiStepCount := 1;
    stRecipe.astSteps[1].uiStepID := 100;
    stRecipe.astSteps[1].uiPhaseID := 1;
    stRecipe.astSteps[1].uiProfileID := 1;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitComplete;
    stRecipe.astSteps[1].udiTimeoutMs := 5000;
    stCommand.udiSessionID := stConfig.udiSessionID;
    stCommand.uiProcessID := 1;
    stCommand.uiSourceID := 1;
    stCommand.udiRecipeID := 10;
    stCommand.udiRecipeRevision := 1;
    stCommand.udiRequestID := 1;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.xValid := TRUE;
1:
    stCommand.udiBatchID := 1;
    stCommand.udiRequestID := 2;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.xValid := TRUE;
3:
    xAllowExecution := FALSE;
4:
    xFinishActions := TRUE;
5:
    udiReleaseIntentBefore := fbSeq.stControlRequest.udiIntentID;
6:
    udiAuthorityID := 2;
7:
    stCommand.udiRequestID := 3;
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
END_CASE;
fbMock(xEnable := TRUE, stRequest := fbSeq.stControlRequest,
    stConfig := stConfig, xAllowRequests := TRUE,
    xAllowExecution := xAllowExecution, xAllowPublication := TRUE,
    xQualified := FALSE, xStepComplete := FALSE,
    xFaulted := FALSE, xRejectRequest := FALSE,
    xFinishActions := xFinishActions, udiAuthorityID := udiAuthorityID);
stAuthorityToSeq := fbMock.stAuthority;
stRuntimeToSeq := fbMock.stRuntime;
IF uiStep = 5 THEN
    // All scalar freshness/BatchID/IntentID fields match, but generations differ.
    // Keep the valid old-generation Release result intact to reproduce the bug.
    stAuthorityToSeq.udiAuthorityID := 2;
    stRuntimeToSeq.udiAuthorityID := 2;
END_IF;
fbSeq(xEnable := TRUE, stConfig := stConfig, udiDeltaMs := 10,
    stCommand := stCommand, stRecipeCandidate := stRecipe,
    stAuthority := stAuthorityToSeq, stControlResult := fbMock.stResult,
    stControlRuntime := stRuntimeToSeq,
    udiEventAckSessionID := 0, udiEventAckID := 0);
xPass := FALSE;
CASE uiStep OF
0:
    xPass := fbSeq.stRuntime.xRecipeLoaded;
1:
    xPass := fbSeq.stRuntime.eState = E_SEQ_STATE.Starting;
2:
    xPass := fbSeq.stRuntime.eState = E_SEQ_STATE.Running;
3:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort);
4:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release);
5:
    xPass := fbMock.stResult.xReleased AND (fbMock.stResult.udiAuthorityID = 1)
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND fbSeq.stControlRequest.xValid
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release)
        AND (fbSeq.stControlRequest.udiAuthorityID = 2)
        AND (fbSeq.stControlRequest.udiIntentID > udiReleaseIntentBefore);
6:
    xPass := fbMock.stResult.xReleased AND (fbMock.stResult.udiAuthorityID = 2)
        AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND NOT fbSeq.stControlRequest.xValid;
7:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted);
END_CASE;
uiChecks := uiChecks + 1;
IF NOT xPass THEN
    uiFailures := uiFailures + 1;
    IF uiFirstFailureStep = UINT#65535 THEN uiFirstFailureStep := uiStep; END_IF;
END_IF;
IF uiStep >= 7 THEN xDone := TRUE;
ELSE uiStep := uiStep + 1; END_IF;
END_PROGRAM
