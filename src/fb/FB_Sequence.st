FUNCTION_BLOCK FB_Sequence
VAR_INPUT
    xEnable : BOOL;
    stConfig : ST_SEQ_CONFIG;
    udiDeltaMs : UDINT; // Actual elapsed time from the caller's monotonic clock.
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stRecipeCandidate : ST_SEQ_RECIPE;
    stAuthority : ST_SEQ_CONTROL_AUTHORITY;
    stControlResult : ST_SEQ_CONTROL_RESULT;
    stControlRuntime : ST_SEQ_CONTROL_RUNTIME;
    udiEventAckSessionID : UDINT;
    udiEventAckID : UDINT;
END_VAR
VAR_OUTPUT
    stRuntime : ST_SEQ_RUNTIME;
    stCommandResult : ST_SEQ_COMMAND_RESULT;
    stControlRequest : ST_SEQ_CONTROL_REQUEST;
    xEventAvailable : BOOL;
    stEvent : ST_SEQ_EVENT;
    uiEventCount : UINT;
    udiEventsDropped : UDINT;
END_VAR
VAR
    fbGate : FB_SEQ_CommandGate;
    fbRecipeValidator : FB_SEQ_RecipeValidator;
    fbQualified : FB_SEQ_QualifiedTimer;
    fbEvents : FB_SEQ_EventQueue;
    stCfg : ST_SEQ_CONFIG;
    stRecipe : ST_SEQ_RECIPE;
    stInternal : ST_SEQ_RUNTIME;
    stResult : ST_SEQ_COMMAND_RESULT;
    stIntent : ST_SEQ_CONTROL_REQUEST;
    stDesired : ST_SEQ_CONTROL_REQUEST;
    stNewEvent : ST_SEQ_EVENT;
    stEmptyRuntime : ST_SEQ_RUNTIME;
    stEmptyResult : ST_SEQ_COMMAND_RESULT;
    stEmptyRequest : ST_SEQ_CONTROL_REQUEST;
    stEmptyEvent : ST_SEQ_EVENT;
    eBefore : E_SEQ_STATE;
    uiStepBefore : UINT;
    xInitialized : BOOL;
    xConfigOK : BOOL;
    xCycleOK : BOOL;
    xAuthorityOK : BOOL;
    xCanRequest : BOOL;
    xCanExecute : BOOL;
    xCanPublish : BOOL;
    xRuntimeFresh : BOOL;
    xResultMatches : BOOL;
    xRuntimeMatches : BOOL;
    xFeedbackOK : BOOL;
    xActive : BOOL;
    xTerminal : BOOL;
    xReleasePending : BOOL;
    xClosureConfirmed : BOOL;
    xConfirm : BOOL;
    xStepDone : BOOL;
    xQualified : BOOL;
    xQualifiedPrevious : BOOL;
    xStepChanged : BOOL;
    xIntentChanged : BOOL;
    xRecipeLoadedEvent : BOOL;
    udiIntentWaitMs : UDINT;
    udiNextIntentID : UDINT;
    udiLastBatchID : UDINT;
    udiBatchAuthorityID : UDINT;
    udiNextPromptID : UDINT;
    udiDelta : UDINT;
    udiAck : UDINT;
END_VAR

// 01 - Configuration is latched for the lifetime of this non-retained instance.
IF NOT xInitialized THEN
    stCfg := stConfig;
    xInitialized := TRUE;
    stInternal.uiContractMajor := 0;
    stInternal.uiContractMinor := 1;
    stInternal.uiProcessID := stCfg.uiProcessID;
    stInternal.udiSessionID := stCfg.udiSessionID;
END_IF;
xConfigOK := (stCfg.uiProcessID > 0) AND (stCfg.udiSessionID > 0)
    AND (stCfg.udiMaxFeedbackAgeMs > 0) AND (stCfg.udiTransitionTimeoutMs > 0)
    AND (stCfg.udiMaxCycleMs > 0)
    AND (stConfig.uiProcessID = stCfg.uiProcessID)
    AND (stConfig.udiSessionID = stCfg.udiSessionID)
    AND (stConfig.udiMaxFeedbackAgeMs = stCfg.udiMaxFeedbackAgeMs)
    AND (stConfig.udiTransitionTimeoutMs = stCfg.udiTransitionTimeoutMs)
    AND (stConfig.udiMaxCycleMs = stCfg.udiMaxCycleMs);
