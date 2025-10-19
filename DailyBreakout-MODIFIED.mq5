//+------------------------------------------------------------------+
//|                                            Daily Range Breakout EA |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link ""
#property version "1.00"

// Include required libraries
#include <Trade\Trade.mqh>
CTrade trade;

// Input Parameters
input int magic_number = 12345;                        // Magic Number
input bool autolot = true;                             // Use autolot based on balance
input double base_balance = 100.0;                     // Base balance for lot calculation
input double lot = 0.01;                               // Lot size for each base_balance unit
input double min_lot = 0.01;                           // Minimum lot size
input double max_lot = 10.0;                           // Maximum lot size
input double risk_percentage = 1.0;                    // Risk percentage of account balance (minimum 1%, required for SL)
input int take_profit = 0;                             // Take Profit in % of the range (0=off)
input int range_start_time = 90;                       // Range start time in minutes
input int range_duration = 270;                        // Range duration in minutes
input int range_close_time = 1200;                     // Range close time in minutes (-1=off)
input string breakout_mode = "one breakout per range"; // Breakout Mode
input bool range_on_monday = true;                     // Range on Monday
input bool range_on_tuesday = false;                   // Range on Tuesday
input bool range_on_wednesday = true;                  // Range on Wednesday
input bool range_on_thursday = true;                   // Range on Thursday
input bool range_on_friday = true;                     // Range on Friday
input int trailing_stop = 300;                         // Trailing Stop in points (0=off)
input int trailing_start = 500;                        // Activate trailing after profit in points
input double max_range_size = 1500;                    // Maximum range size in points (0=off)
input double min_range_size = 500;                     // Minimum range size in points (0=off)

// Global Variables
double g_high_price = 0;
double g_low_price = 0;
datetime g_range_end_time = 0;
datetime g_close_time = 0;
bool g_range_calculated = false;
bool g_orders_placed = false;
ulong g_buy_ticket = 0;
ulong g_sell_ticket = 0;
double g_lot_size = 0;
datetime g_range_start_time = 0;
datetime g_current_day = 0;
string g_start_line_name = "Range_Start_Line";
string g_end_line_name = "Range_End_Line";
string g_close_line_name = "Range_Close_Line";
bool g_lines_drawn = false;
int g_trailing_points = 300;       // Trailing stop in points (default 30 pips)
bool g_trailing_activated = false; // Default trailing status

// Add these global variables to track ranges
double g_max_range_ever = 0;      // Track maximum range seen
double g_min_range_ever = 999999; // Track minimum range seen
datetime g_max_range_date = 0;    // Date of maximum range
datetime g_min_range_date = 0;    // Date of minimum range
bool g_one_breakout_per_range = false; // Cached breakout mode flag
double g_risk_percentage = 1.0;   // Validated risk percentage (minimum 1%)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate risk percentage - MUST be at least 1%
   if (risk_percentage < 1.0)
   {
      Print("ERROR: risk_percentage must be at least 1%. Current value: ", risk_percentage);
      g_risk_percentage = 1.0;
      Print("Automatically set to minimum 1.0%");
   }
   else
   {
      g_risk_percentage = risk_percentage;
   }

   // Initialize
   g_range_calculated = false;
   g_orders_placed = false;
   g_lines_drawn = false;
   g_trailing_points = trailing_stop;

   // Cache breakout mode to avoid repeated string comparisons
   g_one_breakout_per_range = (StringCompare(breakout_mode, "one breakout per range") == 0);

   // Set current day
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   g_current_day = StructToTime(dt);

   // Delete any existing lines
   DeleteAllLines();

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
   DeleteAllLines();
   if (g_max_range_ever > 0)
   {
      Print("=== Range Statistics ===");
      Print("Maximum range during backtest: ", g_max_range_ever, " points on ", TimeToString(g_max_range_date));
      Print("Minimum range during backtest: ", g_min_range_ever, " points on ", TimeToString(g_min_range_date));
      Print("======================");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if day has changed
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today = StructToTime(dt);

   if (today != g_current_day)
   {
      // New day, reset EA
      g_range_calculated = false;
      g_orders_placed = false;
      g_lines_drawn = false;
      g_current_day = today;
      DeleteAllLines();
   }

   // Check if it's a valid trading day
   if (!IsTradingDay())
      return;

   // Calculate daily range if not already done
   if (!g_range_calculated)
   {
      CalculateDailyRange();
      return;
   }

   // Draw vertical lines for range times if not already drawn
   if (!g_lines_drawn)
   {
      DrawRangeLines();
      g_lines_drawn = true;
   }

   // Check if we should place orders
   if (!g_orders_placed && TimeCurrent() >= g_range_end_time)
   {
      PlacePendingOrders();
      return;
   }

   // Apply trailing stop to open positions if enabled
   if (trailing_stop > 0)
   {
      ManageTrailingStop();
   }

   // Check if we should close all orders
   if (g_orders_placed && range_close_time > 0 && TimeCurrent() >= g_close_time)
   {
      CloseAllOrders();
      return;
   }

   // Manage existing orders
   ManageOrders();
}

