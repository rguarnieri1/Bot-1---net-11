# Importa nel database "bot" i cicli del Bot 1 gia presenti su file:
#   Logs\cycles_*.log -> bot1.bot1_cycles
# Trade, segnali e operazioni chiuse sono gia nel database e non vengono toccati.
# Si puo rieseguire: i cicli gia presenti (stesso orario di inizio) non vengono duplicati.
# L'esito viene scritto in importa-cicli-bot1-log.txt.
param([string]$BinDir)

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BinDir) { $BinDir = Join-Path $dir 'bin\Release\net11.0' }
$log = Join-Path $dir 'importa-cicli-bot1-log.txt'
$inv = [Globalization.CultureInfo]::InvariantCulture
function Log($m) { $m | Out-File $log -Append -Encoding utf8; $m }
"=== IMPORTA CICLI BOT 1 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8

function ToDec($s) { [decimal]::Parse(($s -replace ',', '.'), $inv) }
function TfSpan($tf) {
    if ($tf -match '^(\d+)([mhd])$') {
        $n = [int]$Matches[1]
        switch ($Matches[2]) { 'm' { return [TimeSpan]::FromMinutes($n) } 'h' { return [TimeSpan]::FromHours($n) } 'd' { return [TimeSpan]::FromDays($n) } }
    }
    return [TimeSpan]::FromDays(1)
}
function AddParam($cmd, $name, $type, $value) {
    $p = $cmd.Parameters.Add($name, $type)
    if ($type -eq [Data.SqlDbType]::Decimal) { $p.Precision = 38; $p.Scale = 18 }
    if ($null -eq $value) { $p.Value = [DBNull]::Value } else { $p.Value = $value }
}