xCycleOK := (udiDeltaMs > 0) AND (udiDeltaMs <= stCfg.udiMaxCycleMs);
udiDelta := 0;
IF xCycleOK THEN udiDelta := udiDeltaMs; END_IF;
xAuthorityOK := xConfigOK AND stAuthority.xValid
    AND (stAuthority.udiSessionID = stCfg.udiSessionID)
    AND (stAuthority.uiProcessID = stCfg.uiProcessID)
    AND (stAuthority.udiAuthorityID > 0)
    AND (stAuthority.udiAgeMs <= stCfg.udiMaxFeedbackAgeMs);
xCanRequest := xAuthorityOK AND stAuthority.xAllowRequests;
xCanExecute := xCanRequest AND stAuthority.xAllowExecution;
xCanPublish := xAuthorityOK AND stAuthority.xAllowPublication;
xRuntimeFresh := stControlRuntime.xValid
    AND (stControlRuntime.udiSessionID = stCfg.udiSessionID)
    AND (stControlRuntime.uiProcessID = stCfg.uiProcessID)
    AND (stControlRuntime.udiAuthorityID = stAuthority.udiAuthorityID)
    AND (stControlRuntime.udiAgeMs <= stCfg.udiMaxFeedbackAgeMs);
xResultMatches := stIntent.xValid AND stControlResult.xValid
    AND (stControlResult.udiSessionID = stIntent.udiSessionID)
    AND (stControlResult.uiProcessID = stIntent.uiProcessID)
    AND (stControlResult.udiAuthorityID = stIntent.udiAuthorityID)
    AND (stControlResult.udiBatchID = stIntent.udiBatchID)
    AND (stControlResult.udiIntentID = stIntent.udiIntentID)
    AND (stControlResult.udiAgeMs <= stCfg.udiMaxFeedbackAgeMs);
xRuntimeMatches := xRuntimeFresh AND stIntent.xValid
    AND (stControlRuntime.udiBatchID = stIntent.udiBatchID)
    AND (stControlRuntime.udiIntentID = stIntent.udiIntentID);
xFeedbackOK := xResultMatches AND xRuntimeMatches
    AND stControlResult.xAccepted AND NOT stControlResult.xRejected;
xTerminal := (stInternal.eState = E_SEQ_STATE.Idle)
    OR (stInternal.eState = E_SEQ_STATE.Complete)
    OR (stInternal.eState = E_SEQ_STATE.Stopped)
    OR (stInternal.eState = E_SEQ_STATE.Aborted);
xActive := NOT xTerminal AND (stInternal.eState <> E_SEQ_STATE.Faulted);
eBefore := stInternal.eState;
uiStepBefore := stInternal.uiStepIndex;
xConfirm := FALSE;
xRecipeLoadedEvent := FALSE;
xStepDone := FALSE;

// 02 - Control owns ALL authority. No permission can be synthesized by Sequence.
// Revocation latches a fault; regrant alone can never resume a batch.
IF NOT xConfigOK THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.ConfigInvalid;
ELSIF xActive AND NOT xCycleOK THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.CycleInvalid;
ELSIF xActive AND NOT xEnable THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.Disabled;
ELSIF xActive AND ((NOT xCanExecute)
    OR (stAuthority.udiAuthorityID <> udiBatchAuthorityID)) THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.AuthorityDenied;
ELSIF xActive AND xRuntimeFresh AND stControlRuntime.xFaulted THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.ControlFault;
ELSIF xActive AND xResultMatches AND stControlResult.xRejected THEN
    stInternal.eState := E_SEQ_STATE.Faulted;
    stInternal.eReason := E_SEQ_REASON.IntentRejected;
END_IF;
IF (stInternal.eState = E_SEQ_STATE.Faulted) AND (eBefore <> E_SEQ_STATE.Faulted) THEN
    xReleasePending := FALSE;
    xClosureConfirmed := FALSE;
END_IF;

// 03 - A command result reports admission; process completion lives in runtime.
fbGate(stRequest := stCommand, udiSessionID := stCfg.udiSessionID,
       uiProcessID := stCfg.uiProcessID);
