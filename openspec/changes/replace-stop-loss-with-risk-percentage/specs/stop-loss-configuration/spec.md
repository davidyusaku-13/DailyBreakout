# Specification: Stop Loss Configuration

**Status:** Draft  
**Version:** 1.0

## Overview

The Stop Loss Configuration capability controls how stop loss (SL) levels are calculated and applied to buy/sell orders in the Daily Breakout EA. The SL is derived from a configurable risk percentage applied to the daily range.

## Behavior

#### Requirement: Risk Percentage Parameter

**Type:** Modified

**Description:**  
The expert advisor exposes a configurable input parameter named `risk_percentage` that defines the percentage of the daily range used to calculate stop loss distance from entry points. This parameter replaces the previous `stop_loss` parameter.

**Scenarios:**

- **Scenario:** SL calculation with default risk percentage  
  Given: Daily range = 100 pips, risk_percentage = 90 (default)  
  When: Buy order is placed above range high  
  Then: Buy SL is placed 90 pips below the range high (100 × 90%)
- **Scenario:** Disable SL with zero risk percentage  
  Given: risk_percentage = 0  
  When: Placing pending orders  
  Then: No stop loss is applied to buy or sell orders
- **Scenario:** Custom risk percentage  
  Given: Daily range = 100 pips, risk_percentage = 50  
  When: Sell order is placed below range low  
  Then: Sell SL is placed 50 pips above the range low (100 × 50%)

#### Requirement: SL Calculation for Buy Orders

**Type:** Modified

**Description:**  
Buy stop loss is calculated as the range high minus (range size × risk_percentage / 100).

**Formula:**  
`buy_sl = g_high_price - (range_size * risk_percentage / 100)`

**Scenarios:**

- **Scenario:** Buy SL with standard setup  
  Given: Range high = 1.0500, range size = 100 pips, risk_percentage = 90  
  When: Calculating buy SL  
  Then: buy_sl = 1.0500 - 90 = 1.0410

#### Requirement: SL Calculation for Sell Orders

**Type:** Modified

**Description:**  
Sell stop loss is calculated as the range low plus (range size × risk_percentage / 100).

**Formula:**  
`sell_sl = g_low_price + (range_size * risk_percentage / 100)`

**Scenarios:**

- **Scenario:** Sell SL with standard setup  
  Given: Range low = 1.0400, range size = 100 pips, risk_percentage = 90  
  When: Calculating sell SL  
  Then: sell_sl = 1.0400 + 90 = 1.0490

## Notes

- `risk_percentage` is used **exclusively** for stop loss calculation and no other purpose
- When `risk_percentage = 0`, SL functionality is disabled
- The parameter name `risk_percentage` clarifies the intent: controlling the risk exposure via SL placement
- The calculation logic and default value (90) are preserved from the previous `stop_loss` parameter
