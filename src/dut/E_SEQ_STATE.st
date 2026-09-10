{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_STATE :
(
    Idle := 0,
    Starting := 10,
    Running := 20,
    Holding := 30,
    Held := 40,
    Completing := 50,
    Complete := 60,
    Stopping := 70,
    Stopped := 80,
    Aborting := 90,
    Aborted := 100,
    Faulted := 110
) UINT := Idle;
END_TYPE
