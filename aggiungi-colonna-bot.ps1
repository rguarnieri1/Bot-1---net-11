# Esegue aggiungi-colonna-bot.sql su (localdb)\MSSQLLocalDB e scrive l'esito in aggiungi-colonna-bot-log.txt
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'aggiungi-colonna-bot-log.txt'
"=== AGGIUNGI COLONNA BOT $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8
try {
    $sql = Get-Content (Join-Path $dir 'aggiungi-colonna-bot.sql') -Raw
    $batches = [regex]::Split($sql, '(?m)^\s*GO\s*$') | Where-Object { $_.Trim() -ne '' }
    $conn = New-Object System.Data.SqlClient.SqlConnection 'Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=True'
    $conn.add_InfoMessage({ param($s, $e) $e.Message | Out-File $log -Append -Encoding utf8 })
    $conn.Open()
    foreach ($b in $batches) {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $b; [void]$cmd.ExecuteNonQuery()
    }
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT o.name + '.' + c.name + ' ' + t.name + ' default ' + ISNULL(dc.definition,'') FROM sys.columns c JOIN sys.objects o ON o.object_id = c.object_id JOIN sys.types t ON t.user_type_id = c.user_type_id LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id WHERE c.name = 'Bot' AND SCHEMA_NAME(o.schema_id) = 'bot1' ORDER BY o.name"
    $r = $cmd.ExecuteReader(); "Colonne:" | Out-File $log -Append -Encoding utf8
    while ($r.Read()) { "  " + $r.GetString(0) | Out-File $log -Append -Encoding utf8 }
    $r.Close(); $conn.Close()
    "OK" | Out-File $log -Append -Encoding utf8
} catch {
    "ERRORE: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}
