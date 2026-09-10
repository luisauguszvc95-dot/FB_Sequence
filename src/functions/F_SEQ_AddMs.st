// Saturating unsigned addition. Check remaining capacity before adding.
// Usable for elapsed milliseconds and diagnostic counters.
FUNCTION F_SEQ_AddMs : UDINT
VAR_INPUT
    udiValue : UDINT;
    udiDelta : UDINT;
END_VAR
VAR CONSTANT
    C_MAX : UDINT := UDINT#4294967295;
END_VAR

IF udiDelta > (C_MAX - udiValue) THEN
    F_SEQ_AddMs := C_MAX;
ELSE
    F_SEQ_AddMs := udiValue + udiDelta;
END_IF;
END_FUNCTION