//+------------------------------------------------------------------+
//| Check if today is a valid trading day                            |
//+------------------------------------------------------------------+
bool IsTradingDay()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int day_of_week = dt.day_of_week;

   switch (day_of_week)
   {
   case 1:
      return range_on_monday;
   case 2:
      return range_on_tuesday;
   case 3:
      return range_on_wednesday;
   case 4:
      return range_on_thursday;
   case 5:
      return range_on_friday;
   default:
      return false; // Weekend
   }
}

//+------------------------------------------------------------------+
//| Calculate the daily high/low range                               |
//+------------------------------------------------------------------+
void CalculateDailyRange()
{
   datetime current_time = TimeCurrent();

   // Calculate range start time (from the start of the day)
   MqlDateTime dt;
   TimeToStruct(current_time, dt);

   // Reset time to beginning of day
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   datetime today = StructToTime(dt);

   // Calculate range start time
   g_range_start_time = today + range_start_time * 60;

   // Calculate range end time
   g_range_end_time = g_range_start_time + range_duration * 60;

   // Calculate order close time
   if (range_close_time > 0)
      g_close_time = today + range_close_time * 60;
   else
      g_close_time = 0; // No automatic close time

   // Check if we're still in range calculation period
   if (current_time < g_range_end_time)
      return;

   // Calculate the high and low of the range using optimized iHighest/iLowest
   g_high_price = 0;
   g_low_price = 99999999;

   // Find the index of the highest and lowest bars within the range period
   // Use true (less-than-or-equal mode) to find nearest bar at or before specified time
   int start_bar = iBarShift(_Symbol, PERIOD_M1, g_range_start_time, true);
   int end_bar = iBarShift(_Symbol, PERIOD_M1, g_range_end_time, true);

   // Validate we have valid bar indices with historical data
   if (start_bar < 0 || end_bar < 0)
   {
      Print("Not enough historical data for range calculation. start_bar: ", start_bar, ", end_bar: ", end_bar);
      return;
   }

   // Ensure correct order (start_bar should be higher index than end_bar in MQL5)
   if (start_bar < end_bar)
   {
      int temp = start_bar;
      start_bar = end_bar;
      end_bar = temp;
   }

   // Use iHighest and iLowest to find extremes within the range
   if (end_bar <= start_bar)
   {
      int highest_bar = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, start_bar - end_bar + 1, end_bar);
      int lowest_bar = iLowest(_Symbol, PERIOD_M1, MODE_LOW, start_bar - end_bar + 1, end_bar);

      if (highest_bar >= 0)
         g_high_price = iHigh(_Symbol, PERIOD_M1, highest_bar);
      if (lowest_bar >= 0)
         g_low_price = iLow(_Symbol, PERIOD_M1, lowest_bar);
   }

   // Mark range as calculated
   if (g_high_price > 0 && g_low_price < 99999999)
   {
      g_range_calculated = true;
      double range_size = g_high_price - g_low_price;
      double range_points = range_size / _Point;

      // Track maximum and minimum ranges observed
      if (range_points > g_max_range_ever)
      {
         g_max_range_ever = range_points;
         g_max_range_date = TimeCurrent();
         Print("New maximum range detected: ", range_points, " points on ", TimeToString(g_max_range_date));
      }

      if (range_points < g_min_range_ever)
      {
         g_min_range_ever = range_points;
         g_min_range_date = TimeCurrent();
         Print("New minimum range detected: ", range_points, " points on ", TimeToString(g_min_range_date));
      }

      Print("Daily range calculated - High: ", g_high_price, " Low: ", g_low_price,
            " Range: ", range_points, " points");
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on the settings (independent of risk)  |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size)
{
   if (autolot) // Autolot mode
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Calculate lot size proportional to account balance
      double balance_ratio = account_balance / base_balance;
      double lot_size = NormalizeDouble(balance_ratio * lot, 2);

      // Apply min/max limits
      if (lot_size < min_lot)
         lot_size = min_lot;
      else if (lot_size > max_lot)
         lot_size = max_lot;

      Print("Autolot calculation - Balance: ", account_balance, ", Base balance: ", base_balance,
            ", Balance ratio: ", balance_ratio, ", Base lot: ", lot, ", Calculated lot: ", lot_size);

      return lot_size;
   }
   else // Fixed lot size
   {
      return lot; // Use lot as fixed lot value
   }
}

