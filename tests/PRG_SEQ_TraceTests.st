// OFFLINE EVENT-BUILDER FIXTURES ONLY. No Service, transport or physical I/O.
// Run cyclically in the simulator. Expected xDone/uiChecks/uiFailures/
// uiFirstFailureStep = TRUE/16/0/65535 after 16 scans. Native run is required;
// a static source check does not establish that these assertions have passed.
PROGRAM PRG_SEQ_TraceTests
VAR
    fbBuilder : FB_SEQ_EventBuilder;
    stBefore : ST_SEQ_RUNTIME;
    stAfter : ST_SEQ_RUNTIME;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stResult : ST_SEQ_COMMAND_RESULT;
    stEmptyRuntime : ST_SEQ_RUNTIME;
    stEmptyCommand : ST_SEQ_COMMAND_REQUEST;
    stEmptyResult : ST_SEQ_COMMAND_RESULT;
    xCommandNew : BOOL;
    xRecipeLoaded : BOOL;
    xStepCompleted : BOOL;
    xConfirmed : BOOL;
    xPass : BOOL;
    i : UINT;
    uiStep : UINT;
    uiChecks : UINT;
    uiFailures : UINT;
    uiFirstFailureStep : UINT := UINT#65535;
    xDone : BOOL;
END_VAR

IF xDone THEN RETURN; END_IF;
// Each fixture is independent, but the same builder instance is reused to
// detect stale outputs. DataValid remains FALSE: inputs are internal snapshots.
stBefore := stEmptyRuntime;
stBefore.uiMachineID := 2;
stBefore.uiProducerSourceID := 31;
stBefore.uiProcessID := 4;
stBefore.udiSessionID := 9001;
stBefore.udiAuthorityID := 6;
stBefore.udiRecipeID := 17;
stBefore.udiRecipeRevision := 3;
stBefore.udiBatchID := 81;
stBefore.eState := E_SEQ_STATE.Running;
stBefore.uiStepID := 100;
stBefore.uiPhaseID := 10;
stBefore.uiProfileID := 20;
stBefore.udiLastControlIntentID := 301;
stBefore.udiTickMs := 240;
stBefore.xTimeValid := TRUE;
stBefore.xSyntheticTime := TRUE;
stAfter := stBefore;
stAfter.udiTickMs := 250;
stAfter.udiLastControlIntentID := 302;
stCommand := stEmptyCommand;
stCommand.udiSessionID := 9001;
stCommand.udiRequestID := 25;
stCommand.uiSourceID := 7;
stCommand.uiProcessID := 4;
stResult := stEmptyResult;
stResult.udiSessionID := 9001;
stResult.udiRequestID := 25;
stResult.uiSourceID := 7;
stResult.uiProcessID := 4;
xCommandNew := FALSE;
xRecipeLoaded := FALSE;
xStepCompleted := FALSE;
xConfirmed := FALSE;

CASE uiStep OF
0, 14:
    // Quiet Idle before/after, including after a nonempty event-producing scan.
    stBefore.eState := E_SEQ_STATE.Idle;
    stAfter := stBefore;
1:
    // Reset clears runtime identity but must retain the prior lot in the facts.
    stBefore.eState := E_SEQ_STATE.Faulted;
    stBefore.eReason := E_SEQ_REASON.StepTimeout;
    stAfter.eState := E_SEQ_STATE.Idle;
    stAfter.uiStepID := 0;
    stAfter.udiBatchID := 0;
2:
    // Reject candidate 999; do not report it as the already applied recipe 17.
    xCommandNew := TRUE;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.udiRecipeID := 999;
    stCommand.udiRecipeRevision := 5;
    stResult.xValid := TRUE;
    stResult.eCommand := E_SEQ_CMD.LoadRecipe;
    stResult.eResult := E_SEQ_RESULT.Rejected;
    stResult.eReason := E_SEQ_REASON.InvalidRecipeRef;
    stAfter.xTimeValid := FALSE;
