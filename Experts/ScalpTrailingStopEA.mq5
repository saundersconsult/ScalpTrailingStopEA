//+------------------------------------------------------------------+
//| ScalpTrailingStopEA.mq5                                          |
//| Version 1.00                                                     |
//+------------------------------------------------------------------+
//| Copyright 2025, ScalpTrailingStopEA Development Team             |
//| https://github.com/saundersconsult/ScalpTrailingStopEA           |
//+------------------------------------------------------------------+
//| EXPERT ADVISOR: ScalpTrailingStopEA                              |
//| Version 1.00                                                     |
//|                                                                   |
//| CAPABILITIES:                                                    |
//| - Multi-indicator scalping strategy (MACD + Stochastic)          |
//| - Trailing stop loss that moves in sync with take profit         |
//| - Configurable timeframe selection                               |
//| - Points-based take profit system                                |
//| - Dynamic stop loss placement (nearest highs/lows + 1 point)     |
//| - Backtest support with optimization parameters                  |
//| - Customizable indicator settings for market adaptation          |
//| - Max spread filtering for execution quality                     |
//| - Trading hours and days filter                                  |
//| - Optional news avoidance                                        |
//| - Flexible position sizing (fixed lots or % risk)                |
//|                                                                   |
//| OPTIMUM TIMEFRAME: 1M                                            |
//|                                                                   |
//| RECOMMENDED PAIRS:                                               |
//| Any High Volatility Pairs                                        |
//| Initial Testing: AUDJPY, GBPNZD, CADJPY, EURUSD, GBPUSD         |
//|                                                                   |
//| TRADING HOURS RECOMMENDATION:                                    |
//| Recommend Major pairs group - lower spreads, higher margin,      |
//| and recommend American or European trading hours for best        |
//| results.                                                          |
//|                                                                   |
//| FUTURE IMPROVEMENTS:                                             |
//| - Advanced money management with dynamic risk adjustment         |
//| - Multi-timeframe confirmation filters                           |
//| - Trade statistics and performance analytics                     |
//| - Machine learning parameter optimization                        |
//| - Advanced trailing algorithms (ATR-based, percentage-based)     |
//| - Partial position closing for profit taking                     |
//| - Break-even stop loss automation                                |
//| - News feed integration for automated avoidance                  |
//+------------------------------------------------------------------+

#property strict
#property copyright "2025, ScalpTrailingStopEA Development Team"
#property link      "https://github.com/saundersconsult/ScalpTrailingStopEA"
#property version   "1.00"
#property description "Scalping EA with trailing stop loss synchronized to take profit"

//--- Input Parameters
input group "=== GENERAL SETTINGS ==="
input ulong InpMagicNumber = 111333;           // Magic Number for trade identification
input double InpMaxSpread = 20;                 // Maximum spread in points (default 20)
input double InpSlippage = 0;                   // Slippage in pips (default 0)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1; // Timeframe for analysis
input string InpComment = "ScalpTrailingStopEA"; // Terminal comment (editable)
input bool InpAllowAlgoTrading = true;          // Allow algorithmic trading (default true)
input ENUM_ORDER_TYPE_FILLING InpOrderFilling = ORDER_FILLING_IOC; // Order filling mode (IOC=Immediate-or-Cancel, FOK=Fill-or-Kill)

input group "=== POSITION SETTINGS ==="
input double InpLongTakeProfit = 10;            // Long position take profit in points
input double InpShortTakeProfit = 10;           // Short position take profit in points

input group "=== POSITION SIZING ==="
input double InpLotSize = 0;                    // Fixed lot size (0 = use risk %)
input double InpRiskPercent = 1.0;              // Risk percentage if lot size = 0 (default 1%)
input bool InpRiskOnBalance = true;             // Risk based on Balance (true) or Equity (false)

input group "=== TRADING HOURS & DAYS ==="
input bool InpUseTimeFilter = false;            // Enable trading hours filter
input int InpStartHour = 0;                     // Start hour (0-23, default 0)
input int InpStartMinute = 0;                   // Start minute (0-59, default 0)
input int InpEndHour = 23;                      // End hour (0-23, default 23)
input int InpEndMinute = 59;                    // End minute (0-59, default 59)
input bool InpTradeMondayFriday = true;         // Trade Monday-Friday (default true)
input bool InpTradeSaturday = false;            // Trade Saturday (default false)
input bool InpTradeSunday = false;              // Trade Sunday (default false)

