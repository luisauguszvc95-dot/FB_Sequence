// Same-scan audit facts only. No queue, clock, authentication or process control.
// Event IDs are assigned by FB_SEQ_EventQueue, never by this builder.
// The two runtime arguments are coherent internal snapshots of one Sequence scan.
FUNCTION_BLOCK FB_SEQ_EventBuilder
VAR_INPUT
    stBefore : ST_SEQ_RUNTIME;
    stAfter : ST_SEQ_RUNTIME;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stResult : ST_SEQ_COMMAND_RESULT;
    xCommandNew : BOOL;
    xRecipeLoaded : BOOL;
    xStepCompleted : BOOL;
    xConfirmed : BOOL;
    udiCompletedStepElapsedMs : UDINT;
    udiCompletedQualifiedMs : UDINT;
END_VAR
VAR_OUTPUT
    astEvents : ARRAY[1..16] OF ST_SEQ_EVENT;
    uiCount : UINT;
END_VAR
VAR
    stEmpty : ST_SEQ_EVENT;
    stBase : ST_SEQ_EVENT;
    axEmit : ARRAY[1..15] OF BOOL;
    aeKind : ARRAY[1..15] OF E_SEQ_EVENT_KIND;
    i : UINT;
    xCorrelateCommand : BOOL;
END_VAR

// Explicitly clear every output each invocation; no event survives a quiet scan.
uiCount := 0;
FOR i := 1 TO 16 DO astEvents[i] := stEmpty; END_FOR;
stBase := stEmpty;
stBase.uiContractMajor := 0;
stBase.uiContractMinor := 2;
stBase.uiMachineID := stAfter.uiMachineID;
stBase.uiProducerSourceID := stAfter.uiProducerSourceID;
stBase.udiSessionID := stAfter.udiSessionID;
stBase.udiAuthorityID := stAfter.udiAuthorityID;
stBase.uiProcessID := stAfter.uiProcessID;
stBase.udiOccurrenceTickMs := stAfter.udiTickMs;
stBase.xOccurrenceTimeValid := stAfter.xTimeValid;
stBase.xSyntheticTime := stAfter.xSyntheticTime;
stBase.udiBatchID := stAfter.udiBatchID;
// Reset clears the runtime BatchID. Its event still belongs to the previous lot.
IF stBase.udiBatchID = 0 THEN stBase.udiBatchID := stBefore.udiBatchID; END_IF;
stBase.udiRecipeID := stAfter.udiRecipeID;
stBase.udiRecipeRevision := stAfter.udiRecipeRevision;
stBase.eState := stAfter.eState;
stBase.eStateBefore := stBefore.eState;
stBase.eReason := stAfter.eReason;
stBase.uiStepID := stAfter.uiStepID;
stBase.uiStepIDBefore := stBefore.uiStepID;
stBase.udiBatchIDBefore := stBefore.udiBatchID;
stBase.udiRecipeIDBefore := stBefore.udiRecipeID;
stBase.udiRecipeRevisionBefore := stBefore.udiRecipeRevision;
stBase.uiPhaseID := stAfter.uiPhaseID;
stBase.uiProfileID := stAfter.uiProfileID;
stBase.udiIntentID := stAfter.udiLastControlIntentID;
stBase.udiPromptID := stAfter.udiPromptID;
stBase.udiResourceTokenBefore := stBefore.udiResourceToken;
stBase.udiResourceToken := stAfter.udiResourceToken;
stBase.udiStepElapsedMs := stAfter.udiStepElapsedMs;
stBase.udiQualifiedElapsedMs := stAfter.udiQualifiedElapsedMs;

// Preserve the legacy ordering and wire values before appending semantic facts.
aeKind[1] := E_SEQ_EVENT_KIND.StateChanged;
axEmit[1] := stBefore.eState <> stAfter.eState;
aeKind[2] := E_SEQ_EVENT_KIND.StepChanged;
axEmit[2] := stBefore.uiStepID <> stAfter.uiStepID;
aeKind[3] := E_SEQ_EVENT_KIND.RecipeLoaded;
axEmit[3] := xRecipeLoaded;
aeKind[4] := E_SEQ_EVENT_KIND.CommandResult;
axEmit[4] := xCommandNew AND stResult.xValid;
aeKind[5] := E_SEQ_EVENT_KIND.BatchStarted;
// BatchStarted means admitted Start, NOT evidence that Control is executing.
axEmit[5] := axEmit[4] AND (stResult.eCommand = E_SEQ_CMD.Start)
    AND (stResult.eResult = E_SEQ_RESULT.Accepted)
    AND (stBefore.udiBatchID = 0) AND (stAfter.udiBatchID <> 0);
aeKind[6] := E_SEQ_EVENT_KIND.BatchFinished;
// Faulted is deliberately nonterminal: cleanup/recovery still has to run.
axEmit[6] := axEmit[1] AND ((stAfter.eState = E_SEQ_STATE.Complete)
    OR (stAfter.eState = E_SEQ_STATE.Stopped)
    OR (stAfter.eState = E_SEQ_STATE.Aborted));
