# Change Proposal: Update Risk Calculation and Naming

**Change ID:** `update-risk-calculation-and-naming`  
**Status:** Pending Review  
**Date Created:** 2025-10-21

## Summary

This proposal encompasses two coordinated changes:

1. **Risk Calculation:** Change `risk_percentage` from being a percentage of the daily range to a percentage of account balance. This allows stop loss to be calculated based on actual account risk exposure rather than arbitrary range percentages.

2. **Variable Naming:** Rename the `lot` input parameter to `base_lot` to clarify its role as the base unit of lot size used in autolot calculations.

Both changes improve code clarity and align the EA with standard risk management practices where position sizing is based on account balance and risk tolerance.

## Motivation

### Risk Calculation Change

- **Industry Practice:** Professional traders size positions based on account risk percentage, not range size
- **Better Risk Control:** Directly ties stop loss to account balance, providing predictable risk per trade
- **Clarity:** `risk_percentage` now means "% of balance to risk per trade" rather than arbitrary range percentage
- **Flexibility:** Decouples SL calculation from daily range volatility

### Naming Change

- **Clarity:** `base_lot` explicitly indicates this is the foundational lot unit for scaling
- **Context:** In autolot calculations, it's the base multiplier applied to the balance ratio
- **Consistency:** Better names in the `CalculateLotSize()` function where lot scaling occurs

## Scope

**Affected Components:**

1. **Input Parameters (lines 15-20):**

   - Rename `lot` → `base_lot`
   - Modify `risk_percentage` comment/semantics (now % of balance, not % of range)

2. **PlacePendingOrders() Function (lines ~320-360):**

   - Remove dependency on `range_size` for SL calculation
   - Change SL calculation to: `buy_sl = g_high_price - (AccountInfoDouble(ACCOUNT_BALANCE) * risk_percentage / 100) / g_lot_size / _Point`
   - Update sell SL similarly

3. **CalculateLotSize() Function (lines ~262-289):**

   - Update references from `lot` to `base_lot`
   - Update Print statements to reference `base_lot`

4. **Comments and Print Statements:**
   - Update all references to clarify new semantics

**Out of Scope:**

- Take profit calculation (remains range-based)
- Trailing stop logic
- Autolot enable/disable functionality
- Other order placement logic

## Key Changes

### Current Risk Calculation (% of Range)

```mql5
// Old: SL based on range percentage
buy_sl = g_high_price - (range_size * risk_percentage / 100);
sell_sl = g_low_price + (range_size * risk_percentage / 100);
```

### New Risk Calculation (% of Balance)

```mql5
// New: SL based on account balance percentage
double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percentage / 100;
double risk_pips = (risk_amount / g_lot_size) / _Point;
buy_sl = g_high_price - risk_pips * _Point;
sell_sl = g_low_price + risk_pips * _Point;
```

### Variable Renaming

```mql5
// Old
input double lot = 0.01;  // Lot size for each base_balance unit

// New
input double base_lot = 0.01;  // Base lot size for autolot calculation
```

## Acceptance Criteria

- [ ] `lot` input parameter renamed to `base_lot` throughout codebase
- [ ] `risk_percentage` semantics changed from range-based to balance-based
- [ ] SL calculation uses new formula: `(ACCOUNT_BALANCE * risk_percentage / 100) / g_lot_size / _Point`
- [ ] All print statements updated to reference `base_lot` instead of `lot`
- [ ] Code compiles without errors
- [ ] Function behavior is correct for both Buy and Sell orders
- [ ] Default value for `risk_percentage` adjusted to reflect new semantics (may need testing)

## Notes

- **Default Value:** The original default of 90% may need adjustment after testing, as it now means "risk 90% of balance" instead of "use 90% of range for SL"
- **Testing:** Backtests using the old change will have different results due to different SL placement
- **Backward Compatibility:** This is a breaking change; existing EA configurations are incompatible

## Implementation Notes

- This change builds on the previous `replace-stop-loss-with-risk-percentage` change
- Both changes work together to improve risk management clarity
- Need to handle the relationship between lot size and risk calculation carefully
