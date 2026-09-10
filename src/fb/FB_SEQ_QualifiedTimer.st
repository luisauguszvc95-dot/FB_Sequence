// Accumulate only qualified active time. Call exactly once per Sequence cycle.
// The caller supplies measured/validated cycle delta; this is not a wall clock.
// Disabling or losing qualification retains elapsed time. Reset dominates.
// Keep target fixed during a step; reducing it clamps the stored elapsed value.
FUNCTION_BLOCK FB_SEQ_QualifiedTimer
VAR_INPUT
    xReset : BOOL;
    xEnable : BOOL;
    xQualified : BOOL;
    udiDeltaMs : UDINT;
    udiTargetMs : UDINT;
END_VAR
VAR_OUTPUT
    udiElapsedMs : UDINT;
    xDone : BOOL;
END_VAR

IF xReset THEN
    udiElapsedMs := UDINT#0;
ELSE
    IF xEnable AND xQualified THEN
        udiElapsedMs := F_SEQ_AddMs(
            udiValue := udiElapsedMs,
            udiDelta := udiDeltaMs);
    END_IF;
    IF udiElapsedMs > udiTargetMs THEN
        udiElapsedMs := udiTargetMs;
    END_IF;
END_IF;

// Zero is an invalid target, never an immediately completed duration.
xDone := (udiTargetMs > UDINT#0) AND (udiElapsedMs >= udiTargetMs);
END_FUNCTION_BLOCK
