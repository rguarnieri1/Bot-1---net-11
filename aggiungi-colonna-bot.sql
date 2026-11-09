-- Aggiunge alle tabelle bot1.Trades, bot1.Signals e bot1.Cycles la colonna Bot con valore fisso 'Bot 1'
-- (default del database: le righe gia presenti e quelle nuove scritte dal bot ricevono 'Bot 1').
-- Non fa nulla sulle tabelle che hanno gia la colonna.
USE [bot];
GO
IF COL_LENGTH(N'bot1.Trades', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[Trades] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Trades_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.Trades';
END
GO
IF COL_LENGTH(N'bot1.Signals', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[Signals] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Signals_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.Signals';
END
GO
IF COL_LENGTH(N'bot1.Cycles', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[Cycles] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Cycles_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.Cycles';
END
GO
