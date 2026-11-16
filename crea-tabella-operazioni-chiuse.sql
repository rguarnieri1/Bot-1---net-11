-- Tabella bot1.bot1_operazioni_chiuse del Bot 1: un record per ogni operazione chiusa,
-- con gli stessi campi del blocco "OPERAZIONE CHIUSA" che veniva scritto in Logs/Operazioni_chiuse.log.
-- Non modifica la tabella se esiste gia. Alla fine copia da bot1.bot1_trades le operazioni
-- gia chiuse che mancano (una riga per trade, senza duplicati).
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot1') IS NULL
    EXEC(N'CREATE SCHEMA [bot1]');
GO
IF OBJECT_ID(N'bot1.bot1_operazioni_chiuse', N'U') IS NULL
BEGIN
    CREATE TABLE [bot1].[bot1_operazioni_chiuse] (
        [Id]               bigint IDENTITY(1,1) NOT NULL,
        [TradeId]          nvarchar(36)    NOT NULL, -- "ID" = bot1.bot1_trades.Id
        [Symbol]           nvarchar(50)    NULL,     -- "Simbolo"
        [Strategy]         nvarchar(200)   NULL,     -- "Strategia"
        [IsLong]           bit             NOT NULL, -- "Direzione": 1 = LONG, 0 = SHORT
        [StopLoss]         decimal(38, 18) NULL,     -- "Stop Loss"
        [TargetPrice]      decimal(38, 18) NULL,     -- "Target"
        [ExitReason]       nvarchar(100)   NULL,     -- "Motivo uscita", es. Stop loss
        [EntryPrice]       decimal(38, 18) NOT NULL, -- "Prezzo Entrata"
        [ExitPrice]        decimal(38, 18) NULL,     -- "Prezzo Uscita"
        [Profit]           decimal(38, 18) NULL,     -- "Profitto" (EUR, netto commissioni)
        [ProfitPercentage] decimal(38, 18) NULL,     -- "Percentuale"
        [Status]           nvarchar(20)    NULL,     -- "Stato"
        [OpenTime]         datetime2       NOT NULL, -- "Apertura" (UTC)
        [CloseTime]        datetime2       NOT NULL, -- "Chiusura" (UTC)
        [Bot]              nvarchar(50)    NOT NULL CONSTRAINT [DF_bot1_operazioni_chiuse_Bot] DEFAULT (N'Bot 1'), -- bot che ha scritto la riga
        CONSTRAINT [PK_bot1_operazioni_chiuse] PRIMARY KEY ([Id])
    );
    CREATE UNIQUE INDEX [UX_bot1_operazioni_chiuse_TradeId] ON [bot1].[bot1_operazioni_chiuse] ([TradeId]);
    CREATE INDEX [IX_bot1_operazioni_chiuse_CloseTime] ON [bot1].[bot1_operazioni_chiuse] ([CloseTime]);
    PRINT 'Tabella bot1.bot1_operazioni_chiuse creata';
END
ELSE
    PRINT 'Tabella bot1.bot1_operazioni_chiuse gia esistente: nessuna modifica';
GO
IF OBJECT_ID(N'bot1.bot1_trades', N'U') IS NOT NULL
BEGIN
    INSERT INTO [bot1].[bot1_operazioni_chiuse]
        ([TradeId], [Symbol], [Strategy], [IsLong], [StopLoss], [TargetPrice], [ExitReason], [EntryPrice],
         [ExitPrice], [Profit], [ProfitPercentage], [Status], [OpenTime], [CloseTime])
    SELECT t.[Id], t.[Symbol], t.[Strategy], t.[IsLong], t.[StopLoss], t.[TargetPrice], t.[ExitReason], t.[EntryPrice],
           t.[ExitPrice], t.[Profit], t.[ProfitPercentage], t.[Status], t.[OpenTime], t.[CloseTime]
    FROM [bot1].[bot1_trades] t
    WHERE t.[Status] = N'Closed' AND t.[CloseTime] IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [bot1].[bot1_operazioni_chiuse] c WHERE c.[TradeId] = t.[Id])
    ORDER BY t.[CloseTime];
    PRINT 'Operazioni chiuse copiate da bot1.bot1_trades: ' + CAST(@@ROWCOUNT AS nvarchar(20));
END
GO
