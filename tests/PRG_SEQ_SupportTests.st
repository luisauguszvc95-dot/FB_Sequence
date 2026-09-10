// Simulator-only self-checking POU; no GVLs, physical I/O, network, or tasks.
// Import DUTs, F_SEQ_AddMs, FB_SEQ_* and this PROGRAM into Machine Expert.
// Attach ONLY this POU to a simulator task; observe xDone, uiChecks, uiFailures.
// Expected result: xDone = TRUE, uiChecks = 40, uiFailures = 0.
// Reset/reinitialize the application to rerun: stateful instances are intentional.
// Deliberate sequential FB calls model scan boundaries with explicit deltas.
// These are authored executable simulator tests; not proof of a native compile.
PROGRAM PRG_SEQ_SupportTests
VAR
    xDone : BOOL;
    uiChecks : UINT;
    uiFailures : UINT;
    fbTimer : FB_SEQ_QualifiedTimer;
    fbRecipe : FB_SEQ_RecipeValidator;
    fbQueue : FB_SEQ_EventQueue;
    fbGate : FB_SEQ_CommandGate;
    stRecipe : ST_SEQ_RECIPE;
    stEvent : ST_SEQ_EVENT;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    uiIndex : UINT;
    udiExpectedID : UDINT;
    xDrainCorrect : BOOL;
END_VAR

IF xDone THEN RETURN; END_IF;

// 01 - Overflow-safe addition, including boundary equality.
uiChecks := uiChecks + 1;
IF F_SEQ_AddMs(UDINT#4294967294, UDINT#1) <> UDINT#4294967295 THEN
    uiFailures := uiFailures + 1;
END_IF;
uiChecks := uiChecks + 1;
IF F_SEQ_AddMs(UDINT#4294967294, UDINT#2) <> UDINT#4294967295 THEN
    uiFailures := uiFailures + 1;
END_IF;
uiChecks := uiChecks + 1;
IF F_SEQ_AddMs(UDINT#4294967295, UDINT#4294967295) <> UDINT#4294967295 THEN
    uiFailures := uiFailures + 1;
END_IF;

// 02 - Qualified timer: reset dominates an enabled/qualified call.
fbTimer(xReset := TRUE, xEnable := TRUE, xQualified := TRUE,
    udiDeltaMs := 100, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 0) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := TRUE, xQualified := TRUE,
    udiDeltaMs := 40, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 40) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := FALSE, xQualified := TRUE,
    udiDeltaMs := 80, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 40) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := TRUE, xQualified := FALSE,
    udiDeltaMs := 80, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 40) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := TRUE, xQualified := TRUE,
    udiDeltaMs := UDINT#4294967295, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 100) OR NOT fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := FALSE, xQualified := FALSE,
    udiDeltaMs := 100, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 100) OR NOT fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := TRUE, xEnable := TRUE, xQualified := TRUE,
    udiDeltaMs := 100, udiTargetMs := 100);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 0) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;
fbTimer(xReset := FALSE, xEnable := TRUE, xQualified := TRUE,
    udiDeltaMs := 100, udiTargetMs := 0);
uiChecks := uiChecks + 1;
IF (fbTimer.udiElapsedMs <> 0) OR fbTimer.xDone THEN
    uiFailures := uiFailures + 1;
END_IF;

// 03 - Structural recipe validation. Physical limits need adapter tests.
stRecipe.udiRecipeID := 1;
stRecipe.udiRevision := 1;
stRecipe.uiStepCount := 2;
FOR uiIndex := 1 TO 2 DO
    stRecipe.astSteps[uiIndex].uiStepID := uiIndex;
    stRecipe.astSteps[uiIndex].uiPhaseID := 1;
    stRecipe.astSteps[uiIndex].uiProfileID := 1;
    stRecipe.astSteps[uiIndex].eKind := E_SEQ_STEP_KIND.WaitQualified;
    stRecipe.astSteps[uiIndex].udiQualifiedMs := 100;
    stRecipe.astSteps[uiIndex].udiTimeoutMs := 200;
END_FOR;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF NOT fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 0)
   OR (fbRecipe.eReason <> E_SEQ_REASON.None) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.astSteps[2].uiStepID := 1;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 2)
   OR (fbRecipe.eReason <> E_SEQ_REASON.RecipeInvalid) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.astSteps[2].uiStepID := 2;
stRecipe.uiStepCount := 0;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.uiStepCount := 17;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.uiStepCount := UINT#65535;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.uiStepCount := 2;
stRecipe.udiRevision := 0;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.udiRevision := 1;
stRecipe.astSteps[2].uiProfileID := 0;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 2) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.astSteps[2].uiProfileID := 1;
stRecipe.astSteps[2].udiQualifiedMs := 201;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 2) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.astSteps[2].udiQualifiedMs := 0;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF fbRecipe.xValid OR (fbRecipe.uiInvalidStep <> 2) THEN
    uiFailures := uiFailures + 1;
END_IF;
stRecipe.astSteps[2].udiQualifiedMs := 200;
fbRecipe(stRecipe := stRecipe);
uiChecks := uiChecks + 1;
IF NOT fbRecipe.xValid THEN uiFailures := uiFailures + 1; END_IF;

// 04 - Ring wrap, full queue drop-new, exact ACK and repeated ACK.
stEvent.udiSessionID := 1;
stEvent.uiProcessID := 1;
stEvent.udiEventID := 900; // Producer ID must be overwritten by the queue.
FOR uiIndex := 1 TO 32 DO
    fbQueue(xPush := TRUE, stEvent := stEvent, udiAckEventID := 0);