//+------------------------------------------------------------------+
//| Calculate SL distance based on mandatory risk percentage         |
//+------------------------------------------------------------------+
double CalculateSLDistance(double lot_size)
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * g_risk_percentage / 100.0;

   // Get tick value and size for accurate point value calculation
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point_value = tick_value / tick_size * _Point;

   // Calculate SL distance in points
   double sl_distance_points = risk_amount / (lot_size * point_value);

   Print("SL Distance Calculation - Risk %: ", g_risk_percentage,
         ", Risk Amount: ", risk_amount,
         ", Lot Size: ", lot_size,
         ", SL Distance: ", sl_distance_points, " points");

   return sl_distance_points;
}

//+------------------------------------------------------------------+
//| Place pending orders based on the calculated range               |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if (g_high_price <= 0 || g_low_price >= 99999999)
      return;

   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;

   Print("=== Daily Range Details ===");
   Print("Date: ", TimeToString(TimeCurrent()));
   Print("Range High: ", g_high_price);
   Print("Range Low: ", g_low_price);
   Print("Range Size: ", range_points, " points");
   Print("=========================");

   // Check if range size is within acceptable limits
   if (max_range_size > 0 && range_points > max_range_size)
   {
      Print("Range size (", range_points, " points) exceeds maximum (", max_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   if (min_range_size > 0 && range_points < min_range_size)
   {
      Print("Range size (", range_points, " points) is below minimum (", min_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   // Calculate lot size (independent of risk)
   g_lot_size = CalculateLotSize(range_size);

   // Calculate SL distance based on mandatory risk percentage
   double sl_distance_points = CalculateSLDistance(g_lot_size);
   double buy_sl = g_high_price - sl_distance_points * _Point;
   double sell_sl = g_low_price + sl_distance_points * _Point;

   // Calculate TP (if enabled)
   double buy_tp = 0, sell_tp = 0;
   if (take_profit > 0)
   {
      buy_tp = g_high_price + (range_size * take_profit / 100);
      sell_tp = g_low_price - (range_size * take_profit / 100);
   }

   // Place buy stop order at the high of the range
   trade.SetExpertMagicNumber(magic_number);

   bool buy_success = trade.BuyStop(
       g_lot_size,
       g_high_price,
       _Symbol,
       buy_sl,
       buy_tp,
       ORDER_TIME_DAY,
       0,
       "Range Breakout Buy");

   if (buy_success)
   {
      ulong buy_ticket = trade.ResultOrder();

      // Confirm order was placed successfully
      if (buy_ticket > 0 && OrderSelect(buy_ticket))
      {
         g_buy_ticket = buy_ticket;
         Print("Buy Stop order CONFIRMED - Ticket: ", buy_ticket, ", Price: ", g_high_price, ", Lot: ", g_lot_size);
      }
      else
      {
         Print("Buy Stop placed but FAILED to confirm. Ticket: ", buy_ticket);
         g_buy_ticket = 0;
      }
   }
   else
   {
      Print("Failed to place Buy Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      g_buy_ticket = 0;
   }

   // Place sell stop order at the low of the range
   bool sell_success = trade.SellStop(
       g_lot_size,
       g_low_price,
       _Symbol,
       sell_sl,
       sell_tp,
       ORDER_TIME_DAY,
       0,
       "Range Breakout Sell");

   if (sell_success)
   {
      ulong sell_ticket = trade.ResultOrder();

      // Confirm order was placed successfully
      if (sell_ticket > 0 && OrderSelect(sell_ticket))
      {
         g_sell_ticket = sell_ticket;
         Print("Sell Stop order CONFIRMED - Ticket: ", sell_ticket, ", Price: ", g_low_price, ", Lot: ", g_lot_size);
      }
      else
      {
         Print("Sell Stop placed but FAILED to confirm. Ticket: ", sell_ticket);
         g_sell_ticket = 0;
      }
   }
   else
   {
      Print("Failed to place Sell Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      g_sell_ticket = 0;
   }

   g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| Manage open orders                                               |
//+------------------------------------------------------------------+
void ManageOrders()
{
   // If using "one breakout per range" mode, check if one order has been triggered
   if (g_one_breakout_per_range)
   {
      bool buy_triggered = false;
      bool sell_triggered = false;

      // Check buy order/position status
      ENUM_ORDER_TYPE buy_order_type = ORDER_TYPE_BUY_STOP; // Default pending type
      if (g_buy_ticket > 0)
      {
         if (OrderSelect(g_buy_ticket))
         {
            buy_order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (buy_order_type == ORDER_TYPE_BUY) // Market order = triggered
               buy_triggered = true;
         }
         else if (PositionSelectByTicket(g_buy_ticket))
         {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               buy_triggered = true;
         }
         else
         {
            g_buy_ticket = 0; // Order/position no longer exists
         }
      }

      // Check sell order/position status
      ENUM_ORDER_TYPE sell_order_type = ORDER_TYPE_SELL_STOP; // Default pending type
      if (g_sell_ticket > 0)
      {
         if (OrderSelect(g_sell_ticket))
         {
            sell_order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (sell_order_type == ORDER_TYPE_SELL) // Market order = triggered
               sell_triggered = true;
         }
         else if (PositionSelectByTicket(g_sell_ticket))
         {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               sell_triggered = true;
         }
         else
         {
            g_sell_ticket = 0; // Order/position no longer exists
         }
      }

      // If one order has been triggered, delete the other pending order
      if (buy_triggered && g_sell_ticket > 0)
      {
         if (sell_order_type == ORDER_TYPE_SELL_STOP)
            trade.OrderDelete(g_sell_ticket);
         g_sell_ticket = 0;
      }
      else if (sell_triggered && g_buy_ticket > 0)
      {
         if (buy_order_type == ORDER_TYPE_BUY_STOP)
            trade.OrderDelete(g_buy_ticket);
         g_buy_ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Close all orders for this EA                                     |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   // Close all positions with this magic number
   int positions_total = PositionsTotal();
   for (int i = positions_total - 1; i >= 0; i--)
   {
      ulong position_ticket = PositionGetTicket(i);
      if (position_ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(position_ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to close position #", position_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Delete all pending orders with this magic number
   int orders_total = OrdersTotal();
   for (int i = orders_total - 1; i >= 0; i--)
   {
      ulong order_ticket = OrderGetTicket(i);
      if (order_ticket > 0)
      {
         if (OrderGetInteger(ORDER_MAGIC) == magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(order_ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to delete order #", order_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Reset flags for next day
   g_range_calculated = false;
   g_orders_placed = false;
   g_buy_ticket = 0;
   g_sell_ticket = 0;
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if (trailing_stop <= 0 || trailing_start <= 0)
      return;

   // Check all open positions
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);

      if (position_ticket > 0)
      {
         // Check if this position belongs to our EA
         if (PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Get position details
            double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double position_sl = PositionGetDouble(POSITION_SL);
            double position_tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Current price depending on position type
            double current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // Calculate current profit in points
            double profit_points = 0;

            if (position_type == POSITION_TYPE_BUY)
               profit_points = (current_price - position_open_price) / _Point;
            else
               profit_points = (position_open_price - current_price) / _Point;

            // If profit has not reached trailing_start, skip
            if (profit_points < trailing_start)
               continue;

            // Calculate new stop loss level
            double new_sl = 0;

            if (position_type == POSITION_TYPE_BUY)
            {
               // For buy positions, trail below current price
               new_sl = current_price - trailing_stop * _Point;

               // Only modify if new SL is higher than current SL
               if (position_sl == 0 || new_sl > position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
                  Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
               }
            }
            else
            {
               // For sell positions, trail above current price
               new_sl = current_price + trailing_stop * _Point;

               // Only modify if new SL is lower than current SL or no SL is set
               if (position_sl == 0 || new_sl < position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
                  Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw vertical lines for range times                             |
//+------------------------------------------------------------------+
void DrawRangeLines()
{
   // Delete any existing lines
   DeleteAllLines();

   // Draw range start line (blue)
   ObjectCreate(0, g_start_line_name, OBJ_VLINE, 0, g_range_start_time, 0);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_WIDTH, 2); // Thicker line
   ObjectSetString(0, g_start_line_name, OBJPROP_TOOLTIP, "Range Start Time");

   // Draw range end line (blue)
   ObjectCreate(0, g_end_line_name, OBJ_VLINE, 0, g_range_end_time, 0);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_WIDTH, 2); // Thicker line
   ObjectSetString(0, g_end_line_name, OBJPROP_TOOLTIP, "Range End Time");

   // Draw range close line (red) if applicable
   if (g_close_time > 0)
   {
      ObjectCreate(0, g_close_line_name, OBJ_VLINE, 0, g_close_time, 0);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_WIDTH, 2); // Thicker line
      ObjectSetString(0, g_close_line_name, OBJPROP_TOOLTIP, "Range Close Time");
   }

   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete all vertical lines                                        |
//+------------------------------------------------------------------+
void DeleteAllLines()
{
   ObjectDelete(0, g_start_line_name);
   ObjectDelete(0, g_end_line_name);
   ObjectDelete(0, g_close_line_name);
}