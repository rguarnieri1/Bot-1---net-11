-- Aggiunge alle tabelle bot1.bot1_trades, bot1.bot1_signals e bot1.bot1_cycles la colonna Bot con valore fisso 'Bot 1'
-- (default del database: le righe gia presenti e quelle nuove scritte dal bot ricevono 'Bot 1').
-- Non fa nulla sulle tabelle che hanno gia la colonna.
USE [bot];
GO
IF COL_LENGTH(N'bot1.bot1_trades', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[bot1_trades] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Trades_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.bot1_trades';
END
GO
IF COL_LENGTH(N'bot1.bot1_signals', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[bot1_signals] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Signals_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.bot1_signals';
END
GO
IF COL_LENGTH(N'bot1.bot1_cycles', N'Bot') IS NULL
BEGIN
    ALTER TABLE [bot1].[bot1_cycles] ADD [Bot] nvarchar(50) NOT NULL CONSTRAINT [DF_Cycles_Bot] DEFAULT (N'Bot 1') WITH VALUES;
    PRINT 'Colonna Bot aggiunta a bot1.bot1_cycles';
END
GO
