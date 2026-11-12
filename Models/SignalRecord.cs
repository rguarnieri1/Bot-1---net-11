namespace BotCripto.Models;

// Segnale valido della strategia (AnalysisResult con IsSignal = true) calcolato sulle candele di crypto.com,
// con gli indicatori e l'esito del Risk Manager. Salvato nella tabella bot1.bot1_signals.
public class SignalRecord
{
    public long Id { get; set; }
    public string Symbol { get; set; } = "";
    public string? Strategy { get; set; }
    public string? Signal { get; set; }
    public bool IsLong { get; set; }
    public string? Timeframe { get; set; }
    public DateTime SignalCandleTime { get; set; }
    public DateTime AnalysisTime { get; set; }
    public decimal Price { get; set; }

    // Indicatori della strategia
    public decimal? EMA5 { get; set; }
    public decimal? EMA10 { get; set; }
    public decimal? EMA20 { get; set; }
    public decimal? EMA30 { get; set; }
    public int? Trend { get; set; }
    public decimal? Volume { get; set; }
    public decimal? AvgVolume { get; set; }
    public decimal? VolumeRatio { get; set; }
    public decimal? CandleBodyStrength { get; set; }
    public decimal? RSI { get; set; }
    public decimal? SignalStrength { get; set; }
    public decimal? StopLoss { get; set; }

    // Esito del Risk Manager
    public bool Accepted { get; set; }
    public string? RejectionReason { get; set; }
    public decimal? Target { get; set; }
    public decimal? PositionSize { get; set; }
    public decimal? RiskRewardRatio { get; set; }
    public decimal? ExpectedProfit { get; set; }
    public string? TradeId { get; set; }

    // Crea il record dal risultato dell'analisi, copiando gli indicatori presenti
    public static SignalRecord FromAnalysis(AnalysisResult a, string timeframe, DateTime signalCandleTime, decimal price, bool isLong)
    {
        decimal? I(string key) => a.Indicators.TryGetValue(key, out var v) ? v : null;
        return new SignalRecord
        {
            Symbol = a.Symbol,
            Strategy = a.StrategyName,
            Signal = a.Signal,
            IsLong = isLong,
            Timeframe = timeframe,
            SignalCandleTime = signalCandleTime,
            AnalysisTime = a.AnalysisTime,
            Price = price,
            EMA5 = I("EMA5"),
            EMA10 = I("EMA10"),
            EMA20 = I("EMA20"),
            EMA30 = I("EMA30"),
            Trend = I("Trend") is decimal t ? (int)t : null,
            Volume = I("Volume"),
            AvgVolume = I("AvgVolume"),
            VolumeRatio = I("VolumeRatio"),
            CandleBodyStrength = I("CandleBodyStrength"),
            RSI = I("RSI"),
            SignalStrength = I("SignalStrength"),
            StopLoss = I("StopLoss")
        };
    }
}
