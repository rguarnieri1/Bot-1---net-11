using BotCripto.Models;

namespace BotCripto.Strategies;

public class EmaRibbonTrendFollowingStrategy
{
    // Configurazione "B" scelta dall'ottimizzazione su 4 anni di dati (candele 6h):
    // i periodi sono ordinati dalla EMA più veloce alla più lenta (negli Indicators restano le chiavi EMA5/10/20/30:
    // indicano rispettivamente la 1ª, 2ª, 3ª e 4ª EMA del ribbon).
    private readonly int[] _emaPeriods = { 2, 3, 10, 30 };
    private readonly decimal _volumeMultiplierThreshold = 3.0m;  // Volume almeno 3x la media delle ultime 20 candele
    private const int BtcRegimeEmaPeriod = 20;
    private readonly decimal _bodyStrengthThreshold = 0.4m;      // Corpo almeno 40% della candela
    private const decimal RsiOverextendedHigh = 70m; // niente long oltre questo RSI
    private const decimal RsiOverextendedLow = 30m;  // niente short sotto questo RSI
    private const decimal StopBuffer = 0.015m;       // stop 1,5% oltre EMA/estremo della candela

    // Filtro "mercato laterale": il prezzo di BTC deve essere almeno il 3% lontano dalla sua EMA a 5 periodi
    // (in valore assoluto): se BTC resta attaccato alla media il mercato è laterale e non si opera.
    private const int BtcTrendEmaPeriod = 5;
    private const decimal BtcMinDistanceFromEma = 0.03m;

    // Regime di mercato: true se BTC chiude sopra la sua EMA20 sull'ultima candela, false se sotto,
    // null se i dati BTC non sono sufficienti.
    public static bool? IsBtcBullish(List<Candle> btcCandles)
    {
        var ema = TechnicalIndicators.CalculateEMA(btcCandles.Select(c => c.Close).ToList(), BtcRegimeEmaPeriod);
        if (ema.Count == 0)
            return null;
        return btcCandles.Last().Close > ema.Last();
    }

    // Filtro mercato laterale: true se BTC è abbastanza "mosso" da operare, false se laterale,
    // null se i dati BTC non sono sufficienti.
    public static bool? IsBtcTrending(List<Candle> btcCandles)
    {
        var ema = TechnicalIndicators.CalculateEMA(btcCandles.Select(c => c.Close).ToList(), BtcTrendEmaPeriod);
        if (ema.Count == 0 || ema.Last() <= 0)
            return null;
        return Math.Abs(btcCandles.Last().Close - ema.Last()) / ema.Last() >= BtcMinDistanceFromEma;
    }

