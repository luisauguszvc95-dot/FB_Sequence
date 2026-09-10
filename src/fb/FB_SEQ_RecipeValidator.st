// Structural validation of a candidate recipe; no machine/process semantics.
// uiInvalidStep is the ARRAY INDEX (1..16), not uiStepID; 0 = header failure.
// Physical profile validation belongs to the Control IF adapter: known profile
// and phase IDs, finite REAL parameters (reject NaN and +/- infinity), units,
// allowed ranges, parameter relationships, and machine/process constraints.
// xValid means structurally valid, not approved for a physical machine.
FUNCTION_BLOCK FB_SEQ_RecipeValidator
VAR_INPUT
    stRecipe : ST_SEQ_RECIPE;
END_VAR
VAR_OUTPUT
    xValid : BOOL;
    eReason : E_SEQ_REASON;
    uiInvalidStep : UINT;
END_VAR
VAR
    uiIndex : UINT;
    uiPrevious : UINT;
END_VAR

xValid := FALSE;
eReason := E_SEQ_REASON.RecipeInvalid;
uiInvalidStep := UINT#0;

IF (stRecipe.udiRecipeID = UDINT#0) OR
   (stRecipe.udiRevision = UDINT#0) THEN
    RETURN;
END_IF;

// Validate cardinality before any array access, including loop bounds.
IF (stRecipe.uiStepCount < UINT#1) OR
   (stRecipe.uiStepCount > UINT#16) THEN
    RETURN;
END_IF;

FOR uiIndex := UINT#1 TO stRecipe.uiStepCount DO
    uiInvalidStep := uiIndex;

    IF (stRecipe.astSteps[uiIndex].uiStepID = UINT#0) OR
       (stRecipe.astSteps[uiIndex].uiPhaseID = UINT#0) OR
       (stRecipe.astSteps[uiIndex].uiProfileID = UINT#0) OR
       (stRecipe.astSteps[uiIndex].udiTimeoutMs = UDINT#0) THEN
        RETURN;
    END_IF;

    IF uiIndex > UINT#1 THEN
        FOR uiPrevious := UINT#1 TO (uiIndex - UINT#1) DO
            IF stRecipe.astSteps[uiPrevious].uiStepID =
               stRecipe.astSteps[uiIndex].uiStepID THEN
                RETURN;
            END_IF;
        END_FOR;
    END_IF;

    CASE stRecipe.astSteps[uiIndex].eKind OF
        E_SEQ_STEP_KIND.WaitQualified:
            IF (stRecipe.astSteps[uiIndex].udiQualifiedMs = UDINT#0) OR
               (stRecipe.astSteps[uiIndex].udiQualifiedMs >
                stRecipe.astSteps[uiIndex].udiTimeoutMs) THEN
                RETURN;
            END_IF;

        E_SEQ_STEP_KIND.WaitComplete,
        E_SEQ_STEP_KIND.WaitOperator:
            // Qualified duration is unused for these completion policies.
            ;

        ELSE
            RETURN;
    END_CASE;
END_FOR;

uiInvalidStep := UINT#0;
eReason := E_SEQ_REASON.None;
xValid := TRUE;
END_FUNCTION_BLOCK