IF fbGate.xNew THEN
    stResult.xValid := TRUE;
    stResult.udiSessionID := stCommand.udiSessionID;
    stResult.udiRequestID := stCommand.udiRequestID;
    stResult.uiSourceID := stCommand.uiSourceID;
    stResult.uiProcessID := stCommand.uiProcessID;
    stResult.eCommand := stCommand.eCommand;
    stResult.eResult := E_SEQ_RESULT.Rejected;
    stResult.eReason := fbGate.eReason;
    IF stResult.eReason = E_SEQ_REASON.None THEN
        IF NOT xConfigOK THEN
            stResult.eReason := E_SEQ_REASON.ConfigInvalid;
        ELSIF NOT xCanRequest THEN
            stResult.eReason := E_SEQ_REASON.AuthorityDenied;
        ELSIF ((stCommand.eCommand = E_SEQ_CMD.Hold) OR (stCommand.eCommand = E_SEQ_CMD.Resume)
            OR (stCommand.eCommand = E_SEQ_CMD.Stop) OR (stCommand.eCommand = E_SEQ_CMD.Abort)
            OR (stCommand.eCommand = E_SEQ_CMD.Reset))
            AND (stCommand.udiBatchID <> stInternal.udiBatchID) THEN
            stResult.eReason := E_SEQ_REASON.InvalidRequest;
        ELSE
            stResult.eReason := E_SEQ_REASON.InvalidState;
            CASE stCommand.eCommand OF
            E_SEQ_CMD.LoadRecipe:
                IF stInternal.eState = E_SEQ_STATE.Idle THEN
                    fbRecipeValidator(stRecipe := stRecipeCandidate);
                    IF NOT fbRecipeValidator.xValid THEN
                        stResult.eReason := E_SEQ_REASON.RecipeInvalid;
                    ELSIF (stCommand.udiRecipeID <> stRecipeCandidate.udiRecipeID)
                       OR (stCommand.udiRecipeRevision <> stRecipeCandidate.udiRevision) THEN
                        stResult.eReason := E_SEQ_REASON.InvalidRecipeRef;
                    ELSE
                        stRecipe := stRecipeCandidate;
                        stInternal.xRecipeLoaded := TRUE;
                        stInternal.udiRecipeID := stRecipe.udiRecipeID;
                        stInternal.udiRecipeRevision := stRecipe.udiRevision;
                        stInternal.uiStepCount := stRecipe.uiStepCount;
                        stResult.eReason := E_SEQ_REASON.None;
                        xRecipeLoadedEvent := TRUE;
                    END_IF;
                END_IF;
            E_SEQ_CMD.Start:
                IF stInternal.eState = E_SEQ_STATE.Idle THEN
                    IF NOT xEnable THEN
                        stResult.eReason := E_SEQ_REASON.Disabled;
                    ELSIF NOT xCycleOK THEN
                        stResult.eReason := E_SEQ_REASON.CycleInvalid;
                    ELSIF NOT xCanExecute THEN
                        stResult.eReason := E_SEQ_REASON.AuthorityDenied;
                    ELSIF NOT stInternal.xRecipeLoaded THEN
                        stResult.eReason := E_SEQ_REASON.NoRecipe;
                    ELSIF (stCommand.udiRecipeID <> stRecipe.udiRecipeID)
                       OR (stCommand.udiRecipeRevision <> stRecipe.udiRevision) THEN
                        stResult.eReason := E_SEQ_REASON.InvalidRecipeRef;
                    ELSIF (stCommand.udiBatchID = 0) OR (stCommand.udiBatchID <= udiLastBatchID) THEN
                        stResult.eReason := E_SEQ_REASON.InvalidRequest;
                    ELSIF NOT xRuntimeFresh OR NOT stControlRuntime.xReady
                       OR stControlRuntime.xFaulted OR stControlRuntime.xResourceGranted THEN
                        stResult.eReason := E_SEQ_REASON.NotReady;
                    ELSE
                        stInternal.udiBatchID := stCommand.udiBatchID;
                        udiLastBatchID := stCommand.udiBatchID;
                        udiBatchAuthorityID := stAuthority.udiAuthorityID;
                        stInternal.uiStepIndex := 1;
                        stInternal.udiResourceToken := 0;
                        stInternal.eReason := E_SEQ_REASON.None;
                        stInternal.eState := E_SEQ_STATE.Starting;
                        xClosureConfirmed := FALSE;
                        xReleasePending := FALSE;
                        stResult.eReason := E_SEQ_REASON.None;
                    END_IF;
                END_IF;
            E_SEQ_CMD.Hold:
                IF stInternal.eState = E_SEQ_STATE.Running THEN
                    stInternal.eState := E_SEQ_STATE.Holding;
                    stResult.eReason := E_SEQ_REASON.None;
                END_IF;
            E_SEQ_CMD.Resume:
                IF stInternal.eState = E_SEQ_STATE.Held THEN
                    IF xEnable AND xCanExecute AND xCycleOK AND xFeedbackOK
                       AND stControlRuntime.xReady AND NOT stControlRuntime.xFaulted
                       AND stControlRuntime.xResourceGranted
                       AND (stControlRuntime.udiResourceToken = stInternal.udiResourceToken) THEN
                        stInternal.eState := E_SEQ_STATE.Running;
                        stResult.eReason := E_SEQ_REASON.None;
                    ELSE
                        stResult.eReason := E_SEQ_REASON.NotReady;
                    END_IF;
                END_IF;
            E_SEQ_CMD.Stop:
                IF (stInternal.eState = E_SEQ_STATE.Starting)
                   OR (stInternal.eState = E_SEQ_STATE.Running)
                   OR (stInternal.eState = E_SEQ_STATE.Holding)
                   OR (stInternal.eState = E_SEQ_STATE.Held)
                   OR (stInternal.eState = E_SEQ_STATE.Completing) THEN
                    stInternal.eState := E_SEQ_STATE.Stopping;
                    xReleasePending := FALSE;
                    stResult.eReason := E_SEQ_REASON.None;
                END_IF;
            E_SEQ_CMD.Abort:
                IF NOT xTerminal AND (stInternal.eState <> E_SEQ_STATE.Aborting)
                   AND (stInternal.eState <> E_SEQ_STATE.Faulted) THEN
                    stInternal.eState := E_SEQ_STATE.Aborting;
                    xReleasePending := FALSE;
                    stResult.eReason := E_SEQ_REASON.None;
                END_IF;
            E_SEQ_CMD.Reset:
                IF (stInternal.eState = E_SEQ_STATE.Complete)
                   OR (stInternal.eState = E_SEQ_STATE.Stopped)
                   OR (stInternal.eState = E_SEQ_STATE.Aborted)
                   OR (stInternal.eState = E_SEQ_STATE.Faulted) THEN
                    IF xCycleOK AND xRuntimeFresh AND stControlRuntime.xReady
                       AND NOT stControlRuntime.xFaulted AND NOT stControlRuntime.xResourceGranted
                       AND (xClosureConfirmed OR (stInternal.udiBatchID = 0)) THEN
                        stInternal.eState := E_SEQ_STATE.Idle;
                        stInternal.eReason := E_SEQ_REASON.None;
                        stInternal.uiStepIndex := 0;
                        stInternal.udiBatchID := 0;
                        stInternal.udiResourceToken := 0;
                        xReleasePending := FALSE;
                        stResult.eReason := E_SEQ_REASON.None;
                    ELSE
                        stResult.eReason := E_SEQ_REASON.NotReady;
                    END_IF;
                END_IF;
            E_SEQ_CMD.ConfirmStep:
                IF (stInternal.eState = E_SEQ_STATE.Running) AND stInternal.xWaitingOperator THEN
                    IF (stCommand.udiBatchID = stInternal.udiBatchID)
                       AND (stCommand.uiStepID = stInternal.uiStepID)
                       AND (stCommand.udiPromptID = stInternal.udiPromptID)
                       AND (stCommand.udiPromptID > 0)
                       AND xFeedbackOK AND stControlRuntime.xQualified THEN
                        xConfirm := TRUE;
                        stResult.eReason := E_SEQ_REASON.None;
                    ELSE
                        stResult.eReason := E_SEQ_REASON.InvalidConfirm;
                    END_IF;
                END_IF;
            END_CASE;
        END_IF;
    END_IF;
    IF stResult.eReason = E_SEQ_REASON.None THEN stResult.eResult := E_SEQ_RESULT.Accepted; END_IF;
