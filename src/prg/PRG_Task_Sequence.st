PROGRAM PRG_Task_Sequence
VAR
    fbSequence : FB_Sequence;
END_VAR

// Call once per cycle. Multi-task integration needs coherent mailboxes; see INTEGRATION.md.
fbSequence(
    xEnable := GVL_SEQ_IF.xEnable,
    stConfig := GVL_SEQ_IF.stConfig,
    udiDeltaMs := GVL_SEQ_IF.udiDeltaMs,
    stTraceTime := GVL_SEQ_IF.stTraceTime,
    stCommand := GVL_SEQ_IF.stCommand,
    stRecipeCandidate := GVL_SEQ_IF.stRecipeCandidate,
    stAuthority := GVL_SEQ_IF.stAuthority,
    stControlResult := GVL_SEQ_IF.stControlResult,
    stControlRuntime := GVL_SEQ_IF.stControlRuntime,
    udiEventAckSessionID := GVL_SEQ_IF.udiEventAckSessionID,
    udiEventAckID := GVL_SEQ_IF.udiEventAckID);

GVL_SEQ_IF.stControlRequest := fbSequence.stControlRequest;
GVL_SEQ_IF.stRuntime := fbSequence.stRuntime;
GVL_SEQ_IF.stCommandResult := fbSequence.stCommandResult;
GVL_SEQ_IF.xEventAvailable := fbSequence.xEventAvailable;
GVL_SEQ_IF.stEvent := fbSequence.stEvent;
GVL_SEQ_IF.uiEventCount := fbSequence.uiEventCount;
GVL_SEQ_IF.udiEventsDropped := fbSequence.udiEventsDropped;
END_PROGRAM
