//+------------------------------------------------------------------+
//|                              DailyBreakout with Neural Network  |
//|                           Integrated Adam Optimizer & Learning  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link ""
#property version "2.00"

// Include required libraries
#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>

CTrade trade;

// Input Parameters (identical to MODIFIED version)
input int magic_number = 12345;                        // Magic Number
input bool autolot = true;                             // Use autolot based on balance
input double base_balance = 100.0;                     // Base balance for lot calculation
input double lot = 0.01;                               // Lot size for each base_balance unit
input double min_lot = 0.01;                           // Minimum lot size
input double max_lot = 10.0;                           // Maximum lot size
input double risk_percentage = 1.0;                    // Risk percentage of account balance (0=off)
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

// Neural Network Parameters
input bool use_neural_network = true;                  // Enable Neural Network
input double nn_learning_rate = 0.001;                 // NN Learning Rate
input int nn_batch_size = 32;                          // NN Batch Size
input double nn_confidence_threshold = 0.6;            // NN Confidence Threshold for trades

//+------------------------------------------------------------------+
//| Neural Network Implementation                                    |
//+------------------------------------------------------------------+

// Activation Functions
class ActivationFunction
{
public:
   static double ReLU(double x) { return MathMax(0, x); }
   static double ReLU_derivative(double x) { return x > 0 ? 1 : 0; }
   
   static double Sigmoid(double x) { return 1.0 / (1.0 + MathExp(-x)); }
   static double Sigmoid_derivative(double x) 
   { 
      double s = Sigmoid(x);
      return s * (1 - s);
   }
   
   static void Softmax(double &output[], double &inp[], int size)
   {
      double max_val = inp[0];
      for(int i = 1; i < size; i++)
         if(inp[i] > max_val) max_val = inp[i];
      
      double sum = 0;
      for(int i = 0; i < size; i++)
      {
         output[i] = MathExp(inp[i] - max_val);
         sum += output[i];
      }
      
      for(int i = 0; i < size; i++)
         output[i] /= sum;
   }
};

//+------------------------------------------------------------------+
//| Adam Optimizer Implementation                                    |
//+------------------------------------------------------------------+
class AdamOptimizer
{
private:
   double learning_rate;
   double beta1, beta2, epsilon;
   int timestep;
   
public:
   AdamOptimizer()
   {
      learning_rate = 0.001;
      beta1 = 0.9;
      beta2 = 0.999;
      epsilon = 1e-8;
      timestep = 0;
   }
   
   void SetLearningRate(double lr) { learning_rate = lr; }
   
   void UpdateWeights(double &weights[], double &gradients[], double &m[], double &v[], int size)
   {
      timestep++;
      if(ArraySize(m) != size) ArrayResize(m, size);
      if(ArraySize(v) != size) ArrayResize(v, size);
      
      for(int i = 0; i < size; i++)
      {
         // Update biased first moment estimate
         m[i] = beta1 * m[i] + (1 - beta1) * gradients[i];
         
         // Update biased second moment estimate
         v[i] = beta2 * v[i] + (1 - beta2) * gradients[i] * gradients[i];
         
         // Compute bias-corrected moments
         double m_hat = m[i] / (1 - MathPow(beta1, timestep));
         double v_hat = v[i] / (1 - MathPow(beta2, timestep));
         
         // Update weights
         weights[i] -= learning_rate * m_hat / (MathSqrt(v_hat) + epsilon);
      }
   }
};

//+------------------------------------------------------------------+
//| Dense Layer Implementation                                       |
//+------------------------------------------------------------------+
class DenseLayer
{
private:
   int input_size, output_size;
   double weights[];
   double bias[];
   double m_weights[], v_weights[];  // Adam moments for weights
   double m_bias[], v_bias[];        // Adam moments for bias
   double input_cache[];
   double output[];
   double gradients[];
   string activation;
   
public:
   DenseLayer() {}
   
   void Initialize(int in_size, int out_size, string activ = "relu")
   {
      input_size = in_size;
      output_size = out_size;
      activation = activ;
      
      // Initialize weights with He initialization
      int weight_size = input_size * output_size;
      ArrayResize(weights, weight_size);
      ArrayResize(m_weights, weight_size);
      ArrayResize(v_weights, weight_size);
      ArrayInitialize(m_weights, 0);
      ArrayInitialize(v_weights, 0);
      
      double scale = MathSqrt(2.0 / input_size);
      for(int i = 0; i < weight_size; i++)
         weights[i] = (MathRand() / 32768.0 - 0.5) * 2 * scale;
      
      // Initialize bias
      ArrayResize(bias, output_size);
      ArrayResize(m_bias, output_size);
      ArrayResize(v_bias, output_size);
      ArrayInitialize(bias, 0);
      ArrayInitialize(m_bias, 0);
      ArrayInitialize(v_bias, 0);
      
      ArrayResize(output, output_size);
      ArrayResize(gradients, input_size);
   }
   
