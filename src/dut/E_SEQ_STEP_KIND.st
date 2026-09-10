{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_STEP_KIND :
(
    WaitQualified := 0,
    WaitComplete := 1,
    WaitOperator := 2
) UINT := WaitQualified;
END_TYPE
