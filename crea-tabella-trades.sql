-- Tabella bot1.bot1_trades del Bot 1, con gli stessi campi della classe Trade (Models/Cryptocurrency.cs)
-- e la stessa mappatura di Data/BotDbContext.cs. Lo script non fa nulla se la tabella esiste già.
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot1') IS NULL
    EXEC(N'CREATE SCHEMA [bot1]');
GO
IF OBJECT_ID(N'bot1.bot1_trades', N'U') IS NULL
BEGIN
    CREATE TABLE [bot1].[bot1_trades] (
        [Id]               nvarchar(36)    NOT NULL,
        [Symbol]           nvarchar(50)    NULL,
        [OpenTime]         datetime2       NOT NULL,
        [CloseTime]        datetime2       NULL,
        [EntryPrice]       decimal(38, 18) NOT NULL,
        [ExitPrice]        decimal(38, 18) NULL,
        [Strategy]         nvarchar(200)   NULL,
        [Status]           nvarchar(20)    NULL,
        [Profit]           decimal(38, 18) NULL,
        [ProfitPercentage] decimal(38, 18) NULL,
        [IsLong]           bit             NOT NULL,
        [StopLoss]         decimal(38, 18) NOT NULL,
        [TargetPrice]      decimal(38, 18) NOT NULL,
        [PositionSize]     decimal(38, 18) NOT NULL,
        [SignalCandleTime] datetime2       NULL,
        [ExitReason]       nvarchar(100)   NULL,
        [Bot]                nvarchar(50)    NOT NULL CONSTRAINT [DF_Trades_Bot] DEFAULT (N'Bot 1'), -- bot che ha scritto la riga
        CONSTRAINT [PK_Trades] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_Trades_Symbol_Status] ON [bot1].[bot1_trades] ([Symbol], [Status]);
    PRINT 'Tabella bot1.bot1_trades creata';
END
ELSE
    PRINT 'Tabella bot1.bot1_trades gia esistente: nessuna modifica';
GO