input group "=== NEWS SETTINGS ==="
input bool InpAvoidNews = false;                // Avoid trading during major news (default false)
input int InpNewsMinutesBefore = 30;            // Minutes before news to stop trading
input int InpNewsMinutesAfter = 30;             // Minutes after news to resume trading

input group "=== MACD SETTINGS ==="
input int InpMACDFastMA = 13;                   // MACD Fast EMA period (default 13)
input int InpMACDSlowMA = 26;                   // MACD Slow EMA period (default 26)
input int InpMACDSignal = 9;                    // MACD Signal line SMA period (default 9)
input ENUM_APPLIED_PRICE InpMACDAppliedPrice = PRICE_CLOSE; // Applied price for MACD

input group "=== STOCHASTIC SETTINGS ==="
input int InpStochKPeriod = 3;                  // Stochastic %K period (default 3)
input int InpStochDPeriod = 3;                  // Stochastic %D period (default 3)
input int InpStochSlowing = 9;                  // Stochastic Slowing (default 9)
input ENUM_STO_PRICE InpStochPriceField = STO_LOWHIGH; // Price field (Low/High or Close/Close)
input ENUM_MA_METHOD InpStochMethod = MODE_SMMA; // Smoothing method (Smoothed by default)

//--- Global Variables
int hMACD = INVALID_HANDLE;
int hStoch = INVALID_HANDLE;
double macdMain[], macdSignal[];
double stochMain[], stochSignal[];

//--- Entry signal tracking (prevent multiple entries on same signal)
bool lastLongSignalProcessed = false;
bool lastShortSignalProcessed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create MACD indicator handle
   hMACD = iMACD(_Symbol, InpTimeframe, InpMACDFastMA, InpMACDSlowMA, 
                 InpMACDSignal, InpMACDAppliedPrice);
   if(hMACD == INVALID_HANDLE)
   {
      Print("Error creating MACD indicator: ", GetLastError());
      return INIT_FAILED;
   }

   // Create Stochastic indicator handle
   hStoch = iStochastic(_Symbol, InpTimeframe, InpStochKPeriod, InpStochDPeriod,
                        InpStochSlowing, InpStochMethod, InpStochPriceField);
   if(hStoch == INVALID_HANDLE)
   {
      Print("Error creating Stochastic indicator: ", GetLastError());
      return INIT_FAILED;
   }

   // Set indicator buffers as series
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(stochMain, true);
   ArraySetAsSeries(stochSignal, true);

   Print("ScalpTrailingStopEA v1.00 initialized successfully. Magic Number: ", InpMagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(hMACD != INVALID_HANDLE)
      IndicatorRelease(hMACD);
   if(hStoch != INVALID_HANDLE)
      IndicatorRelease(hStoch);

   Print("ScalpTrailingStopEA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if algo trading is allowed
   if(!InpAllowAlgoTrading)
   {
      Comment("Algorithmic trading is disabled");
      return;
   }

   // Check trading hours and days filter
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      Comment("Outside trading hours");
      return;
   }

   // Check news filter
   if(InpAvoidNews && IsNearNewsEvent())
   {
      Comment("Near major news event - trading paused");
      return;
   }

   // Check if we have enough bars
   if(Bars(_Symbol, InpTimeframe) < 30)
      return;

   // Check spread filter
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpread)
   {
      Comment("Spread too high: ", DoubleToString(spread, 1), " > ", DoubleToString(InpMaxSpread, 1));
      return;
   }

   // Update indicator buffers
   if(!UpdateIndicators())
      return;

   // Update trailing stops for existing positions
   UpdateTrailingStops();

   // Check for existing positions
   if(HasOpenPosition())
   {
      // Reset signal flags when position is open (prevents new entries while trading)
      lastLongSignalProcessed = false;
      lastShortSignalProcessed = false;
      UpdateComment();
      return;
   }

   // Reset signals when no position is open (ready for new entry)
   bool longSignal = CheckLongSignal();
   bool shortSignal = CheckShortSignal();

   // Only open if signal is new (not already processed)
   if(longSignal && !lastLongSignalProcessed)
   {
      OpenLongPosition();
      lastLongSignalProcessed = true;
      lastShortSignalProcessed = false;
   }
   else if(shortSignal && !lastShortSignalProcessed)
   {
      OpenShortPosition();
      lastShortSignalProcessed = true;
      lastLongSignalProcessed = false;
   }

   // Clear signal flags if signals are no longer active
   if(!longSignal)
      lastLongSignalProcessed = false;
   if(!shortSignal)
      lastShortSignalProcessed = false;
}

