//+------------------------------------------------------------------+
//| BalanceRegression.mqh                                            |
//| Helper class for balance regression and Sharpe Ratio calculation |
//+------------------------------------------------------------------+
#include <Math\Alglib\alglib.mqh>

class CBalanceRegression
{
private:
    double m_start_balance;
    datetime m_from_date;
    bool m_volume_normalization;

public:
    void SetStartBalance(double balance) { m_start_balance = balance; }
    void SetFromDate(datetime from_date) { m_from_date = from_date; }
    void SetVolumeNormalization(bool norm) { m_volume_normalization = norm; }
    double GetProfitStability(datetime to_date)
    {
        double arr_profits[];
        double total_volume = 0;
        HistorySelect(m_from_date, to_date);
        uint total_deals = HistoryDealsTotal();
        ulong ticket_history_deal = 0;
        for (uint i = 0; i < total_deals; i++)
        {
            if ((ticket_history_deal = HistoryDealGetTicket(i)) > 0)
            {
                long deal_type = HistoryDealGetInteger(ticket_history_deal, DEAL_TYPE);
                double deal_volume = HistoryDealGetDouble(ticket_history_deal, DEAL_VOLUME);
                double deal_commission = HistoryDealGetDouble(ticket_history_deal, DEAL_COMMISSION);
                double deal_swap = HistoryDealGetDouble(ticket_history_deal, DEAL_SWAP);
                double deal_profit = HistoryDealGetDouble(ticket_history_deal, DEAL_PROFIT);
                if (deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
                    continue;
                if (deal_commission == 0.0 && deal_swap == 0.0 && deal_profit == 0.0)
                    continue;
                total_volume += deal_volume;
                int arr_size = ArraySize(arr_profits);
                ArrayResize(arr_profits, arr_size + 1, 50);
                if (arr_size == 0)
                    arr_profits[arr_size] = m_start_balance + deal_commission + deal_swap + deal_profit;
                else
                    arr_profits[arr_size] = arr_profits[arr_size - 1] + deal_commission + deal_swap + deal_profit;
            }
        }
        int arr_size = ArraySize(arr_profits);
        if (arr_size < 2)
            return 0.0;
        CMatrixDouble xy(arr_size, 2);
        for (int i = 0; i < arr_size; i++)
        {
            xy.Set(i, 0, i + 1);
            xy.Set(i, 1, arr_profits[i]);
        }
        CLinReg linear_regression;
        CLinearModel linear_model;
        CLRReport linear_report;
        int retcode;
        linear_regression.LRBuild(xy, arr_size, 1, retcode, linear_model, linear_report);
        if (retcode != 1)
        {
            Print("Linear regression failed, error code=", retcode);
            return 0.0;
        }
        int nvars;
        double coefficients[];
        linear_regression.LRUnpack(linear_model, coefficients, nvars);
        double coeff_a = coefficients[0];
        double coeff_b = coefficients[1];
        double TrendProfit = ((double)arr_size * coeff_a + coeff_b) - (1.0 * coeff_a + coeff_b);
        TrendProfit /= (double)arr_size;
        double TrendMSE = linear_report.m_RMSError;
        double ProfitStability = TrendProfit / TrendMSE;
        if (m_volume_normalization && total_volume > 0)
            ProfitStability /= total_volume;
        ProfitStability *= arr_size;
        return ProfitStability * 10000.0;
    }
    double GetSharpeRatio()
    {
        double returns[];
        double prev_balance = m_start_balance;
        double total_return = 0.0;
        double total_return_sq = 0.0;
        int n = 0;
        HistorySelect(m_from_date, TimeCurrent());
        uint total_deals = HistoryDealsTotal();
        ulong ticket_history_deal = 0;
        for (uint i = 0; i < total_deals; i++)
        {
            if ((ticket_history_deal = HistoryDealGetTicket(i)) > 0)
            {
                long deal_type = HistoryDealGetInteger(ticket_history_deal, DEAL_TYPE);
                double deal_commission = HistoryDealGetDouble(ticket_history_deal, DEAL_COMMISSION);
                double deal_swap = HistoryDealGetDouble(ticket_history_deal, DEAL_SWAP);
                double deal_profit = HistoryDealGetDouble(ticket_history_deal, DEAL_PROFIT);
                if (deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
                    continue;
                double new_balance = prev_balance + deal_commission + deal_swap + deal_profit;
                double ret = new_balance - prev_balance;
                total_return += ret;
                total_return_sq += ret * ret;
                prev_balance = new_balance;
                n++;
            }
        }
        if (n < 2)
            return 0.0;
        double mean = total_return / n;
        double variance = (total_return_sq - n * mean * mean) / (n - 1);
        double stddev = MathSqrt(variance);
        if (stddev == 0.0)
            return 0.0;
        return mean / stddev;
    }
};