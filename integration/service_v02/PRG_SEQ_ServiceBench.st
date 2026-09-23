// OFFLINE SIMULATOR ONLY. Independent instances; no GVL, I/O or network writer.
// Select this program alone in one cyclic simulation task. Native execution is pending.
PROGRAM PRG_SEQ_ServiceBench
VAR
    xEnableBench : BOOL := FALSE;
    xAllowRequests : BOOL := FALSE;
    xAllowExecution : BOOL := FALSE;
    xAllowPublication : BOOL := FALSE;
    xQualified : BOOL := FALSE;
    xStepComplete : BOOL := FALSE;
    xFinishActions : BOOL := FALSE;
    xMockFaulted : BOOL := FALSE;
    xMockRejectRequest : BOOL := FALSE;
    udiAuthorityID : UDINT := 17;
    stSequenceCfg : ST_SEQ_CONFIG := (uiProcessID := 7, udiSessionID := 1001,
        udiMaxFeedbackAgeMs := 250, udiTransitionTimeoutMs := 5000,
        udiMaxCycleMs := 100, uiMachineID := 1, uiProducerSourceID := 301);
    stMapCfg : ST_SEQ_SVC_CONFIG := (uiServiceContractMajor := 2,
        uiServiceContractMinor := 0, udiMappingRevision := 1,
        uiExpectedMachineID := 1, uiExpectedProducerSourceID := 301,
        uiExpectedProcessID := 7, udiProducerID := 301);
    stServiceCfg : ST_SVC_Config;
    stTraceTime : ST_SEQ_TRACE_TIME;
    stServiceTime : ST_SVC_TimeContext;
    stCommand : ST_SEQ_COMMAND_REQUEST;
    stRecipe : ST_SEQ_RECIPE;
    // The sole external writer may copy the ACTUAL sink receipt after file COMMIT.
    // First observe this raw receipt invalid while xCaptureReady; never synthesize ownership.
    stSinkReturned : ST_SEQ_SVC_SINK_RECEIPT;
    // Separate audit channel: no value is derived from source/sink receipt.
    stAuditAck : ST_SVC_AuditAck;
    stRuntimeUnknown : ST_SVC_RuntimeInput;
    stOperationsUnknown : ST_SVC_OperationsInput;
    aAlarmUnknown : ARRAY[1..16] OF ST_SVC_AlarmCondition;
    aEvents : ARRAY[1..8] OF ST_SVC_EventInput;
    stNoEvent : ST_SVC_EventInput;
    stCaptureEnvelope : ST_SEQ_SVC_ENVELOPE;
    stCaptureIngress : ST_SVC_EventReceipt;
    stEmptyEnvelope : ST_SEQ_SVC_ENVELOPE;
    stEmptyIngress : ST_SVC_EventReceipt;
    xCaptureReady : BOOL;
    xPublicationAllowed : BOOL;
    udiSourceAckSession : UDINT;
    udiSourceAckEvent : UDINT;
    fbControlMock : FB_SEQ_ControlMock;
    fbSequence : FB_Sequence;
    fbMapper : FB_SEQ_ToServiceAdapter;
    fbService : FB_Service;
    fbReceiptGate : FB_SEQ_ServiceReceiptGate;
    xInitialized : BOOL;
END_VAR

IF NOT xInitialized THEN
    stServiceCfg.uiContractMajor := UINT#2;
    stServiceCfg.uiContractMinor := UINT#0;
    stServiceCfg.udiConfigRevision := UDINT#1;
    stServiceCfg.udiBootID := UDINT#2002;
    stServiceCfg.uiServiceSourceID := UINT#900;
    stServiceCfg.stAsset.uiMachineID := UINT#1;
    stServiceCfg.stAsset.uiWorkUnitID := UINT#1;
    stServiceCfg.udiRuntimeFreshnessMs := UDINT#500;
    stServiceCfg.udiOperationsFreshnessMs := UDINT#500;
    stServiceCfg.udiAlarmFreshnessMs := UDINT#500;
    // No OEE or equipment facts are invented for this event-only composition.
    stServiceCfg.stOEEPolicy.xEnabled := FALSE;
    stRecipe.udiRecipeID := UDINT#1;
    stRecipe.udiRevision := UDINT#1;
    stRecipe.uiStepCount := UINT#1;
    stRecipe.astSteps[1].uiStepID := UINT#10;
    stRecipe.astSteps[1].uiPhaseID := UINT#10;
    stRecipe.astSteps[1].uiProfileID := UINT#100;
    stRecipe.astSteps[1].eKind := E_SEQ_STEP_KIND.WaitQualified;
    stRecipe.astSteps[1].udiQualifiedMs := UDINT#250;
    stRecipe.astSteps[1].udiTimeoutMs := UDINT#10000;
    xInitialized := TRUE;