3:
    // Timing arguments include the completion scan before the core resets them.
    stBefore.udiPromptID := 54;
    stAfter.uiStepID := 200;
    stAfter.uiPhaseID := 11;
    stAfter.uiProfileID := 21;
    stAfter.udiStepElapsedMs := 0;
    stAfter.udiQualifiedElapsedMs := 0;
    xStepCompleted := TRUE;
4:
    // A fault is not a successful/aborted/stopped batch terminal outcome.
    stAfter.eState := E_SEQ_STATE.Faulted;
    stAfter.eReason := E_SEQ_REASON.ResourceLost;
5:
    stBefore.eState := E_SEQ_STATE.Starting;
    stAfter.udiResourceToken := 77;
6:
    // Resume keeps PromptID: no repeated PromptIssued or StepStarted.
    stBefore.eState := E_SEQ_STATE.Held;
    stBefore.udiPromptID := 55;
    stBefore.xWaitingOperator := FALSE;
    stAfter.udiPromptID := 55;
    stAfter.xWaitingOperator := TRUE;
7:
    stBefore.udiPromptID := 54;
    stAfter.udiPromptID := 55;
    stAfter.xWaitingOperator := TRUE;
8:
    stBefore.udiPromptID := 55;
    stBefore.xWaitingOperator := TRUE;
    stAfter.udiPromptID := 0;
    stAfter.uiStepID := 200;
    stAfter.uiPhaseID := 11;
    stAfter.uiProfileID := 21;
    xCommandNew := TRUE;
    xConfirmed := TRUE;
    xStepCompleted := TRUE;
    stCommand.eCommand := E_SEQ_CMD.ConfirmStep;
    stCommand.udiPromptID := 55;
    stCommand.uiStepID := 100;
    stResult.xValid := TRUE;
    stResult.eCommand := E_SEQ_CMD.ConfirmStep;
    stResult.eResult := E_SEQ_RESULT.Accepted;
9:
    stBefore.eState := E_SEQ_STATE.Completing;
    stBefore.udiResourceToken := 77;
    stAfter.eState := E_SEQ_STATE.Complete;
10:
    stBefore.eState := E_SEQ_STATE.Stopping;
    stAfter.eState := E_SEQ_STATE.Stopped;
11:
    stBefore.eState := E_SEQ_STATE.Aborting;
    stAfter.eState := E_SEQ_STATE.Aborted;
12:
    stBefore.eState := E_SEQ_STATE.Idle;
    stBefore.udiRecipeID := 0;
    stBefore.udiRecipeRevision := 0;
    stAfter.eState := E_SEQ_STATE.Idle;
    stAfter.xRecipeLoaded := TRUE;
    xRecipeLoaded := TRUE;
    xCommandNew := TRUE;
    stCommand.eCommand := E_SEQ_CMD.LoadRecipe;
    stCommand.udiRecipeID := 17;
    stCommand.udiRecipeRevision := 3;
    stResult.xValid := TRUE;
    stResult.eCommand := E_SEQ_CMD.LoadRecipe;
    stResult.eResult := E_SEQ_RESULT.Accepted;
13:
    stBefore.eState := E_SEQ_STATE.Idle;
    stBefore.udiBatchID := 0;
    stBefore.uiStepID := 0;
    stAfter.eState := E_SEQ_STATE.Starting;
    xCommandNew := TRUE;
    stCommand.eCommand := E_SEQ_CMD.Start;
    stCommand.udiBatchID := 81;
    stResult.xValid := TRUE;
    stResult.eCommand := E_SEQ_CMD.Start;
    stResult.eResult := E_SEQ_RESULT.Accepted;
15:
    // Replacement token records both identities, not just the new token.
    stBefore.udiResourceToken := 77;
    stAfter.udiResourceToken := 78;
    stAfter.udiAuthorityID := 7;
END_CASE;

