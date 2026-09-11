TYPE ST_SEQ_TRACE_TIME :
STRUCT
    xValid : BOOL; // Caller asserts a valid source monotonic sample, not UTC.
    xSynthetic : BOOL; // Explicitly TRUE for offline virtual time.
    udiTickMs : UDINT; // Same epoch/timebase as source; modular 32-bit tick.
END_STRUCT
END_TYPE