END_IF;

// 04 - Lifecycle and process criteria use correlated feedback, never transport ACK.
xQualified := FALSE;
IF (stInternal.eState = E_SEQ_STATE.Running) AND xCanExecute AND xFeedbackOK THEN
    xQualified := stControlRuntime.xQualified AND stControlRuntime.xReady
        AND NOT stControlRuntime.xFaulted AND stControlRuntime.xResourceGranted
        AND (stControlRuntime.udiResourceToken = stInternal.udiResourceToken);
END_IF;
xStepChanged := (stInternal.uiStepIndex <> uiStepBefore);
IF (stInternal.uiStepIndex >= 1) AND (stInternal.uiStepIndex <= stRecipe.uiStepCount)
   AND (stInternal.uiStepIndex <= 16) THEN
    fbQualified(xReset := xStepChanged, xEnable := (stInternal.eState = E_SEQ_STATE.Running),
        xQualified := xQualified AND xQualifiedPrevious, udiDeltaMs := udiDelta,
        udiTargetMs := stRecipe.astSteps[stInternal.uiStepIndex].udiQualifiedMs);
ELSE
    fbQualified(xReset := TRUE, xEnable := FALSE, xQualified := FALSE,
        udiDeltaMs := 0, udiTargetMs := 0);
END_IF;
xQualifiedPrevious := xQualified AND NOT xStepChanged;
IF (stInternal.eState = E_SEQ_STATE.Running) AND (eBefore = E_SEQ_STATE.Running) THEN
    stInternal.udiStepElapsedMs := F_SEQ_AddMs(stInternal.udiStepElapsedMs, udiDelta);
