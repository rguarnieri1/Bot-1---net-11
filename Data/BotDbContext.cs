using BotCripto.Models;
using Microsoft.EntityFrameworkCore;

namespace BotCripto.Data;

// Contesto Entity Framework sul database SQL Server "bot" (autenticazione Windows).
// Le tabelle del Bot 1 stanno nello schema "bot1", così il database può essere condiviso con gli altri bot.
public class BotDbContext : DbContext
{
    public const string Schema = "bot1";

    // Valore fisso della colonna Bot nelle tabelle bot1.bot1_trades, bot1.bot1_signals e bot1.bot1_cycles
    public const string BotName = "Bot 1";

    private readonly string _connectionString;

    public BotDbContext(string connectionString)
    {
        _connectionString = connectionString;
    }

    public DbSet<Trade> Trades => Set<Trade>();
    public DbSet<SignalRecord> Signals => Set<SignalRecord>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseSqlServer(_connectionString, sql => sql.EnableRetryOnFailure(3));
    }

    // Prima di ogni salvataggio scrive "Bot 1" nella colonna Bot delle righe inserite o aggiornate
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        foreach (var entry in ChangeTracker.Entries())
            if (entry.State is EntityState.Added or EntityState.Modified
                && entry.Metadata.FindProperty(BotColumn) != null)
                entry.Property(BotColumn).CurrentValue = BotName;
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    private const string BotColumn = "Bot";

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(Schema);

        modelBuilder.Entity<Trade>(e =>
        {
            e.ToTable("bot1_trades");
            e.HasKey(t => t.Id);
            e.Property(t => t.Id).HasMaxLength(36);
            e.Property(t => t.Symbol).HasMaxLength(50).IsRequired(false);
            e.Property(t => t.Strategy).HasMaxLength(200).IsRequired(false);
            e.Property(t => t.Status).HasMaxLength(20).IsRequired(false);
            e.Property(t => t.ExitReason).HasMaxLength(100);

            // Prezzi e quantità delle crypto possono avere molte cifre decimali (es. 0.00000123)
            foreach (var p in new[] { nameof(Trade.EntryPrice), nameof(Trade.ExitPrice), nameof(Trade.StopLoss),
                                      nameof(Trade.TargetPrice), nameof(Trade.PositionSize), nameof(Trade.Profit),
                                      nameof(Trade.ProfitPercentage) })
                e.Property(p).HasPrecision(38, 18);

            e.Ignore(t => t.IsPaperManaged);
            e.Property<string>(BotColumn).HasMaxLength(50).IsRequired();
            e.HasIndex(t => new { t.Symbol, t.Status });
        });

        modelBuilder.Entity<SignalRecord>(e =>
        {
            e.ToTable("bot1_signals");
            e.HasKey(s => s.Id);
            e.Property(s => s.Id).UseIdentityColumn();
            e.Property(s => s.Symbol).HasMaxLength(50);
            e.Property(s => s.Strategy).HasMaxLength(200);
            e.Property(s => s.Signal).HasMaxLength(200);
            e.Property(s => s.Timeframe).HasMaxLength(10);
            e.Property(s => s.RejectionReason).HasMaxLength(100);
            e.Property(s => s.TradeId).HasMaxLength(36);

            foreach (var p in typeof(SignalRecord).GetProperties()
                         .Where(p => p.PropertyType == typeof(decimal) || p.PropertyType == typeof(decimal?)))
                e.Property(p.Name).HasPrecision(38, 18);

            e.Property<string>(BotColumn).HasMaxLength(50).IsRequired();
            e.HasIndex(s => new { s.Symbol, s.SignalCandleTime });
        });
    }
}