$T = [Data.SqlDbType]
try {
    $cycles = New-Object System.Collections.ArrayList
    $c = $null; $inRej = $false
    foreach ($f in Get-ChildItem (Join-Path $BinDir 'Logs') -Filter 'cycles_*.log' -ErrorAction SilentlyContinue | Sort-Object Name) {
        foreach ($raw in Get-Content $f.FullName -Encoding utf8) {
            if ($raw -notmatch '^(\d\d:\d\d:\d\d) (.*)$') { $inRej = $false; continue }
            $hms = $Matches[1]; $line = $Matches[2]

            if ($line -match 'Ciclo #(\d+) - (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) UTC') {
                $c = @{ Number = [int]$Matches[1]; Start = [datetime]::ParseExact($Matches[2], 'yyyy-MM-dd HH:mm:ss', $inv); End = $null
                        Timeframe = $null; NewCandle = $false; Candle = $null; Regime = $null; Cryptos = $null
                        Closed = 0; Found = 0; Filtered = 0; Open = 0; Capital = [decimal]0; Pnl = [decimal]0
                        Rej = (New-Object System.Collections.ArrayList); Error = $null }
                [void]$cycles.Add($c); $inRej = $false; continue
            }
            if ($null -eq $c) { continue }

            if ($inRej) {
                if ($line -match '^\s+\S (.+): (\d+)$') {
                    [void]$c.Rej.Add('"' + $Matches[1].Replace('\', '\\').Replace('"', '\"') + '":' + $Matches[2]); continue
                }
                $inRej = $false
            }

            # Fine del ciclo = orario della riga, sulla data di inizio (o il giorno dopo se si e passata la mezzanotte)
            $at = $c.Start.Date + [TimeSpan]::Parse($hms)
            if ($at -lt $c.Start.AddSeconds(-1)) { $at = $at.AddDays(1) }

            if ($line -match 'Candela (\S+) chiusa alle (\d{4}-\d\d-\d\d \d\d:\d\d) UTC: ricerca segnali') {
                $c.Timeframe = $Matches[1]; $c.NewCandle = $true
                $c.Candle = [datetime]::ParseExact($Matches[2], 'yyyy-MM-dd HH:mm', $inv) - (TfSpan $Matches[1])
            }
            elseif ($line -match 'Nessuna candela (\S+) appena chiusa.*\((\d{4}-\d\d-\d\d \d\d:\d\d) UTC\)') {
                $c.Timeframe = $Matches[1]; $span = TfSpan $Matches[1]
                $c.Candle = [datetime]::ParseExact($Matches[2], 'yyyy-MM-dd HH:mm', $inv) - $span - $span
            }
            # Maiuscole rispettate: "contro il regime BTC: 2" e una riga dei motivi di scarto, non il regime
            elseif ($line -cmatch 'Regime BTC: ([a-z]+)') { $r = $Matches[1]; $c.Regime = $r.Substring(0, 1).ToUpper() + $r.Substring(1) }
            elseif ($line -match 'Analizzando (\d+) criptovalute') { $c.Cryptos = [int]$Matches[1] }
            elseif ($line -match 'Ciclo completato') { $c.End = $at }
            elseif ($line -match 'Trade chiusi \(stop/target\): (\d+)') { $c.Closed = [int]$Matches[1] }
            elseif ($line -match 'Segnali trovati: (\d+)') { $c.Found = [int]$Matches[1] }
            elseif ($line -match 'Segnali filtrati \(rischio\): (\d+)') { $c.Filtered = [int]$Matches[1] }
            elseif ($line -match 'Trade aperti: (\d+) \(capitale impegnato \D?(-?[\d.,]+)\)') { $c.Open = [int]$Matches[1]; $c.Capital = ToDec $Matches[2] }
            elseif ($line -match 'P&L realizzato: \D?(-?[\d.,]+)') { $c.Pnl = ToDec $Matches[1] }
            elseif ($line -match 'Motivi di scarto in questo ciclo') { $inRej = $true }
            elseif ($line -match 'Errore nel controllo del mercato: (.*)$') { $c.Error = $Matches[1]; $c.End = $at }
        }
        $inRej = $false
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection 'Server=(localdb)\MSSQLLocalDB;Database=bot;Integrated Security=True'
    $conn.Open()
    $tx = $conn.BeginTransaction()
    $n = 0
    foreach ($c in $cycles) {
        $rej = $null; if ($c.Rej.Count -gt 0) { $rej = '{' + ($c.Rej -join ',') + '}' }
        $cmd = $conn.CreateCommand(); $cmd.Transaction = $tx
        $cmd.CommandText = @"
IF NOT EXISTS (SELECT 1 FROM bot1.bot1_cycles WHERE StartTime >= @Start AND StartTime < DATEADD(second, 1, @Start))
INSERT INTO bot1.bot1_cycles (CycleNumber, StartTime, EndTime, Timeframe, NewCandle, SignalCandleTime, BtcRegime, CryptosAnalyzed,
                              TradesClosed, SignalsFound, SignalsFiltered, OpenTrades, CapitalCommitted, RealizedPnl, RejectionCounts, Error, Bot)
VALUES (@Number, @Start, @End, @Timeframe, @NewCandle, @Candle, @Regime, @Cryptos,
        @Closed, @Found, @Filtered, @Open, @Capital, @Pnl, @Rej, @Error, N'Bot 1')
"@
        foreach ($p in @(
            @('@Number', $T::Int, $c.Number), @('@Start', $T::DateTime2, $c.Start), @('@End', $T::DateTime2, $c.End),
            @('@Timeframe', $T::NVarChar, $c.Timeframe), @('@NewCandle', $T::Bit, $c.NewCandle), @('@Candle', $T::DateTime2, $c.Candle),
            @('@Regime', $T::NVarChar, $c.Regime), @('@Cryptos', $T::Int, $c.Cryptos), @('@Closed', $T::Int, $c.Closed),
            @('@Found', $T::Int, $c.Found), @('@Filtered', $T::Int, $c.Filtered), @('@Open', $T::Int, $c.Open),
            @('@Capital', $T::Decimal, $c.Capital), @('@Pnl', $T::Decimal, $c.Pnl), @('@Rej', $T::NVarChar, $rej), @('@Error', $T::NVarChar, $c.Error))) {
            AddParam $cmd $p[0] $p[1] $p[2]
        }
        $n += [Math]::Max(0, $cmd.ExecuteNonQuery())
    }
    $tx.Commit()
    $conn.Close()
    Log "Cycles: $($cycles.Count) nei log, $n inseriti"
    Log "OK"
} catch {
    if ($tx) { try { $tx.Rollback() } catch {} }
    Log "ERRORE: $($_.Exception.Message) (riga $($_.InvocationInfo.ScriptLineNumber))"
}