   void Forward(double &inp[], int in_size, double &result[])
   {
      ArrayResize(input_cache, in_size);
      ArrayCopy(input_cache, inp);
      
      ArrayResize(result, output_size);
      
      // Compute weighted sum
      for(int i = 0; i < output_size; i++)
      {
         result[i] = bias[i];
         for(int j = 0; j < input_size; j++)
            result[i] += inp[j] * weights[i * input_size + j];
      }
      
      // Apply activation
      if(activation == "relu")
      {
         for(int i = 0; i < output_size; i++)
            result[i] = ActivationFunction::ReLU(result[i]);
      }
      else if(activation == "sigmoid")
      {
         for(int i = 0; i < output_size; i++)
            result[i] = ActivationFunction::Sigmoid(result[i]);
      }
      else if(activation == "softmax")
      {
         ActivationFunction::Softmax(result, result, output_size);
      }
      
      ArrayCopy(output, result);
   }
   
   void Backward(double &grad_output[], double &grad_input[], AdamOptimizer &optimizer)
   {
      ArrayResize(grad_input, input_size);
      ArrayInitialize(grad_input, 0);
      
      double grad_pre_activation[];
      ArrayResize(grad_pre_activation, output_size);
      
      // Apply activation derivative
      if(activation == "relu")
      {
         for(int i = 0; i < output_size; i++)
            grad_pre_activation[i] = grad_output[i] * ActivationFunction::ReLU_derivative(output[i]);
      }
      else if(activation == "sigmoid")
      {
         for(int i = 0; i < output_size; i++)
            grad_pre_activation[i] = grad_output[i] * ActivationFunction::Sigmoid_derivative(output[i]);
      }
      else
      {
         ArrayCopy(grad_pre_activation, grad_output);
      }
      
      // Compute gradients for weights and bias
      double weight_gradients[];
      ArrayResize(weight_gradients, ArraySize(weights));
      
      for(int i = 0; i < output_size; i++)
      {
         for(int j = 0; j < input_size; j++)
         {
            int idx = i * input_size + j;
            weight_gradients[idx] = grad_pre_activation[i] * input_cache[j];
            grad_input[j] += grad_pre_activation[i] * weights[idx];
         }
      }
      
      // Update weights and bias using Adam
      optimizer.UpdateWeights(weights, weight_gradients, m_weights, v_weights, ArraySize(weights));
      optimizer.UpdateWeights(bias, grad_pre_activation, m_bias, v_bias, output_size);
   }
   
   void GetWeights(double &w[]) { ArrayCopy(w, weights); }
   void SetWeights(const double &w[]) { ArrayCopy(weights, w); }
};

//+------------------------------------------------------------------+
//| Neural Network Class                                             |
//+------------------------------------------------------------------+
class NeuralNetwork
{
private:
   DenseLayer layer1, layer2, layer3, output_layer;
   AdamOptimizer optimizer;
   double features[];
   double prediction[];
   int feature_size;
   int hidden1_size, hidden2_size, hidden3_size;
   int output_size;
   
   // Training data buffer
   double training_features[][25];  // Max 25 features
   double training_labels[][3];     // 3 output classes
   int training_buffer_size;
   int current_buffer_pos;
   
public:
   NeuralNetwork()
   {
      feature_size = 20;
      hidden1_size = 32;
      hidden2_size = 16;
      hidden3_size = 8;
      output_size = 3;  // Buy signal, Sell signal, No trade
      
      training_buffer_size = 1000;
      current_buffer_pos = 0;
      ArrayResize(training_features, training_buffer_size);
      ArrayResize(training_labels, training_buffer_size);
   }
   
   void Initialize(double learning_rate = 0.001)
   {
      layer1.Initialize(feature_size, hidden1_size, "relu");
      layer2.Initialize(hidden1_size, hidden2_size, "relu");
      layer3.Initialize(hidden2_size, hidden3_size, "relu");
      output_layer.Initialize(hidden3_size, output_size, "softmax");
      
      optimizer.SetLearningRate(learning_rate);
   }
   