fbBuilder(stBefore := stBefore, stAfter := stAfter,
    stCommand := stCommand, stResult := stResult,
    xCommandNew := xCommandNew, xRecipeLoaded := xRecipeLoaded,
    xStepCompleted := xStepCompleted, xConfirmed := xConfirmed,
    udiCompletedStepElapsedMs := 1010, udiCompletedQualifiedMs := 800);

xPass := FALSE;
CASE uiStep OF
0, 14:
    xPass := fbBuilder.uiCount = 0;
    FOR i := 1 TO 16 DO
        xPass := xPass AND (fbBuilder.astEvents[i].udiSessionID = 0)
            AND (fbBuilder.astEvents[i].udiRequestID = 0)
            AND (fbBuilder.astEvents[i].udiBatchID = 0);
    END_FOR;
1:
    xPass := (fbBuilder.uiCount = 3)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.StateChanged)
        AND (fbBuilder.astEvents[1].eStateBefore = E_SEQ_STATE.Faulted)
        AND (fbBuilder.astEvents[1].eState = E_SEQ_STATE.Idle)
        AND (fbBuilder.astEvents[1].udiBatchID = 81)
        AND (fbBuilder.astEvents[1].udiBatchIDBefore = 81)
        AND (fbBuilder.astEvents[1].uiStepIDBefore = 100)
        AND (fbBuilder.astEvents[1].udiRecipeIDBefore = 17)
        AND (fbBuilder.astEvents[3].eKind = E_SEQ_EVENT_KIND.FaultCleared)
        AND (fbBuilder.astEvents[3].eReason = E_SEQ_REASON.StepTimeout);
2:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.CommandResult)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.RecipeRejected)
        AND (fbBuilder.astEvents[2].udiRecipeID = 17)
        AND (fbBuilder.astEvents[2].udiRequestedRecipeID = 999)
        AND (fbBuilder.astEvents[2].udiRequestedRecipeRevision = 5)
        AND (fbBuilder.astEvents[2].udiRequestID = 25)
        AND (fbBuilder.astEvents[2].uiSourceID = 7)
        AND (fbBuilder.astEvents[2].uiProducerSourceID = 31)
        AND (fbBuilder.astEvents[2].udiOccurrenceTickMs = 250)
        AND NOT fbBuilder.astEvents[2].xOccurrenceTimeValid
        AND fbBuilder.astEvents[2].xSyntheticTime;
3:
    xPass := (fbBuilder.uiCount = 3)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.StepChanged)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.StepFinished)
        AND (fbBuilder.astEvents[2].uiStepID = 100)
        AND (fbBuilder.astEvents[2].uiPhaseID = 10)
        AND (fbBuilder.astEvents[2].uiProfileID = 20)
        AND (fbBuilder.astEvents[2].udiIntentID = 301)
        AND (fbBuilder.astEvents[2].udiPromptID = 54)
        AND (fbBuilder.astEvents[2].udiStepElapsedMs = 1010)
        AND (fbBuilder.astEvents[2].udiQualifiedElapsedMs = 800)
        AND (fbBuilder.astEvents[3].eKind = E_SEQ_EVENT_KIND.StepStarted)
        AND (fbBuilder.astEvents[3].uiStepID = 200)
        AND (fbBuilder.astEvents[3].udiIntentID = 302);
4:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.StateChanged)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.FaultRaised)
        AND (fbBuilder.astEvents[2].eReason = E_SEQ_REASON.ResourceLost);
5:
    xPass := (fbBuilder.uiCount = 3)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.StepStarted)
        AND (fbBuilder.astEvents[3].eKind = E_SEQ_EVENT_KIND.ResourceAcquired)
        AND (fbBuilder.astEvents[3].udiIntentID = 301)
        AND (fbBuilder.astEvents[3].udiResourceToken = 77)
        AND (fbBuilder.astEvents[3].udiResourceTokenBefore = 0);
6:
    xPass := (fbBuilder.uiCount = 1)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.StateChanged);
7:
    xPass := (fbBuilder.uiCount = 1)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.PromptIssued)
        AND (fbBuilder.astEvents[1].udiPromptID = 55);
