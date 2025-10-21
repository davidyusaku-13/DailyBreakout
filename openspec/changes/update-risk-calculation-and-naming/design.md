# Design Document: Update Risk Calculation and Naming

## Overview

This design document outlines two coordinated changes:

1. **Risk Calculation Refactor:** Shift `risk_percentage` calculation from range-based to account balance-based
2. **Variable Naming Improvement:** Rename `lot` to `base_lot` for clarity

## Current Implementation

### Input Parameters

```mql5
input double lot = 0.01;           // Lot size for each base_balance unit
input int risk_percentage = 90;    // Risk Percentage in % of the range for SL (0=off)
```

### Current SL Calculation (Range-Based)

In `PlacePendingOrders()` (lines 350-351):

```mql5
if (risk_percentage > 0)
{
    // Calculate SL based on range percentage
    buy_sl = g_high_price - (range_size * risk_percentage / 100);
    sell_sl = g_low_price + (range_size * risk_percentage / 100);
}
```

### Current Lot Calculation

In `CalculateLotSize()` (lines 272-281):

```mql5
double balance_ratio = account_balance / base_balance;
double lot_size = NormalizeDouble(balance_ratio * lot, 2);  // 'lot' is the multiplier
```

## Proposed Implementation

### Input Parameters

```mql5
input double base_lot = 0.01;      // Base lot size for autolot calculation
input int risk_percentage = 2;     // Risk Percentage of account balance for SL (0=off)
```

### New SL Calculation (Balance-Based)

```mql5
if (risk_percentage > 0)
{
    // Calculate SL based on account balance percentage
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * risk_percentage / 100;

    // Convert risk amount to pips: risk_amount / (lot_size * contract_value_in_points)
    double risk_pips = risk_amount / g_lot_size / _Point;

    buy_sl = g_high_price - risk_pips * _Point;
    sell_sl = g_low_price + risk_pips * _Point;
}
```

### Updated Lot Calculation

In `CalculateLotSize()`:

```mql5
double balance_ratio = account_balance / base_balance;
double lot_size = NormalizeDouble(balance_ratio * base_lot, 2);
```

## Architectural Rationale

### Risk Calculation Shift

**Problem with Current Approach:**

- Range-based SL is arbitrary and disconnected from actual account risk
- On a 500-point range with 90% risk, SL is 450 points away
- On a 100-point range with 90% risk, SL is only 90 points away
- Same parameter produces vastly different risk exposures

**Solution: Balance-Based Calculation:**

- Ties risk to account balance (e.g., "risk 2% per trade")
- Professional standard in money management
- Predictable and manageable risk exposure
- Risk amount = `ACCOUNT_BALANCE * risk_percentage / 100`
- SL in pips = `risk_amount / (lot_size * _Point)`

**Default Value Adjustment:**

- Old: 90% (of range) ≈ very aggressive
- New: 2% (of balance) ≈ standard professional approach
- Subject to user adjustment based on trading style

### Variable Naming

**Problem with `lot`:**

- Ambiguous: could mean fixed lot or lot multiplier
- In context of autolot, it's actually a base multiplier, not an absolute lot size

**Solution: `base_lot`:**

- Explicitly signals it's the foundational unit
- Clear in `balance_ratio * base_lot` formula
- Aligns with similar EA naming conventions

## Implementation Strategy

### Phase 1: Input Parameter Updates

1. Rename parameter definition: `lot` → `base_lot`
2. Update parameter comment to reflect new meaning
3. Adjust `risk_percentage` default and comment

### Phase 2: Stop Loss Calculation Refactor

1. Replace range-based formula with balance-based formula
2. Add account balance retrieval
3. Add risk amount calculation
4. Add pip conversion logic

### Phase 3: Lot Size Function Updates

1. Update `CalculateLotSize()` to use `base_lot` instead of `lot`
2. Update all print statements

### Phase 4: Documentation and Testing

1. Update all comments and print statements
2. Verify compilation
3. Unit test lot calculation with various balances
4. Backtest to confirm expected SL placement

## Risk Assessment

### Breaking Changes

- **Critical:** Existing EA configurations incompatible
- **User Impact:** Must reconfigure `risk_percentage` value
- **Workaround:** Document old-to-new conversion guide

### Data Validation

- Ensure `risk_percentage > 0` before calculations
- Validate `g_lot_size > 0` before division
- Handle edge case where risk amount exceeds maximum SL distance

### Testing Strategy

1. **Unit Tests:** Verify lot calculation with known balance values
2. **Integration Tests:** Confirm SL placed at correct price levels
3. **Edge Cases:**
   - Very small lot sizes
   - Very large lot sizes
   - Risk percentage = 0 (disabled)
   - Extreme balance changes

## Rollback Strategy

If issues arise:

1. Revert parameter names: `base_lot` → `lot`
2. Revert SL formula to range-based calculation
3. Restore old default values
4. No data migration needed

## Performance Considerations

- **Minimal Impact:** Risk calculation called once per day during order placement
- **Account Balance Query:** `AccountInfoDouble()` is fast; no performance concerns
- \*\*No additional loops or complex operations introduced

## Future Considerations

- Could add validation to ensure SL fits within acceptable distance
- Could add warnings if calculated SL is too close to entry
- Could add configuration option to use minimum or maximum SL