   void ExtractFeatures(double &result[])
   {
      ArrayResize(result, feature_size);
      
      // Feature 1-3: Normalized range metrics
      double range_size = (g_high_price - g_low_price) / _Point;
      result[0] = range_size / 1000.0;  // Normalized range size
      result[1] = (g_high_price - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point / 100.0;
      result[2] = (SymbolInfoDouble(_Symbol, SYMBOL_BID) - g_low_price) / _Point / 100.0;
      
      // Feature 4-8: Day of week encoding (one-hot)
      MqlDateTime dt;
      TimeCurrent(dt);
      for(int i = 3; i < 8; i++) result[i] = 0;
      if(dt.day_of_week >= 1 && dt.day_of_week <= 5)
         result[2 + dt.day_of_week] = 1;
      
      // Feature 9-10: Time features
      result[8] = dt.hour / 24.0;
      result[9] = dt.min / 60.0;
      
      // Feature 11-15: Price momentum indicators
      double ma_fast_buffer[1], ma_slow_buffer[1];
      double ma_fast = 0, ma_slow = 0;
      
      if(g_ma_fast_handle != INVALID_HANDLE && g_ma_slow_handle != INVALID_HANDLE)
      {
         CopyBuffer(g_ma_fast_handle, 0, 0, 1, ma_fast_buffer);
         CopyBuffer(g_ma_slow_handle, 0, 0, 1, ma_slow_buffer);
         ma_fast = ma_fast_buffer[0];
         ma_slow = ma_slow_buffer[0];
      }
      
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      result[10] = (current_price - ma_fast) / _Point / 100.0;
      result[11] = (current_price - ma_slow) / _Point / 100.0;
      result[12] = (ma_fast - ma_slow) / _Point / 100.0;
      
      // Feature 14-15: RSI and ATR
      double rsi_buffer[1], atr_buffer[1];
      double rsi = 50, atr = 0;  // Default values
      
      if(g_rsi_handle != INVALID_HANDLE && g_atr_handle != INVALID_HANDLE)
      {
         CopyBuffer(g_rsi_handle, 0, 0, 1, rsi_buffer);
         CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer);
         rsi = rsi_buffer[0];
         atr = atr_buffer[0];
      }
      result[13] = rsi / 100.0;
      result[14] = atr / _Point / 100.0;
      
      // Feature 16-20: Historical performance (simplified)
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      result[15] = (equity - balance) / balance;  // Current P&L ratio
      result[16] = MathMin(range_size / max_range_size, 1.0);  // Range size ratio
      result[17] = MathMax(range_size / min_range_size, 0.0);
      result[18] = autolot ? 1.0 : 0.0;  // Trading mode
      result[19] = risk_percentage / 100.0;  // Risk level
   }
   
   void Forward(double &inp[], int size, double &outp[])
   {
      double temp1[], temp2[], temp3[];
      
      layer1.Forward(inp, size, temp1);
      layer2.Forward(temp1, hidden1_size, temp2);
      layer3.Forward(temp2, hidden2_size, temp3);
      output_layer.Forward(temp3, hidden3_size, outp);
   }
   
   void Train(double &features_in[], double &label[])
   {
      // Store in training buffer
      if(current_buffer_pos < training_buffer_size)
      {
         for(int i = 0; i < feature_size && i < 25; i++)
            training_features[current_buffer_pos][i] = features_in[i];
         for(int i = 0; i < 3; i++)
            training_labels[current_buffer_pos][i] = label[i];
         current_buffer_pos++;
      }
      
      // Batch training when buffer is full enough
      if(current_buffer_pos >= nn_batch_size)
      {
         TrainBatch();
      }
   }
   
   void TrainBatch()
   {
      if(current_buffer_pos < nn_batch_size) return;
      
      // Sample random batch
      for(int batch = 0; batch < nn_batch_size; batch++)
      {
         int idx = MathRand() % current_buffer_pos;
         
         double sample_features[];
         double sample_label[];
         ArrayResize(sample_features, feature_size);
         ArrayResize(sample_label, 3);
         
         for(int i = 0; i < feature_size; i++)
            sample_features[i] = training_features[idx][i];
         for(int i = 0; i < 3; i++)
            sample_label[i] = training_labels[idx][i];
         
         // Forward pass
         double output[];
         Forward(sample_features, feature_size, output);
         
         // Compute loss gradient (cross-entropy)
         double grad_output[];
         ArrayResize(grad_output, 3);
         for(int i = 0; i < 3; i++)
            grad_output[i] = output[i] - sample_label[i];
         
         // Backward pass
         double grad3[], grad2[], grad1[], grad_input[];
         output_layer.Backward(grad_output, grad3, optimizer);
         layer3.Backward(grad3, grad2, optimizer);
         layer2.Backward(grad2, grad1, optimizer);
         layer1.Backward(grad1, grad_input, optimizer);
      }
   }
   
