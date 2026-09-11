TYPE ST_SEQ_SVC_CONFIG :
STRUCT
    xEnable : BOOL;
    uiServiceContractMajor : UINT;
    uiServiceContractMinor : UINT;
    udiMappingRevision : UDINT;
    uiExpectedMachineID : UINT;
    uiExpectedProducerSourceID : UINT;
    uiExpectedProcessID : UINT;
    udiProducerID : UDINT;
END_STRUCT
END_TYPE
