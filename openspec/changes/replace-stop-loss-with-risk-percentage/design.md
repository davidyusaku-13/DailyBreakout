# Design Document: Replace stop_loss with risk_percentage

## Overview

This change renames the `stop_loss` input parameter to `risk_percentage` to clarify that:

1. This parameter is exclusively used for stop loss calculation
2. The value represents the percentage of range used to calculate SL distance
3. No other trading logic depends on this variable

## Current Behavior

**Input Parameter:**

```mql5
input int stop_loss = 90;  // Stop Loss in % of the range (0=off)
```

**Stop Loss Calculation (lines 350-351):**

```mql5
buy_sl = g_high_price - (range_size * stop_loss / 100);
sell_sl = g_low_price + (range_size * stop_loss / 100);
```

**Logic:**

- `stop_loss` is checked with `if (stop_loss > 0)` to determine if SL should be applied
- When SL is enabled, it's calculated as a percentage of the daily range
- For buy orders: SL is placed below the high by `(range_size * stop_loss / 100)` pips
- For sell orders: SL is placed above the low by `(range_size * stop_loss / 100)` pips

## Proposed Behavior

**Input Parameter:**

```mql5
input int risk_percentage = 90;  // Risk Percentage in % of the range for SL (0=off)
```

**Stop Loss Calculation:**

```mql5
buy_sl = g_high_price - (range_size * risk_percentage / 100);
sell_sl = g_low_price + (range_size * risk_percentage / 100);
```

## Architectural Rationale

**Naming Clarity:**

- `risk_percentage` immediately conveys that this parameter controls the risk exposure (via SL placement)
- Previous name `stop_loss` was ambiguous—it could mean "stop loss level" or "percentage used for SL"
- New name establishes clear intent: this percentage represents how much of the range to risk

**Scope Constraint:**

- Explicitly stating "used only for SL calculation" prevents future misuse for other purposes
- Simplifies code review and maintenance
- Reduces cognitive load when reading the code

**No Behavioral Change:**

- Functionality remains identical to the original implementation
- Default value (90%) preserved
- Calculation formula unchanged
- Trading behavior is not affected

## Implementation Strategy

1. **Direct rename:** Replace parameter definition and all references in calculation
2. **Limited scope:** Only touches the `PlacePendingOrders()` function
3. **Low risk:** Simple find-and-replace; no logic changes

## Testing Strategy

- Verify compilation succeeds
- Confirm no lingering references to `stop_loss` in SL calculation context
- Manual testing: place orders and confirm SL is positioned correctly
- Backtest: ensure existing test results remain unchanged

## Rollback

If needed, reverse the change by renaming `risk_percentage` back to `stop_loss` in the three locations (parameter definition and two calculation lines).