   double GetConfidence(double &pred[])
   {
      return MathMax(pred[0], MathMax(pred[1], pred[2]));
   }
   
   int GetSignal(double &pred[])
   {
      if(pred[0] > pred[1] && pred[0] > pred[2])
         return 1;  // Buy
      else if(pred[1] > pred[0] && pred[1] > pred[2])
         return -1; // Sell
      else
         return 0;  // No trade
   }
   
   void SaveWeights(string filename)
   {
      int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
      if(handle != INVALID_HANDLE)
      {
         // Save network architecture
         FileWriteInteger(handle, feature_size);
         FileWriteInteger(handle, hidden1_size);
         FileWriteInteger(handle, hidden2_size);
         FileWriteInteger(handle, hidden3_size);
         FileWriteInteger(handle, output_size);
         
         // Save weights for each layer
         double weights[];
         
         layer1.GetWeights(weights);
         FileWriteInteger(handle, ArraySize(weights));
         for(int i = 0; i < ArraySize(weights); i++)
            FileWriteDouble(handle, weights[i]);
         
         layer2.GetWeights(weights);
         FileWriteInteger(handle, ArraySize(weights));
         for(int i = 0; i < ArraySize(weights); i++)
            FileWriteDouble(handle, weights[i]);
         
         layer3.GetWeights(weights);
         FileWriteInteger(handle, ArraySize(weights));
         for(int i = 0; i < ArraySize(weights); i++)
            FileWriteDouble(handle, weights[i]);
         
         output_layer.GetWeights(weights);
         FileWriteInteger(handle, ArraySize(weights));
         for(int i = 0; i < ArraySize(weights); i++)
            FileWriteDouble(handle, weights[i]);
         
         FileClose(handle);
         Print("Neural network weights saved to ", filename);
      }
   }
   
