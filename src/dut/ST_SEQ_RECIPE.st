TYPE ST_SEQ_RECIPE :
STRUCT
    udiRecipeID : UDINT;
    udiRevision : UDINT;
    uiStepCount : UINT;
    astSteps : ARRAY[1..16] OF ST_SEQ_STEP;
END_STRUCT
END_TYPE
