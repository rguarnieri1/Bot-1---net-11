using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Newtonsoft.Json.Linq;

namespace BotCripto.Data;

// Legge la stringa di connessione da appsettings.json (sovrascrivibile in appsettings.local.json)
// e apre la connessione al database (lo crea se manca); l'esistenza delle tabelle non viene controllata.
public static class BotDatabase
{
    public static string? ConnectionString { get; private set; }
    public static bool IsAvailable { get; private set; }

    public static BotDbContext CreateContext() =>
        new(ConnectionString ?? throw new InvalidOperationException("Database non configurato"));

    private static bool _initialized;

    // Chiamato all'avvio del bot (Program.cs) e poi dal ReportingService: la connessione viene provata una sola volta.
    // Nel log scrive solo l'esito della connessione.
    public static bool Initialize()
    {
        if (_initialized) return IsAvailable;
        _initialized = true;

        ConnectionString = ReadConnectionString();
        if (string.IsNullOrWhiteSpace(ConnectionString))
        {
            Console.WriteLine("❌ Database non connesso: stringa di connessione BotDb vuota");
            return IsAvailable = false;
        }

        try
        {
            using var db = CreateContext();
            var creator = db.GetService<IRelationalDatabaseCreator>();
            if (!creator.Exists())
                creator.Create();

            using var conn = new SqlConnection(ConnectionString);
            conn.Open();
            Console.WriteLine($"✅ Connesso al database {conn.Database} su {conn.DataSource}");
            return IsAvailable = true;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Database non connesso: {ex.GetBaseException().Message}");
            return IsAvailable = false;
        }
    }

    private static string? ReadConnectionString()
    {
        string? result = null;
        foreach (var file in new[] { "appsettings.json", "appsettings.local.json" })
        {
            var path = Path.Combine(AppContext.BaseDirectory, file);
            if (!File.Exists(path)) continue;
            var value = JObject.Parse(File.ReadAllText(path)).SelectToken("ConnectionStrings.BotDb")?.Value<string>();
            if (value != null) result = value;
        }
        return result;
    }
}