   bool LoadWeights(string filename)
   {
      int handle = FileOpen(filename, FILE_READ | FILE_BIN);
      if(handle != INVALID_HANDLE)
      {
         // Load and verify architecture
         int fs = FileReadInteger(handle);
         int h1 = FileReadInteger(handle);
         int h2 = FileReadInteger(handle);
         int h3 = FileReadInteger(handle);
         int os = FileReadInteger(handle);
         
         if(fs != feature_size || h1 != hidden1_size || h2 != hidden2_size || 
            h3 != hidden3_size || os != output_size)
         {
            Print("Network architecture mismatch!");
            FileClose(handle);
            return false;
         }
         
         // Load weights
         double weights[];
         int size;
         
         size = FileReadInteger(handle);
         ArrayResize(weights, size);
         for(int i = 0; i < size; i++)
            weights[i] = FileReadDouble(handle);
         layer1.SetWeights(weights);
         
         size = FileReadInteger(handle);
         ArrayResize(weights, size);
         for(int i = 0; i < size; i++)
            weights[i] = FileReadDouble(handle);
         layer2.SetWeights(weights);
         
         size = FileReadInteger(handle);
         ArrayResize(weights, size);
         for(int i = 0; i < size; i++)
            weights[i] = FileReadDouble(handle);
         layer3.SetWeights(weights);
         
         size = FileReadInteger(handle);
         ArrayResize(weights, size);
         for(int i = 0; i < size; i++)
            weights[i] = FileReadDouble(handle);
         output_layer.SetWeights(weights);
         
         FileClose(handle);
         Print("Neural network weights loaded from ", filename);
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
// Original EA globals
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
int g_trailing_points = 300;
bool g_trailing_activated = false;
double g_max_range_ever = 0;
double g_min_range_ever = 999999;
datetime g_max_range_date = 0;
datetime g_min_range_date = 0;

// Neural Network globals
NeuralNetwork g_neural_network;
double g_last_features[];
double g_last_prediction[];
bool g_nn_initialized = false;
int g_trades_completed = 0;
double g_total_profit = 0;

// Indicator handles (initialized once)
int g_ma_fast_handle = INVALID_HANDLE;
int g_ma_slow_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_atr_handle = INVALID_HANDLE;

// Performance tracking
struct TradeResult
{
   datetime close_time;
   double profit;
   double features[25];
   int signal_type;  // 1=buy, -1=sell
   bool success;
};
TradeResult g_trade_history[];
int g_history_size = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize original EA components
   g_range_calculated = false;
   g_orders_placed = false;
   g_lines_drawn = false;
   g_trailing_points = trailing_stop;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   g_current_day = StructToTime(dt);
   
   DeleteAllLines();
   
   // Initialize Neural Network
   if(use_neural_network)
   {
      g_neural_network.Initialize(nn_learning_rate);
      
      // Try to load existing weights
      string weights_file = "DailyBreakout_NN_weights.bin";
      if(!g_neural_network.LoadWeights(weights_file))
      {
         Print("No existing weights found, starting with random initialization");
      }
      
      g_nn_initialized = true;
      ArrayResize(g_trade_history, 5000);
      
      Print("Neural Network initialized with learning rate: ", nn_learning_rate);
      
      // Initialize indicator handles
      g_ma_fast_handle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_SMA, PRICE_CLOSE);
      g_ma_slow_handle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE);
      g_rsi_handle = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
      g_atr_handle = iATR(_Symbol, PERIOD_D1, 14);
      
      if(g_ma_fast_handle == INVALID_HANDLE || g_ma_slow_handle == INVALID_HANDLE ||
         g_rsi_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
      {
         Print("Failed to create indicator handles");
         return (INIT_FAILED);
      }
   }
   
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllLines();
   
   // Release indicator handles
   if(g_ma_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ma_fast_handle);
   if(g_ma_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ma_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   
   if(g_max_range_ever > 0)
   {
      Print("=== Range Statistics ===");
      Print("Maximum range: ", g_max_range_ever, " points on ", TimeToString(g_max_range_date));
      Print("Minimum range: ", g_min_range_ever, " points on ", TimeToString(g_min_range_date));
   }
   
   if(use_neural_network && g_nn_initialized)
   {
      // Save neural network weights
      string weights_file = "DailyBreakout_NN_weights.bin";
      g_neural_network.SaveWeights(weights_file);
      
      Print("=== Neural Network Statistics ===");
      Print("Total trades completed: ", g_trades_completed);
      Print("Total profit: ", g_total_profit);
      if(g_trades_completed > 0)
         Print("Average profit per trade: ", g_total_profit / g_trades_completed);
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
   
   if(today != g_current_day)
   {
      g_range_calculated = false;
      g_orders_placed = false;
      g_lines_drawn = false;
      g_current_day = today;
      DeleteAllLines();
   }
   
   if(!IsTradingDay())
      return;
   
   if(!g_range_calculated)
   {
      CalculateDailyRange();
      return;
   }
   
   if(!g_lines_drawn)
   {
      DrawRangeLines();
      g_lines_drawn = true;
   }
   
   // Neural Network prediction and order placement
   if(!g_orders_placed && TimeCurrent() >= g_range_end_time)
   {
      if(use_neural_network && g_nn_initialized)
      {
         // Extract features and get prediction
         g_neural_network.ExtractFeatures(g_last_features);
         g_neural_network.Forward(g_last_features, ArraySize(g_last_features), g_last_prediction);
         
         double confidence = g_neural_network.GetConfidence(g_last_prediction);
         int signal = g_neural_network.GetSignal(g_last_prediction);
         
         Print("NN Prediction - Buy: ", NormalizeDouble(g_last_prediction[0], 3),
               " Sell: ", NormalizeDouble(g_last_prediction[1], 3),
               " NoTrade: ", NormalizeDouble(g_last_prediction[2], 3),
               " Signal: ", signal, " Confidence: ", NormalizeDouble(confidence, 3));
         
         // Only place orders if confidence is above threshold
         if(confidence >= nn_confidence_threshold && signal != 0)
         {
            PlacePendingOrdersWithNN(signal, confidence);
         }
         else
         {
            Print("NN confidence too low or no trade signal, skipping orders");
            g_orders_placed = true;  // Mark as processed
         }
      }
      else
      {
         PlacePendingOrders();  // Original logic
      }
      return;
   }
   
   if(trailing_stop > 0)
   {
      ManageTrailingStop();
   }
   
   if(g_orders_placed && range_close_time > 0 && TimeCurrent() >= g_close_time)
   {
      CloseAllOrders();
      return;
   }
   
   ManageOrders();
}

//+------------------------------------------------------------------+
//| Place pending orders with Neural Network guidance               |
//+------------------------------------------------------------------+
void PlacePendingOrdersWithNN(int signal, double confidence)
{
   if(g_high_price <= 0 || g_low_price >= 99999999)
      return;
   
   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;
   
   // Check range limits
   if(max_range_size > 0 && range_points > max_range_size)
   {
      Print("Range exceeds maximum, no orders");
      g_orders_placed = true;
      return;
   }
   
   if(min_range_size > 0 && range_points < min_range_size)
   {
      Print("Range below minimum, no orders");
      g_orders_placed = true;
      return;
   }
   
   // Adjust lot size based on NN confidence
   double confidence_factor = 0.5 + (confidence - nn_confidence_threshold) / 
                             (1.0 - nn_confidence_threshold) * 0.5;  // 0.5x to 1.0x
   
   g_lot_size = CalculateLotSize(range_size) * confidence_factor;
   g_lot_size = NormalizeDouble(g_lot_size, 2);
   
   // Calculate SL and TP
   double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;
   
   if(risk_percentage > 0)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * risk_percentage / 100.0;
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point_value = tick_value / tick_size * _Point;
      double sl_distance_points = risk_amount / (g_lot_size * point_value);
      
      buy_sl = g_high_price - sl_distance_points * _Point;
      sell_sl = g_low_price + sl_distance_points * _Point;
   }
   
   if(take_profit > 0)
   {
      // Adjust TP based on NN prediction strength
      double tp_multiplier = 1.0 + (confidence - nn_confidence_threshold) * 0.5;
      buy_tp = g_high_price + (range_size * take_profit / 100 * tp_multiplier);
      sell_tp = g_low_price - (range_size * take_profit / 100 * tp_multiplier);
   }
   
   trade.SetExpertMagicNumber(magic_number);
   
   // Place orders based on NN signal
   if(signal == 1 || signal == 0)  // Buy signal or neutral
   {
      bool buy_success = trade.BuyStop(
          g_lot_size,
          g_high_price,
          _Symbol,
          buy_sl,
          buy_tp,
          ORDER_TIME_DAY,
          0,
          "NN Buy (Conf: " + DoubleToString(confidence, 2) + ")");
      
      if(buy_success)
      {
         g_buy_ticket = trade.ResultOrder();
         Print("NN-guided Buy Stop at ", g_high_price, " lot: ", g_lot_size);
      }
   }
   
   if(signal == -1 || signal == 0)  // Sell signal or neutral
   {
      bool sell_success = trade.SellStop(
          g_lot_size,
          g_low_price,
          _Symbol,
          sell_sl,
          sell_tp,
          ORDER_TIME_DAY,
          0,
          "NN Sell (Conf: " + DoubleToString(confidence, 2) + ")");
      
      if(sell_success)
      {
         g_sell_ticket = trade.ResultOrder();
         Print("NN-guided Sell Stop at ", g_low_price, " lot: ", g_lot_size);
      }
   }
   
   g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| OnTrade event - Train NN on completed trades                    |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(!use_neural_network || !g_nn_initialized)
      return;
   
   // Check for recently closed positions
   if(!HistorySelect(TimeCurrent() - 3600, TimeCurrent()))
      return;
   
   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic_number)
         continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double total_profit = profit + commission + swap;
         
         // Create training label based on trade outcome
         double label[3];
         ArrayInitialize(label, 0);
         
         if(total_profit > 0)
         {
            // Profitable trade - reinforce the signal that was used
            if(g_neural_network.GetSignal(g_last_prediction) == 1)
               label[0] = 1;  // Reinforce buy signal
            else if(g_neural_network.GetSignal(g_last_prediction) == -1)
               label[1] = 1;  // Reinforce sell signal
         }
         else
         {
            // Loss - suggest opposite or no trade
            label[2] = 0.7;  // Lean towards no trade
            if(g_neural_network.GetSignal(g_last_prediction) == 1)
               label[1] = 0.3;  // Suggest sell instead
            else if(g_neural_network.GetSignal(g_last_prediction) == -1)
               label[0] = 0.3;  // Suggest buy instead
         }
         
         // Train the network with this experience
         g_neural_network.Train(g_last_features, label);
         
         g_trades_completed++;
         g_total_profit += total_profit;
         
         // Store in history
         if(g_history_size < 5000)
         {
            g_trade_history[g_history_size].close_time = TimeCurrent();
            g_trade_history[g_history_size].profit = total_profit;
            g_trade_history[g_history_size].success = total_profit > 0;
            g_history_size++;
         }
         
         Print("Trade closed with profit: ", total_profit, 
               " - Training NN (Total trades: ", g_trades_completed, ")");
         
         break;  // Process only one trade per OnTrade call
      }
   }
}

