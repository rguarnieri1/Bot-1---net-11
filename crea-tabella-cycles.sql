-- Tabella bot1.Cycles del Bot 1: un record per ogni ciclo di controllo del mercato (CheckMarketAsync),
-- con gli stessi dati del report "Ciclo completato" scritto in Logs/cycles_yyyy-MM-dd.log.
-- Non fa nulla se la tabella esiste gia.
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot1') IS NULL
    EXEC(N'CREATE SCHEMA [bot1]');
GO
IF OBJECT_ID(N'bot1.Cycles', N'U') IS NULL
BEGIN
    CREATE TABLE [bot1].[Cycles] (
        [Id]               bigint IDENTITY(1,1) NOT NULL,
        [CycleNumber]      int             NOT NULL, -- "Ciclo #N" (riparte da 1 a ogni avvio del bot)
        [StartTime]        datetime2       NOT NULL, -- inizio del ciclo (UTC)
        [EndTime]          datetime2       NULL,     -- fine del ciclo (UTC)
        [Timeframe]        nvarchar(10)    NULL,     -- es. 12h
        [NewCandle]        bit             NOT NULL, -- 1 = candela appena chiusa, ricerca segnali eseguita
        [SignalCandleTime] datetime2       NULL,     -- inizio dell'ultima candela chiusa (UTC)
        [BtcRegime]        nvarchar(20)    NULL,     -- Rialzista / Ribassista / Sconosciuto (solo con ricerca segnali)
        [CryptosAnalyzed]  int             NULL,     -- criptovalute analizzate (solo con ricerca segnali)
        [TradesClosed]     int             NOT NULL, -- trade chiusi su stop/target
        [SignalsFound]     int             NOT NULL, -- segnali trovati (trade aperti)
        [SignalsFiltered]  int             NOT NULL, -- segnali filtrati dal Risk Manager
        [OpenTrades]       int             NOT NULL, -- trade aperti a fine ciclo
        [CapitalCommitted] decimal(38, 18) NOT NULL, -- capitale impegnato nei trade aperti (EUR)
        [RealizedPnl]      decimal(38, 18) NOT NULL, -- P&L realizzato cumulativo (EUR)
        [RejectionCounts]  nvarchar(max)   NULL,     -- motivi di scarto del ciclo in JSON, es. {"Volume insufficiente": 120}
        [Error]            nvarchar(max)   NULL,     -- messaggio se il ciclo e terminato con errore
        [Bot]                nvarchar(50)    NOT NULL CONSTRAINT [DF_Cycles_Bot] DEFAULT (N'Bot 1'), -- bot che ha scritto la riga
        CONSTRAINT [PK_Cycles] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_Cycles_StartTime] ON [bot1].[Cycles] ([StartTime]);
    PRINT 'Tabella bot1.Cycles creata';
END
ELSE
    PRINT 'Tabella bot1.Cycles gia esistente: nessuna modifica';
GO
