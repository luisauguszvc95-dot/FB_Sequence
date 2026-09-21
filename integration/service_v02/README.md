# Optional Sequence 0.2 → Service 2.0 mapper

Current compatibility candidate: [transactional ingress and full-envelope receipt
gate](PATCH_COMPATIBILITY.md). Exact Service dependency: `service_dependency.json`.
The historical ingestion gap described below applies to the earlier `b2140a5`
baseline. The new patch closes cursor-before-insertion loss and adds an explicit
insertion receipt; full-source transport and native integration remain pending.

Status: **offline integration draft; not connected, not natively compiled, no
end-to-end audit acceptance claim.** The Sequence and Service demos remain
independent. Nothing here belongs in the isolated Sequence demo task.

Earlier dependency: [FB_Service `refactor/service-core-v0.2`, `b2140a5`](https://github.com/luisauguszvc95-dot/FB_Service/tree/b2140a5ab4756f1c435ebcf7848270dad2f097d5).
The repository version `v0.2` uses Service **wire schema 2.0**. It is not the
old `main` contract and has no `ST_SVC_SequenceSnapshot` or command dispatcher.

## Boundary and data retained

`FB_SEQ_ToServiceAdapter` translates one immutable public Sequence event. It
does not execute recipes, dispatch commands, authorize Control, infer safety,
calculate OEE, write I/O, publish MQTT, or access a database.

| Output | Meaning |
| --- | --- |
| `stEnvelope.stSourceEvent` | Full copy of the source `ST_SEQ_EVENT`, including command correlation, requested context, authority, intent, resource, phase/profile and occurrence-time provenance |
| `stEnvelope.stServiceEvent` | Partial `ST_SVC_EventInput` projection for searching/categorizing |
| `stEnvelope.udiMappingRevision` | Externally configured, stable mapping revision |
| `stEnvelope.xProjectionLossless` | Always `FALSE`; the generic Service DTO cannot hold all source fields |
| `xEnvelopeValid` | Full envelope may be consumed while source publication remains permitted |
| `xAck` and `udiEventAckSessionID` / `udiEventAckID` | Receipt-gated ACK held for the exact owned head until it changes; not automatically written to Sequence |

The identity is `(MachineID, ProducerSourceID, ProcessID, SessionID, EventID)`.
Configure a distinct nonzero producer SourceID for each Sequence instance so
Service's narrower `(SourceID, Epoch, Seq)` identity remains unique. The source
event's existing `uiSourceID` identifies a command origin: it MUST NOT replace
`uiProducerSourceID` in the producer header or be claimed as an authenticated
operator. Actor remains `UNKNOWN / 0`; external actor enrichment requires its
own evidence and must preserve the original record.

## Projection contract

| Source | Service projection |
| --- | --- |
| `uiProducerSourceID`, `udiSessionID`, `udiEventID` | Header SourceID, SourceEpoch, SourceSeq |
| Configured `udiProducerID` | Header ProducerID; ProducerKind is `SEQUENCE_SOURCE` |
| `udiOccurrenceTickMs` | Header tick and event `stTime.udiTickMs` |
| `xOccurrenceTimeValid` | `stTime.xValid`: known source monotonic time, NOT synchronized UTC |
| No UTC measurement supplied | UTC/clock-source remain zero, time quality `UNSYNCHRONIZED` |
| Synthetic/invalid occurrence time | Data quality `UNCERTAIN`; otherwise `GOOD` |
| Batch/recipe/revision/process/step | The corresponding `stContext` fields; unsupported MES IDs remain zero/unknown |
| `eKind`, `eReason` | Exact numeric `uiEventCode`, `uiReasonID`, using the versioned Sequence enums |
| `eStateBefore`, `eState` | `dwOldState`, `dwNewState` |
| `uiStepIDBefore`, `uiStepID` | `diOldValue`, `diNewValue`; these fields mean step IDs in this mapper |
| `udiRequestID` | CorrelationID; full session/origin/request tuple is only in the source sidecar |

If `xOccurrenceTimeValid=FALSE`, the full envelope remains available but its
generic `stServiceEvent.xValid` and header valid are FALSE. The Service collector
would otherwise replace invalid source time with Service ingestion time. This
mapper blocks that projection instead of presenting a fabricated occurrence
time. The sidecar still preserves the unknown-time fact for an approved sink.

Event kinds 1–15 map explicitly. Fault events are process transitions, not
invented alarm occurrences. Recipe load is context change, not an approval or
new recipe revision. Phase/profile IDs are not silently relabeled as MES
segments. `ST_SVC_OperationsInput` is deliberately not generated: planning,
quantities, rates and final quality belong to their actual providers, not to a
guess from `Running`. A separate application-owned composer will join those
inputs for Service's operational OEE; MES owns official consolidation.

## Receipt protocol: default is NO ACK

The consumer must copy and assume responsibility for the **full envelope**
before setting `ST_SEQ_SVC_RECEIPT.xFullEnvelopeOwned`. A generic projection
alone is insufficient. Receipt must echo mapping revision plus all five source
identity fields. The adapter must first observe `xValid=FALSE` while this exact
head is eligible, and then receive matching `xValid=TRUE`. Preheld receipts,
wrong identities, repeated receipts, and receipts while disabled or publication
is withdrawn do not release another event. Once full ownership is established,
ACK is held/retried for that exact source head while it remains eligible; queue
ACK is idempotent. Publication revocation suppresses ACK, and regrant restores
the already-owned head's ACK, avoiding a lost-one-scan-ACK deadlock. A new head
always needs its own low-then-matching receipt cycle.

Unowned pending data is never replaced by a new source identity or reinterpreted
under a changed mapping. `xPendingConflict` inhibits publication/ACK; reconcile
the retained envelope before a controlled adapter reinitialization. Do not use
reinitialization as a data-discard mechanism. A source boot/session change is a
continuity boundary, not implicit permission to discard an unowned old event.

The exact ownership level must be agreed by the integration: a downstream
reliable queue may assume volatile retry ownership, but durable acceptance
requires a committed full record. This adapter supplies neither persistence nor
authentication of receipts. Bind the receipt writer to the approved consumer;
do not map it to an operator toggle or an untrusted transport field.

Pass **all four FB inputs explicitly every invocation**. As with IEC FB calls,
an omitted input can retain its previous value; omission is not revocation.
Fresh unconfigured instances fail closed. To revoke publication, explicitly
pass `xEventAvailable := FALSE`; to disable, pass a config with `xEnable=FALSE`.

### Historical Service ingestion gap — earlier baseline

At the earlier `b2140a5` commit, `FB_SVC_EventCollector` advances its per-slot dedup cursor
before `FB_Service` attempts an outbox push. A full outbox, disabled Service,
invalid config, or boot mismatch can leave an event marked seen without a
queued record. `FB_Service` exposes no per-event successful-ingestion ACK.
Retrying the same slot/identity then cannot recover that missing record.

Therefore **never derive the Sequence receipt from assigning `aEvents`, a scan
elapsed, an accepted count, or `ST_SVC_AuditAck` alone**. The latter carries only
Service BootID/RecordID and cannot identify ownership of the full source event.
Service's generic DTO and fixed wire image also lack the full source sidecar.
The historian's additive JSON support does not fill that PLC/wire gap.

Required integration work remains: preserve the full source sidecar through the
approved sink and return an exact full-envelope receipt, or extend Service
transactional ingress/typed payload plus its wire/sink contract. This folder
does not alter Service to do either. Until then leave the receipt invalid.
For an eventual projection connection, dedicate a fixed `aEvents[1..8]` slot to
each producer: Service deduplicates by slot, so moving the same event between
slots can duplicate it. Copy consistently within one task; a BOOL valid flag
alone does not make cross-task STRUCT copying atomic.

## Import and checks — separate offline project only

1. Complete the isolated Sequence and Service tests first. Keep their current
   demo tasks and Watches unchanged.
2. In a separate offline integration project import the pinned Service types:
   `E_SVC_ActorKind`, `E_SVC_DataQuality`, `E_SVC_TimeQuality`, `E_SVC_Domain`,
   `E_SVC_EventKind`, `ST_SVC_SourceHeader`, `ST_SVC_TimeContext`,
   `ST_SVC_OperationsContext`, `ST_SVC_EventInput`. Use each canonical DUT once;
   do not create renamed or duplicated copies.
3. Import Sequence 0.2 enums and `ST_SEQ_EVENT`, then this folder's three DUTs
   and `FB_SEQ_ToServiceAdapter`. Compile natively in Machine Expert 2.6.
   Config must use target major/minor `2/0`, a nonzero mapping revision and
   verified nonzero machine/producer/process identities. No native compilation
   has yet been performed by these repository checks.
4. Run `python -m unittest discover -s integration/service_v02/tests -v` from
   the repository root. These are protocol-model/static tests, not ST execution.
   Repeat the receipt cases natively before considering any connection.
5. Proceed to actual Sequence + Service integration only after full-payload
   retention, transaction/receipt semantics, task consistency and restart-loss
   behavior are resolved and tested. Physical Control integration is a later
   gate, outside this mapper.

Dependency identity check (read-only):
`python integration/service_v02/verify_service_dependency.py PATH_TO_FB_SERVICE`.
It checks the canonical DUT blob hashes listed in the dependency manifest. A different
checkout or line endings fails closed and requires review; this is not a
compiler. The dependency is not vendored in this repository.

For the native offline receipt test import
`tests/PRG_SEQ_ServiceAdapterTests.st` from this folder and schedule only that
test program in the isolated integration application. The expected target
result is `xDone=TRUE / uiChecks=23 / uiFailures=0 / uiFirstFailure=0`.
This expectation is **not yet verified on Machine Expert**. The test performs
bounded sequential adapter calls with no I/O, Service instance or network.