//+------------------------------------------------------------------+
//| Tester function for optimization                                 |
//+------------------------------------------------------------------+
double OnTester()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
   
   if(initial_deposit <= 0) return 0;
   
   // Calculate Sharpe ratio
   double sharpe_ratio = 0;
   if(g_history_size > 1)
   {
      double returns[];
      ArrayResize(returns, g_history_size);
      
      for(int i = 0; i < g_history_size; i++)
         returns[i] = g_trade_history[i].profit;
      
      double mean = MathMean(returns);
      double std = MathStandardDeviation(returns);
      
      if(std > 0)
         sharpe_ratio = mean / std * MathSqrt(252);  // Annualized
   }
   
   // Combined score: Sharpe ratio weighted by final balance
   double score = sharpe_ratio * 1000.0 + balance;
   
   if(use_neural_network)
   {
      // Add NN performance bonus
      double win_rate = 0;
      if(g_trades_completed > 0)
      {
         int wins = 0;
         for(int i = 0; i < g_history_size; i++)
            if(g_trade_history[i].success) wins++;
         
         win_rate = (double)wins / g_trades_completed;
      }
      
      score += win_rate * 500.0;  // Bonus for high win rate
   }
   
   return score;
}

// Include all helper functions from original EA
//+------------------------------------------------------------------+
//| Check if today is a valid trading day                            |
//+------------------------------------------------------------------+
bool IsTradingDay()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int day_of_week = dt.day_of_week;
   
   switch(day_of_week)
   {
   case 1: return range_on_monday;
   case 2: return range_on_tuesday;
   case 3: return range_on_wednesday;
   case 4: return range_on_thursday;
   case 5: return range_on_friday;
   default: return false;
   }
}

