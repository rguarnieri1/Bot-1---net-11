using BotCripto.Models;
using Microsoft.EntityFrameworkCore;

namespace BotCripto.Data;

// Contesto Entity Framework sul database SQL Server "bot" (autenticazione Windows).
// Le tabelle del Bot 1 stanno nello schema "bot1", così il database può essere condiviso con gli altri bot.
public class BotDbContext : DbContext
{
    public const string Schema = "bot1";

    private readonly string _connectionString;

    public BotDbContext(string connectionString)
    {
        _connectionString = connectionString;
    }

    public DbSet<Trade> Trades => Set<Trade>();

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseSqlServer(_connectionString, sql => sql.EnableRetryOnFailure(3));
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(Schema);

        modelBuilder.Entity<Trade>(e =>
        {
            e.ToTable("Trades");
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
            e.HasIndex(t => new { t.Symbol, t.Status });
        });
    }
}