END_FOR;
uiChecks := uiChecks + 1;
IF (fbQueue.uiCount <> 32) OR (fbQueue.stHead.udiEventID <> 1)
   OR NOT fbQueue.xAvailable OR (fbQueue.udiDropped <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
fbQueue(xPush := TRUE, stEvent := stEvent, udiAckEventID := 0);
uiChecks := uiChecks + 1;
IF (fbQueue.uiCount <> 32) OR (fbQueue.stHead.udiEventID <> 1)
   OR (fbQueue.udiDropped <> 1) THEN
    uiFailures := uiFailures + 1;
END_IF;
fbQueue(xPush := FALSE, stEvent := stEvent, udiAckEventID := 1);
uiChecks := uiChecks + 1;
IF (fbQueue.uiCount <> 31) OR (fbQueue.stHead.udiEventID <> 2) THEN
    uiFailures := uiFailures + 1;
END_IF;
fbQueue(xPush := FALSE, stEvent := stEvent, udiAckEventID := 1);
fbQueue(xPush := FALSE, stEvent := stEvent, udiAckEventID := 100);
uiChecks := uiChecks + 1;
IF (fbQueue.uiCount <> 31) OR (fbQueue.stHead.udiEventID <> 2) THEN
    uiFailures := uiFailures + 1;
END_IF;
// Pop then push; accepted new event gets ID33 (dropped event consumed no ID).
fbQueue(xPush := TRUE, stEvent := stEvent, udiAckEventID := 2);
fbQueue(xPush := TRUE, stEvent := stEvent, udiAckEventID := 0);
uiChecks := uiChecks + 1;
IF (fbQueue.uiCount <> 32) OR (fbQueue.stHead.udiEventID <> 3) THEN
    uiFailures := uiFailures + 1;
END_IF;
xDrainCorrect := TRUE;
FOR udiExpectedID := 3 TO 34 DO
    IF NOT fbQueue.xAvailable OR (fbQueue.stHead.udiEventID <> udiExpectedID) THEN
        xDrainCorrect := FALSE;
    END_IF;
    fbQueue(xPush := FALSE, stEvent := stEvent, udiAckEventID := udiExpectedID);
END_FOR;
uiChecks := uiChecks + 1;
IF NOT xDrainCorrect OR fbQueue.xAvailable OR (fbQueue.uiCount <> 0)
   OR (fbQueue.stHead.udiEventID <> 0) THEN
    uiFailures := uiFailures + 1;
END_IF;
// A speculative ACK cannot remove the event first enqueued by this same call.
fbQueue(xPush := TRUE, stEvent := stEvent, udiAckEventID := 35);
uiChecks := uiChecks + 1;
IF NOT fbQueue.xAvailable OR (fbQueue.uiCount <> 1)
   OR (fbQueue.stHead.udiEventID <> 35) OR (fbQueue.udiDropped <> 1) THEN
    uiFailures := uiFailures + 1;
END_IF;

// 05 - Command high-water mark survives repeats, clear, old IDs, wrong sessions.
stCommand.xValid := TRUE;
stCommand.udiSessionID := 1;
stCommand.uiProcessID := 1;
stCommand.udiRequestID := 10;
stCommand.eCommand := E_SEQ_CMD.Start;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.None)
   OR (fbGate.udiLastRequestID <> 10) THEN
    uiFailures := uiFailures + 1;
END_IF;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF fbGate.xNew THEN uiFailures := uiFailures + 1; END_IF;
stCommand.xValid := FALSE;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
stCommand.xValid := TRUE;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF fbGate.xNew OR (fbGate.udiLastRequestID <> 10) THEN
    uiFailures := uiFailures + 1;
END_IF;
stCommand.eCommand := E_SEQ_CMD.Stop;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF fbGate.xNew THEN uiFailures := uiFailures + 1; END_IF;
stCommand.udiRequestID := 9;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.InvalidRequest)
   OR (fbGate.udiLastRequestID <> 10) THEN
    uiFailures := uiFailures + 1;
END_IF;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF fbGate.xNew THEN uiFailures := uiFailures + 1; END_IF;
stCommand.udiRequestID := 10;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.InvalidRequest)
   OR (fbGate.udiLastRequestID <> 10) THEN
    uiFailures := uiFailures + 1;
END_IF;
stCommand.udiSessionID := 2;
stCommand.udiRequestID := 1000;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.SessionMismatch)
   OR (fbGate.udiLastRequestID <> 10) THEN
    uiFailures := uiFailures + 1;
END_IF;
stCommand.udiSessionID := 1;
stCommand.udiRequestID := 11;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.None)
   OR (fbGate.udiLastRequestID <> 11) THEN
    uiFailures := uiFailures + 1;
END_IF;
stCommand.uiProcessID := 2;
stCommand.udiRequestID := 12;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.WrongProcess)
   OR (fbGate.udiLastRequestID <> 12) THEN
    uiFailures := uiFailures + 1;
END_IF;
stCommand.uiProcessID := 1;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF fbGate.xNew THEN uiFailures := uiFailures + 1; END_IF;
stCommand.udiRequestID := 13;
fbGate(stRequest := stCommand, udiSessionID := 1, uiProcessID := 1);
uiChecks := uiChecks + 1;
IF NOT fbGate.xNew OR (fbGate.eReason <> E_SEQ_REASON.None)
   OR (fbGate.udiLastRequestID <> 13) THEN
    uiFailures := uiFailures + 1;
END_IF;

xDone := TRUE;
END_PROGRAM