//+------------------------------------------------------------------+
//| Calculate the daily high/low range                               |
//+------------------------------------------------------------------+
void CalculateDailyRange()
{
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   
   datetime today = StructToTime(dt);
   g_range_start_time = today + range_start_time * 60;
   g_range_end_time = g_range_start_time + range_duration * 60;
   
   if(range_close_time > 0)
      g_close_time = today + range_close_time * 60;
   else
      g_close_time = 0;
   
   if(current_time < g_range_end_time)
      return;
   
   g_high_price = 0;
   g_low_price = 99999999;
   
   int bars_to_check = range_duration / PeriodSeconds(PERIOD_M1) * 60;
   if(bars_to_check > Bars(_Symbol, PERIOD_M1))
      bars_to_check = Bars(_Symbol, PERIOD_M1);
   
   for(int i = 0; i < bars_to_check; i++)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_M1, i);
      
      if(bar_time >= g_range_start_time && bar_time <= g_range_end_time)
      {
         double bar_high = iHigh(_Symbol, PERIOD_M1, i);
         if(bar_high > g_high_price)
            g_high_price = bar_high;
         
         double bar_low = iLow(_Symbol, PERIOD_M1, i);
         if(bar_low < g_low_price)
            g_low_price = bar_low;
      }
   }
   
   if(g_high_price > 0 && g_low_price < 99999999)
   {
      g_range_calculated = true;
      double range_size = g_high_price - g_low_price;
      double range_points = range_size / _Point;
      
      if(range_points > g_max_range_ever)
      {
         g_max_range_ever = range_points;
         g_max_range_date = TimeCurrent();
      }
      
      if(range_points < g_min_range_ever)
      {
         g_min_range_ever = range_points;
         g_min_range_date = TimeCurrent();
      }
      
      Print("Range calculated - High: ", g_high_price, " Low: ", g_low_price,
            " Range: ", range_points, " points");
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on the settings                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size)
{
   if(autolot)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double balance_ratio = account_balance / base_balance;
      double lot_size = NormalizeDouble(balance_ratio * lot, 2);
      
      if(lot_size < min_lot)
         lot_size = min_lot;
      else if(lot_size > max_lot)
         lot_size = max_lot;
      
      return lot_size;
   }
   else
   {
      return lot;
   }
}