END_IF;

stTraceTime.udiTickMs := F_SEQ_AddMs(stTraceTime.udiTickMs, UDINT#20);
stTraceTime.xValid := stTraceTime.udiTickMs < UDINT#4294967295;
stTraceTime.xSynthetic := TRUE;
stServiceTime.xValid := stTraceTime.xValid;
stServiceTime.udiTickMs := stTraceTime.udiTickMs;
stServiceTime.eQuality := E_SVC_TimeQuality.UNSYNCHRONIZED;

// Previous scan's request enters the Control test double, which owns permissions.
fbControlMock(xEnable := xEnableBench, stRequest := fbSequence.stControlRequest,
    stConfig := stSequenceCfg, xAllowRequests := xAllowRequests,
    xAllowExecution := xAllowExecution, xAllowPublication := xAllowPublication,
    xQualified := xQualified, xStepComplete := xStepComplete,
    xFaulted := xMockFaulted, xRejectRequest := xMockRejectRequest,
    xFinishActions := xFinishActions, udiAuthorityID := udiAuthorityID);
xPublicationAllowed := xEnableBench AND fbControlMock.stAuthority.xValid
    AND fbControlMock.stAuthority.xAllowPublication
    AND (fbControlMock.stAuthority.udiSessionID = stSequenceCfg.udiSessionID)
    AND (fbControlMock.stAuthority.uiProcessID = stSequenceCfg.uiProcessID)
    AND (fbControlMock.stAuthority.udiAuthorityID <> UDINT#0)
    AND (fbControlMock.stAuthority.udiAgeMs <= stSequenceCfg.udiMaxFeedbackAgeMs);

// Only the previous mapper output is a source ACK, and only under current publication permission.
udiSourceAckSession := UDINT#0;
udiSourceAckEvent := UDINT#0;
IF xPublicationAllowed AND fbMapper.xAck THEN
    udiSourceAckSession := fbMapper.udiEventAckSessionID;
    udiSourceAckEvent := fbMapper.udiEventAckID;
END_IF;
fbSequence(xEnable := xEnableBench, stConfig := stSequenceCfg,
    udiDeltaMs := UDINT#20, stTraceTime := stTraceTime,
    stCommand := stCommand, stRecipeCandidate := stRecipe,
    stAuthority := fbControlMock.stAuthority, stControlResult := fbControlMock.stResult,
    stControlRuntime := fbControlMock.stRuntime,
    udiEventAckSessionID := udiSourceAckSession, udiEventAckID := udiSourceAckEvent);

// One mapper call per scan. Its receipt input is the gate's previous scan output.
stMapCfg.xEnable := xPublicationAllowed;
fbMapper(stCfg := stMapCfg, xEventAvailable := fbSequence.xEventAvailable,
    stEvent := fbSequence.stEvent, stReceipt := fbReceiptGate.stReceipt);
aEvents[1] := stNoEvent;
IF fbMapper.xEnvelopeValid THEN
    // Level held, immutable, fixed producer slot 1 until ownership is confirmed.
    aEvents[1] := fbMapper.stEnvelope.stServiceEvent;
END_IF;
stServiceCfg.xEnabled := xEnableBench;
fbService(stCfg := stServiceCfg, stTime := stServiceTime,
    stRuntime := stRuntimeUnknown, stOperations := stOperationsUnknown,
    aAlarmConditions := aAlarmUnknown, aEvents := aEvents,
    stAuditAck := stAuditAck, xResetOEEWindow := FALSE, udiNextOEEWindowID := UDINT#0);
fbReceiptGate(xEnable := xPublicationAllowed,
    xEnvelopeValid := fbMapper.xEnvelopeValid, stEnvelope := fbMapper.stEnvelope,
    stIngress := fbService.aEventReceipts[1], stSink := stSinkReturned);

// Same-task export view: capture these two complete structures together.
// An IDE/platform exporter must still be validated; this POU does not serialize files.
xCaptureReady := fbReceiptGate.xEligible;
stCaptureEnvelope := stEmptyEnvelope;
stCaptureIngress := stEmptyIngress;
IF xCaptureReady THEN
    stCaptureEnvelope := fbMapper.stEnvelope;
    stCaptureIngress := fbService.aEventReceipts[1];
END_IF;
END_PROGRAM
