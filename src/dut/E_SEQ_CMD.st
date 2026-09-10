{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_CMD :
(
    None := 0,
    LoadRecipe := 1,
    Start := 2,
    Hold := 3,
    Resume := 4,
    Stop := 5,
    Abort := 6,
    Reset := 7,
    ConfirmStep := 8
) UINT := None;
END_TYPE
