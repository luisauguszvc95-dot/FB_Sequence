{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_SEQ_REASON :
(
    None := 0,
    Disabled := 1,
    SessionMismatch := 2,
    InvalidRequest := 3,
    WrongProcess := 4,
    InvalidState := 5,
    NoRecipe := 6,
    RecipeInvalid := 7,
    NotReady := 8,
    ControlFault := 9,
    StaleFeedback := 10,
    ResourceLost := 11,
    StepTimeout := 12,
    TransitionTimeout := 13,
    InvalidConfirm := 14,
    ConfigInvalid := 15,
    IntentRejected := 16,
    InvalidRecipeRef := 17,
    CycleInvalid := 18,
    CounterExhausted := 19,
    AuthorityDenied := 20
) UINT := None;
END_TYPE
