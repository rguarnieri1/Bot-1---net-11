-- Tabella bot1.Signals del Bot 1: un record per ogni segnale valido della strategia EMA Ribbon
-- calcolato sulle candele scaricate da crypto.com (AnalysisResult con IsSignal = true),
-- con gli indicatori della strategia e l'esito del Risk Manager. Non fa nulla se la tabella esiste già.
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot1') IS NULL
    EXEC(N'CREATE SCHEMA [bot1]');
GO
IF OBJECT_ID(N'bot1.Signals', N'U') IS NULL
BEGIN
    CREATE TABLE [bot1].[Signals] (
        [Id]                 bigint IDENTITY(1,1) NOT NULL,
        [Symbol]             nvarchar(50)    NOT NULL,
        [Strategy]           nvarchar(200)   NULL,   -- StrategyName
        [Signal]             nvarchar(200)   NULL,   -- testo del segnale, es. BUY - EMA Ribbon Bullish
        [IsLong]             bit             NOT NULL,
        [Timeframe]          nvarchar(10)    NULL,   -- es. 12h
        [SignalCandleTime]   datetime2       NOT NULL, -- inizio della candela chiusa che ha generato il segnale (UTC)
        [AnalysisTime]       datetime2       NOT NULL, -- momento dell'analisi (UTC)
        [Price]              decimal(38, 18) NOT NULL, -- CurrentPrice = chiusura della candela del segnale
        -- Indicatori della strategia
        [EMA5]               decimal(38, 18) NULL,
        [EMA10]              decimal(38, 18) NULL,
        [EMA20]              decimal(38, 18) NULL,
        [EMA30]              decimal(38, 18) NULL,
        [Trend]              int             NULL,   -- 1 rialzista, -1 ribassista
        [Volume]             decimal(38, 18) NULL,
        [AvgVolume]          decimal(38, 18) NULL,
        [VolumeRatio]        decimal(38, 18) NULL,
        [CandleBodyStrength] decimal(38, 18) NULL,
        [RSI]                decimal(38, 18) NULL,
        [SignalStrength]     decimal(38, 18) NULL,
        [StopLoss]           decimal(38, 18) NULL,
        -- Esito del Risk Manager
        [Accepted]           bit             NOT NULL, -- 1 = trade aperto, 0 = scartato dal Risk Manager
        [RejectionReason]    nvarchar(100)   NULL,
        [Target]             decimal(38, 18) NULL,
        [PositionSize]       decimal(38, 18) NULL,
        [RiskRewardRatio]    decimal(38, 18) NULL,
        [ExpectedProfit]     decimal(38, 18) NULL,
        [TradeId]            nvarchar(36)    NULL,   -- bot1.Trades.Id del trade aperto dal segnale
        [Bot]                nvarchar(50)    NOT NULL CONSTRAINT [DF_Signals_Bot] DEFAULT (N'Bot 1'), -- bot che ha scritto la riga
        CONSTRAINT [PK_Signals] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_Signals_Symbol_SignalCandleTime] ON [bot1].[Signals] ([Symbol], [SignalCandleTime]);
    PRINT 'Tabella bot1.Signals creata';
END
ELSE
    PRINT 'Tabella bot1.Signals gia esistente: nessuna modifica';
GO
