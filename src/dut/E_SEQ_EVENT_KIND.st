{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_EVENT_KIND :
(
    StateChanged := 1,
    StepChanged := 2,
    CommandResult := 3,
    RecipeLoaded := 4
) UINT := StateChanged;
END_TYPE
