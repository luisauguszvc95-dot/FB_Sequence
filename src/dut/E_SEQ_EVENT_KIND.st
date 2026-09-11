{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_EVENT_KIND :
(
    StateChanged := 1,
    StepChanged := 2,
    CommandResult := 3,
    RecipeLoaded := 4,
    BatchStarted := 5,
    BatchFinished := 6,
    StepStarted := 7,
    StepFinished := 8,
    PromptIssued := 9,
    PromptConfirmed := 10,
    ResourceAcquired := 11,
    ResourceReleased := 12,
    FaultRaised := 13,
    FaultCleared := 14,
    RecipeRejected := 15
) UINT := StateChanged;
END_TYPE