END_IF;
IF stInternal.eState = eBefore THEN
    stInternal.udiStateElapsedMs := F_SEQ_AddMs(stInternal.udiStateElapsedMs, udiDelta);
ELSE
    stInternal.udiStateElapsedMs := 0;
END_IF;

IF xCanRequest THEN
    CASE stInternal.eState OF
    E_SEQ_STATE.Starting:
        IF xCanExecute AND xFeedbackOK AND (stIntent.eAction = E_SEQ_ACTION.Acquire)
           AND stControlResult.xDone AND stControlResult.xResourceGranted
           AND stControlRuntime.xResourceGranted AND (stControlResult.udiResourceToken > 0)
           AND (stControlResult.udiResourceToken = stControlRuntime.udiResourceToken) THEN
            stInternal.udiResourceToken := stControlResult.udiResourceToken;
            stInternal.eState := E_SEQ_STATE.Running;
        END_IF;
    E_SEQ_STATE.Running:
        IF xCanExecute AND (stIntent.eAction = E_SEQ_ACTION.Execute) AND xFeedbackOK
           AND (stIntent.uiStepID = stRecipe.astSteps[stInternal.uiStepIndex].uiStepID) THEN
            IF NOT stControlRuntime.xResourceGranted
               OR (stControlRuntime.udiResourceToken <> stInternal.udiResourceToken) THEN
                stInternal.eState := E_SEQ_STATE.Faulted;
                stInternal.eReason := E_SEQ_REASON.ResourceLost;
            ELSE
                CASE stRecipe.astSteps[stInternal.uiStepIndex].eKind OF
                E_SEQ_STEP_KIND.WaitQualified: xStepDone := fbQualified.xDone;
                E_SEQ_STEP_KIND.WaitComplete: xStepDone := xQualified AND stControlRuntime.xStepComplete;
                E_SEQ_STEP_KIND.WaitOperator: xStepDone := xQualified AND xConfirm;
                END_CASE;
                IF xStepDone THEN
                    IF stInternal.uiStepIndex < stRecipe.uiStepCount THEN
                        stInternal.uiStepIndex := stInternal.uiStepIndex + 1;
                    ELSE
                        stInternal.eState := E_SEQ_STATE.Completing;
                        xReleasePending := FALSE;
                    END_IF;
                END_IF;
            END_IF;
        END_IF;
        IF (stInternal.eState = E_SEQ_STATE.Running) AND NOT xStepDone
           AND (stInternal.udiStepElapsedMs >= stRecipe.astSteps[stInternal.uiStepIndex].udiTimeoutMs) THEN
            stInternal.eState := E_SEQ_STATE.Faulted;
            stInternal.eReason := E_SEQ_REASON.StepTimeout;
        END_IF;
    E_SEQ_STATE.Holding, E_SEQ_STATE.Held:
        IF xFeedbackOK AND (stIntent.eAction = E_SEQ_ACTION.Hold) THEN
            IF NOT stControlRuntime.xResourceGranted
               OR (stControlRuntime.udiResourceToken <> stInternal.udiResourceToken) THEN
                stInternal.eState := E_SEQ_STATE.Faulted;
                stInternal.eReason := E_SEQ_REASON.ResourceLost;
            ELSIF stControlResult.xDone THEN
                stInternal.eState := E_SEQ_STATE.Held;
            END_IF;
        END_IF;
    E_SEQ_STATE.Completing, E_SEQ_STATE.Stopping, E_SEQ_STATE.Aborting, E_SEQ_STATE.Faulted:
        IF xFeedbackOK AND stControlResult.xDone THEN
            IF ((stInternal.eState = E_SEQ_STATE.Completing) AND (stIntent.eAction = E_SEQ_ACTION.Complete))
               OR ((stInternal.eState = E_SEQ_STATE.Stopping) AND (stIntent.eAction = E_SEQ_ACTION.Stop))
               OR (((stInternal.eState = E_SEQ_STATE.Aborting) OR (stInternal.eState = E_SEQ_STATE.Faulted))
                   AND (stIntent.eAction = E_SEQ_ACTION.Abort)) THEN
                xReleasePending := TRUE;
            ELSIF xReleasePending AND (stIntent.eAction = E_SEQ_ACTION.Release)
               AND stControlResult.xReleased AND NOT stControlResult.xResourceGranted
               AND NOT stControlRuntime.xResourceGranted THEN
                xClosureConfirmed := TRUE;
                stInternal.udiResourceToken := 0;
                CASE stInternal.eState OF
                E_SEQ_STATE.Completing: stInternal.eState := E_SEQ_STATE.Complete;
                E_SEQ_STATE.Stopping: stInternal.eState := E_SEQ_STATE.Stopped;
                E_SEQ_STATE.Aborting: stInternal.eState := E_SEQ_STATE.Aborted;
                END_CASE;
            END_IF;
        END_IF;
    END_CASE;
