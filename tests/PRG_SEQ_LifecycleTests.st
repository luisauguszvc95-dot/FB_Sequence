// OFFLINE MULTISCAN TEST ONLY: no physical I/O or task scheduling assumptions.
// Run a fresh, non-retained instance for 56 simulated scans of 10 ms each.
// Expected: xDone=TRUE, uiChecks=56, uiFailures=0, uiFirstFailureStep=65535.
// Exercises actual FB_Sequence code when run in the target IDE; NOT run here.
PROGRAM PRG_SEQ_LifecycleTests
VAR
    fbSeq : FB_Sequence;
    fbMock : FB_SEQ_ControlMock;
    stConfig : ST_SEQ_CONFIG;
    stRecipe : ST_SEQ_RECIPE;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stRuntimeToSeq : ST_SEQ_CONTROL_RUNTIME;
    xQualified : BOOL;
    xFinishActions : BOOL;
    xInjectHoldQualified : BOOL;
    xInjectNotReady : BOOL;
    xPass : BOOL;
    xSawResetBatch : BOOL;
    udiRequestID : UDINT;
    udiAck : UDINT;
    udiPrompt : UDINT;
    uiStep : UINT;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailureStep : UINT := UINT#65535;
    xDone : BOOL;
END_VAR

IF xDone THEN RETURN; END_IF;
stCommand.xValid := FALSE;
xQualified := TRUE;
xFinishActions := FALSE;
xInjectHoldQualified := FALSE;
xInjectNotReady := FALSE;

CASE uiStep OF
0:
    stConfig.uiProcessID := 1;
    stConfig.udiSessionID := 5001;
    stConfig.udiMaxFeedbackAgeMs := 100;
    stConfig.udiTransitionTimeoutMs := 30;
    stConfig.udiMaxCycleMs := 100;
    stRecipe.udiRecipeID := 10;
    stRecipe.udiRevision := 1;
    stRecipe.uiStepCount := 1;
    stRecipe.astSteps[1].uiStepID := 100;
    stRecipe.astSteps[1].uiPhaseID := 1;
    stRecipe.astSteps[1].uiProfileID := 1;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitQualified;
    stRecipe.astSteps[1].udiQualifiedMs := 100;
    stRecipe.astSteps[1].udiTimeoutMs := 5000;
    stCommand.udiSessionID := stConfig.udiSessionID;
    stCommand.uiProcessID := stConfig.uiProcessID;
    stCommand.uiSourceID := 1;
    stCommand.udiRecipeID := 10;
    stCommand.udiRecipeRevision := 1;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.xValid := TRUE;
1:
    stCommand.udiBatchID := 1;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.xValid := TRUE;
5:
    stCommand.eCommand := E_SEQ_CMD.Hold;
    stCommand.xValid := TRUE;
6:
    xFinishActions := TRUE;
7:
    xInjectHoldQualified := TRUE;
8: // Old Hold feedback must not qualify the first interval after Resume.
    xInjectHoldQualified := TRUE;
    stCommand.eCommand := E_SEQ_CMD.Resume;
    stCommand.xValid := TRUE;
9: // Changing the candidate cannot mutate the already applied recipe snapshot.
    stRecipe.udiRevision := 99;
    stRecipe.astSteps[1].udiQualifiedMs := 1;
11:
    stCommand.eCommand := E_SEQ_CMD.Stop;
    stCommand.xValid := TRUE;
13:
    xFinishActions := TRUE;
15:
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
16:
    stRecipe.udiRevision := 2;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitOperator;
    stRecipe.astSteps[1].udiQualifiedMs := 0;
    stCommand.udiRecipeRevision := 2;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.xValid := TRUE;
17:
    stCommand.udiBatchID := 2;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.xValid := TRUE;
19: // Matching/qualified feedback that is not Ready must reject confirmation.
    udiPrompt := fbSeq.stRuntime.udiPromptID;
    stCommand.uiStepID := 100;
    stCommand.udiPromptID := udiPrompt;
    stCommand.eCommand := E_SEQ_CMD.ConfirmStep;
    stCommand.xValid := TRUE;
    xInjectNotReady := TRUE;
20:
    stCommand.udiPromptID := udiPrompt + 1;
    stCommand.eCommand := E_SEQ_CMD.ConfirmStep;
    stCommand.xValid := TRUE;
26: // Running now exceeds the transition limit; new Completing starts at zero.
    stCommand.udiPromptID := udiPrompt;
    stCommand.eCommand := E_SEQ_CMD.ConfirmStep;
    stCommand.xValid := TRUE;
27:
    xFinishActions := TRUE;
29:
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
30:
    stCommand.udiBatchID := 3;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.xValid := TRUE;
32:
    stCommand.eCommand := E_SEQ_CMD.Abort;
    stCommand.xValid := TRUE;
33:
    xFinishActions := TRUE;