//+------------------------------------------------------------------+
//| Place pending orders (original logic without NN)                 |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if(g_high_price <= 0 || g_low_price >= 99999999)
      return;
   
   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;
   
   if(max_range_size > 0 && range_points > max_range_size)
   {
      g_orders_placed = true;
      return;
   }
   
   if(min_range_size > 0 && range_points < min_range_size)
   {
      g_orders_placed = true;
      return;
   }
   
   double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;
   
   if(risk_percentage > 0)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * risk_percentage / 100.0;
      g_lot_size = CalculateLotSize(range_size);
      
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point_value = tick_value / tick_size * _Point;
      double sl_distance_points = risk_amount / (g_lot_size * point_value);
      
      buy_sl = g_high_price - sl_distance_points * _Point;
      sell_sl = g_low_price + sl_distance_points * _Point;
   }
   else
   {
      g_lot_size = CalculateLotSize(range_size);
   }
   
   if(take_profit > 0)
   {
      buy_tp = g_high_price + (range_size * take_profit / 100);
      sell_tp = g_low_price - (range_size * take_profit / 100);
   }
   
   trade.SetExpertMagicNumber(magic_number);
   
   bool buy_success = trade.BuyStop(
       g_lot_size, g_high_price, _Symbol,
       buy_sl, buy_tp, ORDER_TIME_DAY, 0,
       "Range Breakout Buy");
   
   if(buy_success)
      g_buy_ticket = trade.ResultOrder();
   
   bool sell_success = trade.SellStop(
       g_lot_size, g_low_price, _Symbol,
       sell_sl, sell_tp, ORDER_TIME_DAY, 0,
       "Range Breakout Sell");
   
   if(sell_success)
      g_sell_ticket = trade.ResultOrder();
   
   g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| Manage open orders                                               |
//+------------------------------------------------------------------+
void ManageOrders()
{
   if(StringCompare(breakout_mode, "one breakout per range") == 0)
   {
      bool buy_triggered = false;
      bool sell_triggered = false;
      
      if(g_buy_ticket > 0)
      {
         if(OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_BUY)
               buy_triggered = true;
         }
         else
         {
            if(PositionSelectByTicket(g_buy_ticket))
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  buy_triggered = true;
            }
            else
            {
               g_buy_ticket = 0;
            }
         }
      }
      
      if(g_sell_ticket > 0)
      {
         if(OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_SELL)
               sell_triggered = true;
         }
         else
         {
            if(PositionSelectByTicket(g_sell_ticket))
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  sell_triggered = true;
            }
            else
            {
               g_sell_ticket = 0;
            }
         }
      }
      
      if(buy_triggered && g_sell_ticket > 0)
      {
         if(OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_SELL_STOP)
               trade.OrderDelete(g_sell_ticket);
         }
         g_sell_ticket = 0;
      }
      else if(sell_triggered && g_buy_ticket > 0)
      {
         if(OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_BUY_STOP)
               trade.OrderDelete(g_buy_ticket);
         }
         g_buy_ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Close all orders for this EA                                     |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   int positions_total = PositionsTotal();
   for(int i = positions_total - 1; i >= 0; i--)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(position_ticket);
         }
      }
   }
   
   int orders_total = OrdersTotal();
   for(int i = orders_total - 1; i >= 0; i--)
   {
      ulong order_ticket = OrderGetTicket(i);
      if(order_ticket > 0)
      {
         if(OrderGetInteger(ORDER_MAGIC) == magic_number && 
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(order_ticket);
         }
      }
   }
   
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
   if(trailing_stop <= 0 || trailing_start <= 0)
      return;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      
      if(position_ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double position_sl = PositionGetDouble(POSITION_SL);
            double position_tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double current_price = (position_type == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double profit_points = 0;
            
            if(position_type == POSITION_TYPE_BUY)
               profit_points = (current_price - position_open_price) / _Point;
            else
               profit_points = (position_open_price - current_price) / _Point;
            
            if(profit_points < trailing_start)
               continue;
            
            double new_sl = 0;
            
            if(position_type == POSITION_TYPE_BUY)
            {
               new_sl = current_price - trailing_stop * _Point;
               
               if(position_sl == 0 || new_sl > position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
               }
            }
            else
            {
               new_sl = current_price + trailing_stop * _Point;
               
               if(position_sl == 0 || new_sl < position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
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
   DeleteAllLines();
   
   ObjectCreate(0, g_start_line_name, OBJ_VLINE, 0, g_range_start_time, 0);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_WIDTH, 2);
   
   ObjectCreate(0, g_end_line_name, OBJ_VLINE, 0, g_range_end_time, 0);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_WIDTH, 2);
   
   if(g_close_time > 0)
   {
      ObjectCreate(0, g_close_line_name, OBJ_VLINE, 0, g_close_time, 0);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_WIDTH, 2);
   }
   
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
   ChartRedraw();
}
