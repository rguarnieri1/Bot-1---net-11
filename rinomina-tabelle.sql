-- Rinomina le tabelle del Bot 1 nello schema bot1:
--   bot1.Trades -> bot1.bot1_trades, bot1.Signals -> bot1.bot1_signals, bot1.Cycles -> bot1.bot1_cycles
-- I dati, gli indici e i vincoli restano invariati. Non fa nulla sulle tabelle gia rinominate.
-- Il confronto dei nomi e binario (COLLATE Latin1_General_BIN) cosi lo script funziona anche
-- se il database non distingue maiuscole e minuscole.
USE [bot];
GO
IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'bot1') AND name COLLATE Latin1_General_BIN = N'Trades')
BEGIN
    EXEC sp_rename N'bot1.Trades', N'bot1_trades';
    PRINT 'Tabella bot1.Trades rinominata in bot1.bot1_trades';
END
GO
IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'bot1') AND name COLLATE Latin1_General_BIN = N'Signals')
BEGIN
    EXEC sp_rename N'bot1.Signals', N'bot1_signals';
    PRINT 'Tabella bot1.Signals rinominata in bot1.bot1_signals';
END
GO
IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'bot1') AND name COLLATE Latin1_General_BIN = N'Cycles')
BEGIN
    EXEC sp_rename N'bot1.Cycles', N'bot1_cycles';
    PRINT 'Tabella bot1.Cycles rinominata in bot1.bot1_cycles';
END
GO
