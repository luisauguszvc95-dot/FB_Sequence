// Offline-only fixtures: no Control outputs, no physical I/O, no process Start.
// Call once per scan in an isolated simulation task. Reinitialize to run again.
// The clock values below are assertions used to exercise flags, not measured time.
PROGRAM PRG_SEQ_TraceEngineTests
VAR
    xDone : BOOL;
    uiTests : UINT;
    uiFailures : UINT;
    uiFirstFailure : UINT := UINT#65535;
    uiCase : UINT;
    xPass : BOOL;
    fbSeq : FB_Sequence;
    stCfg : ST_SEQ_CONFIG := (uiProcessID := 1, udiSessionID := 9,
        udiMaxFeedbackAgeMs := 250, udiTransitionTimeoutMs := 5000,
        udiMaxCycleMs := 100, uiMachineID := 2, uiProducerSourceID := 3);
    stClock : ST_SEQ_TRACE_TIME;
    stAuth : ST_SEQ_CONTROL_AUTHORITY;
    stCmd : ST_SEQ_COMMAND_REQUEST;
    stRecipe : ST_SEQ_RECIPE;
    udiAckSession : UDINT;
    udiAckID : UDINT;
END_VAR

IF xDone THEN RETURN; END_IF;
stAuth.xValid := TRUE;
stAuth.udiSessionID := 9;
stAuth.uiProcessID := 1;
stAuth.udiAuthorityID := 1;
stAuth.xAllowRequests := TRUE;
stAuth.xAllowExecution := FALSE;
stAuth.xAllowPublication := TRUE;
stAuth.udiAgeMs := 0;
stClock.udiTickMs := 100 + UINT_TO_UDINT(uiCase) * 10;
stClock.xValid := uiCase <> 0;
stClock.xSynthetic := FALSE;
stCmd.xValid := FALSE;
udiAckSession := 9;
udiAckID := 0;

IF uiCase = 0 THEN
    stRecipe.udiRecipeID := 1;
    stRecipe.udiRevision := 1;
    stRecipe.uiStepCount := 1;
    stRecipe.astSteps[1].uiStepID := 10;
    stRecipe.astSteps[1].uiPhaseID := 20;
    stRecipe.astSteps[1].uiProfileID := 30;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitComplete;
    stRecipe.astSteps[1].udiTimeoutMs := 1000;
    stCmd.udiSessionID := 9;
    stCmd.uiProcessID := 1;
    stCmd.uiSourceID := 4;
    stCmd.udiRequestID := 1;
    stCmd.eCommand := E_SEQ_CMD.LoadRecipe;
    stCmd.udiRecipeID := 1;
    stCmd.udiRecipeRevision := 1;
END_IF;
CASE uiCase OF
1, 10: stCmd.xValid := TRUE;
2: stClock.xSynthetic := TRUE;
3: stClock.xValid := FALSE;
4: udiAckSession := 8; udiAckID := 1;
5, 6: udiAckID := 1;
7: stAuth.xAllowPublication := FALSE; udiAckID := 2;
9: udiAckID := 2;
29: udiAckID := 3;
31: stCfg.uiMachineID := 99;
32: stCfg.uiMachineID := 2;
END_CASE;
IF (uiCase >= 11) AND (uiCase <= 27) THEN
    stCmd.xValid := TRUE;
    stCmd.udiRequestID := UINT_TO_UDINT(uiCase);
    stCmd.udiRecipeID := 99; // Rejected reference; applied recipe stays 1.
END_IF;

fbSeq(xEnable := FALSE, stConfig := stCfg, udiDeltaMs := 10,
    stTraceTime := stClock, stCommand := stCmd, stRecipeCandidate := stRecipe,
    stAuthority := stAuth, udiEventAckSessionID := udiAckSession,
    udiEventAckID := udiAckID);
xPass := TRUE;
CASE uiCase OF
0:
    xPass := NOT fbSeq.stRuntime.xTimeValid AND NOT fbSeq.stRuntime.xTraceReady
        AND fbSeq.stRuntime.xTraceHistoryComplete AND (fbSeq.stRuntime.udiRevision = 1);
