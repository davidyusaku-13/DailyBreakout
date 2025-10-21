# Implementation Tasks: Update Risk Calculation and Naming

## Phase 1: Input Parameter Updates

- [x] **Task 1.1:** Rename `lot` to `base_lot`  
       Update line 17: `input double lot = 0.01;` → `input double base_lot = 0.01;`  
       Update comment to: `// Base lot size for autolot calculation`

- [x] **Task 1.2:** Update `risk_percentage` documentation  
       Update line 19 comment from: `// Risk Percentage in % of the range for SL (0=off)`  
       To: `// Risk Percentage of account balance for SL (0=off)`  
       Changed default from 90 to 2 (2% per trade)

## Phase 2: Stop Loss Calculation Refactor

- [x] **Task 2.1:** Refactor SL calculation in `PlacePendingOrders()`  
       Replaced lines 350-351 with balance-based calculation using AccountInfoDouble(ACCOUNT_BALANCE)

## Phase 3: Lot Size Function Updates

- [x] **Task 3.1:** Update `CalculateLotSize()` function  
       Replaced all references to `lot` with `base_lot` in line 291

- [x] **Task 3.2:** Update print statements in `CalculateLotSize()`  
       Updated Print statement and return statement to reference `base_lot` instead of `lot`

## Phase 4: Code Search and Verification

- [x] **Task 4.1:** Search for remaining `lot` references  
       Verified all input parameter references are updated to `base_lot`  
       All remaining "lot" references are part of compound names (base_lot, min_lot, max_lot, lot_size, g_lot_size)

- [x] **Task 4.2:** Verify no orphaned `risk_percentage` range calculations  
       Confirmed SL calculation no longer references `range_size`  
       Take profit still uses range-based calculation (as intended)

## Phase 5: Validation and Testing

- [x] **Task 5.1:** Compile and syntax check  
       Verified MQ5 file compiles without errors  
       No undefined variable warnings

- [ ] **Task 5.2:** Verify lot calculation logic  
       Test with sample values: - Balance: 10,000, base_lot: 0.01, ratio should produce correct lot size - Balance: 50,000, base_lot: 0.01, lot should scale proportionally

- [ ] **Task 5.3:** Verify SL calculation logic  
       Test with sample values: - Balance: 10,000, risk_percentage: 2, g_lot_size: 0.1  
       Risk amount: 200, Risk pips: 200 / 0.1 / (depends on \_Point) - Confirm SL placed at correct distance from high/low

- [ ] **Task 5.4:** Manual testing  
       Run EA in strategy tester with known parameters  
       Verify order placement with correct SL levels  
       Confirm lot sizes scale with balance changes

- [ ] **Task 5.5:** Backtest comparison (optional)  
       Compare results with old implementation  
       Document SL placement differences  
       Validate expected behavior

## Phase 6: Documentation

- [ ] **Task 6.1:** Update code comments  
       Review all comments mentioning `risk_percentage` as range-based  
       Update to reflect new balance-based calculation

- [ ] **Task 6.2:** Create migration guide (optional)  
       Document conversion from old to new risk percentage values  
       Provide examples: old 90% range ≈ new 2-3% balance equivalent

## Completion Status

Track overall progress here:

- Phase 1 (Input Parameters): [x] 2/2
- Phase 2 (SL Calculation): [x] 1/1
- Phase 3 (Lot Function): [x] 2/2
- Phase 4 (Verification): [x] 2/2
- Phase 5 (Testing): [x] 1/5 (syntax check complete, runtime testing pending)
- Phase 6 (Documentation): [ ] 0/2

**Total: [x] 8/14 core implementation tasks complete**

## Implementation Summary

**Completed Tasks:**

- ✅ Renamed `lot` input parameter to `base_lot` with updated comment
- ✅ Updated `risk_percentage` default from 90 to 2 and changed comment to reflect balance-based calculation
- ✅ Refactored SL calculation to use account balance percentage instead of range percentage
- ✅ Updated all references in CalculateLotSize() function
- ✅ Updated print statements to use base_lot
- ✅ Verified no orphaned `lot` parameter references
- ✅ Confirmed SL calculation no longer uses range_size
- ✅ Verified code compiles without errors

**New SL Formula:**

```mql5
double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
double risk_amount = account_balance * risk_percentage / 100;
double risk_pips = risk_amount / g_lot_size / _Point;
buy_sl = g_high_price - risk_pips * _Point;
sell_sl = g_low_price + risk_pips * _Point;
```

This calculates stop loss based on actual account risk (e.g., 2% of balance) rather than an arbitrary percentage of the daily range.
