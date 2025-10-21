# Implementation Tasks

## Phase 1: Code Changes

- [x] **Task 1.1:** Replace input parameter  
      Replace `input int stop_loss = 90;` with `input int risk_percentage = 90;` at line 20

- [x] **Task 1.2:** Update SL calculation in PlacePendingOrders()  
      Replace `range_size * stop_loss / 100` with `range_size * risk_percentage / 100` in two locations:
  - Buy SL calculation (line 350)
  - Sell SL calculation (line 351)

## Phase 2: Validation

- [x] **Task 2.1:** Verify code compiles  
      Ensure the modified MQ5 file has no syntax errors

- [x] **Task 2.2:** Confirm no other references  
      Search codebase to ensure `stop_loss` is not referenced elsewhere in SL calculation logic

- [x] **Task 2.3:** Functional verification  
      Confirm that stop loss orders are still placed correctly with the new parameter

## Completion Checklist

All items complete - implementation finished.
