# Esegue rinomina-tabelle.sql su (localdb)\MSSQLLocalDB e scrive l'esito in rinomina-tabelle-log.txt
# ATTENZIONE: fermare il Bot 1 prima di eseguirlo e riavviarlo con la build aggiornata.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'rinomina-tabelle-log.txt'
"=== RINOMINA TABELLE $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $log -Encoding utf8
try {
    $sql = Get-Content (Join-Path $dir 'rinomina-tabelle.sql') -Raw
    $batches = [regex]::Split($sql, '(?m)^\s*GO\s*$') | Where-Object { $_.Trim() -ne '' }
    $conn = New-Object System.Data.SqlClient.SqlConnection 'Server=(localdb)\MSSQLLocalDB;Database=master;Integrated Security=True'
    $conn.add_InfoMessage({ param($s, $e) $e.Message | Out-File $log -Append -Encoding utf8 })
    $conn.Open()
    foreach ($b in $batches) {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $b; [void]$cmd.ExecuteNonQuery()
    }
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT SCHEMA_NAME(t.schema_id) + '.' + t.name + ' righe=' + CAST((SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = t.object_id AND p.index_id IN (0,1)) AS varchar(20)) FROM sys.tables t WHERE t.schema_id = SCHEMA_ID(N'bot1') ORDER BY 1"
    $r = $cmd.ExecuteReader(); "Tabelle:" | Out-File $log -Append -Encoding utf8
    while ($r.Read()) { "  " + $r.GetString(0) | Out-File $log -Append -Encoding utf8 }
    $r.Close(); $conn.Close()
    "OK" | Out-File $log -Append -Encoding utf8
} catch {
    "ERRORE: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}