END_IF;

// 05 - Bounded waits. Correlated but incomplete transition feedback does not hide timeout.
IF (stInternal.eState = E_SEQ_STATE.Starting) OR (stInternal.eState = E_SEQ_STATE.Holding)
   OR (stInternal.eState = E_SEQ_STATE.Completing) OR (stInternal.eState = E_SEQ_STATE.Stopping)
   OR (stInternal.eState = E_SEQ_STATE.Aborting) THEN
    IF stInternal.udiStateElapsedMs >= stCfg.udiTransitionTimeoutMs THEN
        stInternal.eState := E_SEQ_STATE.Faulted;
        stInternal.eReason := E_SEQ_REASON.TransitionTimeout;
        xReleasePending := FALSE;
    END_IF;
END_IF;
IF (stInternal.eState <> E_SEQ_STATE.Idle) AND (stInternal.eState <> E_SEQ_STATE.Complete)
   AND (stInternal.eState <> E_SEQ_STATE.Stopped) AND (stInternal.eState <> E_SEQ_STATE.Aborted)
   AND (stInternal.eState <> E_SEQ_STATE.Faulted) THEN
    IF xFeedbackOK THEN udiIntentWaitMs := 0;
    ELSE udiIntentWaitMs := F_SEQ_AddMs(udiIntentWaitMs, udiDelta); END_IF;
    IF udiIntentWaitMs >= stCfg.udiTransitionTimeoutMs THEN
        stInternal.eState := E_SEQ_STATE.Faulted;
        stInternal.eReason := E_SEQ_REASON.StaleFeedback;
        xReleasePending := FALSE;
    END_IF;
END_IF;
IF (stInternal.eState = E_SEQ_STATE.Faulted) AND (eBefore <> E_SEQ_STATE.Faulted) THEN
    xReleasePending := FALSE;
    xClosureConfirmed := FALSE;
END_IF;

