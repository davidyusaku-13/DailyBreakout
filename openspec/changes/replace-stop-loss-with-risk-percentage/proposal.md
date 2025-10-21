# Change Proposal: Replace stop_loss with risk_percentage

**Change ID:** `replace-stop-loss-with-risk-percentage`  
**Status:** Pending Review  
**Date Created:** 2025-10-21

## Summary

Replace the `stop_loss` input parameter with a new `risk_percentage` parameter. The new `risk_percentage` variable will be used exclusively for stop loss (SL) calculation in the DailyBreakout EA. This change clarifies intent by decoupling SL configuration from any other uses and makes the codebase more maintainable.

## Motivation

- **Clarity:** `risk_percentage` explicitly signals that this parameter controls risk via SL placement, not any other trading logic
- **Scope:** The constraint "used only for SL calculation" ensures no accidental reuse for other purposes
- **Maintainability:** Clearer naming improves future maintenance and code review

## Scope

**Affected Components:**

- Input parameter definition (line 20)
- Stop loss calculation logic in `PlacePendingOrders()` function (lines 347–351)

**Out of Scope:**

- Trailing stop logic (independent of this change)
- Take profit calculation
- Any other order placement logic

## Acceptance Criteria

- [ ] `stop_loss` input parameter is removed
- [ ] New `risk_percentage` input parameter is added with same default value (90)
- [ ] SL calculation uses `risk_percentage` instead of `stop_loss`
- [ ] Code compiles and maintains existing functionality
- [ ] Variable name `risk_percentage` is used only in SL calculation context

## Notes

- The `risk_percentage` parameter will have identical functionality to the original `stop_loss` parameter
- Default value remains 90 (representing 90% of range size for SL calculation)
- No behavioral changes; this is a naming/clarity refactor
