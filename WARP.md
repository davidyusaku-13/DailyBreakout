# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a **MetaTrader 5 (MT5) Expert Advisor** project for algorithmic forex trading. The repository contains:
- **DailyBreakout EA**: A range breakout trading strategy that identifies daily price ranges and places stop orders
- **BalanceRegression Library**: Custom helper class for calculating Sharpe Ratio and profit stability metrics
- **Neural Network Components**: MQL5 implementation of neural networks (attention, LSTM, convolution, GPT-style models) with Python reference implementations

## Development Environment

**Platform**: MetaTrader 5 (MetaEditor)
**Language**: MQL5 (MetaQuotes Language 5)
**Testing**: MT5 Strategy Tester
**Operating System**: Windows

### Compilation

MQL5 files are compiled within MetaEditor (part of MetaTrader 5):
1. Open `.mq5` files in MetaEditor
2. Press F7 or click "Compile" button
3. Compiled `.ex5` files are generated automatically

There are no command-line build tools for MQL5 compilation on Windows.

## Core Architecture

### Main Expert Advisor: DailyBreakout EA

**Location**: `DailyBreakout-MODIFIED.mq5` (active version) and `DailyBreakout-ORIGINAL.mq5` (reference)

**Strategy Logic**:
1. **Range Calculation Phase**: During configured range hours (e.g., 90-360 minutes from day start), tracks high/low prices
2. **Order Placement Phase**: After range ends, places:
   - Buy Stop order at range high
   - Sell Stop order at range low
3. **Execution Phase**: When price breaks out:
   - One order triggers and becomes active position
   - Other pending order is deleted (if using "one breakout per range" mode)
   - Trailing stop activates after reaching configured profit threshold
4. **Close Phase**: All positions/orders close at configured time (if enabled)

**Key Components**:
- `OnInit()`: Initializes EA state, resets daily flags
- `OnTick()`: Main event loop, called on each price tick
- `OnTester()`: Custom optimization criterion using Sharpe Ratio + balance
- `CalculateDailyRange()`: Scans M1 bars to find range high/low
- `PlacePendingOrders()`: Creates BuyStop/SellStop orders with risk-based or fixed lot sizing
- `ManageOrders()`: Implements "one breakout per range" logic
- `ManageTrailingStop()`: Updates stop loss as profit increases
- `CloseAllOrders()`: Cleans up positions and pending orders

**Input Parameters**:
- `autolot`: Enables dynamic lot sizing based on account balance
- `risk_percentage`: Calculates stop loss distance based on account risk (overrides fixed SL)
- `range_start_time`, `range_duration`: Defines observation window in minutes from day start
- `range_close_time`: Auto-close time in minutes from day start
- `max_range_size`, `min_range_size`: Filters trading days by range volatility
- `trailing_stop`, `trailing_start`: Trailing stop parameters in points

### Helper Library: BalanceRegression

**Location**: `Include/BalanceRegression/BalanceRegression.mqh`

**Purpose**: Provides advanced optimization metrics for backtesting

**Key Methods**:
- `GetSharpeRatio()`: Calculates risk-adjusted return (mean return / stddev)
- `GetProfitStability()`: Uses linear regression to measure profit trend consistency
- Relies on `<Math\Alglib\alglib.mqh>` for regression algorithms

**Usage in EA**:
```mql5
CBalanceRegression g_balance_regression;
// In OnTester():
g_balance_regression.SetStartBalance(initial_deposit);
double sharpe = g_balance_regression.GetSharpeRatio();
double score = sharpe * 1000.0 + balance; // Custom optimization criterion
```

### Neural Network Components

**Location**: `Include/NeuroNetworksBook/` and `Scripts/NeuroNetworksBook/`

**Structure**:
- `realization/`: Core MQL5 neural network classes
  - `neuronnet.mqh`: Base neural network class
  - `neuronbase.mqh`: Base neuron layer implementation
  - `neuronconv.mqh`: Convolutional layers
  - `neuronlstm.mqh`: LSTM recurrent layers
  - `neuronattention.mqh`, `neuronmhattention.mqh`: Attention mechanisms
  - `neurongpt.mqh`: GPT-style transformer implementation
  - `opencl.mqh`, `opencl_program.cl`: GPU acceleration via OpenCL
  - `activation.mqh`: Activation functions (ReLU, Sigmoid, etc.)
  - `lossfunction_.mqh`: Loss functions for training

- `Scripts/`: Test scripts and Python references
  - `*_test.mq5`: MQL5 test scripts for each component
  - `*.py`: Python reference implementations for validation
  - `initial_data/`: Scripts to prepare training data from market indicators

**Key Concepts**:
- MQL5 implementations are designed to match Python/PyTorch behavior
- OpenCL support for GPU-accelerated matrix operations
- Gradient checking scripts (`check_gradient_*.mq5`) validate backpropagation

## File Organization

```
E:\FOREX\DailyBreakout\
├── DailyBreakout-MODIFIED.mq5     # Active EA (with BalanceRegression)
├── DailyBreakout-ORIGINAL.mq5     # Original EA (without BalanceRegression)
├── Include/
│   ├── BalanceRegression/
│   │   └── BalanceRegression.mqh  # Sharpe/ProfitStability calculator
│   └── NeuroNetworksBook/
│       ├── realization/           # Neural network core classes
│       ├── algotrading/           # Trading-specific utilities
│       └── about_ai/              # Educational/reference code
├── Experts/
│   └── NeuroNetworksBook/
│       └── ea_template.mq5        # Neural network EA template
└── Scripts/
    └── NeuroNetworksBook/         # Test scripts and Python references
```