8:
    xPass := (fbBuilder.uiCount = 5)
        AND (fbBuilder.astEvents[5].eKind = E_SEQ_EVENT_KIND.PromptConfirmed)
        AND (fbBuilder.astEvents[5].udiPromptID = 55)
        AND (fbBuilder.astEvents[5].udiRequestedPromptID = 55)
        AND (fbBuilder.astEvents[5].uiRequestedStepID = 100)
        AND (fbBuilder.astEvents[5].uiStepID = 100)
        AND (fbBuilder.astEvents[5].uiPhaseID = 10)
        AND (fbBuilder.astEvents[5].uiProfileID = 20)
        AND (fbBuilder.astEvents[5].udiIntentID = 301)
        AND (fbBuilder.astEvents[5].udiStepElapsedMs = 1010)
        AND (fbBuilder.astEvents[5].udiQualifiedElapsedMs = 800);
9:
    xPass := (fbBuilder.uiCount = 3)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.BatchFinished)
        AND (fbBuilder.astEvents[2].eState = E_SEQ_STATE.Complete)
        AND (fbBuilder.astEvents[3].eKind = E_SEQ_EVENT_KIND.ResourceReleased)
        AND (fbBuilder.astEvents[3].udiIntentID = 301)
        AND (fbBuilder.astEvents[3].udiResourceToken = 77);
10:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.BatchFinished)
        AND (fbBuilder.astEvents[2].eState = E_SEQ_STATE.Stopped);
11:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.BatchFinished)
        AND (fbBuilder.astEvents[2].eState = E_SEQ_STATE.Aborted);
12:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.RecipeLoaded)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.CommandResult)
        AND (fbBuilder.astEvents[1].udiRecipeID = 17)
        AND (fbBuilder.astEvents[1].udiRecipeIDBefore = 0)
        AND (fbBuilder.astEvents[1].udiRequestID = 25);
13:
    xPass := (fbBuilder.uiCount = 4)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.StateChanged)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.StepChanged)
        AND (fbBuilder.astEvents[3].eKind = E_SEQ_EVENT_KIND.CommandResult)
        AND (fbBuilder.astEvents[4].eKind = E_SEQ_EVENT_KIND.BatchStarted)
        AND (fbBuilder.astEvents[4].eState = E_SEQ_STATE.Starting)
        AND (fbBuilder.astEvents[4].udiRequestedBatchID = 81);
15:
    xPass := (fbBuilder.uiCount = 2)
        AND (fbBuilder.astEvents[1].eKind = E_SEQ_EVENT_KIND.ResourceReleased)
        AND (fbBuilder.astEvents[1].udiResourceToken = 77)
        AND (fbBuilder.astEvents[1].udiAuthorityID = 6)
        AND (fbBuilder.astEvents[1].udiIntentID = 301)
        AND (fbBuilder.astEvents[2].eKind = E_SEQ_EVENT_KIND.ResourceAcquired)
        AND (fbBuilder.astEvents[2].udiResourceToken = 78)
        AND (fbBuilder.astEvents[2].udiAuthorityID = 7)
        AND (fbBuilder.astEvents[2].udiIntentID = 301);
END_CASE;
// Every emitted fact has source metadata, no fabricated wall-clock/EventID.
FOR i := 1 TO fbBuilder.uiCount DO
    xPass := xPass AND (fbBuilder.astEvents[i].udiEventID = 0)
        AND (fbBuilder.astEvents[i].uiContractMinor = 2)
        AND (fbBuilder.astEvents[i].uiMachineID = 2)
        AND (fbBuilder.astEvents[i].udiSessionID = 9001);
END_FOR;
uiChecks := uiChecks + 1;
IF NOT xPass THEN
    uiFailures := uiFailures + 1;
    IF uiFirstFailureStep = UINT#65535 THEN uiFirstFailureStep := uiStep; END_IF;
END_IF;
IF uiStep >= 15 THEN xDone := TRUE;
ELSE uiStep := uiStep + 1; END_IF;
END_PROGRAM