// 06 - Enter step once. Prompt IDs cannot be recycled within a session.
xStepChanged := (stInternal.uiStepIndex <> uiStepBefore);
IF xStepChanged THEN
    stInternal.udiStepElapsedMs := 0;
    fbQualified(xReset := TRUE, xEnable := FALSE, xQualified := FALSE,
        udiDeltaMs := 0, udiTargetMs := 0);
    xQualifiedPrevious := FALSE;
    stInternal.udiPromptID := 0;
END_IF;
stInternal.uiStepID := 0;
stInternal.uiPhaseID := 0;
stInternal.xWaitingOperator := FALSE;
IF (stInternal.uiStepIndex >= 1) AND (stInternal.uiStepIndex <= stRecipe.uiStepCount)
   AND (stInternal.uiStepIndex <= 16) THEN
    stInternal.uiStepID := stRecipe.astSteps[stInternal.uiStepIndex].uiStepID;
    stInternal.uiPhaseID := stRecipe.astSteps[stInternal.uiStepIndex].uiPhaseID;
    IF (stInternal.eState = E_SEQ_STATE.Running)
       AND (stRecipe.astSteps[stInternal.uiStepIndex].eKind = E_SEQ_STEP_KIND.WaitOperator) THEN
        IF stInternal.udiPromptID = 0 THEN
            IF udiNextPromptID < UDINT#4294967295 THEN
                udiNextPromptID := udiNextPromptID + 1;
                stInternal.udiPromptID := udiNextPromptID;
            ELSE
                stInternal.eState := E_SEQ_STATE.Faulted;
                stInternal.eReason := E_SEQ_REASON.CounterExhausted;
            END_IF;
        END_IF;
        stInternal.xWaitingOperator := stInternal.eState = E_SEQ_STATE.Running;
    END_IF;
END_IF;
stInternal.udiQualifiedElapsedMs := fbQualified.udiElapsedMs;
IF stInternal.eState <> eBefore THEN stInternal.udiStateElapsedMs := 0; END_IF;

// 07 - Build intentions. Control must independently enforce authority and equipment rules.
stDesired := stEmptyRequest;
stDesired.udiSessionID := stCfg.udiSessionID;
stDesired.udiAuthorityID := stAuthority.udiAuthorityID;
stDesired.uiProcessID := stCfg.uiProcessID;
stDesired.udiBatchID := stInternal.udiBatchID;
stDesired.uiStepID := stInternal.uiStepID;
stDesired.uiPhaseID := stInternal.uiPhaseID;
stDesired.udiResourceToken := stInternal.udiResourceToken;
IF stInternal.uiStepIndex > 0 THEN
    stDesired.uiProfileID := stRecipe.astSteps[stInternal.uiStepIndex].uiProfileID;
    stDesired.rParameter1 := stRecipe.astSteps[stInternal.uiStepIndex].rParameter1;
    stDesired.rParameter2 := stRecipe.astSteps[stInternal.uiStepIndex].rParameter2;
END_IF;
CASE stInternal.eState OF
E_SEQ_STATE.Starting: stDesired.eAction := E_SEQ_ACTION.Acquire;
E_SEQ_STATE.Running: stDesired.eAction := E_SEQ_ACTION.Execute;
E_SEQ_STATE.Holding, E_SEQ_STATE.Held: stDesired.eAction := E_SEQ_ACTION.Hold;
E_SEQ_STATE.Completing: stDesired.eAction := E_SEQ_ACTION.Complete;
E_SEQ_STATE.Stopping: stDesired.eAction := E_SEQ_ACTION.Stop;
E_SEQ_STATE.Aborting: stDesired.eAction := E_SEQ_ACTION.Abort;
E_SEQ_STATE.Faulted:
    IF (stInternal.udiBatchID > 0) AND NOT xClosureConfirmed THEN stDesired.eAction := E_SEQ_ACTION.Abort; END_IF;
END_CASE;
IF xReleasePending AND NOT xClosureConfirmed THEN stDesired.eAction := E_SEQ_ACTION.Release; END_IF;
stDesired.xValid := stDesired.eAction <> E_SEQ_ACTION.None;
xIntentChanged := (stDesired.eAction <> stIntent.eAction)
    OR (stDesired.uiStepID <> stIntent.uiStepID)
    OR (stDesired.udiBatchID <> stIntent.udiBatchID)
    OR (stDesired.udiAuthorityID <> stIntent.udiAuthorityID);