// For same-scan advancement, finish the old step before selecting the new one.
aeKind[7] := E_SEQ_EVENT_KIND.StepFinished;
axEmit[7] := xStepCompleted;
aeKind[8] := E_SEQ_EVENT_KIND.StepStarted;
// This is step selection/start admission, not physical execution confirmation.
axEmit[8] := (stAfter.eState = E_SEQ_STATE.Running)
    AND ((stBefore.eState = E_SEQ_STATE.Starting)
        OR ((stBefore.eState = E_SEQ_STATE.Running) AND axEmit[2]));
aeKind[9] := E_SEQ_EVENT_KIND.PromptIssued;
// Hold/Resume may change xWaitingOperator; the same PromptID is not re-issued.
axEmit[9] := stAfter.xWaitingOperator AND (stAfter.udiPromptID <> 0)
    AND (stAfter.udiPromptID <> stBefore.udiPromptID);
aeKind[10] := E_SEQ_EVENT_KIND.PromptConfirmed;
axEmit[10] := xConfirmed;
// Token replacement, if observed, releases the old identity before the new one.
aeKind[11] := E_SEQ_EVENT_KIND.ResourceReleased;
axEmit[11] := (stBefore.udiResourceToken <> 0)
    AND (stAfter.udiResourceToken <> stBefore.udiResourceToken);
aeKind[12] := E_SEQ_EVENT_KIND.ResourceAcquired;
axEmit[12] := (stAfter.udiResourceToken <> 0)
    AND (stAfter.udiResourceToken <> stBefore.udiResourceToken);
aeKind[13] := E_SEQ_EVENT_KIND.FaultRaised;
axEmit[13] := axEmit[1] AND (stAfter.eState = E_SEQ_STATE.Faulted);
aeKind[14] := E_SEQ_EVENT_KIND.FaultCleared;
axEmit[14] := axEmit[1] AND (stBefore.eState = E_SEQ_STATE.Faulted);
aeKind[15] := E_SEQ_EVENT_KIND.RecipeRejected;
axEmit[15] := axEmit[4] AND (stResult.eCommand = E_SEQ_CMD.LoadRecipe)
    AND (stResult.eResult = E_SEQ_RESULT.Rejected);

// Finite bound: one candidate per predicate, at most 15 events in 16 slots.
FOR i := 1 TO 15 DO
    IF axEmit[i] THEN
        uiCount := uiCount + 1;
        astEvents[uiCount] := stBase;
        astEvents[uiCount].eKind := aeKind[i];
        // Only facts that directly establish the command relationship use it.
        // A rejected command may share a scan with an unrelated Control change.
        xCorrelateCommand := axEmit[4] AND ((i = 3) OR (i = 4)
            OR (i = 5) OR (i = 10) OR (i = 15));
        IF xCorrelateCommand THEN
            astEvents[uiCount].udiRequestID := stResult.udiRequestID;
            astEvents[uiCount].udiCommandSessionID := stResult.udiSessionID;
            astEvents[uiCount].uiSourceID := stResult.uiSourceID;
            astEvents[uiCount].eCommand := stResult.eCommand;
            astEvents[uiCount].eCommandResult := stResult.eResult;
            astEvents[uiCount].eReason := stResult.eReason;
            // Requested identity is separate from the actually applied recipe/lot.
            // SourceID is a route identity; it is not an authenticated actor.
            astEvents[uiCount].udiRequestedRecipeID := stCommand.udiRecipeID;
            astEvents[uiCount].udiRequestedRecipeRevision := stCommand.udiRecipeRevision;
            astEvents[uiCount].udiRequestedBatchID := stCommand.udiBatchID;
            astEvents[uiCount].uiRequestedStepID := stCommand.uiStepID;
            astEvents[uiCount].udiRequestedPromptID := stCommand.udiPromptID;
        END_IF;
        IF (i = 7) OR (i = 10) THEN
            // The core may already have selected the next step/reset its timers.
            astEvents[uiCount].uiStepID := stBefore.uiStepID;
            astEvents[uiCount].uiPhaseID := stBefore.uiPhaseID;
            astEvents[uiCount].uiProfileID := stBefore.uiProfileID;
            astEvents[uiCount].udiIntentID := stBefore.udiLastControlIntentID;
            astEvents[uiCount].udiPromptID := stBefore.udiPromptID;
            astEvents[uiCount].udiAuthorityID := stBefore.udiAuthorityID;
            astEvents[uiCount].udiResourceToken := stBefore.udiResourceToken;
            astEvents[uiCount].udiStepElapsedMs := udiCompletedStepElapsedMs;
            astEvents[uiCount].udiQualifiedElapsedMs := udiCompletedQualifiedMs;
        END_IF;
        IF (i = 11) OR (i = 12) THEN
            // The token transition responds to the prior intent, not the Execute
            // or later request that the core may already have selected this scan.
            astEvents[uiCount].udiIntentID := stBefore.udiLastControlIntentID;
        END_IF;
        IF i = 11 THEN
            astEvents[uiCount].udiResourceToken := stBefore.udiResourceToken;
            astEvents[uiCount].udiAuthorityID := stBefore.udiAuthorityID;
        END_IF;
        IF i = 14 THEN astEvents[uiCount].eReason := stBefore.eReason; END_IF;
    END_IF;
END_FOR;
END_FUNCTION_BLOCK