1:
    xPass := fbSeq.stRuntime.xTraceReady AND (fbSeq.uiEventCount = 2)
        AND (fbSeq.stEvent.eKind = E_SEQ_EVENT_KIND.RecipeLoaded)
        AND (fbSeq.stEvent.udiOccurrenceTickMs = 110)
        AND (fbSeq.stEvent.uiMachineID = 2) AND (fbSeq.stEvent.uiProducerSourceID = 3)
        AND (fbSeq.stEvent.uiSourceID = 4) AND (fbSeq.stEvent.udiRequestedRecipeID = 1);
2:
    xPass := fbSeq.stRuntime.xSyntheticTime AND NOT fbSeq.stRuntime.xTraceReady
        AND NOT fbSeq.stEvent.xSyntheticTime AND (fbSeq.stEvent.udiOccurrenceTickMs = 110);
3:
    xPass := NOT fbSeq.stRuntime.xTraceReady AND NOT fbSeq.stRuntime.xTimeValid
        AND fbSeq.stEvent.xOccurrenceTimeValid;
4:
    xPass := (fbSeq.stEvent.udiEventID = 1) AND (fbSeq.uiEventCount = 2);
5, 6:
    xPass := (fbSeq.stEvent.udiEventID = 2) AND (fbSeq.uiEventCount = 1);
7:
    xPass := NOT fbSeq.stRuntime.xDataValid AND NOT fbSeq.xEventAvailable
        AND (fbSeq.stEvent.udiEventID = 0) AND (fbSeq.uiEventCount = 0);
8:
    xPass := (fbSeq.stEvent.udiEventID = 2) AND (fbSeq.uiEventCount = 1);
9, 10:
    xPass := NOT fbSeq.xEventAvailable AND (fbSeq.uiEventCount = 0);
28:
    xPass := (fbSeq.uiEventCount = 32) AND (fbSeq.udiEventsDropped = 2)
        AND NOT fbSeq.stRuntime.xTraceHistoryComplete AND NOT fbSeq.stRuntime.xTraceReady
        AND (fbSeq.stEvent.udiEventID = 3) AND (fbSeq.stEvent.udiOccurrenceTickMs = 210)
        AND (fbSeq.stEvent.udiRecipeID = 1) AND (fbSeq.stEvent.udiRequestedRecipeID = 99);
29, 30:
    xPass := (fbSeq.uiEventCount = 31) AND (fbSeq.udiEventsDropped = 2)
        AND NOT fbSeq.stRuntime.xTraceHistoryComplete AND NOT fbSeq.stRuntime.xTraceReady
        AND (fbSeq.stEvent.udiEventID = 4);
31:
    xPass := NOT fbSeq.stRuntime.xDataValid AND NOT fbSeq.xEventAvailable
        AND NOT fbSeq.stControlRequest.xValid;
32:
    xPass := (fbSeq.stRuntime.eState = E_SEQ_STATE.Faulted)
        AND (fbSeq.stRuntime.eReason = E_SEQ_REASON.ConfigInvalid)
        AND NOT fbSeq.stRuntime.xTraceHistoryComplete
        AND (fbSeq.uiEventCount = 32) AND (fbSeq.udiEventsDropped = 3)
        AND (fbSeq.stEvent.udiEventID = 4);
END_CASE;
IF (uiCase >= 11) AND (uiCase <= 27) THEN
    xPass := (fbSeq.stCommandResult.eResult = E_SEQ_RESULT.Rejected)
        AND (fbSeq.stRuntime.udiRecipeID = 1) AND (fbSeq.stRuntime.eState = E_SEQ_STATE.Idle);
END_IF;
uiTests := uiTests + 1;
IF NOT xPass THEN
    uiFailures := uiFailures + 1;
    IF uiFirstFailure = UINT#65535 THEN uiFirstFailure := uiCase; END_IF;
END_IF;
IF uiCase = 32 THEN xDone := TRUE; ELSE uiCase := uiCase + 1; END_IF;
END_PROGRAM