35:
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
36:
    stCommand.udiBatchID := 4;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.xValid := TRUE;
38:
    stCommand.eCommand := E_SEQ_CMD.Hold;
    stCommand.xValid := TRUE;
42:
    xFinishActions := TRUE;
44:
    stCommand.eCommand := E_SEQ_CMD.Reset;
    stCommand.xValid := TRUE;
END_CASE;
IF stCommand.xValid THEN
    udiRequestID := udiRequestID + 1;
    stCommand.udiRequestID := udiRequestID;
END_IF;

// Acknowledge ONLY an event actually observed in the previous published scan.
udiAck := 0;
IF fbSeq.xEventAvailable THEN
    udiAck := fbSeq.stEvent.udiEventID;
    IF (fbSeq.stEvent.eKind = E_SEQ_EVENT_KIND.CommandResult)
       AND (fbSeq.stEvent.eCommand = E_SEQ_CMD.Reset)
       AND (fbSeq.stEvent.udiBatchID = 1)
       AND (fbSeq.stEvent.eCommandResult = E_SEQ_RESULT.Accepted) THEN
        xSawResetBatch := TRUE;
    END_IF;
END_IF;
fbMock(xEnable := TRUE, stRequest := fbSeq.stControlRequest,
    stConfig := stConfig, xAllowRequests := TRUE,
    xAllowExecution := TRUE, xAllowPublication := TRUE,
    xQualified := xQualified, xStepComplete := FALSE,
    xFaulted := FALSE, xRejectRequest := FALSE,
    xFinishActions := xFinishActions, udiAuthorityID := 1);
stRuntimeToSeq := fbMock.stRuntime;
IF xInjectHoldQualified THEN stRuntimeToSeq.xQualified := TRUE; END_IF;
IF xInjectNotReady THEN stRuntimeToSeq.xReady := FALSE; END_IF;
fbSeq(xEnable := TRUE, stConfig := stConfig, udiDeltaMs := 10,
    stCommand := stCommand, stRecipeCandidate := stRecipe,
    stAuthority := fbMock.stAuthority, stControlResult := fbMock.stResult,
    stControlRuntime := stRuntimeToSeq,
    udiEventAckSessionID := stConfig.udiSessionID, udiEventAckID := udiAck);

xPass := FALSE;
CASE uiStep OF
0:
    xPass := fbSeq.stRuntime.xRecipeLoaded
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted);
1, 17, 30, 36:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Starting)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Acquire);
2, 3:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 0);
4:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 10);
5:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Holding)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 10);
6, 7:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Held)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 10);
8, 9:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 10)
        AND (fbSeq.stRuntime.udiRecipeRevision = 1);
10:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stRuntime.udiQualifiedElapsedMs = 20);
11, 12:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Stopping)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Stop);
13:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Stopping)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release);
14:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Stopped)
        AND NOT fbSeq.stControlRequest.xValid;
15, 29, 35, 44:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.stRuntime.udiBatchID = 0)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Accepted);
16:
    xPass := fbSeq.stRuntime.xRecipeLoaded AND (fbSeq.stRuntime.udiRecipeRevision = 2);
18, 21, 22, 23, 24, 25, 31, 37:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND fbSeq.stRuntime.xWaitingOperator AND (fbSeq.stRuntime.udiPromptID > 0);
19, 20:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Running)
        AND (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Rejected)
        AND (fbSeq.stCommandResult.eReason = E_SEQ_REASON.InvalidConfirm);
26:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Completing)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Complete)
        AND (fbSeq.stRuntime.udiStateElapsedMs = 0)
        AND (fbSeq.stRuntime.eReason = E_SEQ_REASON.None);
27:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Completing)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release);
28:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Complete)
        AND NOT fbSeq.stControlRequest.xValid;
32:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Aborting)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort);
33:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Aborting)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release);
34:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Aborted)
        AND NOT fbSeq.stControlRequest.xValid;
38, 39, 40:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Holding)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Hold);
41:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stRuntime.eReason = E_SEQ_REASON.TransitionTimeout)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Abort);
42:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stControlRequest.eAction = E_SEQ_ACTION.Release);
43:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND NOT fbSeq.stControlRequest.xValid
        AND NOT fbMock.stRuntime.xResourceGranted;
ELSE
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle)
        AND (fbSeq.udiEventsDropped = 0);
END_CASE;
IF uiStep = 55 THEN
    xPass := xPass AND xSawResetBatch AND NOT fbSeq.xEventAvailable;
END_IF;
uiChecks := uiChecks + 1;
IF NOT xPass THEN
    uiFailures := uiFailures + 1;
    IF uiFirstFailureStep = UINT#65535 THEN uiFirstFailureStep := uiStep; END_IF;
END_IF;
IF uiStep >= 55 THEN xDone := TRUE;
ELSE uiStep := uiStep + 1; END_IF;
END_PROGRAM