//+------------------------------------------------------------------+
//| Update indicator buffers                                         |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // Copy MACD values
   if(CopyBuffer(hMACD, 0, 0, 3, macdMain) <= 0)
   {
      Print("Error copying MACD main buffer: ", GetLastError());
      return false;
   }
   if(CopyBuffer(hMACD, 1, 0, 3, macdSignal) <= 0)
   {
      Print("Error copying MACD signal buffer: ", GetLastError());
      return false;
   }

   // Copy Stochastic values
   if(CopyBuffer(hStoch, 0, 0, 3, stochMain) <= 0)
   {
      Print("Error copying Stochastic main buffer: ", GetLastError());
      return false;
   }
   if(CopyBuffer(hStoch, 1, 0, 3, stochSignal) <= 0)
   {
      Print("Error copying Stochastic signal buffer: ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check for long signal                                            |
//+------------------------------------------------------------------+
bool CheckLongSignal()
{
   // MACD must be in positive zone (above zero)
   if(macdMain[1] <= 0)
      return false;

   // Stochastic was below 20 and has risen above it
   if(stochMain[2] >= 20)  // Previous bar must be below 20
      return false;
   
   if(stochMain[1] <= 20)  // Current bar must be above 20
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check for short signal                                           |
//+------------------------------------------------------------------+
bool CheckShortSignal()
{
   // MACD must be in negative zone (below zero)
   if(macdMain[1] >= 0)
      return false;

   // Stochastic was above 80 and has declined below it
   if(stochMain[2] <= 80)  // Previous bar must be above 80
      return false;
   
   if(stochMain[1] >= 80)  // Current bar must be below 80
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Open long position                                               |
//+------------------------------------------------------------------+
void OpenLongPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = GetLongStopLoss();
   double takeProfit = ask + (InpLongTakeProfit * _Point);
   
   // Get broker's minimum stop level
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = (stopLevel == 0 ? 10 : stopLevel) * _Point; // Minimum 10 points if broker allows 0
   
   // Validate and adjust stop loss distance
   if(ask - stopLoss < minDistance)
   {
      stopLoss = ask - minDistance;
      Print("Stop loss adjusted to meet broker requirements: ", stopLoss);
   }
   
   // Validate and adjust take profit distance
   if(takeProfit - ask < minDistance)
   {
      takeProfit = ask + minDistance;
      Print("Take profit adjusted to meet broker requirements: ", takeProfit);
   }
   
   // Normalize prices
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   double volume = CalculateVolume(ask, stopLoss);

   // Validate stop loss
   if(stopLoss >= ask)
   {
      Print("Invalid stop loss for long position");
      return;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = (ulong)InpSlippage;
   request.comment = InpComment;
   request.magic = InpMagicNumber;
   request.type_filling = InpOrderFilling;  // Set execution mode

   if(OrderSend(request, result))
   {
      Print("Long position opened at ", ask, " SL: ", stopLoss, " TP: ", takeProfit);
   }
   else
   {
      Print("Failed to open long position. Error: ", GetLastError(), " Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Open short position                                              |
//+------------------------------------------------------------------+
void OpenShortPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = GetShortStopLoss();
   double takeProfit = bid - (InpShortTakeProfit * _Point);
   
   // Get broker's minimum stop level
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = (stopLevel == 0 ? 10 : stopLevel) * _Point; // Minimum 10 points if broker allows 0
   
   // Validate and adjust stop loss distance
   if(stopLoss - bid < minDistance)
   {
      stopLoss = bid + minDistance;
      Print("Stop loss adjusted to meet broker requirements: ", stopLoss);
   }
   
   // Validate and adjust take profit distance
   if(bid - takeProfit < minDistance)
   {
      takeProfit = bid - minDistance;
      Print("Take profit adjusted to meet broker requirements: ", takeProfit);
   }
   
   // Normalize prices
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   double volume = CalculateVolume(bid, stopLoss);

   // Validate stop loss
   if(stopLoss <= bid)
   {
      Print("Invalid stop loss for short position");
      return;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = (ulong)InpSlippage;
   request.comment = InpComment;
   request.magic = InpMagicNumber;
   request.type_filling = InpOrderFilling;  // Set execution mode

   if(OrderSend(request, result))
   {
      Print("Short position opened at ", bid, " SL: ", stopLoss, " TP: ", takeProfit);
   }
   else
   {
      Print("Failed to open short position. Error: ", GetLastError(), " Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Get stop loss for long position (1 point below nearest low)      |
//+------------------------------------------------------------------+
double GetLongStopLoss()
{
   double nearestLow = iLow(_Symbol, InpTimeframe, 1); // Previous bar low
   return nearestLow - _Point;
}

//+------------------------------------------------------------------+
//| Get stop loss for short position (1 point above nearest high)    |
//+------------------------------------------------------------------+
double GetShortStopLoss()
{
   double nearestHigh = iHigh(_Symbol, InpTimeframe, 1); // Previous bar high
   return nearestHigh + _Point;
}

//+------------------------------------------------------------------+
//| Update trailing stops for all open positions                     |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

      double newSL = currentSL;
      double distanceFromTP = 0;

      if(posType == POSITION_TYPE_BUY)
      {
         // Calculate distance between current SL and TP
         distanceFromTP = currentTP - currentSL;
         
         // Calculate new SL maintaining distance from TP as price moves up
         double potentialNewSL = currentTP - distanceFromTP;
         
         // Only move SL up, never down
         if(potentialNewSL > currentSL && potentialNewSL < currentPrice)
         {
            newSL = NormalizeDouble(potentialNewSL, _Digits);
            ModifyPosition(ticket, newSL, currentTP);
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         // Calculate distance between current TP and SL
         distanceFromTP = currentSL - currentTP;
         
         // Calculate new SL maintaining distance from TP as price moves down
         double potentialNewSL = currentTP + distanceFromTP;
         
         // Only move SL down, never up
         if(potentialNewSL < currentSL && potentialNewSL > currentPrice)
         {
            newSL = NormalizeDouble(potentialNewSL, _Digits);
            ModifyPosition(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify position SL and TP                                        |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double newSL, double newTP)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = newSL;
   request.tp = newTP;
   request.magic = InpMagicNumber;
   request.symbol = _Symbol;

   if(!OrderSend(request, result))
   {
      Print("Error modifying position: ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate trading volume                                         |
//+------------------------------------------------------------------+
double CalculateVolume(double entryPrice, double stopLoss)
{
   double volume = InpLotSize;

   // If lot size is set to 0, calculate based on risk percentage
   if(InpLotSize <= 0)
   {
      double accountValue = InpRiskOnBalance ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = accountValue * (InpRiskPercent / 100.0);
      double stopLossPoints = MathAbs(entryPrice - stopLoss) / _Point;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(stopLossPoints > 0 && tickValue > 0)
      {
         volume = riskAmount / (stopLossPoints * tickValue);
      }
      else
      {
         volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      }
   }

   // Normalize and validate volume
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathMax(volume, minVolume);
   volume = MathMin(volume, maxVolume);
   volume = NormalizeDouble(volume / volumeStep, 0) * volumeStep;

   return volume;
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   // Check day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
   if(dt.day_of_week == 0 && !InpTradeSunday)
      return false;
   if(dt.day_of_week == 6 && !InpTradeSaturday)
      return false;
   if(dt.day_of_week >= 1 && dt.day_of_week <= 5 && !InpTradeMondayFriday)
      return false;

   // Check time
   int currentTime = dt.hour * 100 + dt.min;
   int startTime = InpStartHour * 100 + InpStartMinute;
   int endTime = InpEndHour * 100 + InpEndMinute;

   if(startTime <= endTime)
   {
      return (currentTime >= startTime && currentTime <= endTime);
   }
   else
   {
      // Overnight session
      return (currentTime >= startTime || currentTime <= endTime);
   }
}

//+------------------------------------------------------------------+
//| Check if near news event (placeholder)                           |
//+------------------------------------------------------------------+
bool IsNearNewsEvent()
{
   // Placeholder for news detection logic
   // In production, integrate with news calendar API or service
   return false;
}

//+------------------------------------------------------------------+
//| Update chart comment                                             |
//+------------------------------------------------------------------+
void UpdateComment()
{
   string comment = "";
   comment += "EA: " + InpComment + " v1.00\n";
   comment += "Magic: " + IntegerToString(InpMagicNumber) + "\n";
   comment += "Timeframe: " + EnumToString(InpTimeframe) + "\n";
   comment += "Spread: " + DoubleToString((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point, 1) + " pts\n";
   comment += "MACD: " + DoubleToString(macdMain[1], 5) + "\n";
   comment += "Stoch: " + DoubleToString(stochMain[1], 2) + "\n";

   Comment(comment);
}
