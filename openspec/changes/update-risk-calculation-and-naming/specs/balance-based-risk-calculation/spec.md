# Specification: Balance-Based Risk Calculation

**Specification ID:** `balance-based-risk-calculation`  
**Related Change:** `update-risk-calculation-and-naming`  
**Status:** Draft

## MODIFIED Requirements

### Requirement: Risk Percentage Based on Account Balance

**ID:** `risk-calc-balance-based`

**Description:**  
The `risk_percentage` input parameter now specifies the percentage of account balance to risk per trade, used to calculate stop loss placement. Instead of being a percentage of the daily range, it is now a percentage of the trader's account balance.

**Type:** Core Calculation Logic

**Formula:**

```
risk_amount = ACCOUNT_BALANCE * (risk_percentage / 100)
risk_pips = risk_amount / lot_size / _Point
SL_distance = risk_pips * _Point
```

**Acceptance Criteria:**

- [ ] Risk amount is calculated as: `AccountInfoDouble(ACCOUNT_BALANCE) * risk_percentage / 100`
- [ ] Stop loss distance in pips is: `risk_amount / g_lot_size / _Point`
- [ ] Buy stop loss placed at: `g_high_price - (risk_pips * _Point)`
- [ ] Sell stop loss placed at: `g_low_price + (risk_pips * _Point)`
- [ ] When `risk_percentage = 0`, SL calculation is disabled
- [ ] Default value adjusted to 2 (representing 2% of account balance per trade)

#### Scenario: Small Account with 2% Risk

- Given: Account balance = $10,000, risk_percentage = 2, lot_size = 0.1
- When: SL is calculated
- Then:
  - Risk amount = $10,000 \* 0.02 = $200
  - Risk pips = $200 / 0.1 / (point_value) = expected distance
  - SL is placed at distance matching $200 loss if trade hits SL

#### Scenario: Large Account with 2% Risk

- Given: Account balance = $100,000, risk_percentage = 2, lot_size = 1.0
- When: SL is calculated
- Then:
  - Risk amount = $100,000 \* 0.02 = $2,000
  - Risk pips = $2,000 / 1.0 / (point_value) = expected distance
  - SL is placed at distance matching $2,000 loss if trade hits SL

#### Scenario: Risk Disabled

- Given: risk_percentage = 0
- When: Orders are placed
- Then: Stop loss calculation is skipped, buy_sl and sell_sl remain at 0

### Requirement: Account Balance Integration

**ID:** `risk-calc-account-integration`

**Description:**  
Risk calculation queries the account balance at order placement time and incorporates it into SL calculation, ensuring risk adapts to account equity changes.

**Type:** Integration

**Acceptance Criteria:**

- [ ] `AccountInfoDouble(ACCOUNT_BALANCE)` is called during `PlacePendingOrders()`
- [ ] Account balance is cached in a local variable for calculation consistency
- [ ] Lot size (g_lot_size) is used in the calculation to relate balance to position size
- [ ] Calculation occurs only when `risk_percentage > 0`

#### Scenario: Equity Growth During Trading

- Given: Initial account balance = $10,000, risk_percentage = 2
- When: After some profit, balance becomes $12,000 and new orders placed
- Then: New SL is calculated based on $12,000 balance (2% = $240 risk instead of $200)

### Requirement: Validation and Safety

**ID:** `risk-calc-validation`

**Description:**  
Risk calculation validates inputs to prevent invalid calculations.

**Type:** Safety

**Acceptance Criteria:**

- [ ] Division by zero is prevented (g_lot_size must be > 0)
- [ ] Negative risk_percentage is handled (treated as 0 or clamped)
- [ ] SL placement respects minimum distance from entry (if applicable)
- [ ] Extreme risk values are logged with warnings

#### Scenario: Very Small Lot Size

- Given: risk_percentage = 2, lot_size = 0.01 (very small)
- When: SL is calculated
- Then: Calculation completes without division errors, results in large SL distance

## REMOVED Requirements

### Requirement: Range-Based Risk Calculation

**ID:** `risk-calc-range-based` (DEPRECATED)

**Description:**  
The old implementation where `risk_percentage` was a percentage of the daily range is removed.

```mql5
// OLD - NO LONGER USED
buy_sl = g_high_price - (range_size * risk_percentage / 100);
sell_sl = g_low_price + (range_size * risk_percentage / 100);
```

**Reason:** Replaced with balance-based calculation to provide industry-standard risk management.

## Cross-References

- Related: `parameter-naming-clarity` (works together with base_lot rename)
- Supersedes: Previous `replace-stop-loss-with-risk-percentage` change (which renamed the parameter)
- Impact: Risk management architecture of DailyBreakout EA