    // btcBullish: regime BTC (vedi IsBtcBullish). Long solo con BTC rialzista, short solo con BTC ribassista;
    // se il regime è sconosciuto (null) il segnale viene scartato.
    // btcTrending: filtro mercato laterale (vedi IsBtcTrending); se BTC è laterale o sconosciuto il segnale viene scartato.
    public AnalysisResult Analyze(string symbol, List<Candle> candles, bool? btcBullish, bool? btcTrending)
    {
        var result = new AnalysisResult
        {
            Symbol = symbol,
            StrategyName = "EMA Ribbon Trend Following + Candle Confirmation",
            IsSignal = false,
            Signal = "No Signal",
            AnalysisTime = DateTime.UtcNow
        };

        if (candles.Count < 60)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var closes = candles.Select(c => c.Close).ToList();
        var volumes = candles.Select(c => c.Volume).ToList();
        var highs = candles.Select(c => c.High).ToList();
        var lows = candles.Select(c => c.Low).ToList();

        // 1️⃣ CALCULATE EMA RIBBON
        var emaRibbon = new Dictionary<int, List<decimal>>();
        foreach (var period in _emaPeriods)
        {
            emaRibbon[period] = TechnicalIndicators.CalculateEMA(closes, period);
        }

        // Verifica che tutte le EMA siano state calcolate
        if (emaRibbon.Values.Any(ema => ema.Count == 0))
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var currentPrice = closes.Last();
        var lastEma5 = emaRibbon[_emaPeriods[0]].Last();   // EMA più veloce
        var lastEma10 = emaRibbon[_emaPeriods[1]].Last();
        var lastEma20 = emaRibbon[_emaPeriods[2]].Last();  // usata anche per lo stop
        var lastEma30 = emaRibbon[_emaPeriods[3]].Last();  // EMA più lenta

        result.Indicators["EMA5"] = lastEma5;
        result.Indicators["EMA10"] = lastEma10;
        result.Indicators["EMA20"] = lastEma20;
        result.Indicators["EMA30"] = lastEma30;
        result.CurrentPrice = currentPrice;

        // 2️⃣ TREND FILTER - Ribbon Alignment Check
        // Uptrend: EMA5 > EMA10 > EMA20 > EMA30
        // Downtrend: EMA5 < EMA10 < EMA20 < EMA30
        bool isUptrendAligned = lastEma5 > lastEma10 && lastEma10 > lastEma20 && lastEma20 > lastEma30;
        bool isDowntrendAligned = lastEma5 < lastEma10 && lastEma10 < lastEma20 && lastEma20 < lastEma30;

        if (!isUptrendAligned && !isDowntrendAligned)
        {
            result.Signal = "Rejected - EMA Ribbon not aligned (no clear trend)";
            result.Rejection = RejectionReason.TrendNotAligned;
            return result;
        }

        result.Indicators["Trend"] = isUptrendAligned ? 1 : -1;
        var trendType = isUptrendAligned ? "UPTREND" : "DOWNTREND";

        // 3️⃣ VOLUME FILTER - Ensure strong volume
        var avgVolume = volumes.TakeLast(20).Average();
        var recentVolume = volumes.Last();

        if (avgVolume <= 0)
        {
            result.Signal = "Rejected - No volume data";
            result.Rejection = RejectionReason.NoVolumeData;
            return result;
        }

        if (recentVolume < avgVolume * _volumeMultiplierThreshold)
        {
            result.Signal = "Rejected - Volume insufficient";
            result.Rejection = RejectionReason.VolumeInsufficient;
            return result;
        }

        result.Indicators["Volume"] = recentVolume;
        result.Indicators["AvgVolume"] = avgVolume;
        result.Indicators["VolumeRatio"] = recentVolume / avgVolume;

        // 4️⃣ CANDLE CONFIRMATION - Solid body and alignment
        var lastCandle = candles.Last();

        decimal lastCandleBody, lastCandleRange, bodyStrength;
        bool lastCandleConfirms;

        if (isUptrendAligned)
        {
            // UPTREND - Green candles with solid bodies
            lastCandleBody = lastCandle.Close - lastCandle.Open;
            lastCandleRange = lastCandle.High - lastCandle.Low;
            bodyStrength = lastCandleRange > 0 ? lastCandleBody / lastCandleRange : 0;

            // Candle deve essere bullish e con corpo solido
            lastCandleConfirms = lastCandleBody > 0 && bodyStrength >= _bodyStrengthThreshold;

            if (!lastCandleConfirms)
            {
                result.Signal = "Rejected - Last candle not bullish enough";
                result.Rejection = RejectionReason.CandleNotStrong;
                return result;
            }

            // Verifica che il prezzo sia almeno al livello di EMA10 per conferma forte
            if (currentPrice < lastEma10)
            {
                result.Signal = "Rejected - Price below EMA10 (weak uptrend)";
                result.Rejection = RejectionReason.PriceVsEma10;
                return result;
            }
        }
        else
        {
            // DOWNTREND - Red candles with solid bodies
            lastCandleBody = lastCandle.Open - lastCandle.Close;
            lastCandleRange = lastCandle.High - lastCandle.Low;
            bodyStrength = lastCandleRange > 0 ? lastCandleBody / lastCandleRange : 0;

            // Candle deve essere bearish e con corpo solido
            lastCandleConfirms = lastCandleBody > 0 && bodyStrength >= _bodyStrengthThreshold;

            if (!lastCandleConfirms)
            {
                result.Signal = "Rejected - Last candle not bearish enough";
                result.Rejection = RejectionReason.CandleNotStrong;
                return result;
            }

            // Verifica che il prezzo sia almeno al livello di EMA10 per conferma forte
            if (currentPrice > lastEma10)
            {
                result.Signal = "Rejected - Price above EMA10 (weak downtrend)";
                result.Rejection = RejectionReason.PriceVsEma10;
                return result;
            }
        }

        result.Indicators["CandleBodyStrength"] = bodyStrength;

        // 5️⃣ RSI FILTER - Avoid overbought/oversold extremes
        var rsi = TechnicalIndicators.CalculateRSI(closes);
        if (rsi.Count < 1)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var currentRSI = rsi.Last();
        result.Indicators["RSI"] = currentRSI;

        // Non vogliamo segnali quando RSI è estremamente overextended
        if (isUptrendAligned && currentRSI > RsiOverextendedHigh)
        {
            result.Signal = "Rejected - RSI overbought (extended move)";
            result.Rejection = RejectionReason.RsiExtreme;
            return result;
        }

        if (isDowntrendAligned && currentRSI < RsiOverextendedLow)
        {
            result.Signal = "Rejected - RSI oversold (extended move)";
            result.Rejection = RejectionReason.RsiExtreme;
            return result;
        }

        // 6️⃣ BREAKOUT FROM EMA CONFIRMATION
        // Price should have just crossed above/below key EMA
        var prevPrice = candles[^2].Close;

        bool breakoutConfirmed = false;
        if (isUptrendAligned)
        {
            // Prezzo rompe sopra EMA5 o passa sopra EMA10
            breakoutConfirmed = (prevPrice <= lastEma5 && currentPrice > lastEma5) ||
                               (prevPrice < lastEma10 && currentPrice > lastEma10 && currentPrice > lastEma5);
        }
        else
        {
            // Prezzo rompe sotto EMA5 o passa sotto EMA10
            breakoutConfirmed = (prevPrice >= lastEma5 && currentPrice < lastEma5) ||
                               (prevPrice > lastEma10 && currentPrice < lastEma10 && currentPrice < lastEma5);
        }

        if (!breakoutConfirmed)
        {
            result.Signal = "Rejected - No EMA breakout confirmation";
            result.Rejection = RejectionReason.NoBreakout;
            return result;
        }

        // 7️⃣ BTC REGIME FILTER - segui la direzione del mercato
        if (btcBullish == null || btcBullish != isUptrendAligned)
        {
            result.Signal = "Rejected - Against BTC regime";
            result.Rejection = RejectionReason.AgainstBtcRegime;
            return result;
        }

        // 8️⃣ SIDEWAYS FILTER - niente operazioni quando BTC è in fase laterale
        if (btcTrending != true)
        {
            result.Signal = "Rejected - BTC sideways (close within 3% of EMA5)";
            result.Rejection = RejectionReason.AgainstBtcRegime;
            return result;
        }

        // ✅ SIGNAL GENERATED
        if (isUptrendAligned)
        {
            result.IsSignal = true;
            result.Signal = "🟢 BUY - EMA Ribbon Bullish (Trend + Candle + Volume)";
            result.Indicators["StopLoss"] = Math.Min(lastEma20, lastCandle.Low) * (1 - StopBuffer);
        }
        else
        {
            result.IsSignal = true;
            result.Signal = "🔴 SELL - EMA Ribbon Bearish (Trend + Candle + Volume)";
            result.Indicators["StopLoss"] = Math.Max(lastEma20, lastCandle.High) * (1 + StopBuffer);
        }

        result.Indicators["SignalStrength"] = Math.Min(1m, bodyStrength + (recentVolume / avgVolume - 1) * 0.5m);

        return result;
    }
}
