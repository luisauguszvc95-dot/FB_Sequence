{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_ACTION :
(
    None := 0,
    Acquire := 1,
    Execute := 2,
    Hold := 3,
    Complete := 4,
    Stop := 5,
    Abort := 6,
    Release := 7
) UINT := None;
END_TYPE
