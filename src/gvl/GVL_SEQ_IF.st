{attribute 'qualified_only'}
VAR_GLOBAL
    // SAMPLE configuration only. Control/integration owns boot SessionID.
    // Configure once before the first invocation; reinitialize FB for a new epoch.
    stConfig : ST_SEQ_CONFIG := (uiProcessID := 1, udiSessionID := 1,
        udiMaxFeedbackAgeMs := 250, udiTransitionTimeoutMs := 5000, udiMaxCycleMs := 100);
    xEnable : BOOL := FALSE;
    udiDeltaMs : UDINT; // Caller supplies measured monotonic elapsed time.
    stTraceTime : ST_SEQ_TRACE_TIME; // Defaults unknown; clock owner supplies source sample.

    // External command dispatcher/catalog -> Sequence; one serialized writer.
    // Observation-only FB_Service v0.2 is NOT this command writer.
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stRecipeCandidate : ST_SEQ_RECIPE;
    // Consumer ownership receipt translated by integration; never ACK on DTO copy.
    udiEventAckSessionID : UDINT;
    udiEventAckID : UDINT;

    // Control -> Sequence. Coherent process projection; does not own raw equipment state.
    stAuthority : ST_SEQ_CONTROL_AUTHORITY;
    stControlResult : ST_SEQ_CONTROL_RESULT;
    stControlRuntime : ST_SEQ_CONTROL_RUNTIME;

    // Sequence -> Control IF. Permission is checked again by Control at consumption.
    stControlRequest : ST_SEQ_CONTROL_REQUEST;

    // Sequence -> Service; empty/invalid unless Control allows publication.
    stRuntime : ST_SEQ_RUNTIME;
    stCommandResult : ST_SEQ_COMMAND_RESULT;
    xEventAvailable : BOOL;
    stEvent : ST_SEQ_EVENT;
    uiEventCount : UINT;
    udiEventsDropped : UDINT;
END_VAR
