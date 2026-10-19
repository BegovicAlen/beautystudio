using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace BeautyStudio.Api.Data;

public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<BeautyStudioDbContext>
{
    public BeautyStudioDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
            ?? throw new InvalidOperationException("CONNECTION_STRING must be set before creating a migration.");
        return new BeautyStudioDbContext(new DbContextOptionsBuilder<BeautyStudioDbContext>().UseSqlServer(connectionString).Options);
    }
}