IF xIntentChanged THEN
    IF stDesired.xValid THEN
        IF udiNextIntentID < UDINT#4294967295 THEN
            udiNextIntentID := udiNextIntentID + 1;
        ELSE
            stDesired.xValid := FALSE;
            stInternal.eState := E_SEQ_STATE.Faulted;
            stInternal.eReason := E_SEQ_REASON.CounterExhausted;
        END_IF;
    END_IF;
    stDesired.udiIntentID := udiNextIntentID;
    stIntent := stDesired;
    udiIntentWaitMs := 0;
END_IF;
stControlRequest := stEmptyRequest;
IF xCanRequest AND stIntent.xValid THEN
    stControlRequest := stIntent;
END_IF;
stInternal.udiLastControlIntentID := stIntent.udiIntentID;
stInternal.udiAuthorityID := stAuthority.udiAuthorityID;
stInternal.uiControlReasonID := stControlRuntime.uiReasonID;
IF fbGate.xNew THEN stResult.eStateAfter := stInternal.eState; END_IF;

// 08 - Volatile events retained until ACK/reinitialization; overflow drops new events.
// Service cannot drain while publication is denied. This is not a persistent journal.
udiAck := 0;
IF xCanPublish AND (udiEventAckSessionID = stCfg.udiSessionID) THEN udiAck := udiEventAckID; END_IF;
fbEvents(xPush := FALSE, stEvent := stEmptyEvent, udiAckEventID := udiAck);
stNewEvent := stEmptyEvent;
stNewEvent.udiSessionID := stCfg.udiSessionID;
stNewEvent.udiAuthorityID := stAuthority.udiAuthorityID;
stNewEvent.uiProcessID := stCfg.uiProcessID;
stNewEvent.udiBatchID := stInternal.udiBatchID;
stNewEvent.udiRecipeID := stInternal.udiRecipeID;
stNewEvent.udiRecipeRevision := stInternal.udiRecipeRevision;
stNewEvent.eState := stInternal.eState;
stNewEvent.uiStepID := stInternal.uiStepID;
stNewEvent.eReason := stInternal.eReason;
IF stInternal.eState <> eBefore THEN
    stNewEvent.eKind := E_SEQ_EVENT_KIND.StateChanged;
    fbEvents(xPush := TRUE, stEvent := stNewEvent, udiAckEventID := 0);
END_IF;
IF xStepChanged THEN
    stNewEvent.eKind := E_SEQ_EVENT_KIND.StepChanged;
    fbEvents(xPush := TRUE, stEvent := stNewEvent, udiAckEventID := 0);
END_IF;
IF xRecipeLoadedEvent THEN
    stNewEvent.eKind := E_SEQ_EVENT_KIND.RecipeLoaded;
    fbEvents(xPush := TRUE, stEvent := stNewEvent, udiAckEventID := 0);
END_IF;
IF fbGate.xNew THEN
    stNewEvent.eKind := E_SEQ_EVENT_KIND.CommandResult;
    stNewEvent.udiRequestID := stResult.udiRequestID;
    stNewEvent.udiCommandSessionID := stResult.udiSessionID;
    stNewEvent.uiSourceID := stResult.uiSourceID;
    stNewEvent.eCommand := stResult.eCommand;
    stNewEvent.eCommandResult := stResult.eResult;
    stNewEvent.eReason := stResult.eReason;
    fbEvents(xPush := TRUE, stEvent := stNewEvent, udiAckEventID := 0);
END_IF;

// 09 - Publication is granted by Control, independently from execution permission.
// Only invalid/empty envelopes are exposed while denied; local state remains in stInternal.
stRuntime := stEmptyRuntime;
stCommandResult := stEmptyResult;
stEvent := stEmptyEvent;
xEventAvailable := FALSE;
uiEventCount := 0;
udiEventsDropped := 0;
IF xCanPublish THEN
    stInternal.xDataValid := TRUE;
    stRuntime := stInternal;
    stCommandResult := stResult;
    stEvent := fbEvents.stHead;
    xEventAvailable := fbEvents.xAvailable;
    uiEventCount := fbEvents.uiCount;
    udiEventsDropped := fbEvents.udiDropped;
END_IF;
END_FUNCTION_BLOCK
