// One producer (Sequence), one consumer ACK (Service), fixed memory ring.
// xPush is a producer pulse: every TRUE call requests ONE event; no edge latch.
// Calls may be serialized within one Sequence cycle by the same producer.
// Pass the consumer ACK on the first call only. Service ACKs after taking ownership of
// the head; this volatile queue is not a durable audit journal.
// IDs are monotonic for this FB instance lifetime, never reset by commands.
// On PLC reinitialization use a NEW SessionID and clear stale Service ACKs.
// The full event identity downstream is (SessionID, ProcessID, EventID).
FUNCTION_BLOCK FB_SEQ_EventQueue
VAR_INPUT
    xPush : BOOL;
    stEvent : ST_SEQ_EVENT;
    udiAckEventID : UDINT;
END_VAR
VAR_OUTPUT
    xAvailable : BOOL;
    stHead : ST_SEQ_EVENT;
    uiCount : UINT;
    udiDropped : UDINT;
    xIDExhausted : BOOL;
END_VAR
VAR
    astBuffer : ARRAY[1..32] OF ST_SEQ_EVENT;
    uiHeadIndex : UINT := UINT#1;
    uiTailIndex : UINT := UINT#1;
    udiNextEventID : UDINT := UDINT#1;
    stEmpty : ST_SEQ_EVENT;
END_VAR
VAR CONSTANT
    C_CAPACITY : UINT := UINT#32;
    C_MAX_ID : UDINT := UDINT#4294967295;
END_VAR

// Pop at most one EXISTING head before considering the push. A repeated ACK
// cannot pop the following event because accepted IDs are never reused.
IF uiCount > UINT#0 THEN
    IF (udiAckEventID <> UDINT#0) AND
       (udiAckEventID = astBuffer[uiHeadIndex].udiEventID) THEN
        uiCount := uiCount - UINT#1;
        IF uiHeadIndex = C_CAPACITY THEN
            uiHeadIndex := UINT#1;
        ELSE
            uiHeadIndex := uiHeadIndex + UINT#1;
        END_IF;
    END_IF;
END_IF;

IF xPush THEN
    IF (uiCount = C_CAPACITY) OR xIDExhausted THEN
        // Drop-new preserves the oldest unacknowledged event and its ID.
        udiDropped := F_SEQ_AddMs(
            udiValue := udiDropped,
            udiDelta := UDINT#1);
    ELSE
        astBuffer[uiTailIndex] := stEvent;
        // Never trust/reuse the producer's incoming EventID.
        astBuffer[uiTailIndex].udiEventID := udiNextEventID;
        uiCount := uiCount + UINT#1;

        IF uiTailIndex = C_CAPACITY THEN
            uiTailIndex := UINT#1;
        ELSE
            uiTailIndex := uiTailIndex + UINT#1;
        END_IF;

        IF udiNextEventID = C_MAX_ID THEN
            // The max-ID event was accepted; all later pushes are dropped.
            xIDExhausted := TRUE;
        ELSE
            udiNextEventID := udiNextEventID + UDINT#1;
        END_IF;
    END_IF;
END_IF;

xAvailable := uiCount > UINT#0;
IF xAvailable THEN
    stHead := astBuffer[uiHeadIndex];
ELSE
    stHead := stEmpty;
END_IF;
END_FUNCTION_BLOCK