## Testing & Optimization

**Backtesting**:
1. Open Strategy Tester in MT5 (View > Strategy Tester or Ctrl+R)
2. Select EA file (e.g., `DailyBreakout-MODIFIED.mq5`)
3. Configure symbol, timeframe, date range, and input parameters
4. Run test

**Optimization**:
1. In Strategy Tester, enable "Optimization" mode
2. Check parameters to optimize (double-click parameter value to enable range)
3. Select optimization criterion:
   - Default: Balance, Profit Factor, Sharpe Ratio, etc.
   - Custom: `OnTester()` return value (used in DailyBreakout-MODIFIED for Sharpe-weighted score)
4. Run optimization

**Reading Test Results**:
- Check "Journal" tab for `Print()` statements (range statistics, order details)
- Review "Results" tab for trade-by-trade performance
- Examine "Graph" tab for equity curve
- Check "Report" tab for comprehensive statistics

## Code Patterns

### MQL5 Standard Library Usage

**Trading Operations**:
```mql5
#include <Trade\Trade.mqh>
CTrade trade;
trade.SetExpertMagicNumber(magic_number);
trade.BuyStop(lot_size, price, symbol, sl, tp, ORDER_TIME_DAY, 0, comment);
trade.PositionClose(ticket);
```

**Position/Order Selection**:
```mql5
// By ticket
if (PositionSelectByTicket(ticket)) { /* access position */ }
if (OrderSelect(ticket)) { /* access order */ }

// By index
for (int i = 0; i < PositionsTotal(); i++) {
    ulong ticket = PositionGetTicket(i);
    // Check magic number and symbol
}
```

**Price Data Access**:
```mql5
double high = iHigh(_Symbol, PERIOD_M1, bar_index);
double low = iLow(_Symbol, PERIOD_M1, bar_index);
datetime time = iTime(_Symbol, PERIOD_M1, bar_index);
```

### Risk Management Calculations

**Dynamic Lot Sizing** (proportion to account balance):
```mql5
double balance_ratio = AccountInfoDouble(ACCOUNT_BALANCE) / base_balance;
double lot_size = NormalizeDouble(balance_ratio * lot, 2);
lot_size = MathMax(min_lot, MathMin(lot_size, max_lot)); // Clamp to limits
```

**Risk-Based Stop Loss**:
```mql5
double risk_amount = account_balance * risk_percentage / 100.0;
double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
double point_value = tick_value / tick_size * _Point;
double sl_distance_points = risk_amount / (lot_size * point_value);
```

### State Management

The EA uses **daily state flags** that reset when day changes:
```mql5
// In OnTick():
if (today != g_current_day) {
    g_range_calculated = false;
    g_orders_placed = false;
    g_lines_drawn = false;
    g_current_day = today;
    DeleteAllLines();
}
```

**Critical Global Variables**:
- `g_range_calculated`: Range high/low have been determined
- `g_orders_placed`: Pending orders have been placed
- `g_buy_ticket`, `g_sell_ticket`: Track pending/active orders
- `g_high_price`, `g_low_price`: Range boundaries
- `g_range_start_time`, `g_range_end_time`, `g_close_time`: Key timestamps

## Important Notes

### File Encoding Issues
Many `.mq5` and `.mqh` files are UTF-16 LE encoded (standard for MetaEditor). Text editors may show these as binary. Always open in MetaEditor for proper viewing/editing.

### Differences Between MODIFIED and ORIGINAL
- **MODIFIED**: Includes `#include <BalanceRegression\BalanceRegression.mqh>` and custom `OnTester()` for Sharpe Ratio optimization
- **ORIGINAL**: Removed risk percentage parameter, uses fixed stop loss percentage
- Both versions implement the same core trading logic

### Neural Network Code
The NeuroNetworksBook components are **educational/research** code for implementing neural networks in MQL5. They are NOT actively used by the DailyBreakout EA. These can be studied separately for machine learning integration into trading strategies.

### Points vs Pips
In MQL5, 1 point = smallest price increment (`_Point`). For 5-digit forex quotes (e.g., EUR/USD = 1.12345), 1 pip = 10 points. Always specify trailing stops, ranges, etc. in **points**.

### Magic Numbers
Each EA instance should have a unique `magic_number` to prevent interference when multiple EAs run on the same account. The EA only manages positions/orders with matching magic numbers.

## Debugging Strategies

1. **Print Statements**: Use `Print()` extensively (already present in code)
   ```mql5
   Print("Variable value: ", some_value);
   ```

2. **Journal Tab**: Check MT5 Journal for EA output during testing/live trading

3. **Visual Debugging**: EA draws vertical lines on chart:
   - Blue lines: Range start/end times
   - Red line: Auto-close time

4. **Backtest Statistics**: Range tracking globals (`g_max_range_ever`, `g_min_range_ever`) printed in `OnDeinit()`

5. **Order Comments**: Each order has descriptive comment ("Range Breakout Buy/Sell")

## Working with This Codebase

When modifying the EA:
1. Always preserve the daily state reset logic in `OnTick()`
2. Maintain magic number filtering in position/order loops
3. Use `trade.ResultRetcode()` to check trade operation success
4. Normalize lot sizes with `NormalizeDouble(lot, 2)`
5. Test changes in Strategy Tester before live deployment
6. Consider adding new metrics to `OnTester()` for optimization
