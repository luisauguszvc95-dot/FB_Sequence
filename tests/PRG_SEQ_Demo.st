PROGRAM PRG_SEQ_Demo
VAR
    // Offline-only sandbox. Both mock and Sequence begin disabled.
    xControlMockEnabled : BOOL := FALSE;
    xSequenceEnabled : BOOL := FALSE;
    xAllowRequests : BOOL := FALSE;
    xAllowExecution : BOOL := FALSE;
    xAllowPublication : BOOL := FALSE;
    xQualified : BOOL := FALSE;
    xStepComplete : BOOL := FALSE;
    xFaulted : BOOL := FALSE;
    xRejectRequest : BOOL := FALSE;
    xFinishActions : BOOL := FALSE;
    udiAuthorityID : UDINT := 1;
    stConfig : ST_SEQ_CONFIG := (uiProcessID := 1, udiSessionID := 1,
        udiMaxFeedbackAgeMs := 250, udiTransitionTimeoutMs := 5000, udiMaxCycleMs := 100,
        uiMachineID := 1, uiProducerSourceID := 1);
    stTraceTime : ST_SEQ_TRACE_TIME; // Offline virtual clock; never UTC or measured target time.
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stRecipe : ST_SEQ_RECIPE;
    udiAckSessionID : UDINT;
    udiAckEventID : UDINT;
    fbControlMock : FB_SEQ_ControlMock;
    fbSequence : FB_Sequence;
    xInitialized : BOOL;
END_VAR

IF NOT xInitialized THEN
    xInitialized := TRUE;
    stRecipe.udiRecipeID := 1;
    stRecipe.udiRevision := 1;
    stRecipe.uiStepCount := 3;
    stRecipe.astSteps[1].uiStepID := 10;
    stRecipe.astSteps[1].uiPhaseID := 10;
    stRecipe.astSteps[1].uiProfileID := 100;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitQualified;
    stRecipe.astSteps[1].udiQualifiedMs := 250;
    stRecipe.astSteps[1].udiTimeoutMs := 10000;
    stRecipe.astSteps[2].uiStepID := 20;
    stRecipe.astSteps[2].uiPhaseID := 20;
    stRecipe.astSteps[2].uiProfileID := 200;
    stRecipe.astSteps[2].eKind := E_SEQ_STEP_KIND.WaitComplete;
    stRecipe.astSteps[2].udiTimeoutMs := 10000;
    stRecipe.astSteps[3].uiStepID := 30;
    stRecipe.astSteps[3].uiPhaseID := 30;
    stRecipe.astSteps[3].uiProfileID := 300;
    stRecipe.astSteps[3].eKind := E_SEQ_STEP_KIND.WaitOperator;
    stRecipe.astSteps[3].udiTimeoutMs := 10000;
END_IF;

// One task, one call per scan, previous request consumed by mock on next scan.
stTraceTime.udiTickMs := F_SEQ_AddMs(stTraceTime.udiTickMs, 20);
stTraceTime.xValid := stTraceTime.udiTickMs < UDINT#4294967295;
stTraceTime.xSynthetic := TRUE;
fbControlMock(xEnable := xControlMockEnabled, stRequest := fbSequence.stControlRequest,
    stConfig := stConfig, xAllowRequests := xAllowRequests, xAllowExecution := xAllowExecution,
    xAllowPublication := xAllowPublication, xQualified := xQualified,
    xStepComplete := xStepComplete, xFaulted := xFaulted, xRejectRequest := xRejectRequest,
    xFinishActions := xFinishActions, udiAuthorityID := udiAuthorityID);
fbSequence(xEnable := xSequenceEnabled, stConfig := stConfig, udiDeltaMs := 20,
    stTraceTime := stTraceTime,
    stCommand := stCommand, stRecipeCandidate := stRecipe,
    stAuthority := fbControlMock.stAuthority, stControlResult := fbControlMock.stResult,
    stControlRuntime := fbControlMock.stRuntime,
    udiEventAckSessionID := udiAckSessionID, udiEventAckID := udiAckEventID);
// 20 ms here is synthetic simulation time, not a claim of measured target timing.
END_PROGRAM
